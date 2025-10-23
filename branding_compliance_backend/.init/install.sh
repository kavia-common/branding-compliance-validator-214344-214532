#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/branding-compliance-validator-214344-214532/branding_compliance_backend"
cd "$WS"
# Activate venv
if [ ! -f "$WS/.venv/bin/activate" ]; then
  echo "ERROR: virtualenv not found at $WS/.venv" >&2
  exit 4
fi
. "$WS/.venv/bin/activate"
# Upgrade pip quietly and install requirements into venv
python -m pip install --upgrade pip --quiet
if [ -f requirements.txt ]; then
  python -m pip install --upgrade --quiet --no-cache-dir -r requirements.txt
else
  echo "WARNING: requirements.txt not found; skipping pip install" >&2
fi
# If OCR_CLI=1 ensure tesseract binary exists (install if requested)
if [ "${OCR_CLI:-0}" = "1" ]; then
  if ! command -v tesseract >/dev/null 2>&1; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -q >/dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q tesseract-ocr >/dev/null
  fi
fi
# Check uvicorn version in image (global) and in venv
GLOBAL_UVICORN_VER=$(command -v uvicorn >/dev/null 2>&1 && uvicorn --version 2>/dev/null || true)
VENV_UVICORN_VER=$(python - <<'PY'
import importlib
try:
    m = importlib.import_module('uvicorn')
    print(getattr(m, '__version__', 'unknown'))
except Exception:
    print('absent')
PY
)
printf 'global_uvicorn=%s\nvenv_uvicorn=%s\n' "$GLOBAL_UVICORN_VER" "$VENV_UVICORN_VER"
# Verify key imports and versions; fail on import errors
python - <<'PY'
import sys
try:
    import django; print('django', django.get_version())
    import cv2; print('cv2', cv2.__version__)
    from PIL import Image; print('Pillow', Image.__version__)
    import pytesseract; print('pytesseract', getattr(pytesseract, '__version__', 'unknown'))
except Exception as e:
    print('ERROR: dependency import failed:', e, file=sys.stderr)
    sys.exit(3)
PY
# Warn if pytesseract present but tesseract CLI missing
if python - <<'PY'
import sys
try:
  import pytesseract
  sys.exit(0)
except Exception:
  sys.exit(2)
PY
then
  if ! command -v tesseract >/dev/null 2>&1; then
    echo "WARNING: pytesseract installed but tesseract CLI not found; OCR runtime will fail unless OCR_CLI=1 and tesseract-ocr is installed" >&2
  fi
fi
# Overwrite settings.py with deterministic absolute DB path consistent with .env
SETTINGS_DIR="$WS/project/project"
mkdir -p "$SETTINGS_DIR"
cat > "$SETTINGS_DIR/settings.py" <<PY
from pathlib import Path
BASE_DIR = Path('$WS').resolve()
# SECRET_KEY is taken from .env if present, else a dev fallback
SECRET_KEY = '$([ -f "$WS/.env" ] && grep -m1 '^SECRET_KEY=' "$WS/.env" | cut -d'=' -f2- || echo "dev-secret-key")'
DEBUG = True
ALLOWED_HOSTS = ['*']
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
]
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]
ROOT_URLCONF = 'project.urls'
TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [],
    'APP_DIRS': True,
    'OPTIONS': {'context_processors': [
        'django.template.context_processors.debug',
        'django.template.context_processors.request',
        'django.contrib.auth.context_processors.auth',
        'django.contrib.messages.context_processors.messages',
    ],},
}]
WSGI_APPLICATION = 'project.wsgi.application'
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': str(BASE_DIR / 'db.sqlite3'),
    }
}
AUTH_PASSWORD_VALIDATORS = []
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True
STATIC_URL = '/static/'
STATIC_ROOT = str(BASE_DIR / 'static')
MEDIA_URL = '/media/'
MEDIA_ROOT = str(BASE_DIR / 'media')
PY
