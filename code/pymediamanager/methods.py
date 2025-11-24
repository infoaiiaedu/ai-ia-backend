from datetime import datetime
from os import listdir, makedirs, mkdir, utime
from os.path import basename, isdir, join, splitext


from PIL import Image

from .types import Dict
from .utils import parse_item, slugify


def _get_location_data(media_dir: str, location: str, skip: int = 0, limit: int = 20):
    def is_exclude(name: str):
        if name.startswith("_"):
            return True
        return False

    items = listdir(location)

    has_uploads = False

    if "uploads" in items:
        items.remove("uploads")
        has_uploads = True

    items = sorted(
        (
            parse_item(join(location, name), media_dir)
            for name in items
            if not is_exclude(name)
        ),
        key=lambda it: (it["isdir"], it["ctime"]),
        reverse=True,
    )

    if has_uploads:
        items.insert(0, parse_item(join(location, "uploads"), media_dir))

    count = len(items)

    return Dict(
        skip=skip,
        count=count,
        limit=limit,
        location=location[len(media_dir) :],
        result=items[skip : skip + limit],
    )


def _create_directory(media_dir: str, location: str, name: str):
    i = 0
    d = None

    for _ in range(1000):
        suffix = "" if i == 0 else f"_{i}"
        d = join(location, name + suffix)

        if not isdir(d):
            break
        i += 1

    if d is not None and not isdir(d):
        mkdir(d)

    return Dict(location=d[len(media_dir) :], name=basename(d))


def _write_to_disk(filepath: str, file) -> bool:
    if hasattr(file, "save"):
        file.save(filepath)
    elif hasattr(file, "chunks"):
        with open(filepath, "wb+") as destination:
            for chunk in file.chunks():
                destination.write(chunk)
    else:
        return False

    utime(filepath)

    return True


def _get_name(file):
    if hasattr(file, "filename"):
        return file.filename
    return file.name


def _upload_files(
    media_dir: str,
    thumb_dir: str,
    rellocation: str,
    files: list,
    upload_in_current_dir: bool,
):
    ufs = []

    for file in files:
        name, ext = splitext(_get_name(file))
        ext = ext.lower()

        filename = slugify(name, use_stamp=not upload_in_current_dir) + ext

        if not upload_in_current_dir:
            rellocation = datetime.now().strftime("uploads/%Y/%m-%d")

        location_media = join(media_dir, rellocation)
        location_thumb = join(thumb_dir, rellocation)

        filepath = join(location_media, filename)
        thumbpath = join(location_thumb, filename)

        if not isdir(location_media):
            makedirs(location_media)

        status = _write_to_disk(filepath, file)

        if not status:
            continue

        ufs.append(parse_item(filepath, media_dir))

        try:
            if ext.lower() in [".png", ".jpg", ".jpeg"]:
                ext = ext.lower()
                if not isdir(location_thumb):
                    makedirs(location_thumb)

                thumb, _ = splitext(thumbpath)

                with Image.open(filepath) as img:
                    img.thumbnail((900, 900))
                    img.save(thumb + ext, quality=90)
                    img.save(thumb + ".webp")
        except Exception:
            pass

    return {
        "msg": "ფაილები ატვირთულია",
        "location": "/" + rellocation,
        "files": ufs,
    }
