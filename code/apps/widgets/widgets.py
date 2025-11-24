from django.forms import TextInput


class Widget(TextInput):
    template_name = "dwidgets/widget.html"
    widget_type = ""

    class Media:
        js = (
            "/static/mmanager/mmanager.js",
            "/static/dwidgets/bundle.js",
        )
        css = {"all": ["/static/dwidgets/bundle.css"]}

    def get_context(self, name, value, attrs):
        attrs.update({
            "django_widget": self.widget_type,
            "media_manager_url": "/admin/mmanager/",
        })
        if "data-url_prefix" not in attrs:
            attrs["data-url_prefix"] = "/media/"

        context = super().get_context(name, value, attrs)
        context["value"] = value
        return context

class ImageWidget(Widget):
    widget_type = "image"


class VideoWidget(Widget):
    widget_type = "video"


class AudioWidget(Widget):
    widget_type = "audio"


class GalleryWidget(Widget):
    widget_type = "gallery"
