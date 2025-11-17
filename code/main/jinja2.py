from os.path import join
from django.conf import settings
from django.templatetags.static import static
from django.urls import reverse
from django.utils import translation
from django.utils.module_loading import import_string
from jinja2 import Environment


def reverse_url(name, **kwargs):
    try:
        return reverse(name, kwargs=kwargs)
    except Exception:
        return "#"


def norm_img_url(url):
    if url is None:
        return ""

    media_url = settings.MEDIA_URL

    if url.startswith("http"):
        return url
    if url.startswith("/media/"):
        return url.replace("/media", media_url, 1)
    return join(media_url, url.lstrip("/"))


def iso_time_fmt(val, date=False, time=False):
    try:
        if date:
            return val.strftime("%Y-%m-%d")
        if time:
            return val.strftime("%H:%M:%S")
        return val.strftime("%Y-%m-%dT%H:%M:%S%z")
    except Exception:
        return ""


def environment(**options):
    env = Environment(**options)
    env.install_gettext_translations(translation)

    # Global template variables
    env.globals.update(
        {
            "static": static,
            "url": reverse,
        }
    )

    # Custom filters
    env.filters["norm_img_url"] = norm_img_url
    env.filters["iso_time_fmt"] = iso_time_fmt

    # Get context from processors (custom + Django)
    def get_request_context(request):
        context = {}
        for path in settings.TEMPLATES[1]["OPTIONS"].get("context_processors", []):
            try:
                processor = import_string(path)
                context.update(processor(request))
            except Exception as e:
                print(f"[context processor error] {path} -> {e}")
        return context

    # Patch template class to inject request & context processors
    original_template_class = env.template_class

    class RequestAwareTemplate(original_template_class):
        def render(self, context=None, *args, **kwargs):
            request = kwargs.get("request") or (context and context.get("request"))
            if request and "request" not in context:
                context.update({"request": request})
                context.update(get_request_context(request))
            return super().render(context, *args, **kwargs)

    env.template_class = RequestAwareTemplate

    return env
