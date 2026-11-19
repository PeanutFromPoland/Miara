"""Validate the design contract locally; no backend or external service is called."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
LOCAL_PACKAGES = ROOT / ".tools" / "openapi-validation"
if LOCAL_PACKAGES.is_dir():
    sys.path.insert(0, str(LOCAL_PACKAGES))

# The validator opens bundled local schemas through urllib. It needs no TLS
# key logging; an inherited antivirus key-log path can otherwise deny access.
os.environ.pop("SSLKEYLOGFILE", None)

from jsonschema import Draft202012Validator, FormatChecker
from openapi_spec_validator import validate


class OpenAPIContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads((ROOT / "docs/api/openapi.json").read_text(encoding="utf-8"))
        cls.cases = json.loads(
            (ROOT / "docs/api/contract-cases.json").read_text(encoding="utf-8")
        )["cases"]
        cls.schemas = cls.spec["components"]["schemas"]

    def resolve(self, reference):
        self.assertTrue(reference.startswith("#/"), "Only local references are allowed")
        value = self.spec
        for part in reference[2:].split("/"):
            value = value[part.replace("~1", "/").replace("~0", "~")]
        return value

    def validator(self, schema):
        # References remain rooted in the complete contract, including nullable
        # branches and oneOf discriminators; they are not flattened away.
        return Draft202012Validator(
            {**schema, "components": self.spec["components"]},
            format_checker=FormatChecker(),
        )

    def assert_valid(self, schema, value):
        errors = sorted(self.validator(schema).iter_errors(value), key=lambda e: str(e.path))
        self.assertEqual([], [f"{list(e.path)}: {e.message}" for e in errors])

    def operations(self):
        for path, item in self.spec["paths"].items():
            for method, operation in item.items():
                if method in {"get", "post", "put", "patch", "delete"}:
                    yield path, method, operation

    def test_openapi_standard(self):
        validate(self.spec)

    def test_schema_definitions(self):
        for name, schema in self.schemas.items():
            with self.subTest(schema=name):
                Draft202012Validator.check_schema(schema)

    def test_markdown_operation_index_matches_spec(self):
        description = (ROOT / "docs/kontrakt-api.md").read_text(encoding="utf-8")
        index = re.findall(r"^\| `(GET|POST|PATCH|DELETE)` \| `([^`]+)` \|", description, re.M)
        self.assertEqual(len(index), len(set(index)), "Duplicate operation in Markdown")
        self.assertEqual(
            {(method.upper(), path) for path, method, _ in self.operations()}, set(index)
        )

    def test_all_references_resolve_locally(self):
        def visit(value):
            if isinstance(value, dict):
                if "$ref" in value:
                    self.resolve(value["$ref"])
                for child in value.values():
                    visit(child)
            elif isinstance(value, list):
                for child in value:
                    visit(child)

        visit(self.spec)

    def test_component_examples(self):
        for name, example in self.spec["components"]["examples"].items():
            schema_name = name if name in self.schemas else "Error"
            with self.subTest(example=name):
                self.assert_valid(
                    {"$ref": f"#/components/schemas/{schema_name}"}, example["value"]
                )

    def test_request_and_response_examples(self):
        for path, method, operation in self.operations():
            messages = []
            if "requestBody" in operation:
                messages.append(("request", operation["requestBody"]))
            for status, response in operation["responses"].items():
                if "$ref" in response:
                    response = self.resolve(response["$ref"])
                messages.append((status, response))
            for label, message in messages:
                for media_type, media in message.get("content", {}).items():
                    if media_type != "application/json":
                        continue
                    self.assertTrue(media.get("examples"), f"Missing example: {path} {label}")
                    for name, example in media["examples"].items():
                        if "$ref" in example:
                            example = self.resolve(example["$ref"])
                        with self.subTest(path=path, method=method, message=label, example=name):
                            self.assert_valid(media["schema"], example["value"])

    def test_regression_cases(self):
        names = set()
        for case in self.cases:
            self.assertNotIn(case["name"], names)
            names.add(case["name"])
            with self.subTest(case=case["name"]):
                validator = self.validator({"$ref": f"#/components/schemas/{case['schema']}"})
                self.assertEqual(case["valid"], validator.is_valid(case["value"]))

    def test_operation_ids_paths_and_deletions(self):
        ids = set()
        for path, method, operation in self.operations():
            self.assertNotIn(operation["operationId"], ids)
            ids.add(operation["operationId"])
            parameters = [
                self.resolve(p["$ref"]) if "$ref" in p else p
                for p in operation.get("parameters", [])
            ]
            placeholders = set(re.findall(r"\{([^}]+)\}", path))
            declared = {p["name"] for p in parameters if p["in"] == "path"}
            self.assertEqual(placeholders, declared)
            if method == "delete":
                self.assertNotIn("requestBody", operation)
                self.assertIn("version", {p["name"] for p in parameters if p["in"] == "query"})
                self.assertNotIn("content", operation["responses"]["204"])
        profile_delete = self.spec["paths"]["/v1/profile"]["delete"]
        self.assertIn(
            "id", {self.resolve(p["$ref"])["name"] for p in profile_delete["parameters"]}
        )

    def test_domain_mutations_have_idempotency(self):
        for path, method, operation in self.operations():
            if method not in {"post", "patch", "delete"}:
                continue
            if path.startswith("/v1/auth/") or path == "/v1/labels/parse":
                continue
            names = {
                self.resolve(p["$ref"])["name"] if "$ref" in p else p["name"]
                for p in operation.get("parameters", [])
            }
            self.assertIn("Idempotency-Key", names, (path, method))
        self.assertIn("/v1/operations/{operation_id}", self.spec["paths"])
        self.assertIn("/v1/sync/changes", self.spec["paths"])

    def test_authentication_and_private_data_boundary(self):
        for path, _, operation in self.operations():
            security = operation.get("security", self.spec["security"])
            if not path.startswith("/v1/auth/") and path != "/v1/capabilities":
                self.assertEqual([{"bearerAuth": []}], security)
        self.assertNotIn("password_hash", self.schemas["Account"]["properties"])
        for name in ("ProfileCreate", "ProfilePatch", "PlanCreate", "PlanPatch", "DiaryFromPlan", "DiaryManual", "DiaryPatch"):
            self.assertNotIn("account_id", self.schemas[name]["properties"])
            self.assertFalse(self.schemas[name]["additionalProperties"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
