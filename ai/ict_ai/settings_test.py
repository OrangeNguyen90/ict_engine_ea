"""Isolated SQLite database for unit tests; production settings default to PostgreSQL."""
from .settings import *  # noqa: F403

DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}
