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
