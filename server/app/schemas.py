from __future__ import annotations

from datetime import date as Date
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class APIModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ErrorResponse(BaseModel):
    code: str
    message: str
    details: list | dict | None = None
    request_id: str


class SessionResponse(BaseModel):
    account_id: str
    session_id: str
    access_token: str
    access_expires_at: str
    refresh_token: str
    refresh_expires_at: str | None
    token_type: Literal["Bearer"]


class AccountResponse(BaseModel):
    id: str
    email: str
    created_at: str
    time_zone: str


class ProfileResponse(BaseModel):
    id: str
    daily_kcal_target: int
    protein_g_target: float | None
    carbohydrate_g_target: float | None
    fat_g_target: float | None
    meals_per_day: int | None
    preferences: list[str]
    excluded_products: list[str]
    allergens: list[str]
    version: int
    created_at: str
    updated_at: str


class RecipeSourceResponse(BaseModel):
    url: str
    domain: str
    retrieved_at: str


class RecipeCardResponse(BaseModel):
    recipe_version_id: str
    title: str
    source: RecipeSourceResponse | None
    estimate_per_serving: dict | None
    match: dict
    model_status: str | None = None


class PlanEntryResponse(BaseModel):
    id: str
    date: Date
    recipe_version_id: str
    servings: float
    estimate_snapshot: dict | None
    version: int
    created_at: str
    updated_at: str


class DiaryEntryResponse(BaseModel):
    id: str
    date: Date
    origin: Literal["plan", "manual", "label"]
    plan_entry_id: str | None
    recipe_version_id: str | None
    name: str | None
    quantity: float | None
    unit: str | None
    nutrition_snapshot: dict
    version: int
    created_at: str
    updated_at: str


class DailyPlanResponse(BaseModel):
    date: Date
    entries: list[PlanEntryResponse]
    totals: dict
    next_cursor: str | None


class DailyDiaryResponse(BaseModel):
    date: Date
    entries: list[DiaryEntryResponse]
    totals: dict
    next_cursor: str | None


class SearchCreatedResponse(BaseModel):
    search_id: str
    status: Literal["pending"]
    created_at: str
    deadline_at: str


class SearchResponse(BaseModel):
    search_id: str
    status: Literal["pending", "running", "completed", "partial", "failed", "cancelling", "cancelled"]
    results: list[RecipeCardResponse]
    next_cursor: str | None
    warnings: list[str]
    error: dict | None
    created_at: str
    deadline_at: str
    finished_at: str | None
    expires_at: str | None


class CancelSearchResponse(BaseModel):
    search_id: str
    status: Literal["pending", "running", "partial", "failed", "cancelling", "cancelled", "completed"]


class RegisterRequest(APIModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=8, max_length=256)

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        value = value.strip().lower()
        if value.count("@") != 1 or "." not in value.rsplit("@", 1)[-1]:
            raise ValueError("Podaj prawidłowy adres email.")
        return value


class LoginRequest(RegisterRequest):
    password: str = Field(min_length=1, max_length=256)


class RefreshRequest(APIModel):
    refresh_token: str = Field(min_length=32, max_length=512)


class GoogleAuthRequest(APIModel):
    credential: str = Field(min_length=20, max_length=8192)


class ProfileInput(APIModel):
    id: UUID
    daily_kcal_target: int = Field(gt=0, le=10000)
    protein_g_target: float | None = Field(default=None, ge=0, le=1000)
    carbohydrate_g_target: float | None = Field(default=None, ge=0, le=2000)
    fat_g_target: float | None = Field(default=None, ge=0, le=1000)
    meals_per_day: int | None = Field(default=None, ge=1, le=20)
    preferences: list[str] = Field(default_factory=list, max_length=100)
    excluded_products: list[str] = Field(default_factory=list, max_length=100)
    allergens: list[str] = Field(default_factory=list, max_length=100)


class ProfilePatch(APIModel):
    version: int = Field(ge=1)
    daily_kcal_target: int | None = Field(default=None, gt=0, le=10000)
    protein_g_target: float | None = Field(default=None, ge=0, le=1000)
    carbohydrate_g_target: float | None = Field(default=None, ge=0, le=2000)
    fat_g_target: float | None = Field(default=None, ge=0, le=1000)
    meals_per_day: int | None = Field(default=None, ge=1, le=20)
    preferences: list[str] | None = Field(default=None, max_length=100)
    excluded_products: list[str] | None = Field(default=None, max_length=100)
    allergens: list[str] | None = Field(default=None, max_length=100)

    @model_validator(mode="after")
    def validate_nullability(self):
        if "daily_kcal_target" in self.model_fields_set and self.daily_kcal_target is None:
            raise ValueError("daily_kcal_target nie może być null.")
        for field_name in ("preferences", "excluded_products", "allergens"):
            if field_name in self.model_fields_set and getattr(self, field_name) is None:
                raise ValueError(f"{field_name} nie może być null; użyj pustej listy.")
        return self


class VersionInput(APIModel):
    version: int = Field(ge=1)


class PlanEntryInput(APIModel):
    id: UUID
    date: Date
    recipe_version_id: str = Field(min_length=1, max_length=64)
    servings: float = Field(gt=0, le=100)


class PlanEntryPatch(APIModel):
    version: int = Field(ge=1)
    date: Date | None = None
    recipe_version_id: str | None = Field(default=None, min_length=1, max_length=64)
    servings: float | None = Field(default=None, gt=0, le=100)

    @model_validator(mode="after")
    def validate_non_null_updates(self):
        for field_name in ("date", "recipe_version_id", "servings"):
            if field_name in self.model_fields_set and getattr(self, field_name) is None:
                raise ValueError(f"{field_name} nie może być null.")
        return self


class NutritionValues(APIModel):
    kcal: float | None = Field(default=None, ge=0)
    protein_g: float | None = Field(default=None, ge=0)
    carbohydrate_g: float | None = Field(default=None, ge=0)
    fat_g: float | None = Field(default=None, ge=0)
    completeness: Literal["complete", "partial"] = "partial"
    missing: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_completeness(self):
        values = (self.kcal, self.protein_g, self.carbohydrate_g, self.fat_g)
        has_missing_values = any(value is None for value in values)
        if self.completeness == "complete" and (has_missing_values or self.missing):
            raise ValueError("Kompletny szacunek wymaga wszystkich wartości i pustej listy missing.")
        if self.completeness == "partial" and not (has_missing_values or self.missing):
            raise ValueError("Pełne wartości należy oznaczyć jako complete.")
        return self


class DiaryEntryInput(APIModel):
    id: UUID
    date: Date
    origin: Literal["plan", "manual", "label"]
    plan_entry_id: UUID | None = None
    recipe_version_id: str | None = Field(default=None, max_length=64)
    name: str | None = Field(default=None, max_length=500)
    quantity: float | None = Field(default=None, gt=0, le=100000)
    unit: str | None = Field(default=None, max_length=40)
    nutrition_snapshot: NutritionValues

    @model_validator(mode="after")
    def validate_source(self):
        if self.origin == "plan" and self.plan_entry_id is None:
            raise ValueError("plan_entry_id jest wymagane dla wpisu z planu.")
        if self.origin != "plan" and self.plan_entry_id is not None:
            raise ValueError("plan_entry_id można podać wyłącznie dla wpisu pochodzącego z planu.")
        if self.origin in {"manual", "label"} and self.name is None:
            raise ValueError("name jest wymagane dla wpisu ręcznego lub z etykiety.")
        return self


class DiaryEntryPatch(APIModel):
    version: int = Field(ge=1)
    date: Date | None = None
    name: str | None = Field(default=None, max_length=500)
    quantity: float | None = Field(default=None, gt=0, le=100000)
    unit: str | None = Field(default=None, max_length=40)
    nutrition_snapshot: NutritionValues | None = None

    @model_validator(mode="after")
    def validate_non_null_updates(self):
        if "date" in self.model_fields_set and self.date is None:
            raise ValueError("date nie może być null.")
        if "nutrition_snapshot" in self.model_fields_set and self.nutrition_snapshot is None:
            raise ValueError("nutrition_snapshot nie może być null.")
        return self


class SearchCriteria(APIModel):
    dish_name: str | None = Field(default=None, max_length=200)
    max_time_minutes: int | None = Field(default=None, gt=0, le=1440)
    max_ingredient_count: int | None = Field(default=None, gt=0, le=200)
    kcal_per_serving: dict[str, float] | None = None
    protein_g_per_serving: dict[str, float] | None = None
    carbohydrate_g_per_serving: dict[str, float] | None = None
    fat_g_per_serving: dict[str, float] | None = None
    limit: int = Field(default=20, ge=1, le=100)

    @model_validator(mode="after")
    def validate_ranges(self):
        for field_name in ("kcal_per_serving", "protein_g_per_serving", "carbohydrate_g_per_serving", "fat_g_per_serving"):
            value = getattr(self, field_name)
            if value is None:
                continue
            if set(value) - {"min", "max"} or not value:
                raise ValueError(f"{field_name} dopuszcza tylko min i max.")
            if any(v < 0 for v in value.values()):
                raise ValueError(f"{field_name} nie może zawierać wartości ujemnych.")
            if "min" in value and "max" in value and value["min"] > value["max"]:
                raise ValueError(f"min nie może być większe niż max dla {field_name}.")
        return self


class RecipeVariantInput(APIModel):
    changes: list[dict] = Field(min_length=1, max_length=100)
    servings: float | None = Field(default=None, gt=0, le=1000)
    ingredients: list["RecipeIngredientInput"] | None = Field(default=None, max_length=200)
    approved: bool = False


class RecipeIngredientInput(APIModel):
    id: str | None = Field(default=None, max_length=64)
    name: str = Field(min_length=1, max_length=300)
    quantity: float | None = Field(default=None, ge=0)
    unit: str | None = Field(default=None, max_length=40)
    normalized_quantity: float | None = Field(default=None, ge=0)
    normalized_unit: Literal["g", "ml"] | None = None
    conversion_basis: str | None = Field(default=None, max_length=500)
    review_state: str = "unverified"

    @model_validator(mode="after")
    def validate_normalization(self):
        if self.normalized_quantity is not None and (self.normalized_unit is None or not self.conversion_basis):
            raise ValueError("Konwersja wymaga jednostki g/ml i jawnej conversion_basis.")
        return self


class MatchInput(APIModel):
    version: int = Field(ge=1)
    product_id: str | None = Field(default=None, max_length=255)
    product_name: str | None = Field(default=None, max_length=500)
    quantity: float | None = Field(default=None, gt=0)
    unit: str | None = Field(default=None, max_length=40)

