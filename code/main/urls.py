from django.contrib import admin
from django.urls import path, include
from django.views.generic import TemplateView
from api import api

urlpatterns = [
    path("", TemplateView.as_view(template_name="index.html"), name="home"),
    path("admin/mmanager/", include("pymediamanager.urls")),
    path("admin/", admin.site.urls),
    path("api/", api.urls),
]
