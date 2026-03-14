from __future__ import annotations

import base64
import json
import math
from typing import List, Optional

import boto3

from app.config import settings


def _bedrock():
    return boto3.client(
        "bedrock-runtime",
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
    )


def generate_image_embedding(image_bytes: bytes) -> Optional[List[float]]:
    """
    Generate VECTOR(1024) embedding using Amazon Nova Embed Image.
    """
    if not settings.use_bedrock:
        return None
    bedrock = _bedrock()
    body = {
        "inputImage": base64.b64encode(image_bytes).decode(),
        "embeddingConfig": {"outputEmbeddingLength": 1024},
    }
    try:
        resp = bedrock.invoke_model(
            modelId=settings.NOVA_EMBED_MODEL_ID,
            body=json.dumps(body),
            contentType="application/json",
            accept="application/json",
        )
        embedding = json.loads(resp["body"].read().decode("utf-8")).get("embedding")
        return [float(value) for value in embedding] if embedding else None
    except Exception:
        return None


def generate_location_embedding(latitude: float, longitude: float, area: str = "") -> Optional[List[float]]:
    """
    Generate location embedding using Nova Embed Image with a location description.
    """
    if not settings.use_bedrock:
        return None
    bedrock = _bedrock()
    body = {
        "inputText": (
            f"Pollution location: {area}, Bengaluru, India. GPS coordinates: {latitude:.6f} latitude, "
            f"{longitude:.6f} longitude. Urban area pollution monitoring."
        ),
        "embeddingConfig": {"outputEmbeddingLength": 1024},
    }
    try:
        resp = bedrock.invoke_model(
            modelId=settings.NOVA_EMBED_MODEL_ID,
            body=json.dumps(body),
            contentType="application/json",
            accept="application/json",
        )
        embedding = json.loads(resp["body"].read().decode("utf-8")).get("embedding")
        return [float(value) for value in embedding] if embedding else None
    except Exception:
        return None


def cosine_similarity(a: List[float], b: List[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    mag_a = math.sqrt(sum(x * x for x in a))
    mag_b = math.sqrt(sum(x * x for x in b))
    if mag_a == 0 or mag_b == 0:
        return 0.0
    return dot / (mag_a * mag_b)


def find_similar_reports(target_embedding: List[float], candidates: list, top_k: int = 5) -> list:
    """Cosine similarity search — returns top_k most similar reports."""
    scored = []
    for report, emb in candidates:
        if emb:
            sim = cosine_similarity(target_embedding, emb)
            if sim >= 0.65:
                scored.append((sim, report))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [report for _, report in scored[:top_k]]


class EmbeddingService:
    async def embed_image(self, *, image_bytes: bytes) -> list[float] | None:
        return generate_image_embedding(image_bytes)

    async def embed_location(self, *, latitude: float, longitude: float, area: str = "") -> list[float] | None:
        return generate_location_embedding(latitude, longitude, area)


embedding_service = EmbeddingService()
