from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import CleanZone
from app.schemas import CleanZoneOut


router = APIRouter(prefix="/api", tags=["clean-zones"])


@router.get("/clean-zones", response_model=List[CleanZoneOut])
def get_clean_zones(db: Session = Depends(get_db)):
    return db.query(CleanZone).order_by(CleanZone.aqi).all()
