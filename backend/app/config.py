from pathlib import Path
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    # App
    SECRET_KEY: str = "change_me_in_production_min_32_chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_HOURS: int = 24
    ENVIRONMENT: str = "development"
    ALLOWED_ORIGINS: str = "http://localhost:3000"
    PUBLIC_BASE_URL: str | None = None

    # AWS
    AWS_ACCESS_KEY_ID: str | None = None
    AWS_SECRET_ACCESS_KEY: str | None = None
    AWS_REGION: str = "us-east-1"

    # S3
    S3_BUCKET_NAME: str = "vayunetra-pollution-images"
    S3_REGION: str = "us-east-1"

    # Amazon Bedrock — set to true to use Nova (Lite, Sonic, Embed)
    USE_BEDROCK: bool = True

    # Nova model IDs
    NOVA_LITE_MODEL_ID: str = "us.amazon.nova-2-lite-v1:0"
    NOVA_SONIC_MODEL_ID: str = "us.amazon.nova-2-sonic-v1:0"
    NOVA_EMBED_MODEL_ID: str = "us.amazon.nova-2-multimodal-embeddings-v1:0"

    # Database
    DATABASE_URL: str = "sqlite:///./vayunetra.db"

    # Google Air Quality API (for Clean Air live AQI)
    GOOGLE_AQI_API_KEY: str | None = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    @property
    def allowed_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]

    @property
    def uploads_dir(self) -> Path:
        return BASE_DIR / "uploads"

    @property
    def is_postgres(self) -> bool:
        return self.DATABASE_URL.startswith("postgresql")

    @property
    def use_s3(self) -> bool:
        return bool(self.S3_BUCKET_NAME and self.AWS_ACCESS_KEY_ID and self.AWS_SECRET_ACCESS_KEY)

    @property
    def use_bedrock(self) -> bool:
        return bool(
            self.USE_BEDROCK
            and self.AWS_ACCESS_KEY_ID
            and self.AWS_SECRET_ACCESS_KEY
            and self.AWS_REGION
        )

    @property
    def debug(self) -> bool:
        return self.ENVIRONMENT.lower() == "development"

    @property
    def app_name(self) -> str:
        return "VayuNetra Backend"

    @property
    def cors_origins(self) -> list[str]:
        return self.allowed_origins_list

    @property
    def environment(self) -> str:
        return self.ENVIRONMENT

    @property
    def secret_key(self) -> str:
        return self.SECRET_KEY

    @property
    def algorithm(self) -> str:
        return self.ALGORITHM

    @property
    def access_token_expire_hours(self) -> int:
        return self.ACCESS_TOKEN_EXPIRE_HOURS

    @property
    def aws_access_key_id(self) -> str | None:
        return self.AWS_ACCESS_KEY_ID

    @property
    def aws_secret_access_key(self) -> str | None:
        return self.AWS_SECRET_ACCESS_KEY

    @property
    def aws_region(self) -> str:
        return self.AWS_REGION

    @property
    def s3_bucket_name(self) -> str:
        return self.S3_BUCKET_NAME

    @property
    def s3_region(self) -> str:
        return self.S3_REGION

    @property
    def nova_lite_model_id(self) -> str:
        return self.NOVA_LITE_MODEL_ID

    @property
    def nova_sonic_model_id(self) -> str:
        return self.NOVA_SONIC_MODEL_ID

    @property
    def nova_embed_model_id(self) -> str:
        return self.NOVA_EMBED_MODEL_ID

    @property
    def database_url(self) -> str:
        return self.DATABASE_URL

    @property
    def allowed_origins(self) -> str:
        return self.ALLOWED_ORIGINS

    @property
    def public_base_url(self) -> str | None:
        return self.PUBLIC_BASE_URL

    @property
    def google_aqi_api_key(self) -> str | None:
        return self.GOOGLE_AQI_API_KEY


settings = Settings()
