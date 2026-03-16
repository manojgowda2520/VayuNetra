"""
Run ONCE to:
1. Enable pgvector extension
2. Create all tables
3. Seed pollution types, Bengaluru locations, clean zones, admin user

Usage:
    cd backend
    python scripts/init_db.py
"""

import os
import sys

from passlib.context import CryptContext

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import Base, SessionLocal, enable_pgvector, engine
from app.models import (  # noqa: E402
    AdminRoleEnum,
    AdminUser,
    CleanZone,
    HazardLevelEnum,
    Location,
    PollutionType,
    User,
)


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def seed_pollution_types(db) -> None:
    types = [
        {
            "name": "Vehicle Exhaust",
            "description": "Emissions from cars, buses, trucks",
            "hazard_level": HazardLevelEnum.high,
        },
        {
            "name": "Construction Dust",
            "description": "Dust from construction sites",
            "hazard_level": HazardLevelEnum.medium,
        },
        {
            "name": "Industrial Smoke",
            "description": "Smoke from factories and industries",
            "hazard_level": HazardLevelEnum.high,
        },
        {
            "name": "Garbage Burning",
            "description": "Open burning of waste",
            "hazard_level": HazardLevelEnum.high,
        },
        {
            "name": "Open Burning",
            "description": "Agricultural or unauthorized fires",
            "hazard_level": HazardLevelEnum.high,
        },
        {
            "name": "Chemical Emissions",
            "description": "Chemical plant emissions",
            "hazard_level": HazardLevelEnum.high,
        },
        {
            "name": "Dust Pollution",
            "description": "Road dust and suspended particles",
            "hazard_level": HazardLevelEnum.medium,
        },
        {
            "name": "Mixed Pollution",
            "description": "Multiple pollution sources",
            "hazard_level": HazardLevelEnum.medium,
        },
    ]
    for item in types:
        if not db.query(PollutionType).filter(PollutionType.name == item["name"]).first():
            db.add(PollutionType(**item))
    db.commit()
    print("Seeded pollution types")


def seed_bengaluru_locations(db) -> None:
    locations = [
        {
            "name": "Koramangala",
            "district": "Bengaluru Urban",
            "sub_district": "Koramangala",
            "latitude": 12.9352,
            "longitude": 77.6245,
            "population_estimate": 100000,
        },
        {
            "name": "Whitefield",
            "district": "Bengaluru Urban",
            "sub_district": "Whitefield",
            "latitude": 12.9698,
            "longitude": 77.7499,
            "population_estimate": 150000,
        },
        {
            "name": "Electronic City",
            "district": "Bengaluru Urban",
            "sub_district": "EC Phase 1",
            "latitude": 12.8399,
            "longitude": 77.6770,
            "population_estimate": 80000,
        },
        {
            "name": "Hebbal",
            "district": "Bengaluru Urban",
            "sub_district": "Hebbal",
            "latitude": 13.0358,
            "longitude": 77.5970,
            "population_estimate": 90000,
        },
        {
            "name": "Marathahalli",
            "district": "Bengaluru Urban",
            "sub_district": "Marathahalli",
            "latitude": 12.9591,
            "longitude": 77.6974,
            "population_estimate": 120000,
        },
        {
            "name": "Yeshwanthpur",
            "district": "Bengaluru Urban",
            "sub_district": "Yeshwanthpur",
            "latitude": 13.0261,
            "longitude": 77.5493,
            "population_estimate": 110000,
        },
        {
            "name": "BTM Layout",
            "district": "Bengaluru Urban",
            "sub_district": "BTM",
            "latitude": 12.9166,
            "longitude": 77.6101,
            "population_estimate": 95000,
        },
        {
            "name": "HSR Layout",
            "district": "Bengaluru Urban",
            "sub_district": "HSR",
            "latitude": 12.9116,
            "longitude": 77.6473,
            "population_estimate": 85000,
        },
        {
            "name": "Bellandur",
            "district": "Bengaluru Urban",
            "sub_district": "Bellandur",
            "latitude": 12.9257,
            "longitude": 77.6804,
            "population_estimate": 75000,
        },
        {
            "name": "Rajajinagar",
            "district": "Bengaluru Urban",
            "sub_district": "Rajajinagar",
            "latitude": 12.9972,
            "longitude": 77.5556,
            "population_estimate": 88000,
        },
    ]
    for location in locations:
        if not db.query(Location).filter(Location.name == location["name"]).first():
            db.add(Location(**location))
    db.commit()
    print("Seeded Bengaluru locations")


def seed_clean_zones(db) -> None:
    zones = [
        {
            "name": "Cubbon Park",
            "aqi": 34,
            "status": "Excellent",
            "latitude": 12.9763,
            "longitude": 77.5929,
            "activities": ["Jogging", "Yoga", "Kids", "Elderly"],
        },
        {
            "name": "Lalbagh Garden",
            "aqi": 28,
            "status": "Excellent",
            "latitude": 12.9507,
            "longitude": 77.5848,
            "activities": ["Nature walk", "Yoga", "Photography"],
        },
        {
            "name": "Nandi Hills",
            "aqi": 12,
            "status": "Pristine",
            "latitude": 13.3702,
            "longitude": 77.6835,
            "activities": ["Cycling", "Sunrise", "Camping"],
        },
        {
            "name": "Hesaraghatta Lake",
            "aqi": 18,
            "status": "Excellent",
            "latitude": 13.1378,
            "longitude": 77.4617,
            "activities": ["Birdwatching", "Walking"],
        },
        {
            "name": "Bannerghatta Park",
            "aqi": 45,
            "status": "Good",
            "latitude": 12.7993,
            "longitude": 77.5765,
            "activities": ["Wildlife", "Trekking"],
        },
        {
            "name": "Turahalli Forest",
            "aqi": 38,
            "status": "Good",
            "latitude": 12.8871,
            "longitude": 77.5237,
            "activities": ["Running", "MTB"],
        },
    ]
    for zone in zones:
        if not db.query(CleanZone).filter(CleanZone.name == zone["name"]).first():
            db.add(CleanZone(**zone))
    db.commit()
    print("Seeded clean zones")


def seed_admin(db) -> None:
    admin_email = "admin@vayunetra.com"
    if not db.query(AdminUser).filter(AdminUser.email == admin_email).first():
        db.add(
            AdminUser(
                username="vayunetra_admin",
                email=admin_email,
                password_hash=pwd_context.hash("VayuAdmin@2026!"),
                role=AdminRoleEnum.super_admin,
            )
        )
        db.commit()
        print("Seeded admin user")
    else:
        print("Admin already exists")


def seed_test_user(db) -> None:
    """Seed demo/test user for docs and mobile app: test@vayunetra.com / Test@1234"""
    test_email = "test@vayunetra.com"
    if not db.query(User).filter(User.email == test_email).first():
        db.add(
            User(
                username="test_user",
                email=test_email,
                password_hash=pwd_context.hash("Test@1234"),
                points=0,
                badge_level="Bronze Guardian",
                report_count=0,
            )
        )
        db.commit()
        print("Seeded test user (test@vayunetra.com / Test@1234)")
    else:
        print("Test user already exists")


if __name__ == "__main__":
    db = SessionLocal()
    try:
        print("Enabling pgvector...")
        enable_pgvector(db)

        print("Creating tables...")
        Base.metadata.create_all(bind=engine)

        seed_pollution_types(db)
        seed_bengaluru_locations(db)
        seed_clean_zones(db)
        seed_admin(db)
        seed_test_user(db)
        print("VayuNetra database ready")
    finally:
        db.close()
