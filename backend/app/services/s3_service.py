from __future__ import annotations

import uuid
from pathlib import Path

import aiofiles
import boto3
from botocore.config import Config
from botocore.exceptions import ClientError
from fastapi import Request

from app.config import settings

SIGNED_URL_TTL_SECONDS = 3600


def _suffix_for_content_type(content_type: str) -> str:
    return {
        "image/png": ".png",
        "image/webp": ".webp",
        "image/gif": ".gif",
    }.get(content_type.lower(), ".jpg")


def _s3():
    return boto3.client(
        "s3",
        region_name=settings.S3_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
    )


def upload_photo(file_bytes: bytes, content_type: str = "image/jpeg") -> tuple[str, str]:
    """Upload pollution photo to S3. Returns (canonical_url, s3_key)."""
    s3 = _s3()
    key = f"pollution-reports/{uuid.uuid4()}{_suffix_for_content_type(content_type)}"
    s3.put_object(
        Bucket=settings.S3_BUCKET_NAME,
        Key=key,
        Body=file_bytes,
        ContentType=content_type,
    )
    url = f"https://{settings.S3_BUCKET_NAME}.s3.{settings.S3_REGION}.amazonaws.com/{key}"
    return url, key


def get_photo_url(image_url: str | None, image_key: str | None) -> str | None:
    if image_key and settings.use_s3:
        try:
            return _s3().generate_presigned_url(
                "get_object",
                Params={"Bucket": settings.S3_BUCKET_NAME, "Key": image_key},
                ExpiresIn=SIGNED_URL_TTL_SECONDS,
            )
        except ClientError:
            pass
    return image_url


def delete_photo(s3_key: str) -> bool:
    try:
        _s3().delete_object(Bucket=settings.S3_BUCKET_NAME, Key=s3_key)
        return True
    except ClientError:
        return False


def ensure_bucket_exists():
    if not settings.use_s3:
        return
    s3 = _s3()
    try:
        s3.head_bucket(Bucket=settings.S3_BUCKET_NAME)
    except ClientError as exc:
        error_code = exc.response.get("Error", {}).get("Code")
        if error_code in {"404", "NoSuchBucket", "NotFound"}:
            kwargs = {"Bucket": settings.S3_BUCKET_NAME}
            if settings.S3_REGION != "us-east-1":
                kwargs["CreateBucketConfiguration"] = {"LocationConstraint": settings.S3_REGION}
            s3.create_bucket(**kwargs)
        else:
            raise


class StorageService:
    async def upload_image(
        self,
        *,
        filename: str,
        file_bytes: bytes,
        content_type: str | None,
        request: Request,
    ) -> str:
        if settings.use_s3:
            try:
                canonical_url, s3_key = upload_photo(file_bytes, content_type or "image/jpeg")
                return get_photo_url(canonical_url, s3_key) or canonical_url
            except ClientError:
                pass

        settings.uploads_dir.mkdir(parents=True, exist_ok=True)
        suffix = Path(filename).suffix or ".jpg"
        local_name = f"{uuid.uuid4().hex}{suffix.lower()}"
        local_path = settings.uploads_dir / local_name
        async with aiofiles.open(local_path, "wb") as file_obj:
            await file_obj.write(file_bytes)
        return f"{self._public_base_url(request)}/uploads/{local_name}"

    def _public_base_url(self, request: Request) -> str:
        if settings.PUBLIC_BASE_URL:
            return settings.PUBLIC_BASE_URL.rstrip("/")
        return str(request.base_url).rstrip("/")


storage_service = StorageService()
