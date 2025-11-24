from django.contrib import admin
<<<<<<< HEAD
from django.urls import path, include
from api import api

urlpatterns = [
    path("admin/mmanager/", include("pymediamanager.urls")),
    path("admin/", admin.site.urls),
    path("api/", api.urls),
]
 
=======
from django.urls import path
from api import api

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", api.urls),
]
>>>>>>> 582c3dc12a9409382079981e07f3d17f362746f3
