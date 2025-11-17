from django.conf import settings
from django.http import Http404, HttpRequest, HttpResponse
from django.shortcuts import redirect, render, reverse
from django.views.generic import View
from PIL import Image
from django.template.response import TemplateResponse
from django.utils.module_loading import import_string
from main.jinja2 import environment
from tools import HTTP_HOST, build_url, get_http_host, striptags


class RedirectCanonical(Exception):
    def __init__(self, message):
        self.message = message
        super().__init__(message)


class PageBaseView(View):
    template_name = "pages/index.html"

    lang_code = "ka"
    locale_lang = "ka_GE"

    site_name = settings.SITE_NAME
    site_logo_url = settings.SITE_LOGO_URL

    http_host: HTTP_HOST

    url_pattern: str
    url_pattern_regex: bool = False

    def get(self, request: HttpRequest, **kwargs) -> HttpResponse:
        ID: str = kwargs.get("id", "")

        if str(ID).isdigit() and int(ID).bit_length() > 63:
            raise Http404
        
        self.http_host = get_http_host(request)
        self.request = request

        try:
            context = self.get_context_data(**kwargs)
        except RedirectCanonical as e:
            return redirect(e.message)
        return render(request, self.template_name, context)

    def norm_url(self, url: str = "/", query: str = "", fragment: str = ""):
        if url.startswith("http"):
            return url

        if not url.startswith("/"):
            url = settings.MEDIA_URL + url

        return build_url(
            "https", self.http_host.host, url, query, fragment
        )

    def get_context_data(self, *args, **kwargs):
        context = {}

        env = environment()
        request = getattr(self, "request", None)
        if request:
            for path in settings.TEMPLATES[1]["OPTIONS"]["context_processors"]:
                try:
                    processor = import_string(path)
                    context.update(processor(request))
                except Exception as e:
                    print(f"[context processor error] {path} -> {e}")

        return context

    def get_pagetitle(self, title):
        title_suffix = "" if not self.site_name else " - " + self.site_name

        return title + title_suffix

    def generate_metainfo(
        self,
        title: str,
        description: str,
        url,
        keywords: str = "",
        image=None,
        image_point=(50, 50),
        custom_img=None,
        page_type="website",
    ):
        image = self.norm_url(image or self.site_logo_url)

        metatags = []

        url = self.norm_url(url)

        og_url = url

        if custom_img is not None:
            og_url += f"?img={custom_img}"

        description = striptags(description)

        # html5 tags
        metatags.extend(
            [
                {"tag": "meta", "name": "title", "content": title},
                {"tag": "meta", "name": "image", "content": image},
                {"tag": "meta", "name": "description", "content": description},
                {"tag": "meta", "name": "keywords", "content": keywords},
                {"tag": "link", "rel": "canonical", "href": url},
            ]
        )

        # open graph meta tags
        metatags.extend(
            [
                {"tag": "meta", "property": "og:title", "content": title},
                {"tag": "meta", "property": "og:image", "content": image},
                {"tag": "meta", "property": "og:description", "content": description},
                {"tag": "meta", "property": "og:url", "content": og_url},
                {"tag": "meta", "property": "og:type", "content": page_type},
                {"tag": "meta", "property": "og:site_name", "content": self.site_name},
                {"tag": "meta", "property": "og:locale", "content": self.locale_lang},
            ]
        )

        # twitter meta tags
        metatags.extend(
            [
                    {"tag": "meta", "name": "twitter:title", "content": title},
                {"tag": "meta", "name": "twitter:image", "content": image},
                {"tag": "meta", "name": "twitter:description", "content": description},
                {
                    "tag": "meta",
                    "name": "twitter:domain",
                    "content": self.http_host.host,
                },
            ]
        )

        pagetitle = self.get_pagetitle(title)

        return (pagetitle, metatags)
