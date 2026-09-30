import os, secrets
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8300"
    TELEMETRY_KEY: str = ""
    DATABASE_URL: str = "sqlite:///./wastepay_dev.db"
    SECRET_KEY: str = ""
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    PAYSTACK_SECRET_KEY: str = ""
    PAYSTACK_BASE_URL: str = "https://api.paystack.co"
    PREMBLY_API_KEY: str = ""
    AFRICAS_TALKING_USERNAME: str = "sandbox"
    AFRICAS_TALKING_API_KEY: str = ""
    RATE_PLASTIC: float = 400.0
    RATE_PAPER: float = 300.0
    RATE_GLASS: float = 150.0
    RATE_METAL: float = 600.0
    RATE_ORGANIC: float = 80.0
    RATE_ELECTRONICS: float = 1200.0
    RATE_MIXED: float = 100.0
    LIMIT_TIER_1: float = 20_000.0
    LIMIT_TIER_2: float = 200_000.0
    LIMIT_TIER_3: float = 5_000_000.0
    class Config:
        env_file = ".env"

settings = Settings()
if settings.ENVIRONMENT == "production" and (len(settings.SECRET_KEY) < 32 or settings.SECRET_KEY.startswith("dev-")):
    raise RuntimeError("Production requires a random SECRET_KEY of at least 32 characters")
if not settings.SECRET_KEY:
    settings.SECRET_KEY = secrets.token_urlsafe(48) # Development only; configure a persistent key for deployment.

from app.core.database import SessionLocal, Base, get_db

from datetime import datetime, timedelta
from typing import Optional
from passlib.context import CryptContext
from jose import JWTError, jwt

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

def decode_token(token: str) -> dict:
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
