import asyncio
import copy
import hashlib
import logging
import uuid
from datetime import date, timedelta
from urllib.parse import urlparse

import httpx
import jwt
from fastapi import BackgroundTasks, Depends, FastAPI, Header, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from jwt import InvalidTokenError
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.middleware.base import BaseHTTPMiddleware

from app.config import get_settings
from app.ai import ModelUnavailable, extract_recipe, fallback_recipe_template
from app.db import SessionLocal, get_db
from app.models import (
    Account, DailyPlanEntry, DiaryEntry, ExternalIdentity, NutritionProfile,
    OperationReceipt, RecipeSource, RecipeVersion, SearchRequest, SessionRecord, now_utc,
)
from app.nutrition import estimate_recipe
from app.schemas import (
    AccountResponse, CancelSearchResponse, DailyDiaryResponse, DailyPlanResponse, DiaryEntryInput, DiaryEntryPatch,
    DiaryEntryResponse, GoogleAuthRequest, LoginRequest, MatchInput,
    PlanEntryInput, PlanEntryPatch, PlanEntryResponse, ProfileInput, ProfilePatch, RecipeVariantInput,
    ErrorResponse, ProfileResponse, RecipeCardResponse, RegisterRequest, SearchCreatedResponse, SearchCriteria,
    SearchResponse, SessionResponse, VersionInput, RefreshRequest,
)
from app.security import hash_password, hash_token, issue_access_token, new_refresh_token, verify_password

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("miara.api")
settings = get_settings()
app = FastAPI(title="Miara API", version="1.0.0", description="API aplikacji Miara zgodne z kontraktem v1.", responses={
    401: {"model": ErrorResponse, "description": "Brak lub nieważna sesja"},
    404: {"model": ErrorResponse, "description": "Nie znaleziono zasobu"},
    409: {"model": ErrorResponse, "description": "Konflikt wersji lub idempotencji"},
    410: {"model": ErrorResponse, "description": "Wyniki wyszukiwania wygasły"},
    422: {"model": ErrorResponse, "description": "Błędne dane"},
    500: {"model": ErrorResponse, "description": "Błąd serwera"},
})
bearer_scheme = HTTPBearer(auto_error=False)


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request.state.request_id = str(uuid.uuid4())
        response = await call_next(request)
        response.headers["X-Request-ID"] = request.state.request_id
        return response


app.add_middleware(RequestIdMiddleware)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    fields = []
    for error in exc.errors():
        fields.append({"field": ".".join(str(x) for x in error["loc"] if x != "body"), "reason": error["msg"]})
    return JSONResponse({"code": "VALIDATION_ERROR", "message": "Sprawdź poprawność przesłanych danych.", "details": fields, "request_id": getattr(request.state, "request_id", None)}, status_code=422)


@app.exception_handler(IntegrityError)
async def integrity_error_handler(request: Request, exc: IntegrityError):
    logger.info("Constraint violation request_id=%s", getattr(request.state, "request_id", ""))
    return JSONResponse({"code": "CONFLICT", "message": "Operacja narusza ograniczenie danych.", "request_id": getattr(request.state, "request_id", None)}, status_code=409)


def fail(status: int, code: str, message: str, details=None):
    from fastapi import HTTPException
    raise HTTPException(status_code=status, detail={"code": code, "message": message, "details": details})


@app.exception_handler(Exception)
async def internal_error_handler(request: Request, exc: Exception):
    logger.error("Unhandled request error request_id=%s type=%s", getattr(request.state, "request_id", ""), type(exc).__name__)
    return JSONResponse({"code": "INTERNAL_ERROR", "message": "Wystąpił błąd serwera.", "request_id": getattr(request.state, "request_id", None)}, status_code=500)


from fastapi import HTTPException


@app.exception_handler(HTTPException)
async def http_error_handler(request: Request, exc: HTTPException):
    detail = exc.detail if isinstance(exc.detail, dict) else {"code": "HTTP_ERROR", "message": str(exc.detail)}
    return JSONResponse({**detail, "request_id": getattr(request.state, "request_id", None)}, status_code=exc.status_code)


def profile_out(row: NutritionProfile):
    return {"id": row.id, "daily_kcal_target": row.daily_kcal_target, "protein_g_target": row.protein_g_target,
            "carbohydrate_g_target": row.carbohydrate_g_target, "fat_g_target": row.fat_g_target,
            "meals_per_day": row.meals_per_day, "preferences": row.preferences, "excluded_products": row.excluded_products,
            "allergens": row.allergens, "version": row.version, "created_at": row.created_at.isoformat(), "updated_at": row.updated_at.isoformat()}


def plan_out(row: DailyPlanEntry):
    return {"id": row.id, "date": row.local_date.isoformat(), "recipe_version_id": row.recipe_version_id,
            "servings": row.servings, "estimate_snapshot": row.estimate_snapshot, "version": row.version,
            "created_at": row.created_at.isoformat(), "updated_at": row.updated_at.isoformat()}


def diary_out(row: DiaryEntry):
    return {"id": row.id, "date": row.local_date.isoformat(), "origin": row.origin, "plan_entry_id": row.plan_entry_id,
            "recipe_version_id": row.recipe_version_id, "name": row.name, "quantity": row.quantity, "unit": row.unit,
            "nutrition_snapshot": row.nutrition_snapshot, "version": row.version,
            "created_at": row.created_at.isoformat(), "updated_at": row.updated_at.isoformat()}


def create_session(db: Session, account: Account):
    session_id = str(uuid.uuid4())
    refresh = new_refresh_token()
    access, expiry = issue_access_token(account.id, session_id)
    session = SessionRecord(id=session_id, account_id=account.id, refresh_token_hash=hash_token(refresh), access_expires_at=expiry)
    db.add(session)
    db.commit()
    return {"account_id": account.id, "session_id": session_id, "access_token": access,
            "access_expires_at": expiry.isoformat(), "refresh_token": refresh, "refresh_expires_at": None,
            "token_type": "Bearer"}


def get_current_account(request: Request, credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme), db: Session = Depends(get_db)) -> Account:
    if credentials is None or credentials.scheme.lower() != "bearer":
        fail(401, "UNAUTHENTICATED", "Wymagane jest zalogowanie.")
    token = credentials.credentials
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        account_id, session_id = payload["sub"], payload["sid"]
    except (InvalidTokenError, KeyError, TypeError):
        fail(401, "UNAUTHENTICATED", "Sesja jest nieważna lub wygasła.")
    session = db.get(SessionRecord, session_id)
    account = db.get(Account, account_id)
    if session is None or session.revoked_at is not None or session.account_id != account_id or account is None or account.status != "active":
        fail(401, "UNAUTHENTICATED", "Sesja została unieważniona.")
    request.state.account_id = account.id
    return account


async def idempotent(request: Request, db: Session, account: Account, key: str | None, operation):
    if not key:
        fail(422, "VALIDATION_ERROR", "Wymagany nagłówek Idempotency-Key.", [{"field": "Idempotency-Key", "reason": "UUID jest wymagane"}])
    try:
        operation_id = str(uuid.UUID(key))
    except ValueError:
        fail(422, "VALIDATION_ERROR", "Idempotency-Key musi być UUID.", [{"field": "Idempotency-Key", "reason": "Nieprawidłowy UUID"}])
    raw = await request.body()
    fingerprint = hashlib.sha256((request.method + "\n" + request.url.path + "\n" + raw.decode("utf-8")).encode()).hexdigest()
    db.execute(select(Account.id).where(Account.id == account.id).with_for_update())
    old = db.scalar(select(OperationReceipt).where(OperationReceipt.account_id == account.id, OperationReceipt.operation_id == operation_id))
    if old:
        if old.request_hash != fingerprint:
            fail(409, "IDEMPOTENCY_CONFLICT", "Ten klucz operacji został użyty z inną treścią.")
        return Response(status_code=old.status_code) if old.status_code == 204 else JSONResponse(old.response_body, status_code=old.status_code)
    status_code, body = operation()
    db.add(OperationReceipt(account_id=account.id, operation_id=operation_id, request_hash=fingerprint,
                            status_code=status_code, response_body=body))
    db.commit()
    return Response(status_code=204) if status_code == 204 else JSONResponse(body, status_code=status_code)


def resource_for_account(db: Session, model, resource_id: str, account_id: str):
    row = db.get(model, resource_id)
    if row is None or row.account_id != account_id:
        fail(404, "NOT_FOUND", "Nie znaleziono zasobu.")
    return row


def check_version(row, version: int):
    if row.version != version:
        fail(409, "VERSION_CONFLICT", "Zasób został zmieniony na serwerze.", {"current": row.version})


@app.get("/health", tags=["system"])
def health():
    return {"status": "ok"}


@app.on_event("startup")
async def startup():
    timeout = httpx.Timeout(settings.ai_read_timeout_seconds, connect=settings.ai_connect_timeout_seconds)
    headers = {"Authorization": f"Bearer {settings.ai_api_key}"} if settings.ai_api_key else {}
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.get(settings.ai_base_url.rstrip("/") + "/models", headers=headers)
            response.raise_for_status()
            models = response.json().get("data", [])
            if settings.ai_model not in {item.get("id") for item in models}:
                raise RuntimeError("Skonfigurowany AI_MODEL nie jest dostępny u wybranego dostawcy.")
    except Exception as exc:
        logger.warning(
            "AI provider unavailable at startup provider=%s type=%s; recipe searches will use fallback templates",
            settings.ai_provider,
            type(exc).__name__,
        )
    # Requeue jobs left in a non-terminal state after a process restart.
    with SessionLocal() as db:
        expire_old_searches(db)
        pending = db.scalars(select(SearchRequest).where(SearchRequest.status.in_(["pending", "running"]))).all()
        for job in pending:
            job.status = "pending"
        db.commit()
        for job in pending:
            asyncio.create_task(asyncio.to_thread(run_search, job.id))
    app.state.retention_task = asyncio.create_task(retention_worker())


@app.on_event("shutdown")
async def stop_retention_worker():
    task = getattr(app.state, "retention_task", None)
    if task is not None:
        task.cancel()


async def retention_worker():
    while True:
        await asyncio.sleep(3600)
        await asyncio.to_thread(cleanup_expired_searches)


def cleanup_expired_searches():
    with SessionLocal() as db:
        expire_old_searches(db)


@app.post("/v1/auth/register", status_code=201, tags=["auth"], response_model=SessionResponse)
def register(body: RegisterRequest, db: Session = Depends(get_db)) -> SessionResponse:
    if db.scalar(select(Account).where(Account.email == body.email)):
        fail(409, "ACCOUNT_EXISTS", "Konto z tym adresem email już istnieje.")
    account = Account(email=body.email, password_hash=hash_password(body.password))
    db.add(account)
    db.flush()
    session_data = create_session(db, account)
    return JSONResponse(session_data, status_code=201)


@app.post("/v1/auth/login", tags=["auth"], response_model=SessionResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)) -> SessionResponse:
    account = db.scalar(select(Account).where(Account.email == body.email))
    if account is None or account.password_hash is None or not verify_password(body.password, account.password_hash):
        fail(401, "UNAUTHENTICATED", "Nieprawidłowy email lub hasło.")
    return create_session(db, account)


@app.post("/v1/auth/google", tags=["auth"], response_model=SessionResponse)
def google_login(body: GoogleAuthRequest, db: Session = Depends(get_db)) -> SessionResponse:
    if not settings.google_client_id:
        fail(503, "GOOGLE_UNAVAILABLE", "Logowanie Google nie jest skonfigurowane.")
    try:
        claims = google_id_token.verify_oauth2_token(body.credential, google_requests.Request(), settings.google_client_id)
        subject, email = claims["sub"], claims["email"].strip().lower()
        if claims.get("email_verified") is not True:
            fail(401, "UNAUTHENTICATED", "Adres Google nie został zweryfikowany.")
    except HTTPException:
        raise
    except Exception:
        fail(401, "UNAUTHENTICATED", "Nie można zweryfikować poświadczenia Google.")
    identity = db.scalar(select(ExternalIdentity).where(ExternalIdentity.provider == "google", ExternalIdentity.provider_subject == subject))
    if identity:
        account = db.get(Account, identity.account_id)
    else:
        # Linking to a password account by email is deliberately avoided until the account-linking policy is decided.
        if db.scalar(select(Account).where(Account.email == email)):
            fail(409, "ACCOUNT_LINK_REQUIRED", "Adres jest już powiązany z kontem. Zaloguj się hasłem przed połączeniem.")
        account = Account(email=email)
        db.add(account)
        db.flush()
        db.add(ExternalIdentity(account_id=account.id, provider="google", provider_subject=subject))
        db.flush()
    return create_session(db, account)


@app.post("/v1/auth/refresh", tags=["auth"], response_model=SessionResponse)
def refresh(body: RefreshRequest, db: Session = Depends(get_db)) -> SessionResponse:
    record = db.scalar(select(SessionRecord).where(SessionRecord.refresh_token_hash == hash_token(body.refresh_token)))
    if record is None or record.revoked_at is not None:
        fail(401, "UNAUTHENTICATED", "Sesja została unieważniona.")
    account = db.get(Account, record.account_id)
    if account is None or account.status != "active":
        fail(401, "UNAUTHENTICATED", "Sesja została unieważniona.")
    rotated = new_refresh_token()
    record.refresh_token_hash = hash_token(rotated)
    access, expiry = issue_access_token(account.id, record.id)
    record.access_expires_at = expiry
    db.commit()
    return {"account_id": account.id, "session_id": record.id, "access_token": access, "access_expires_at": expiry.isoformat(),
            "refresh_token": rotated, "refresh_expires_at": None, "token_type": "Bearer"}


@app.post("/v1/auth/logout", status_code=204, tags=["auth"])
def logout(account: Account = Depends(get_current_account), credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme), db: Session = Depends(get_db)):
    token = credentials.credentials
    payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    record = db.get(SessionRecord, payload["sid"])
    if record and record.account_id == account.id:
        record.revoked_at = now_utc()
        db.commit()
    return Response(status_code=204)


@app.get("/v1/me", tags=["auth"], response_model=AccountResponse)
def me(account: Account = Depends(get_current_account)) -> AccountResponse:
    return {"id": account.id, "email": account.email, "created_at": account.created_at.isoformat(), "time_zone": account.time_zone}


@app.post("/v1/profile", status_code=201, tags=["profile"], response_model=ProfileResponse)
async def create_profile(body: ProfileInput, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        if db.scalar(select(NutritionProfile).where(NutritionProfile.account_id == account.id)):
            fail(409, "PROFILE_EXISTS", "Profil dla tego konta już istnieje.")
        row = NutritionProfile(id=str(body.id or uuid.uuid4()), account_id=account.id, **body.model_dump(exclude={"id"}))
        db.add(row)
        db.flush()
        return 201, profile_out(row)
    return await idempotent(request, db, account, idempotency_key, op)


@app.get("/v1/profile", tags=["profile"], response_model=ProfileResponse)
def get_profile(account: Account = Depends(get_current_account), db: Session = Depends(get_db)) -> ProfileResponse:
    row = db.scalar(select(NutritionProfile).where(NutritionProfile.account_id == account.id))
    if row is None:
        fail(404, "NOT_FOUND", "Profil nie został utworzony.")
    return profile_out(row)


@app.patch("/v1/profile", tags=["profile"], response_model=ProfileResponse)
async def patch_profile(body: ProfilePatch, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        row = db.scalar(select(NutritionProfile).where(NutritionProfile.account_id == account.id))
        if row is None:
            fail(404, "NOT_FOUND", "Profil nie został utworzony.")
        check_version(row, body.version)
        for key, value in body.model_dump(exclude={"version"}, exclude_unset=True).items():
            setattr(row, key, value)
        row.version += 1
        row.updated_at = now_utc()
        db.flush()
        return 200, profile_out(row)
    return await idempotent(request, db, account, idempotency_key, op)


@app.delete("/v1/profile", status_code=204, tags=["profile"])
async def delete_profile(body: VersionInput, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        row = db.scalar(select(NutritionProfile).where(NutritionProfile.account_id == account.id))
        if row is None:
            fail(404, "NOT_FOUND", "Profil nie został utworzony.")
        check_version(row, body.version)
        db.delete(row)
        db.flush()
        return 204, None
    return await idempotent(request, db, account, idempotency_key, op)


def page_query(db: Session, query, cursor: str | None, limit: int):
    try:
        offset = max(0, int(cursor or "0"))
    except ValueError:
        fail(422, "VALIDATION_ERROR", "Nieprawidłowy kursor.", [{"field": "cursor", "reason": "oczekiwano kursora liczbowego"}])
    rows = db.scalars(query.offset(offset).limit(limit + 1)).all()
    more = len(rows) > limit
    rows = rows[:limit]
    return rows, (str(offset + limit) if more else None)


def visible_recipe(db: Session, recipe_id: str, account_id: str):
    row = db.get(RecipeVersion, recipe_id)
    if row is None or (row.visibility == "private" and row.created_by_account_id != account_id):
        fail(404, "NOT_FOUND", "Nie znaleziono przepisu.")
    return row


def plan_summary(rows):
    keys = ("kcal", "protein_g", "carbohydrate_g", "fat_g")
    totals = {k: 0.0 for k in keys}
    missing = []
    for row in rows:
        snap = row.estimate_snapshot or {}
        for key in keys:
            val = snap.get("estimate_per_serving", snap).get(key) if isinstance(snap.get("estimate_per_serving", snap), dict) else None
            if val is None:
                missing.append(f"{row.id}.{key}")
            else:
                totals[key] += val * row.servings
    if missing:
        for key in keys:
            totals[key] = None if any(item.endswith("." + key) for item in missing) else round(totals[key], 2)
    else:
        totals = {k: round(v, 2) for k, v in totals.items()}
    return {**totals, "completeness": "partial" if missing else "complete", "missing": missing}


@app.get("/v1/plan", tags=["plan"], response_model=DailyPlanResponse)
def get_plan(date_value: date = Query(alias="date"), limit: int = 100, cursor: str | None = None,
             account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    if not 1 <= limit <= 100:
        fail(422, "VALIDATION_ERROR", "Limit musi być od 1 do 100.")
    base = select(DailyPlanEntry).where(DailyPlanEntry.account_id == account.id, DailyPlanEntry.local_date == date_value).order_by(DailyPlanEntry.created_at, DailyPlanEntry.id)
    rows, next_cursor = page_query(db, base, cursor, limit)
    all_rows = db.scalars(select(DailyPlanEntry).where(DailyPlanEntry.account_id == account.id, DailyPlanEntry.local_date == date_value)).all()
    return {"date": date_value.isoformat(), "entries": [plan_out(x) for x in rows], "totals": plan_summary(all_rows), "next_cursor": next_cursor}


@app.post("/v1/plan/entries", status_code=201, tags=["plan"], response_model=PlanEntryResponse)
async def add_plan_entry(body: PlanEntryInput, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        recipe = visible_recipe(db, body.recipe_version_id, account.id)
        if recipe.kind == "proposal":
            fail(422, "VALIDATION_ERROR", "Zatwierdź proponowaną wersję przed dodaniem jej do planu.")
        estimate = recipe.data.get("estimate_per_serving")
        snapshot = {"estimate_per_serving": estimate} if estimate else None
        row = DailyPlanEntry(id=str(body.id), account_id=account.id, local_date=body.date, recipe_version_id=recipe.id, servings=body.servings, estimate_snapshot=snapshot)
        db.add(row)
        db.flush()
        return 201, plan_out(row)
    return await idempotent(request, db, account, idempotency_key, op)


@app.patch("/v1/plan/entries/{entry_id}", tags=["plan"], response_model=PlanEntryResponse)
async def patch_plan_entry(entry_id: str, body: PlanEntryPatch, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        row = resource_for_account(db, DailyPlanEntry, entry_id, account.id)
        check_version(row, body.version)
        values = body.model_dump(exclude={"version"}, exclude_unset=True)
        if "recipe_version_id" in values:
            recipe = visible_recipe(db, values["recipe_version_id"], account.id)
            if recipe.kind == "proposal":
                fail(422, "VALIDATION_ERROR", "Zatwierdź proponowaną wersję przed dodaniem jej do planu.")
            values["recipe_version_id"] = recipe.id
            estimate = recipe.data.get("estimate_per_serving")
            row.estimate_snapshot = {"estimate_per_serving": estimate} if estimate else None
        for key, value in values.items():
            setattr(row, "local_date" if key == "date" else key, value)
        row.version += 1
        row.updated_at = now_utc()
        db.flush()
        return 200, plan_out(row)
    return await idempotent(request, db, account, idempotency_key, op)


@app.delete("/v1/plan/entries/{entry_id}", status_code=204, tags=["plan"])
async def delete_plan_entry(entry_id: str, body: VersionInput, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        row = resource_for_account(db, DailyPlanEntry, entry_id, account.id)
        check_version(row, body.version)
        db.delete(row)
        db.flush()
        return 204, None
    return await idempotent(request, db, account, idempotency_key, op)


def diary_totals(rows):
    keys = ("kcal", "protein_g", "carbohydrate_g", "fat_g")
    totals = {k: 0.0 for k in keys}
    missing = []
    for row in rows:
        snap = row.nutrition_snapshot or {}
        for key in keys:
            value = snap.get(key)
            if value is None:
                missing.append(f"{row.id}.{key}")
            else:
                totals[key] += value
    return {**{k: (None if any(x.endswith("." + k) for x in missing) else round(v, 2)) for k, v in totals.items()},
            "completeness": "partial" if missing else "complete", "missing": missing}


@app.get("/v1/diary", tags=["diary"], response_model=DailyDiaryResponse)
def get_diary(date_value: date = Query(alias="date"), limit: int = 100, cursor: str | None = None,
              account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    if not 1 <= limit <= 100:
        fail(422, "VALIDATION_ERROR", "Limit musi być od 1 do 100.")
    base = select(DiaryEntry).where(DiaryEntry.account_id == account.id, DiaryEntry.local_date == date_value).order_by(DiaryEntry.created_at, DiaryEntry.id)
    rows, next_cursor = page_query(db, base, cursor, limit)
    all_rows = db.scalars(select(DiaryEntry).where(DiaryEntry.account_id == account.id, DiaryEntry.local_date == date_value)).all()
    return {"date": date_value.isoformat(), "entries": [diary_out(x) for x in rows], "totals": diary_totals(all_rows), "next_cursor": next_cursor}


@app.post("/v1/diary/entries", status_code=201, tags=["diary"], response_model=DiaryEntryResponse)
async def add_diary_entry(body: DiaryEntryInput, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        plan_id = str(body.plan_entry_id) if body.plan_entry_id else None
        recipe_id = body.recipe_version_id
        name, quantity, unit = body.name, body.quantity, body.unit
        if body.origin == "plan":
            plan = resource_for_account(db, DailyPlanEntry, plan_id, account.id)
            recipe_id = plan.recipe_version_id
            name = name or visible_recipe(db, recipe_id, account.id).data.get("title")
        if recipe_id:
            visible_recipe(db, recipe_id, account.id)
        row = DiaryEntry(id=str(body.id), account_id=account.id, local_date=body.date, origin=body.origin,
                         plan_entry_id=plan_id, recipe_version_id=recipe_id, name=name, quantity=quantity,
                         unit=unit, nutrition_snapshot=body.nutrition_snapshot.model_dump())
        db.add(row)
        db.flush()
        return 201, diary_out(row)
    return await idempotent(request, db, account, idempotency_key, op)


@app.patch("/v1/diary/entries/{entry_id}", tags=["diary"], response_model=DiaryEntryResponse)
async def patch_diary_entry(entry_id: str, body: DiaryEntryPatch, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        row = resource_for_account(db, DiaryEntry, entry_id, account.id)
        check_version(row, body.version)
        for key, value in body.model_dump(exclude={"version"}, exclude_unset=True).items():
            if key == "nutrition_snapshot" and value is not None:
                value = value.model_dump() if hasattr(value, "model_dump") else value
            setattr(row, "local_date" if key == "date" else key, value)
        row.version += 1
        row.updated_at = now_utc()
        db.flush()
        return 200, diary_out(row)
    return await idempotent(request, db, account, idempotency_key, op)


@app.delete("/v1/diary/entries/{entry_id}", status_code=204, tags=["diary"])
async def delete_diary_entry(entry_id: str, body: VersionInput, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        row = resource_for_account(db, DiaryEntry, entry_id, account.id)
        check_version(row, body.version)
        db.delete(row)
        db.flush()
        return 204, None
    return await idempotent(request, db, account, idempotency_key, op)


def recipe_card(db: Session, version_id: str, account_id: str):
    version = visible_recipe(db, version_id, account_id)
    source = db.get(RecipeSource, version.source_id)
    data = version.data
    return {"recipe_version_id": version.id, "title": data.get("title") or (source.title if source else "Przepis"),
            "source": {"url": source.canonical_url, "domain": source.source_domain, "retrieved_at": source.retrieved_at.isoformat()} if source else None,
            "estimate_per_serving": data.get("estimate_per_serving"), "match": data.get("match", {"status": "unverified", "reasons": ["brak weryfikacji składu"]}),
            "model_status": data.get("model_status")}


@app.get("/v1/recipes/{version_id}", tags=["recipes"], response_model=dict)
def get_recipe(version_id: str, account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    row = visible_recipe(db, version_id, account.id)
    data = row.data
    return {**recipe_card(db, version_id, account.id),
            "ingredients": data.get("ingredients"), "instructions": data.get("instructions"),
            "servings": data.get("servings"), "total_mass_g": data.get("total_mass_g"),
            "prep_time_minutes": data.get("prep_time_minutes"), "cook_time_minutes": data.get("cook_time_minutes"),
            "declared_nutrition": data.get("declared_nutrition"), "estimate_total": data.get("estimate_total"),
            "estimate_per_serving": data.get("estimate_per_serving"), "missing": data.get("missing", []),
            "model_status": data.get("model_status"), "template_type": data.get("template_type"),
            "changes": data.get("changes", []), "match": data.get("match"),
            "provenance": {"parent_version_id": row.parent_version_id, "kind": row.kind}}


@app.post("/v1/recipes/{version_id}/variants", status_code=201, tags=["recipes"])
async def make_variant(version_id: str, body: RecipeVariantInput, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        parent = visible_recipe(db, version_id, account.id)
        data = copy.deepcopy(parent.data)
        data["changes"] = body.changes
        if body.servings is not None:
            data["servings"] = body.servings
        if body.ingredients is not None:
            prior = {str(x.get("id")): x for x in data.get("ingredients", []) if isinstance(x, dict) and x.get("id")}
            incoming = [item.model_dump(mode="json") for item in body.ingredients]
            for item in incoming:
                old_item = prior.get(str(item.get("id")))
                if old_item and old_item.get("name", "").casefold() == item["name"].casefold():
                    for key in ("nutrition_snapshot", "match"):
                        if key in old_item:
                            item[key] = old_item[key]
            data["ingredients"] = incoming
        data["variant_status"] = "approved" if body.approved else "proposed"
        if body.ingredients is not None:
            data.update(estimate_recipe(data["ingredients"], data.get("servings")))
        else:
            data["estimate_total"] = None
            data["estimate_per_serving"] = None
            data["missing"] = [{"field": "ingredients", "reason": "Zmiana wymaga ponownego podania składu do przeliczenia."}]
        row = RecipeVersion(source_id=parent.source_id, parent_version_id=parent.id, created_by_account_id=account.id,
                            visibility="private", kind="approved" if body.approved else "proposal", data=data)
        db.add(row)
        db.flush()
        return 201, {**recipe_card(db, row.id, account.id), **row.data}
    return await idempotent(request, db, account, idempotency_key, op)


@app.get("/v1/recipes/{version_id}/estimate", tags=["recipes"])
def recipe_estimate(version_id: str, account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    row = visible_recipe(db, version_id, account.id)
    estimate = row.data.get("estimate_per_serving")
    if estimate is None:
        return {"recipe_version_id": row.id, "estimate_total": None, "estimate_per_serving": None,
                "completeness": "partial", "missing": row.data.get("missing", [{"field": "estimate", "reason": "Brak skonfigurowanej bazy żywieniowej."}]),
                "calculated_at": None, "calculation_version": None, "sources": []}
    return {"recipe_version_id": row.id, "estimate_total": row.data.get("estimate_total"),
            "estimate_per_serving": estimate, "completeness": estimate.get("completeness", "partial"),
            "missing": row.data.get("missing", []), "calculated_at": row.data.get("calculated_at"),
            "calculation_version": row.data.get("calculation_version"), "sources": row.data.get("sources", [])}


@app.patch("/v1/recipes/{version_id}/ingredients/{ingredient_id}/match", tags=["recipes"])
async def update_match(version_id: str, ingredient_id: str, body: MatchInput, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        parent = visible_recipe(db, version_id, account.id)
        if parent.created_by_account_id != account.id:
            fail(404, "NOT_FOUND", "Nie znaleziono prywatnej wersji przepisu.")
        check_version(type("V", (), {"version": int(parent.data.get("version", 1))})(), body.version)
        data = copy.deepcopy(parent.data)
        ingredients = data.get("ingredients")
        if not isinstance(ingredients, list):
            fail(422, "INSUFFICIENT_DATA", "Brak składników do dopasowania.")
        ingredient = next((x for x in ingredients if x.get("id") == ingredient_id), None)
        if ingredient is None:
            fail(404, "NOT_FOUND", "Nie znaleziono składnika.")
        nutrition = ingredient.get("nutrition_snapshot")
        if body.product_id and (not isinstance(nutrition, dict) or nutrition.get("product_id") != body.product_id):
            ingredient.pop("nutrition_snapshot", None)
        ingredient.update({"match": {"product_id": body.product_id, "product_name": body.product_name, "status": "selected" if body.product_id else "unverified"},
                           "quantity": body.quantity if body.quantity is not None else ingredient.get("quantity"),
                           "unit": body.unit if body.unit is not None else ingredient.get("unit")})
        data.update({"ingredients": ingredients, "version": body.version + 1})
        data.update(estimate_recipe(ingredients, data.get("servings")))
        row = RecipeVersion(source_id=parent.source_id, parent_version_id=parent.id,
                            created_by_account_id=account.id, visibility="private", kind="approved", data=data)
        db.add(row)
        db.flush()
        return 200, {**recipe_card(db, row.id, account.id), **row.data}
    return await idempotent(request, db, account, idempotency_key, op)


@app.post("/v1/recipe-searches", status_code=202, tags=["search"], response_model=SearchCreatedResponse)
async def create_search(body: SearchCriteria, background: BackgroundTasks, request: Request,
                        idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
                        account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        now = now_utc()
        job = SearchRequest(account_id=account.id, criteria=body.model_dump(exclude_none=True), status="pending",
                            created_at=now, deadline_at=now + timedelta(seconds=settings.search_timeout_seconds))
        db.add(job)
        db.flush()
        response = {"search_id": job.id, "status": job.status, "created_at": now.isoformat(), "deadline_at": job.deadline_at.isoformat()}
        background.add_task(run_search, job.id)
        return 202, response
    return await idempotent(request, db, account, idempotency_key, op)


def run_search(search_id: str):
    with SessionLocal() as db:
        job = db.get(SearchRequest, search_id)
        if job is None or job.status in {"completed", "partial", "failed", "cancelled"}:
            return
        if job.cancel_requested:
            job.status = "cancelled"
            job.finished_at = now_utc()
            job.expires_at = job.finished_at + timedelta(days=settings.search_retention_days)
            db.commit()
            return
        job.status = "running"
        db.commit()
        criteria = dict(job.criteria)
        deadline = job.deadline_at
    if not settings.recipe_discovery_url:
        if not settings.recipe_source_terms_confirmed:
            finish_search(search_id, "failed", error={"code": "SOURCE_UNAVAILABLE", "message": "Przed użyciem źródła operator musi potwierdzić warunki serwisu."})
            return
    remaining = (deadline - now_utc()).total_seconds()
    if remaining <= 0:
        finish_search(search_id, "failed", error={"code": "SEARCH_TIMEOUT", "message": "Przekroczono limit czasu wyszukiwania."})
        return
    headers = {"Authorization": f"Bearer {settings.recipe_discovery_api_key}"} if settings.recipe_discovery_api_key else {}
    try:
        if settings.recipe_discovery_url:
            response = httpx.post(settings.recipe_discovery_url, json=criteria, headers=headers,
                                  timeout=httpx.Timeout(min(remaining, settings.ai_read_timeout_seconds), connect=min(remaining, settings.ai_connect_timeout_seconds)))
            response.raise_for_status()
            payload = response.json()
        else:
            from app.source import discover_metadata
            payload = discover_metadata(criteria, remaining)
        candidates = payload.get("results", [])
        warnings = payload.get("warnings", [])
        for candidate in candidates[:criteria.get("limit", 20)]:
            extraction_input = candidate.pop("extraction_input", None)
            if extraction_input is not None:
                if not settings.source_content_processing_allowed:
                    candidate.pop("ingredients", None)
                    warnings = list(warnings) + ["SOURCE_CONTENT_RESTRICTED"]
                    extraction_input = None
            if extraction_input is not None:
                remaining = (deadline - now_utc()).total_seconds()
                if remaining <= 0:
                    warnings = list(warnings) + ["SEARCH_TIMEOUT"]
                    break
                try:
                    extracted = extract_recipe(str(extraction_input), str(candidate.get("title", "")),
                                               min(remaining, settings.ai_read_timeout_seconds))
                    candidate = {**candidate, **extracted}
                except ModelUnavailable:
                    candidate = {**candidate, **fallback_recipe_template(str(candidate.get("title", "")))}
                    warnings = list(warnings) + ["MODEL_FALLBACK_TEMPLATE"]
            save_candidate(search_id, candidate)
        with SessionLocal() as db:
            job = db.get(SearchRequest, search_id)
            if job is None or job.status in {"completed", "partial", "failed", "cancelled", "expired"}:
                return
            if job.cancel_requested:
                job.status = "cancelled"
            elif now_utc() >= job.deadline_at:
                job.status = "partial" if job.result_ids else "failed"
                job.warnings = list(warnings) + ["SEARCH_TIMEOUT"]
                job.error = None if job.result_ids else {"code": "SEARCH_TIMEOUT", "message": "Przekroczono limit czasu wyszukiwania."}
            else:
                job.status = "partial" if warnings else "completed"
                job.warnings = list(warnings)
            job.finished_at = now_utc()
            job.expires_at = job.finished_at + timedelta(days=settings.search_retention_days)
            db.commit()
    except Exception as exc:
        logger.warning("Recipe discovery failed search_id=%s type=%s", search_id, type(exc).__name__)
        code = "SEARCH_TIMEOUT" if isinstance(exc, httpx.TimeoutException) else "SOURCE_UNAVAILABLE"
        finish_search(search_id, "partial" if search_has_results(search_id) else "failed",
                      warnings=[code], error=None if search_has_results(search_id) else {"code": code, "message": "Źródło przepisów jest niedostępne."})


def save_candidate(search_id: str, candidate: dict):
    # The configured adapter must observe the source allowlist, robots.txt, terms and content-use policy.
    try:
        title = str(candidate["title"]).strip()
        url = str(candidate["source"]["url"])
        parsed = urlparse(url)
        if not title or parsed.scheme != "https" or parsed.hostname not in {"aniagotuje.pl", "www.aniagotuje.pl"} or parsed.username or parsed.password:
            return
        usage = candidate.get("usage_status", "metadata_only")
        permitted = usage in {"licensed", "permitted", "legal_basis_confirmed"}
        domain = parsed.hostname
        with SessionLocal() as db:
            job = db.get(SearchRequest, search_id)
            if job is None:
                return
            source = db.scalar(select(RecipeSource).where(RecipeSource.canonical_url == url))
            if source is None:
                source = RecipeSource(canonical_url=url, title=title[:500], source_domain=domain, retrieved_at=now_utc(), usage_status=usage)
                db.add(source)
                db.flush()
            else:
                source.title = title[:500]
                source.source_domain = domain
                source.retrieved_at = now_utc()
                source.usage_status = usage
            for prior_id in job.result_ids or []:
                prior = db.get(RecipeVersion, prior_id)
                if prior is not None and prior.source_id == source.id:
                    return
            # Only retain extracted content when the adapter explicitly attests to a permitted basis.
            data = {"title": title, "estimate_total": None, "estimate_per_serving": None,
                    "missing": [{"field": "ingredients", "reason": "Dane składników nie zostały trwale zachowane bez potwierdzonej podstawy użycia."}],
                    "match": {"status": "unverified", "reasons": ["niezweryfikowany skład"]}}
            for key in ("model_status", "template_type"):
                if key in candidate:
                    data[key] = candidate[key]
            if candidate.get("model_status") == "fallback_template":
                data["missing"] = candidate.get("missing", data["missing"])
            if permitted:
                for key in ("ingredients", "servings", "total_mass_g", "prep_time_minutes", "cook_time_minutes", "declared_nutrition", "changes"):
                    if key in candidate:
                        data[key] = candidate[key]
                calculation = estimate_recipe(data.get("ingredients"), data.get("servings"))
                data.update(calculation)
            profile = db.scalar(select(NutritionProfile).where(NutritionProfile.account_id == job.account_id))
            data["match"] = assess_match(data, profile, job.criteria)
            version = RecipeVersion(source_id=source.id, data=data, visibility="shared", kind="source")
            db.add(version)
            db.flush()
            ids = list(job.result_ids or [])
            if version.id not in ids:
                ids.append(version.id)
            job.result_ids = ids
            db.commit()
    except (KeyError, TypeError, ValueError):
        return


def assess_match(recipe_data: dict, profile: NutritionProfile | None, criteria: dict):
    ingredients = recipe_data.get("ingredients") or []
    names = [str(x.get("name", "")).casefold() for x in ingredients if isinstance(x, dict)]
    reasons = []
    if profile is None or not names:
        reasons.append("brak profilu lub niepełnej listy składników")
    exclusions = [*((profile.allergens or []) if profile else []), *((profile.excluded_products or []) if profile else [])]
    detected = sorted({term for term in exclusions if any(str(term).casefold() in name for name in names)})
    if detected:
        reasons.append("wykryto zadeklarowane wykluczenia")
    criteria_used = []
    criteria_not_met = []
    criteria_unverifiable = []
    if criteria.get("dish_name"):
        criteria_used.append("dish_name")
    maximum_time = criteria.get("max_time_minutes")
    if maximum_time is not None:
        prep, cook = recipe_data.get("prep_time_minutes"), recipe_data.get("cook_time_minutes")
        if prep is None or cook is None:
            criteria_unverifiable.append("max_time_minutes")
        elif (prep or 0) + (cook or 0) > maximum_time:
            criteria_not_met.append("max_time_minutes")
        else:
            criteria_used.append("max_time_minutes")
    maximum_ingredients = criteria.get("max_ingredient_count")
    if maximum_ingredients is not None:
        if not ingredients:
            criteria_unverifiable.append("max_ingredient_count")
        elif len(ingredients) > maximum_ingredients:
            criteria_not_met.append("max_ingredient_count")
        else:
            criteria_used.append("max_ingredient_count")
    estimate = recipe_data.get("estimate_per_serving") or {}
    for key in ("kcal", "protein_g", "carbohydrate_g", "fat_g"):
        bounds = criteria.get({"kcal": "kcal_per_serving", "protein_g": "protein_g_per_serving",
                              "carbohydrate_g": "carbohydrate_g_per_serving", "fat_g": "fat_g_per_serving"}[key])
        if bounds is None:
            continue
        value = estimate.get(key)
        if value is None:
            criteria_unverifiable.append(key)
        elif (("min" in bounds and value < bounds["min"]) or ("max" in bounds and value > bounds["max"])):
            criteria_not_met.append(key)
        else:
            criteria_used.append(key)
    if criteria_unverifiable:
        reasons.append("część kryteriów nie ma wystarczających danych")
    if not detected:
        reasons.append("brak potwierdzenia bezpieczeństwa alergicznego")
    return {"status": "incompatible" if detected else "unverified", "reasons": reasons,
            "detected": detected, "criteria_used": criteria_used,
            "criteria_not_met": criteria_not_met, "criteria_unverifiable": criteria_unverifiable}


def search_has_results(search_id: str) -> bool:
    with SessionLocal() as db:
        job = db.get(SearchRequest, search_id)
        return bool(job and job.result_ids)


def finish_search(search_id: str, status: str, warnings=None, error=None):
    with SessionLocal() as db:
        job = db.get(SearchRequest, search_id)
        if job is None or job.status in {"completed", "partial", "failed", "cancelled"}:
            return
        job.status = "cancelled" if job.cancel_requested else status
        job.warnings = [] if job.cancel_requested else (warnings or [])
        job.error = None if job.cancel_requested else error
        job.finished_at = now_utc()
        job.expires_at = job.finished_at + timedelta(days=settings.search_retention_days)
        db.commit()


def search_result(db: Session, job: SearchRequest, account_id: str, cursor: str | None, limit: int):
    if job.status == "expired":
        fail(410, "SEARCH_EXPIRED", "Wyniki wyszukiwania wygasły.")
    if job.expires_at is not None and job.expires_at <= now_utc():
        fail(410, "SEARCH_EXPIRED", "Wyniki wyszukiwania wygasły.")
    try:
        offset = max(0, int(cursor or "0"))
    except ValueError:
        fail(422, "VALIDATION_ERROR", "Nieprawidłowy kursor.")
    ids = job.result_ids or []
    selected = ids[offset:offset + limit + 1]
    more = len(selected) > limit
    results = [recipe_card(db, rid, account_id) for rid in selected[:limit]]
    return {"search_id": job.id, "status": job.status, "results": results,
            "next_cursor": str(offset + limit) if more else None, "warnings": job.warnings or [], "error": job.error,
            "created_at": job.created_at.isoformat(), "deadline_at": job.deadline_at.isoformat(),
            "finished_at": job.finished_at.isoformat() if job.finished_at else None,
            "expires_at": job.expires_at.isoformat() if job.expires_at else None}


def expire_old_searches(db: Session):
    expired = db.scalars(select(SearchRequest).where(
        SearchRequest.expires_at.is_not(None), SearchRequest.expires_at <= now_utc(), SearchRequest.status != "expired"
    )).all()
    source_ids = set()
    for job in expired:
        for version_id in job.result_ids or []:
            version = db.get(RecipeVersion, version_id)
            if version is not None:
                source_ids.add(version.source_id)
        job.status = "expired"
        job.result_ids = []
        job.criteria = {}
        job.warnings = []
        job.error = None
    if expired:
        protected_ids = set()
        for active_job in db.scalars(select(SearchRequest).where(SearchRequest.status != "expired")).all():
            protected_ids.update(active_job.result_ids or [])
        protected_ids.update(db.scalars(select(DailyPlanEntry.recipe_version_id)).all())
        protected_ids.update(db.scalars(select(DiaryEntry.recipe_version_id).where(DiaryEntry.recipe_version_id.is_not(None))).all())
        for source_id in source_ids:
            versions = db.scalars(select(RecipeVersion).where(RecipeVersion.source_id == source_id)).all()
            if any(version.id in protected_ids for version in versions):
                continue
            for version in versions:
                db.delete(version)
            source = db.get(RecipeSource, source_id)
            if source is not None:
                db.delete(source)
    if expired:
        db.commit()


@app.get("/v1/recipe-searches/{search_id}", tags=["search"], response_model=SearchResponse)
def get_search(search_id: str, limit: int = 20, cursor: str | None = None, account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    if not 1 <= limit <= 100:
        fail(422, "VALIDATION_ERROR", "Limit musi być od 1 do 100.")
    job = db.get(SearchRequest, search_id)
    if job is None or job.account_id != account.id:
        fail(404, "NOT_FOUND", "Nie znaleziono zadania wyszukiwania.")
    if job.status == "expired" or (job.expires_at is not None and job.expires_at <= now_utc()):
        expire_old_searches(db)
        fail(410, "SEARCH_EXPIRED", "Wyniki wyszukiwania wygasły.")
    if job.status in {"pending", "running", "cancelling"} and now_utc() >= job.deadline_at:
        job.status = "partial" if job.result_ids else "failed"
        job.warnings = [*(job.warnings or []), "SEARCH_TIMEOUT"]
        job.error = None if job.result_ids else {"code": "SEARCH_TIMEOUT", "message": "Przekroczono limit czasu wyszukiwania."}
        job.finished_at = now_utc()
        job.expires_at = job.finished_at + timedelta(days=settings.search_retention_days)
        db.commit()
    return search_result(db, job, account.id, cursor, limit)


@app.post("/v1/recipe-searches/{search_id}/cancel", tags=["search"], response_model=CancelSearchResponse,
          responses={202: {"model": CancelSearchResponse, "description": "Anulowanie przyjęte"}})
async def cancel_search(search_id: str, request: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), account: Account = Depends(get_current_account), db: Session = Depends(get_db)):
    def op():
        job = db.get(SearchRequest, search_id)
        if job is None or job.account_id != account.id:
            fail(404, "NOT_FOUND", "Nie znaleziono zadania wyszukiwania.")
        if job.status == "expired":
            fail(410, "SEARCH_EXPIRED", "Wyniki wyszukiwania wygasły.")
        if job.status in {"completed", "partial", "failed", "cancelled"}:
            return 200, {"search_id": job.id, "status": job.status}
        job.cancel_requested = True
        job.status = "cancelling"
        db.flush()
        return 202, {"search_id": job.id, "status": job.status}
    return await idempotent(request, db, account, idempotency_key, op)

