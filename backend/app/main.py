from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.config import settings
from app.database import SessionLocal, enable_pgvector, engine
from app.models import Base
from app.routers import auth, chat, clean_zones, nova_act, reports, search, stats, voice
from app.services.s3_service import ensure_bucket_exists

settings.uploads_dir.mkdir(parents=True, exist_ok=True)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("vayunetra")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting VayuNetra API...")
    db = SessionLocal()
    enable_pgvector(db)
    db.close()
    Base.metadata.create_all(bind=engine)
    logger.info("Database + pgvector ready")
    try:
        ensure_bucket_exists()
        logger.info("S3 ready")
    except Exception as exc:
        logger.warning(f"S3: {exc}")
    logger.info("VayuNetra API started — Nova services: Lite + Sonic + Embed + Act")
    yield


app = FastAPI(
    title="VayuNetra API",
    description="""
# VayuNetra — The Eye on Bengaluru's Air
**ವಾಯು ನೇತ್ರ** | Amazon Nova AI Hackathon 2026

## Nova Services Used
| Model | Purpose |
|-------|---------|
| `us.amazon.nova-2-lite-v1:0` | Photo analysis + AI chat + complaint letter |
| `amazon.nova-2-sonic-v1:0` | Voice transcription EN/KN/HI |
| `amazon.nova-2-multimodal-embeddings-v1:0` | VECTOR(1024) image embeddings |
| `amazon.nova-act-v1:0` | UI automation — KSPCB complaint filing |
    """,
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.exception_handler(Exception)
async def unhandled_exception_handler(_: Request, exc: Exception) -> JSONResponse:
    logger.error(f"Error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


@app.get("/")
def root():
    return {"message": "VayuNetra API", "docs": "/docs", "health": "/health"}


@app.get("/health")
def health():
    db_status = "connected"
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))
        db.close()
    except Exception as exc:
        db_status = f"error: {exc}"
    return {
        "status": "ok",
        "app": "VayuNetra",
        "tagline": "The Eye on Bengaluru's Air — ವಾಯು ನೇತ್ರ",
        "db": db_status,
        "environment": settings.ENVIRONMENT,
        "nova_models": {
            "lite": settings.NOVA_LITE_MODEL_ID,
            "sonic": settings.NOVA_SONIC_MODEL_ID,
            "embed": settings.NOVA_EMBED_MODEL_ID,
            "act": "amazon.nova-act-v1:0",
        },
        "hackathon": "Amazon Nova AI Hackathon 2026",
        "category": "Multimodal Understanding",
    }


app.mount("/uploads", StaticFiles(directory=settings.uploads_dir), name="uploads")

app.include_router(auth.router)
app.include_router(reports.router)
app.include_router(search.router)
app.include_router(stats.router)
app.include_router(chat.router)
app.include_router(clean_zones.router)
app.include_router(voice.router)
app.include_router(nova_act.router)
