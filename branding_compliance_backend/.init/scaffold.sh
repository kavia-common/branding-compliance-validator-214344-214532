#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/branding-compliance-validator-214344-214532/branding_compliance_backend"
mkdir -p "$WS" && cd "$WS"
# Create venv if missing
if [ ! -d "$WS/.venv" ]; then python3 -m venv "$WS/.venv"; fi
if [ ! -x "$WS/.venv/bin/python" ]; then echo "venv_python_missing" >&2; exit 2; fi
# Write minimal requirements (project-level); uvicorn kept for project venv isolation
cat > "$WS/requirements.txt" <<'EOF'
Django>=4.2,<5
opencv-python-headless
Pillow
pytesseract
uvicorn
pytest
EOF
# Create common dirs
mkdir -p "$WS/tmp" "$WS/media" "$WS/static"
# Create .env (dev-only) if missing with generated SECRET_KEY
if [ ! -f "$WS/.env" ]; then
  SECRET_KEY=$(python3 - <<PYTHON
import secrets
print(secrets.token_urlsafe(32))
PYTHON
)
  cat > "$WS/.env" <<EOF
DJANGO_SETTINGS_MODULE=project.settings
SECRET_KEY=$SECRET_KEY
DEBUG=1
DATABASE_URL=sqlite:///$WS/db.sqlite3
MEDIA_ROOT=$WS/media
STATIC_ROOT=$WS/static
EOF
  chmod 600 "$WS/.env"
  if [ -d "$WS/.git" ]; then
    grep -qxF ".env" "$WS/.gitignore" 2>/dev/null || echo ".env" >> "$WS/.gitignore"
  fi
fi
# Initialize Django project only if manage.py missing; do NOT pip install here; use venv python binary for startproject if available
if [ ! -f "$WS/manage.py" ]; then
  if "$WS/.venv/bin/python" -c "import importlib,sys
try:
 importlib.import_module('django')
except Exception:
 sys.exit(2)
" >/dev/null 2>&1; then
    "$WS/.venv/bin/django-admin" startproject project "$WS"
  else
    if command -v django-admin >/dev/null 2>&1; then
      django-admin startproject project "$WS"
    else
      mkdir -p "$WS/project/project"
      cat > "$WS/manage.py" <<'PY'
#!/usr/bin/env python
import os,sys
if __name__=='__main__':
    os.environ.setdefault('DJANGO_SETTINGS_MODULE','project.settings')
    from django.core.management import execute_from_command_line
    execute_from_command_line(sys.argv)
PY
      chmod +x "$WS/manage.py"
      cat > "$WS/project/project/__init__.py" <<'PY'
PY
      cat > "$WS/project/project/urls.py" <<'PY'
from django.urls import path
from django.http import HttpResponse

def index(request):
    return HttpResponse('ok')

urlpatterns = [path('', index)]
PY
      cat > "$WS/project/project/wsgi.py" <<'PY'
import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE','project.settings')
application = get_wsgi_application()
PY
    fi
  fi
  SETTINGS_DIR="$WS/project/project"
  mkdir -p "$SETTINGS_DIR"
  cat > "$SETTINGS_DIR/settings.py" <<'PY'
from pathlib import Path
BASE_DIR = Path('$WS').resolve()
SECRET_KEY = 'dev-secret-key'
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
ROOT_URLCONF = 'project.urls'
WSGI_APPLICATION = 'project.wsgi.application'
DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': str(BASE_DIR / 'db.sqlite3')}}
STATIC_URL = '/static/'
MEDIA_URL = '/media/'
PY
fi
