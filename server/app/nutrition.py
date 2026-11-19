from datetime import datetime, timezone
import math


NUTRIENTS = ("kcal", "protein_g", "carbohydrate_g", "fat_g")


def estimate_recipe(ingredients: list[dict] | None, servings: float | None) -> dict:
    """Calculate only from explicit normalized quantities and a per-amount food snapshot."""
    missing: list[dict[str, str]] = []
    sums = {key: 0.0 for key in NUTRIENTS}
    incomplete = {key: False for key in NUTRIENTS}
    if not ingredients:
        missing.append({"field": "ingredients", "reason": "Brak danych o składnikach."})
        incomplete = {key: True for key in NUTRIENTS}
    for index, ingredient in enumerate(ingredients or []):
        field = f"ingredients[{index}]"
        quantity = ingredient.get("normalized_quantity")
        unit = ingredient.get("normalized_unit")
        snapshot = ingredient.get("nutrition_snapshot") or ingredient.get("nutrition")
        basis = ingredient.get("conversion_basis")
        identity_conversion = ingredient.get("unit") == unit and ingredient.get("quantity") == quantity
        if quantity is None or not isinstance(quantity, (int, float)) or not math.isfinite(quantity) or unit not in {"g", "ml"} or (not identity_conversion and not basis):
            missing.append({"field": f"{field}.quantity", "reason": "Brak ilości lub jawnej konwersji do g/ml."})
            incomplete = {key: True for key in NUTRIENTS}
            continue
        if not isinstance(snapshot, dict):
            missing.append({"field": f"{field}.nutrition", "reason": "Brak dopasowania produktu i danych żywieniowych."})
            incomplete = {key: True for key in NUTRIENTS}
            continue
        reference = snapshot.get("per_amount")
        reference_unit = snapshot.get("per_unit")
        if not isinstance(reference, (int, float)) or not math.isfinite(reference) or reference <= 0 or reference_unit != unit:
            missing.append({"field": f"{field}.nutrition.per_amount", "reason": "Nieznana lub niezgodna jednostka odniesienia."})
            incomplete = {key: True for key in NUTRIENTS}
            continue
        for key in NUTRIENTS:
            value = snapshot.get(key)
            if value is None:
                incomplete[key] = True
                missing.append({"field": f"{field}.nutrition.{key}", "reason": "Brak wartości w źródle żywieniowym."})
            elif isinstance(value, (int, float)) and math.isfinite(value) and value >= 0:
                sums[key] += float(value) * float(quantity) / float(reference)
            else:
                incomplete[key] = True
                missing.append({"field": f"{field}.nutrition.{key}", "reason": "Nieprawidłowa wartość w źródle żywieniowym."})
    total = {key: (None if incomplete[key] else round(value, 2)) for key, value in sums.items()}
    can_divide = isinstance(servings, (int, float)) and servings > 0
    if not can_divide:
        missing.append({"field": "servings", "reason": "Brak dodatniej liczby porcji."})
    per_serving = {key: (round(value / servings, 2) if value is not None and can_divide else None) for key, value in total.items()}
    return {
        "estimate_total": total,
        "estimate_per_serving": {
            **per_serving,
            "completeness": "complete" if all(value is not None for value in per_serving.values()) else "partial",
            "missing": [item["field"] for item in missing],
            "calculated_at": datetime.now(timezone.utc).isoformat(),
            "calculation_version": "1",
            "sources": _sources(ingredients),
        },
        "missing": missing,
    }


def _sources(ingredients: list[dict] | None) -> list[dict]:
    sources = []
    for ingredient in ingredients or []:
        snapshot = ingredient.get("nutrition_snapshot") or ingredient.get("nutrition") or {}
        if snapshot.get("source"):
            sources.append({"ingredient_id": ingredient.get("id"), "source": snapshot["source"],
                            "retrieved_at": snapshot.get("retrieved_at"), "product_id": snapshot.get("product_id")})
    return sources
