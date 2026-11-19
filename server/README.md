# Miara API

Serwer MVP w Pythonie/FastAPI z bazą PostgreSQL, migracją Alembic, trwałymi
sesjami odnawialnymi, izolacją kont, CRUD profilu/planu/dziennika i asynchronicznymi
zadaniami wyszukiwania. Schemat OpenAPI jest generowany przez FastAPI pod `/docs`.

## Uruchomienie

Wymagane są Python 3.11+ oraz PostgreSQL. Serwer nie tworzy schematu po cichu:
najpierw zastosuj migrację.

```powershell
cd server
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
# Ustaw DATABASE_URL, JWT_SECRET i działający AI_PROVIDER / AI_MODEL / AI_BASE_URL.
alembic upgrade head
uvicorn app.main:app --reload
```

`/health` sprawdza dostępność procesu. Przy starcie aplikacja sprawdza `/models`
wybranego dostawcy AI, ale niedostępność modelu nie blokuje uruchomienia API.
Wyszukiwanie przepisów, które wymaga ekstrakcji, zwraca wtedy niekompletny szablon
oznaczony `model_status: "fallback_template"` i ostrzeżenie
`MODEL_FALLBACK_TEMPLATE`. Szablon nie dopowiada składników ani wartości
żywieniowych; wymaga uzupełnienia danych ze źródła.

## Konfiguracja

- `DATABASE_URL` — PostgreSQL, np. `postgresql+psycopg://user:pass@host:5432/miara`.
- `JWT_SECRET` — losowy sekret o długości co najmniej 32 znaków.
- `ACCESS_TOKEN_MINUTES` — czas życia tokenu dostępu (domyślnie 15 minut).
- `SEARCH_TIMEOUT_SECONDS` — limit wyszukiwania (maksymalnie 300 sekund).
- `SEARCH_RETENTION_DAYS` — retencja statusu i wyników, ustalona na 30 dni.
- `AI_PROVIDER` — `openai` albo `lm_studio`; oba interfejsy korzystają z API zgodnego z OpenAI.
- `AI_BASE_URL`, `AI_MODEL`, `AI_API_KEY` — adres, model i opcjonalny klucz dostawcy.
- `RECIPE_DISCOVERY_URL` — opcjonalny adres adaptera wyszukiwania. Adapter przyjmuje kryteria JSON i zwraca `{ "results": [...], "warnings": [] }`.
- `RECIPE_DISCOVERY_API_KEY` — opcjonalny klucz adaptera wyszukiwania.
- `RECIPE_SOURCE_TERMS_CONFIRMED` — wymagane `true` przed włączeniem wbudowanego adaptera AniaGotuje, po sprawdzeniu aktualnych warunków serwisu.
- `SOURCE_CONTENT_PROCESSING_ALLOWED` — domyślnie `false`; zezwala na przekazanie krótkiego fragmentu strony do wybranego modelu po sprawdzeniu warunków źródła.
- `GOOGLE_CLIENT_ID` — opcjonalny identyfikator klienta do weryfikacji logowania Google.

Jeśli nie ustawiono `RECIPE_DISCOVERY_URL`, wbudowany adapter odczytuje sitemapę,
na bieżąco sprawdza `robots.txt`, respektuje `noindex`, ogranicza częstotliwość
żądań i zapisuje wyłącznie tytuł, URL oraz datę. Adapter wyszukiwania ma zwracać
kandydatów z `title`, `source.url`, `usage_status`
i opcjonalnym `extraction_input` (tymczasowy tekst strony). Obsługiwane źródło
jest ograniczone do HTTPS na `aniagotuje.pl`. Należy przestrzegać aktualnego
`robots.txt`, warunków serwisu, limitów i zasad użycia treści. Bez statusu
`licensed`, `permitted` lub `legal_basis_confirmed` trwale zapisywane są tylko
tytuł, URL, domena i data odczytu. AI może normalizować podane fakty, ale nie może
dopowiadać ilości, konwersji ani wartości żywieniowych. Konwersja do g/ml wymaga
`conversion_basis`; szacunki liczy wyłącznie moduł serwera z migawek produktu.

## Zaimplementowane zasoby

- Sesje: `POST /v1/auth/register`, `/login`, `/google`, `/refresh`, `/logout`, `GET /v1/me`.
- Profil: pełny CRUD pod `/v1/profile`.
- Przepisy i wyszukiwanie: `/v1/recipe-searches`, `/v1/recipes/{version_id}`,
  warianty, odczyt oszacowania i korekta dopasowania składnika.
- Plan i dziennik: dzienne odczyty oraz pełny CRUD wpisów pod `/v1/plan` i
  `/v1/diary`.

Prywatne mutacje wymagają `Authorization: Bearer ...` i nagłówka
`Idempotency-Key: <UUID>`. `PATCH` i `DELETE` wymagają `version`. Błędy zwracają
`code`, bezpieczny `message`, opcjonalne `details` oraz `request_id`.

## Granice obecnego MVP

Dokumentacja projektu pozostawia wybór dostawcy bazy żywieniowej, zasad haseł,
łączenia kont Google i miejsca OCR jako otwarte decyzje. Dlatego API nie udaje
integracji żywieniowej ani OCR; bez migawek wartości zwraca szacunek częściowy,
a bez adaptera lub potwierdzonych warunków źródła wyszukiwanie kończy się błędem
`SOURCE_UNAVAILABLE`. Kontrakt nie zawiera usuwania konta ani endpointu synchronizacji zbiorczej.
