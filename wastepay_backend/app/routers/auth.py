"""
WastePay — Auth Router
POST /auth/register
POST /auth/login
POST /auth/refresh
POST /auth/logout
"""

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from pydantic import BaseModel, validator
from typing import Optional
import uuid

from app.core.core import (
    get_db, hash_password, verify_password,
    create_access_token, create_refresh_token, decode_token, settings
)
from app.models.models import User, Wallet, KYCTier

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


# ── Schemas ──────────────────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    phone: str
    full_name: str
    password: str
    email: Optional[str] = None

    @validator("phone")
    def validate_phone(cls, v):
        v = v.strip().replace(" ", "")
        if not v.startswith("+234") and not v.startswith("0"):
            raise ValueError("Phone must be a valid Nigerian number")
        return v

    @validator("password")
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    full_name: str
    kyc_tier: str


class RefreshRequest(BaseModel):
    refresh_token: str


# ── Dependency ────────────────────────────────────────────────────────────────

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise credentials_exception
        user_id: str = payload.get("sub")
        if not user_id:
            raise credentials_exception
    except Exception:
        raise credentials_exception

    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        raise credentials_exception
    return user


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/register", response_model=TokenResponse, status_code=201)
def register(data: RegisterRequest, db: Session = Depends(get_db)):
    # Check phone duplicate
    if db.query(User).filter(User.phone == data.phone).first():
        raise HTTPException(400, "Phone number already registered")
    if data.email and db.query(User).filter(User.email == data.email).first():
        raise HTTPException(400, "Email already registered")

    user = User(
        id=str(uuid.uuid4()),
        phone=data.phone,
        full_name=data.full_name,
        email=data.email,
        hashed_password=hash_password(data.password),
        kyc_tier=KYCTier.TIER_1,
    )
    db.add(user)
    db.flush()

    # Create wallet
    wallet = Wallet(id=str(uuid.uuid4()), user_id=user.id, eco_credits=0.0)
    db.add(wallet)
    db.commit()
    db.refresh(user)

    return TokenResponse(
        access_token=create_access_token({"sub": user.id}),
        refresh_token=create_refresh_token({"sub": user.id}),
        user_id=user.id,
        full_name=user.full_name,
        kyc_tier=user.kyc_tier.value,
    )


@router.post("/login", response_model=TokenResponse)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone == form.username).first()
    if not user or not verify_password(form.password, user.hashed_password):
        raise HTTPException(401, "Incorrect phone or password")
    if not user.is_active:
        raise HTTPException(403, "Account suspended")

    return TokenResponse(
        access_token=create_access_token({"sub": user.id}),
        refresh_token=create_refresh_token({"sub": user.id}),
        user_id=user.id,
        full_name=user.full_name,
        kyc_tier=user.kyc_tier.value,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(data: RefreshRequest, db: Session = Depends(get_db)):
    try:
        payload = decode_token(data.refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(401, "Invalid refresh token")
        user_id = payload.get("sub")
    except Exception:
        raise HTTPException(401, "Invalid or expired refresh token")

    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        raise HTTPException(401, "User not found")

    return TokenResponse(
        access_token=create_access_token({"sub": user.id}),
        refresh_token=create_refresh_token({"sub": user.id}),
        user_id=user.id,
        full_name=user.full_name,
        kyc_tier=user.kyc_tier.value,
    )
