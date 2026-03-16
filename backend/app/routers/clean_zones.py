from typing import List

import httpx
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import CleanZone
from app.schemas import CleanZoneOut, LiveCleanZoneOut


router = APIRouter(prefix="/api", tags=["clean-zones"])

# Bengaluru clean-air zones with coordinates (used for live AQI lookup).
LIVE_ZONES = [
    {"name": "Cubbon Park", "latitude": 12.9763, "longitude": 77.5929, "activities": ["Jogging", "Yoga", "Kids", "Elderly"]},
    {"name": "Lalbagh Garden", "latitude": 12.9507, "longitude": 77.5848, "activities": ["Nature walk", "Yoga", "Photography"]},
    {"name": "Nandi Hills", "latitude": 13.3702, "longitude": 77.6835, "activities": ["Cycling", "Sunrise", "Camping"]},
    {"name": "Hesaraghatta Lake", "latitude": 13.1378, "longitude": 77.4617, "activities": ["Birdwatching", "Walking"]},
    {"name": "Bannerghatta Park", "latitude": 12.7993, "longitude": 77.5765, "activities": ["Wildlife", "Trekking"]},
    {"name": "Turahalli Forest", "latitude": 12.8871, "longitude": 77.5237, "activities": ["Running", "MTB"]},
]


def _aqi_to_status(aqi: int) -> str:
    if aqi <= 50:
        return "Excellent"
    if aqi <= 100:
        return "Good"
    if aqi <= 150:
        return "Moderate"
    return "Unhealthy"


@router.get("/clean-zones", response_model=List[CleanZoneOut])
def get_clean_zones(db: Session = Depends(get_db)):
    return db.query(CleanZone).order_by(CleanZone.aqi).all()


@router.get("/clean-zones/live", response_model=List[LiveCleanZoneOut])
def get_clean_zones_live():
    """Return clean-air zones with live AQI from Google Air Quality API."""
    api_key = settings.google_aqi_api_key
    if not api_key:
        raise HTTPException(
            status_code=503,
            detail="Live AQI not configured. Set GOOGLE_AQI_API_KEY in backend .env.",
        )
    url = "https://airquality.googleapis.com/v1/currentConditions:lookup"
    results: List[LiveCleanZoneOut] = []
    for zone in LIVE_ZONES:
        aqi = 0
        try:
            with httpx.Client(timeout=10.0) as client:
                r = client.post(
                    f"{url}?key={api_key}",
                    json={"location": {"latitude": zone["latitude"], "longitude": zone["longitude"]}},
                    headers={"Content-Type": "application/json"},
                )
                r.raise_for_status()
                data = r.json()
                indexes = data.get("indexes") or []
                if indexes:
                    aqi = int(indexes[0].get("aqi", 0))
        except Exception:
            aqi = 0
        status = _aqi_to_status(aqi) if aqi else "Unknown"
        results.append(
            LiveCleanZoneOut(
                name=zone["name"],
                aqi=aqi,
                status=status,
                latitude=zone["latitude"],
                longitude=zone["longitude"],
                activities=zone["activities"],
            )
        )
    return results
