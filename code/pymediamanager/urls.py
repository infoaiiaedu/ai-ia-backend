from django.urls import path
from django.contrib.admin.views.decorators import staff_member_required

from . import views

app_name = "pymediamanager"


urlpatterns = [
    path("", staff_member_required(views.home_page_view)),
    path("location", staff_member_required(views.location_view)),
    path("search", staff_member_required(views.search_view)),
    path("create-directory/", staff_member_required(views.create_dir_view)),
    path("upload-file/", staff_member_required(views.file_upload_view)),
    # path("/file-action/", views.file_action_view),
]
