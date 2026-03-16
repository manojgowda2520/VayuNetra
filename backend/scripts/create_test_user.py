"""
Create the test/demo user: test@vayunetra.com / Test@1234
Run from backend dir: python scripts/create_test_user.py
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.auth import hash_password
from app.database import SessionLocal
from app.models import User


def main():
    db = SessionLocal()
    try:
        email = "test@vayunetra.com"
        existing = db.query(User).filter(User.email == email).first()
        if existing:
            print(f"User already exists: {email}")
            return
        user = User(
            username="test_user",
            email=email,
            password_hash=hash_password("Test@1234"),
            points=0,
            badge_level="Bronze Guardian",
            report_count=0,
        )
        db.add(user)
        db.commit()
        print(f"Created test user: {email} / Test@1234")
    finally:
        db.close()


if __name__ == "__main__":
    main()
