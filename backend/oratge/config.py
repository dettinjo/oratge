"""Settings from environment variables (Coolify / Infisical)."""
import os
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Settings:
    meteocat_key: str | None = field(default_factory=lambda: os.environ.get('METEOCAT_API_KEY') or None)
    app_token: str | None = field(default_factory=lambda: os.environ.get('ORATGE_TOKEN') or None)
    db_path: str = field(default_factory=lambda: os.environ.get('ORATGE_DB', 'oratge.db'))
    tz: str = 'Europe/Madrid'
    # Free-plan monthly quotas (HA-integration defaults; verify with /quotes/v1/consum-actual).
    quota: dict = field(default_factory=lambda: {
        'prediccio': int(os.environ.get('QUOTA_PREDICCIO', 100)),
        'xema': int(os.environ.get('QUOTA_XEMA', 750)),
        'xdde': int(os.environ.get('QUOTA_XDDE', 250)),
        'referencia': int(os.environ.get('QUOTA_REFERENCIA', 2000)),
        'quotes': int(os.environ.get('QUOTA_QUOTES', 300)),
    })


settings = Settings()
