from django.contrib import admin
from django.urls import path, include, re_path
from django.views.generic import TemplateView, RedirectView
from api import api
from django.conf import settings
from apps.core.views import tinymce_upload_image

admin.site.site_header = settings.SITE_NAME


urlpatterns = [
    path("", TemplateView.as_view(template_name="index.html"), name="home"),
    path("admin/mmanager/", include("pymediamanager.urls")),
    path("admin/tinymce-upload/", tinymce_upload_image, name="tinymce_upload"),
    path("admin/", admin.site.urls),
    path("api/", api.urls),
    # Redirect /api/docs to /api/docs/ (with trailing slash)
    re_path(r"^api/docs$", RedirectView.as_view(url="/api/docs/", permanent=True)),
]
