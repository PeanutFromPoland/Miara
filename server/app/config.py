from functools import lru_cache
from typing import Literal

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "Miara API"
    database_url: str = "postgresql+psycopg://miara:change-me@localhost:5432/miara"
    jwt_secret: str = ""
    access_token_minutes: int = 15
    search_timeout_seconds: int = 300
    search_retention_days: int = 30
    ai_provider: Literal["openai", "lm_studio"] | None = None
    ai_base_url: str | None = None
    ai_model: str | None = None
    ai_api_key: str | None = None
    ai_connect_timeout_seconds: float = 5
    ai_read_timeout_seconds: float = 20
    recipe_discovery_url: str | None = None
    recipe_discovery_api_key: str | None = None
    recipe_source_terms_confirmed: bool = False
    source_content_processing_allowed: bool = False
    google_client_id: str | None = None

    @model_validator(mode="after")
    def validate_runtime_configuration(self):
        if len(self.jwt_secret) < 32:
            raise ValueError("JWT_SECRET musi mieć co najmniej 32 znaki.")
        if not 1 <= self.access_token_minutes <= 120:
            raise ValueError("ACCESS_TOKEN_MINUTES musi mieścić się w zakresie 1–120.")
        if not 1 <= self.search_timeout_seconds <= 300:
            raise ValueError("SEARCH_TIMEOUT_SECONDS musi mieścić się w zakresie 1–300.")
        if self.search_retention_days != 30:
            raise ValueError("SEARCH_RETENTION_DAYS jest obecnie ustalone na 30.")
        if self.ai_provider is None or not self.ai_base_url or not self.ai_model:
            raise ValueError("Wymagana konfiguracja AI_PROVIDER, AI_BASE_URL i AI_MODEL.")
        if self.ai_provider == "openai" and not self.ai_api_key:
            raise ValueError("AI_API_KEY jest wymagany dla dostawcy OpenAI.")
        if self.source_content_processing_allowed and not self.recipe_source_terms_confirmed:
            raise ValueError("Przetwarzanie treści źródła wymaga potwierdzenia jego warunków.")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
