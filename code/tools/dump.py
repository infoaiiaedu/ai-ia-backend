import json
import pathlib
import pickle

from django.conf import settings


def pkl_dump(name, query):
    filename: pathlib.Path = settings.BASE_DIR / f"tmp/dump/{name}.pkl"

    filename.parent.mkdir(parents=True, exist_ok=True)

    with open(filename, "wb") as fp:
        pickle.dump(query, fp)


def pkl_load(name):
    filename: pathlib.Path = settings.BASE_DIR / f"tmp/dump/articles/{name}.pkl"

    if not filename.is_file():
        return None

    with open(filename, "rb") as fp:
        return pickle.load(fp)


def json_dump(name, query):
    filename: pathlib.Path = settings.BASE_DIR / f"tmp/dump/{name}.json"

    filename.parent.mkdir(parents=True, exist_ok=True)

    with open(filename, "w") as fp:
        if isinstance(query, str):
            fp.write(query)
        else:
            json.dump(query, fp, indent=4, ensure_ascii=False)


def json_load(name):
    filename: pathlib.Path = settings.BASE_DIR / f"tmp/dump/{name}.json"

    if not filename.is_file():
        return None

    with open(filename, "r") as fp:
        return json.load(fp)
