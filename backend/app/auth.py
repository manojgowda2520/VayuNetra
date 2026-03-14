from datetime import datetime, timedelta
from typing import Optional

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings


pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd.verify(plain, hashed)


def create_token(data: dict) -> str:
    payload = {**data, "exp": datetime.utcnow() + timedelta(hours=settings.ACCESS_TOKEN_EXPIRE_HOURS)}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        return None


def get_password_hash(password: str) -> str:
    return hash_password(password)


def create_access_token(subject: str, expires_delta: timedelta | None = None) -> str:
    data = {"sub": subject}
    if expires_delta is not None:
        payload = {**data, "exp": datetime.utcnow() + expires_delta}
        return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return create_token(data)


def decode_access_token(token: str) -> dict:
    payload = decode_token(token)
    if payload is None:
        raise ValueError("Could not validate credentials")
    return payload


def compute_badge_level(report_count: int) -> str:
    if report_count >= 100:
        return "Legend of Bengaluru"
    if report_count >= 50:
        return "Diamond Sentinel"
    if report_count >= 20:
        return "Gold Protector"
    if report_count >= 5:
        return "Silver Watchdog"
    return "Bronze Guardian"
