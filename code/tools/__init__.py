import io
import re
import urllib.parse
from collections import namedtuple
from os.path import basename, join, splitext

import httpx
from bs4 import BeautifulSoup
from django.conf import settings
from django.http import HttpRequest
from django.shortcuts import reverse
from PIL import Image
from unidecode import unidecode

from pyconf import get_project_config

from .ismobile import isMobileBrowser
from .useragent import get_client_ip, userAgent

__all__ = [
    "userAgent",
    "isMobileBrowser",
    "get_host",
    "get_alias",
    "reverse",
    "url_beautify",
    "striptags",
    "clean_html",
    "sanitize_html",
    "get_client_ip",
    "in_range",
]

HTTP_HOST = namedtuple("HTTP_HOST", ["protocol", "host"])

GEO = "აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰ".upper()


def build_url(protocol, host, path="/", query="", fragment=""):
    return urllib.parse.urlunparse((protocol, host, path, None, query, fragment))


def get_http_host(request: HttpRequest) -> HTTP_HOST:
    host = request.META.get("HTTP_HOST")
    protocol = "https" if request.is_secure() else "http"

    return HTTP_HOST(protocol=protocol, host=host)


def get_host(request: HttpRequest) -> str:
    obj = get_http_host(request)
    return build_url(obj.protocol, obj.host)


def reverse_url(request: HttpRequest, viewname: str, **kwargs) -> str:
    url = reverse(viewname, kwargs=kwargs)[1:]

    if request is None:
        return url

    return join(get_host(request), url)


def url_beautify(url: str) -> str:
    if "%" in url:
        return urllib.parse.unquote(url)
    return url


def striptags(text: str) -> str:
    try:
        regex = r"(<([^>]+)>)"
        return re.sub(regex, "", text).strip()
    except Exception:
        return text


def get_alias(text: str):
    value = re.sub(r"[^\w\s-]", "", unidecode(text).lower()).strip()
    return re.sub(r"[-\s]+", "-", value)


def clean_html(html):
    config = get_project_config()
    media_url = config.get("MEDIA_URL", settings.MEDIA_URL)

    html = re.sub(r"\r\n", " ", html)
    html = re.sub(r"\n", " ", html)
    html = re.sub(r"\s{2, }", " ", html)
    html = html.replace("/media/", media_url).replace("&nbsp;", "")

    return html


def sanitize_html(value):
    if not isinstance(value, str):
        return ""

    REMOVE_TAGS = ["script", "code", "pre", "template"]
    VALID_TAGS = ["strong", "em", "b", "p", "span", "a"]

    soup = BeautifulSoup(value, "html.parser")

    for tag in soup.findAll(True):
        if tag.name in REMOVE_TAGS:
            tag.extract()
        elif tag.name not in VALID_TAGS:
            tag.hidden = True
        elif tag.name == "a":
            tag["target"] = "_blank"

    return clean_html(soup.renderContents().decode())


def img_download(url, dest, timeout=5, webp=True, thumb=None, enc=None):
    bname = basename(url)
    name, ext = splitext(bname)

    if enc is not None:
        name, ext = enc(url)

    if url.startswith("//"):
        url = "https:" + url

    try:
        r = httpx.get(url, timeout=timeout, verify=False)
    except Exception:
        r = httpx.get(url.replace("https://", "http://"), timeout=timeout, verify=False)

    chunks = r.content
    ext = ext.lower()

    with Image.open(io.BytesIO(chunks)) as img:
        if thumb is not None:
            img.thumbnail(thumb)
        if webp:
            img.save(join(dest, name + ".webp"))
        img.save(join(dest, name + ext))

    return join(dest, name + ext)


def in_range(x, a, b):
    return a <= x and x < b


def clean_text_emoji(text):
    if text is None:
        return None

    def clean(t):
        if t in GEO:
            return t.lower()

        if ord(t) == 0:
            return ""

        if ord(t) < 0xFFFF:
            return t
        return f"&#{ord(t)};"

    return "".join([clean(t) for t in text])


def split(list_a, chunk_size):
    for i in range(0, len(list_a), chunk_size):
        yield list_a[i : i + chunk_size]
