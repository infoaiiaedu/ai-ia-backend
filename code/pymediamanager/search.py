import json
from os import walk
from os.path import join

from .utils import parse_item


def search_generator(location: str, q: str, media_dir: str = ""):
    def exclude_dir(d: str):
        if d.startswith("_") or d.startswith("."):
            return True
        return False

    def check(name):
        return q.lower() in name.lower()

    def walking():
        for root, dirs, files in walk(location, topdown=True):
            dirs[:] = [d for d in dirs if not exclude_dir(d)]

            for name in files:
                if check(name):
                    itm = parse_item(join(root, name), media_dir)
                    yield json.dumps(itm).encode() + b", "

            for name in dirs:
                if check(name):
                    itm = parse_item(join(root, name), media_dir)
                    yield json.dumps(itm).encode() + b", "

    return walking
