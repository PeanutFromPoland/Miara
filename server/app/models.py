from datetime import date, datetime, timezone
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Index, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.types import JSON
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def json_type():
    # JSONB on PostgreSQL, portable JSON on SQLite for local development.
    return JSON().with_variant(JSONB(), "postgresql")


class Account(Base):
    __tablename__ = "accounts"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(512), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="active")
    time_zone: Mapped[str] = mapped_column(String(64), default="Europe/Warsaw")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)


class ExternalIdentity(Base):
    __tablename__ = "external_identities"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    provider: Mapped[str] = mapped_column(String(30))
    provider_subject: Mapped[str] = mapped_column(String(255))
    __table_args__ = (UniqueConstraint("provider", "provider_subject"),)


class SessionRecord(Base):
    __tablename__ = "sessions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    refresh_token_hash: Mapped[str] = mapped_column(String(64))
    access_expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    __table_args__ = (UniqueConstraint("refresh_token_hash"),)


class NutritionProfile(Base):
    __tablename__ = "nutrition_profiles"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), unique=True)
    daily_kcal_target: Mapped[int] = mapped_column(Integer)
    protein_g_target: Mapped[float | None] = mapped_column(Float, nullable=True)
    carbohydrate_g_target: Mapped[float | None] = mapped_column(Float, nullable=True)
    fat_g_target: Mapped[float | None] = mapped_column(Float, nullable=True)
    meals_per_day: Mapped[int | None] = mapped_column(Integer, nullable=True)
    preferences: Mapped[list] = mapped_column(json_type(), default=list)
    excluded_products: Mapped[list] = mapped_column(json_type(), default=list)
    allergens: Mapped[list] = mapped_column(json_type(), default=list)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)


class RecipeSource(Base):
    __tablename__ = "recipe_sources"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    canonical_url: Mapped[str] = mapped_column(Text, unique=True)
    title: Mapped[str] = mapped_column(String(500))
    source_domain: Mapped[str] = mapped_column(String(255))
    retrieved_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    usage_status: Mapped[str] = mapped_column(String(40), default="metadata_only")


class RecipeVersion(Base):
    __tablename__ = "recipe_versions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    source_id: Mapped[str] = mapped_column(ForeignKey("recipe_sources.id"), index=True)
    parent_version_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    created_by_account_id: Mapped[str | None] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), nullable=True, index=True)
    visibility: Mapped[str] = mapped_column(String(20), default="shared")
    kind: Mapped[str] = mapped_column(String(20), default="source")
    data: Mapped[dict] = mapped_column(json_type(), default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)


class SearchRequest(Base):
    __tablename__ = "search_requests"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    criteria: Mapped[dict] = mapped_column(json_type(), default=dict)
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    deadline_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    result_ids: Mapped[list] = mapped_column(json_type(), default=list)
    warnings: Mapped[list] = mapped_column(json_type(), default=list)
    error: Mapped[dict | None] = mapped_column(json_type(), nullable=True)
    cancel_requested: Mapped[bool] = mapped_column(Boolean, default=False)


class DailyPlanEntry(Base):
    __tablename__ = "daily_plan_entries"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    local_date: Mapped[date] = mapped_column(Date, index=True)
    recipe_version_id: Mapped[str] = mapped_column(ForeignKey("recipe_versions.id"))
    servings: Mapped[float] = mapped_column(Float)
    estimate_snapshot: Mapped[dict | None] = mapped_column(json_type(), nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)


class DiaryEntry(Base):
    __tablename__ = "diary_entries"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    local_date: Mapped[date] = mapped_column(Date, index=True)
    origin: Mapped[str] = mapped_column(String(20))
    plan_entry_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    recipe_version_id: Mapped[str | None] = mapped_column(ForeignKey("recipe_versions.id"), nullable=True)
    name: Mapped[str | None] = mapped_column(String(500), nullable=True)
    quantity: Mapped[float | None] = mapped_column(Float, nullable=True)
    unit: Mapped[str | None] = mapped_column(String(40), nullable=True)
    nutrition_snapshot: Mapped[dict] = mapped_column(json_type(), default=dict)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)


class OperationReceipt(Base):
    __tablename__ = "operation_receipts"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    account_id: Mapped[str] = mapped_column(ForeignKey("accounts.id", ondelete="CASCADE"), index=True)
    operation_id: Mapped[str] = mapped_column(String(36))
    request_hash: Mapped[str] = mapped_column(String(64))
    status_code: Mapped[int] = mapped_column(Integer)
    response_body: Mapped[dict | None] = mapped_column(json_type(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now_utc)
    __table_args__ = (UniqueConstraint("account_id", "operation_id"), Index("ix_receipts_created", "created_at"))
