import mimetypes
import re
from datetime import datetime
from os import stat
from os.path import basename, splitext
from stat import S_ISDIR

from unidecode import unidecode

from .types import Dict

from urllib.parse import unquote


def to_uint(n: str) -> int:
    if isinstance(n, int):
        return 0 if n < 0 else n
    if isinstance(n, str) and n.isdigit():
        return int(n)
    return 0


def norm_location(location: str) -> str:
    return unquote(location).rstrip("/")


def parse_item(filepath: str, media_dir: str = ""):
    filestat = stat(filepath)
    filename = basename(filepath)
    is_dir = S_ISDIR(filestat.st_mode)

    ctx = {
        "path": filepath[len(media_dir) :],
        "name": filename,
        "size": filestat.st_size,
        "ctime": filestat.st_ctime,
        "mtime": filestat.st_mtime,
        "isdir": is_dir,
        "content_type": None,
    }

    if not is_dir:
        content_type, _ = mimetypes.guess_type(filename)
        ctx.update({"content_type": content_type or "application/octet-stream"})
    return Dict(**ctx)


def slugify(
    name: str,
    delimiter: str = "-",
    allow_unicode: bool = False,
    use_stamp: bool = False,
) -> str:
    n, ext = splitext(name)

    slug = (n if allow_unicode else unidecode(n)).lower()

    slug = re.sub(r"[^\w\s\-\_]", "", slug)
    slug = re.sub(r"[\-\_]", " ", slug)
    slug = re.sub(r"\s{2,}", " ", slug.strip())
    slug = slug.replace(" ", "-")

    stamp = ""

    if use_stamp:
        stamp = "-" + str(datetime.now().timestamp()).split(".")[0]

    return slug + stamp + ext


"""
import psutil

def index_view():

    hdd = psutil.disk_usage(media_dir)

    return {"free": hdd.free, "percent": hdd.percent}

GetSize(file) {
    const bytes = file.size;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];

    if (bytes == 0) return '0 Byte';
    let i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));

    return Math.round(bytes / Math.pow(1024, i), 2) + ' ' + sizes[i];
}

"""
