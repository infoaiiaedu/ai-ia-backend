import os
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List

import tomli

BASE_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = BASE_DIR.parent / "config" / "project.toml"


def _env_bool(var_name: str, default: bool) -> bool:
    value = os.environ.get(var_name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _env_list(var_name: str, default: List[str]) -> List[str]:
    value = os.environ.get(var_name)
    if not value:
        return default
    return [item.strip() for item in value.split(",") if item.strip()]


def _build_default_config() -> Dict[str, Any]:
    secret_key = os.environ.get("DJANGO_SECRET_KEY", "django-insecure-ci-key")
    redis_uri = os.environ.get("REDIS_URI", "redis://localhost:6379/0")
    project_config = {
        "SECRET_KEY": secret_key,
        "DEBUG": _env_bool("DJANGO_DEBUG", True),
        "ALLOWED_HOSTS": _env_list("DJANGO_ALLOWED_HOSTS", ["*"]),
        "CSRF_TRUSTED_ORIGINS": _env_list("DJANGO_CSRF_TRUSTED_ORIGINS", []),
        "REDIS_URI": redis_uri,
    }

    engine = os.environ.get("DB_ENGINE", "sqlite3").lower()
    if engine == "sqlite":
        engine = "sqlite3"

    if engine == "sqlite3":
        database_config: Dict[str, Any] = {
            "ENGINE": "sqlite3",
            "NAME": os.environ.get("DB_NAME", str(BASE_DIR / "db.sqlite3")),
        }
    else:
        database_config = {
            "ENGINE": engine,
            "NAME": os.environ.get("DB_NAME", "app"),
            "USER": os.environ.get("DB_USER", "postgres"),
            "PASSWORD": os.environ.get("DB_PASSWORD", "postgres"),
            "HOST": os.environ.get("DB_HOST", "localhost"),
            "PORT": os.environ.get("DB_PORT", "5432"),
        }

    server_config = {
        "IP": os.environ.get("SERVER_IP", "0.0.0.0"),
        "User": os.environ.get("SERVER_USER", "app"),
        "Pass": os.environ.get("SERVER_PASS", "app"),
        "PROJECT_DIR": os.environ.get("SERVER_PROJECT_DIR", "/app"),
        "Root_User": os.environ.get("SERVER_ROOT_USER", "root"),
        "Root_Pass": os.environ.get("SERVER_ROOT_PASS", "root"),
    }

    return {"project": project_config, "database": database_config, "server": server_config}


@lru_cache(maxsize=1)
def get_config() -> Dict[str, Any]:
    config_path = Path(os.environ.get("APP_CONFIG_FILE", DEFAULT_CONFIG_PATH))
    if config_path.exists():
        with open(config_path, "rb") as fp:
            return tomli.load(fp)

    return _build_default_config()


def get_project_config() -> dict:
    return get_config().get("project", {})


def get_bank_config() -> dict:
    return get_config().get("bank", {})


def get_database(dbconf) -> dict:
    engine = dbconf.get("ENGINE", "sqlite3")

    charset = dbconf.pop("charset", None)

    if engine == "sqlite3":
        return {"ENGINE": "django.db.backends.sqlite3", "NAME": BASE_DIR / "db.sqlite3"}

    if charset is not None:
        dbconf["OPTIONS"] = {"charset": charset}

    return {**dbconf, "ENGINE": f"django.db.backends.{engine}"}


if __name__ == "__main__":
    conf = get_project_config()
    print(conf)
