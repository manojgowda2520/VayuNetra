from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.auth import create_token, hash_password, verify_password
from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas import TokenResponse, UserLogin, UserOut, UserRegister


router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse)
def register(data: UserRegister, db: Session = Depends(get_db)):
    name = data.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")

    existing = db.query(User).filter(
        (User.email == data.email) | (User.username == name)
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email or username already taken")

    user = User(
        username=name,
        email=data.email.lower() if data.email else None,
        password_hash=hash_password(data.password),
        points=0,
        badge_level="Bronze Guardian",
        report_count=0,
    )
    db.add(user); db.commit(); db.refresh(user)
    return {"token": create_token({"sub": str(user.user_id)}), "user": UserOut.from_user(user)}


@router.post("/login", response_model=TokenResponse)
def login(data: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        (User.email == data.email) | (User.username == data.email)
    ).first()
    if not user or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    user.last_login = datetime.utcnow()
    db.commit()
    return {"token": create_token({"sub": str(user.user_id)}), "user": UserOut.from_user(user)}


@router.get("/me", response_model=UserOut)
def me(current_user: User = Depends(get_current_user)):
    return UserOut.from_user(current_user)
