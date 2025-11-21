from os.path import join
from pathlib import Path
from pyconf import BASE_DIR, get_config, get_database

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

SITE_NAME = "AI-IA"

STORAGE_DIR = BASE_DIR.parent / "storage"

env = get_config()
project_env = env["project"]

SECRET_KEY = project_env["SECRET_KEY"]

DEBUG = project_env.get("DEBUG", True)

ALLOWED_HOSTS = project_env.get("ALLOWED_HOSTS", [])
CSRF_TRUSTED_ORIGINS = project_env.get("CSRF_TRUSTED_ORIGINS", [])

REDIS_URI = project_env.get("REDIS_URI")


AUTH_USER_MODEL = "user.User"

SITE_NAME = "AI-IA"
# SITE_LOGO_URL = "/static/img/logo/logo_icon_32x32.png"

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "adminsortable2",
    "djangoeditorwidgets",
    "apps.core",
    "apps.user",
    "apps.widgets",
    "corsheaders",
    "admin_auto_filters",
    "django.contrib.sitemaps",
]

# X_FRAME_OPTIONS = None


MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    # "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "corsheaders.middleware.CorsMiddleware",
]

ROOT_URLCONF = "main.urls"


TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "main.context.handler",
            ],
        },
    },
    {
        "BACKEND": "django.template.backends.jinja2.Jinja2",
        "DIRS": [BASE_DIR / "jinja2", BASE_DIR / "apps/rss/jinja2",],
        "APP_DIRS": False,
        "OPTIONS": {
            "environment": "main.jinja2.environment",
            "extensions": [
                "jinja2.ext.do",
                "jinja2.ext.loopcontrols",
                "jinja2.ext.i18n",
                "jinja2.ext.debug",
            ],
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.template.context_processors.i18n",
                "django.contrib.messages.context_processors.messages",
                "django.contrib.auth.context_processors.auth",
                "main.context.handler",
                "apps.customscript.context.handler",
            ],
        },
    },
]

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_URI,
    },
    "session": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": f"{REDIS_URI}/1",
    },
}


WSGI_APPLICATION = "main.wsgi.application"

# if DEBUG:
#     import sys
#     LOGGING = {
#         "version": 1,
#         "disable_existing_loggers": False,
#         "formatters": {
#             "verbose": {
#                 "format": "[{asctime}] {levelname} {name} - {message}",
#                 "style": "{",
#             },
#         },
#         "handlers": {
#             "console": {
#                 "level": "DEBUG",
#                 "class": "logging.StreamHandler",
#                 "stream": sys.stdout,  # explicitly set to stdout
#                 "formatter": "verbose",
#             },
#         },
#         "loggers": {
#             "django": {
#                 "handlers": ["console"],
#                 "level": "DEBUG",
#                 "propagate": True,
#             },
#         },
#         "": {
#             "handlers": ["console"],
#             "level": "DEBUG",
#             "propagate": True,
#         },
#     }


DATABASES = {"default": get_database(env["database"])}


AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]


LANGUAGE_CODE = "ka"

TIME_ZONE = "Asia/Tbilisi"
USE_I18N = True
USE_L10N = True
USE_TZ = True


MEDIA_URL = "/media/"
STATIC_URL = "/static/"


MEDIA_ROOT = STORAGE_DIR / "media"
STATIC_ROOT = STORAGE_DIR / "static"
SMALL_IMAGE_SUFFIX = '_small'

STATICFILES_DIRS = [
    BASE_DIR / "staticfiles",
    BASE_DIR / "static_cdn",
]

JWT_SECRET_KEY = project_env["SECRET_KEY"]
JWT_ALGORITHM = "HS256"
JWT_EXP_DELTA_SECONDS = 3600

WEB_EDITOR_DOWNLOAD = {
    "to": BASE_DIR / "static_cdn",
    "tinymce": {
        "url": "https://download.tiny.cloud/tinymce/community/tinymce_5.10.3.zip",
        "target": "tinymce/js/tinymce",
    },
    "monaco": {
        "url": "https://registry.npmjs.org/monaco-editor/-/monaco-editor-0.32.1.tgz",
        "target": "package/min",
    },
}

WEB_EDITOR_CONFIG = {
    "tinymce": {
        "js": [
            join(STATIC_URL, "tinymce/tinymce.min.js"),
            join(STATIC_URL, "djangoeditorwidgets/tinymce/tinymce.config.js"),
            join(STATIC_URL, "djangoeditorwidgets/tinymce/tinymce.init.js"),
        ],
        "css": {
            "all": [
                join(STATIC_URL, "djangoeditorwidgets/tinymce/tinymce.custom.css"),
            ]
        },
    },
    "monaco": {
        "js": [
            join(STATIC_URL, "monaco/vs/loader.js"),
            join(STATIC_URL, "djangoeditorwidgets/monaco/monaco.config.js"),
        ],
        "css": {
            "all": [
                join(STATIC_URL, "djangoeditorwidgets/monaco/monaco.custom.css"),
            ]
        },
    },
}


DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
