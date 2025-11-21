import tomli
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent


def get_config() -> dict:
    with open(BASE_DIR.parent / "config/project.toml", "rb") as fp:
        return tomli.load(fp)


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
