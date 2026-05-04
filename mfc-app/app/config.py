"""Application configuration."""
import os
import secrets
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Database
DATABASE_URL = f"sqlite:///{BASE_DIR / 'mfc.db'}"

# JWT
SECRET_KEY = os.environ.get('MFC_SECRET_KEY') or secrets.token_hex(32)
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_DAYS = 30  # mobile app stays logged in 30 days

# File uploads
UPLOAD_DIR = BASE_DIR / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)
MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10 MB

# App
APP_NAME = "MFC Vysočina"
APP_VERSION = "0.1.0"
PORT = 5002
