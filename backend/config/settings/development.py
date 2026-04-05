"""
Development settings for Dukaan Dost.
Extends base settings with dev-friendly overrides.
"""

from .base import *  # noqa: F401, F403

DEBUG = True

# Allow all hosts in development
ALLOWED_HOSTS = ["*"]

# Use SQLite in development if DATABASE_URL is not set
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",  # noqa: F405
    }
}

# In development, use local memory cache if Redis is not available
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    }
}

# Show emails in console during development
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
