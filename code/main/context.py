from django.http import HttpRequest
import json
from pathlib import Path

from django.conf import settings
from django.utils import timezone

from tools import get_host
from pyconf import get_config


IS_DEBUG: bool = settings.DEBUG
BASE_DIR: Path = settings.BASE_DIR
STORAGE_DIR: Path = settings.STORAGE_DIR


def read_client_manifest():
    modules = []
    legacy = []
    links = []

    manifest_file = STORAGE_DIR / "static/assets/manifest.json"

    if IS_DEBUG:
        manifest_file = BASE_DIR / "client/frontend/assets/manifest.json"

    if not manifest_file.is_file():
        return {"links": links, "legacy": legacy, "modules": modules}

    manifest = json.loads(manifest_file.read_text())

    for m in manifest.values():
        if 'app.css' in m.get('file'):
            links.append({"html": f'<link rel="stylesheet" href="/static/{m.get("file")}">'})
            
        if not m.get("isEntry", False):
            continue

        islegacy = "-legacy" in m["file"]
       

        if islegacy:
            html = f'<script nomodule src="/static/{m["file"]}"></script>'

            if "polyfills" in m["file"]:
                legacy.insert(0, {"html": html})
            else:
                legacy.append({"html": html})

        else:
            modules.append(
                {"html": f'<script type="module" src="/static/{m["file"]}"></script>'}
            )

    return {"links": links, "legacy": legacy, "modules": modules}


def handler(request: HttpRequest):
    env = get_config()
    project_env = env["project"]

    host_url = get_host(request).rstrip("/")
    media_url = project_env.get("MEDIA_URL", "/media/")
    static_url = project_env.get("STATIC_URL", "/static/")

    now = timezone.now()

    context = {
        "lang_code": "ka",
        "static_url": static_url,
        "media_url": media_url,
        "host_url": host_url,
        "debug": settings.DEBUG,
        "now": now.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "now_stamp": int(now.timestamp() * 1000),
        "video_manager_site": project_env.get("VIDEO_MANAGER_SITE"),
        "video_manager_url": project_env.get("VIDEO_MANAGER_URL"),
        "video_manager_key": project_env.get("VIDEO_MANAGER_KEY"),
    }

    try:
        context["manifest"] = read_client_manifest()
    except Exception as e:
        print("Exception:", e)
        context["manifest"] = {"links": [], "modules": [], "legacy": []}

    return context
