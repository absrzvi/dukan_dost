"""
Production settings for Dukaan Dost.

Required environment variables (all must be set — missing values fail hard):
  SECRET_KEY          — Django secret key (generate with: python -c "import secrets; print(secrets.token_hex(50))")
  DATABASE_URL        — PostgreSQL connection string (e.g. postgres://user:pass@host/db)
  ALLOWED_HOSTS       — Comma-separated list of allowed hostnames (e.g. dukaan-dost-api.onrender.com)

Optional:
  DJANGO_SETTINGS_MODULE  — must be config.settings.production
"""

import os

import dj_database_url

from .base import *  # noqa: F401, F403

# -----------------------------------------------------------------------
# Core
# -----------------------------------------------------------------------

DEBUG = False

# Fail hard on startup if SECRET_KEY is not set — never use a default in prod.
SECRET_KEY = os.environ["SECRET_KEY"]

ALLOWED_HOSTS = [h.strip() for h in os.environ.get("ALLOWED_HOSTS", "").split(",") if h.strip()]

# -----------------------------------------------------------------------
# Database — Postgres via DATABASE_URL
# -----------------------------------------------------------------------

DATABASES = {
    "default": dj_database_url.config(
        conn_max_age=600,
        ssl_require=True,
    )
}

# -----------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------

SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000  # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

# -----------------------------------------------------------------------
# Static files — WhiteNoise
# -----------------------------------------------------------------------

STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"  # type: ignore[assignment]

# Insert WhiteNoise after SecurityMiddleware
_WHITENOISE = "whitenoise.middleware.WhiteNoiseMiddleware"
if _WHITENOISE not in MIDDLEWARE:  # noqa: F405
    _idx = next(
        (i for i, m in enumerate(MIDDLEWARE) if "SecurityMiddleware" in m),  # noqa: F405
        0,
    )
    MIDDLEWARE.insert(_idx + 1, _WHITENOISE)  # noqa: F405

STATIC_ROOT = BASE_DIR / "staticfiles"  # noqa: F405

# -----------------------------------------------------------------------
# Logging — structured output for log aggregators
# -----------------------------------------------------------------------

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "WARNING",
    },
}
