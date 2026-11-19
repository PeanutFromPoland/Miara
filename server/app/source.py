import json
import re
import time
import threading
import unicodedata
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from urllib.parse import urlparse
from urllib.robotparser import RobotFileParser

import httpx


BOT = "MiaraRecipeDiscovery/0.1"
ROOT = "https://aniagotuje.pl"
SITEMAP = ROOT + "/sitemap.xml"
_last_request_at = 0.0
_request_lock = threading.Lock()
_sitemap_cache: tuple[float, list[str]] | None = None


class MetadataParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.title = False
        self.title_text = []
        self.meta_title = None
        self.noindex = False
        self.ld_json = False
        self.ld_text = []
        self.is_recipe = False

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == "title":
            self.title = True
        if tag == "meta":
            name = (values.get("name") or "").lower()
            prop = (values.get("property") or "").lower()
            if prop == "og:title" and values.get("content"):
                self.meta_title = values["content"].strip()
            if name == "robots" and "noindex" in (values.get("content") or "").lower():
                self.noindex = True
        if tag == "script" and (values.get("type") or "").lower() == "application/ld+json":
            self.ld_json = True

    def handle_endtag(self, tag):
        if tag == "title":
            self.title = False
        if tag == "script" and self.ld_json:
            self.ld_json = False
            try:
                data = json.loads("".join(self.ld_text))
                self.is_recipe = self.is_recipe or _contains_recipe_type(data)
            except (ValueError, TypeError):
                pass
            self.ld_text.clear()

    def handle_data(self, data):
        if self.title:
            self.title_text.append(data.strip())
        if self.ld_json:
            self.ld_text.append(data)


def _contains_recipe_type(value) -> bool:
    if isinstance(value, dict):
        types = value.get("@type", [])
        if isinstance(types, str):
            types = [types]
        if any(str(item).casefold() == "recipe" for item in types):
            return True
        return any(_contains_recipe_type(item) for item in value.values())
    if isinstance(value, list):
        return any(_contains_recipe_type(item) for item in value)
    return False


def _allowed(url: str, robots: RobotFileParser) -> bool:
    parsed = urlparse(url)
    return parsed.scheme == "https" and parsed.hostname in {"aniagotuje.pl", "www.aniagotuje.pl"} and robots.can_fetch(BOT, url)


def _throttle():
    global _last_request_at
    with _request_lock:
        delay = 0.5 - (time.monotonic() - _last_request_at)
        if delay > 0:
            time.sleep(delay)
        _last_request_at = time.monotonic()


def _sitemap_urls(client: httpx.Client, robots: RobotFileParser, deadline: float) -> list[str]:
    global _sitemap_cache
    if _sitemap_cache and time.monotonic() - _sitemap_cache[0] < 21600:
        return list(_sitemap_cache[1])
    if not _allowed(SITEMAP, robots):
        raise PermissionError("Robots policy disallows the sitemap.")
    todo = [SITEMAP]
    found: list[str] = []
    visited: set[str] = set()
    while todo and len(visited) < 6 and time.monotonic() < deadline:
        sitemap = todo.pop(0)
        if sitemap in visited or not _allowed(sitemap, robots):
            continue
        visited.add(sitemap)
        _throttle()
        response = client.get(sitemap)
        response.raise_for_status()
        if len(response.content) > 8_000_000:
            raise ValueError("Sitemap exceeds the configured size limit.")
        root = ET.fromstring(response.content)
        for item in root.iter():
            if item.tag.endswith("sitemap"):
                loc = next((node.text for node in item if node.tag.endswith("loc") and node.text), None)
                if loc and urlparse(loc).hostname in {"aniagotuje.pl", "www.aniagotuje.pl"}:
                    todo.append(loc)
            elif item.tag.endswith("url"):
                loc = next((node.text for node in item if node.tag.endswith("loc") and node.text), None)
                if loc and urlparse(loc).hostname in {"aniagotuje.pl", "www.aniagotuje.pl"}:
                    found.append(loc)
                    if len(found) >= 10000:
                        return found
    if found:
        _sitemap_cache = (time.monotonic(), list(found))
    return found


def _normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", value.casefold())
    return "".join(ch for ch in value if not unicodedata.combining(ch))


def discover_metadata(criteria: dict, timeout: float) -> dict:
    """Discover only canonical URLs/titles; never stores page bodies or media."""
    deadline = time.monotonic() + timeout
    warnings: list[str] = []
    with httpx.Client(timeout=httpx.Timeout(timeout, connect=min(timeout, 5)), follow_redirects=False,
                      headers={"User-Agent": BOT}) as client:
        robots_url = ROOT + "/robots.txt"
        _throttle()
        robots_response = client.get(robots_url)
        robots_response.raise_for_status()
        robots = RobotFileParser(robots_url)
        robots.parse(robots_response.text.splitlines())
        urls = _sitemap_urls(client, robots, deadline)
        urls = list(dict.fromkeys(urls))
        if not urls:
            warnings.append("SOURCE_UNAVAILABLE")
        query = _normalize(criteria.get("dish_name") or "")
        terms = [term for term in re.findall(r"[a-z0-9]+", query) if len(term) > 1]
        urls = [url for url in urls if "/przepis" in urlparse(url).path.casefold()]
        matches = [url for url in urls if all(term in _normalize(urlparse(url).path) for term in terms)]
        if not terms:
            matches = urls
        if any(criteria.get(key) is not None for key in (
            "max_time_minutes", "max_ingredient_count", "kcal_per_serving", "protein_g_per_serving",
            "carbohydrate_g_per_serving", "fat_g_per_serving"
        )):
            warnings.append("CRITERIA_UNVERIFIABLE")
        results = []
        for url in matches:
            if len(results) >= min(int(criteria.get("limit", 20)), 20) or time.monotonic() >= deadline:
                break
            if not _allowed(url, robots):
                warnings.append("SOURCE_UNAVAILABLE")
                continue
            try:
                _throttle()
                with client.stream("GET", url) as response:
                    response.raise_for_status()
                    final = urlparse(str(response.url))
                    if final.scheme != "https" or final.hostname not in {"aniagotuje.pl", "www.aniagotuje.pl"}:
                        continue
                    body = bytearray()
                    for chunk in response.iter_bytes():
                        body.extend(chunk)
                        if len(body) > 1_000_000:
                            break
                parser = MetadataParser()
                parser.feed(body[:1_000_000].decode("utf-8", errors="replace"))
                if parser.noindex or "noindex" in response.headers.get("X-Robots-Tag", "").lower() or not parser.is_recipe:
                    continue
                title = parser.meta_title or " ".join(parser.title_text)
                title = re.sub(r"\s+", " ", title).strip()
                if not title:
                    warnings.append("SOURCE_MISSING_TITLE")
                    continue
                results.append({"title": title[:500], "source": {"url": url}, "usage_status": "metadata_only"})
            except (httpx.HTTPError, UnicodeError, ValueError):
                warnings.append("SOURCE_UNAVAILABLE")
        return {"results": results, "warnings": sorted(set(warnings))}
