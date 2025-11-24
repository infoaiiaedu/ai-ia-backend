from datetime import datetime

from django.conf import settings
from django.http import JsonResponse, StreamingHttpResponse
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from .base import MediaManager

MEDIA_DIR = settings.MEDIA_ROOT


mm = MediaManager(str(MEDIA_DIR), 30)


@require_http_methods(["GET"])
def home_page_view(request):
    context = {
        "media_url": "/media/",
        "thumb_url": "/media/_thumb/",
        "hash": datetime.now().timestamp(),
    }

    return render(request, "mmanager/index.html", context)


@require_http_methods(["GET"])
def location_view(request):
    location = request.GET.get("path", "/")
    skip = request.GET.get("skip", "0")

    data = mm.get_location_data(location, skip)

    return JsonResponse(data)


@require_http_methods(["GET"])
def search_view(request):
    location = request.GET.get("path", "/")

    q = request.GET.get("q", "")

    if len(q) == 0:
        return {"error": '"q" is empty'}, 422

    walking = mm.get_search_data(location, q)

    return StreamingHttpResponse(walking(), content_type="application/json")


@require_http_methods(["POST"])
@csrf_exempt
def create_dir_view(request):
    location = request.POST.get("location")
    name = request.POST.get("name")

    data = mm.create_directory(location, name)

    return JsonResponse(data)


@require_http_methods(["POST"])
@csrf_exempt
def file_upload_view(request):
    location = request.POST.get("location")
    files = request.FILES.getlist("upload_files")
    upload_in_current_dir = request.POST.get("upload_in_current_dir") == "on"

    if location is None:
        return JsonResponse({"error": "არასწორი პარამატრებია"}, status=422)

    if len(files) == 0:
        return JsonResponse({"error": "არ არის ასატვირთი ფაილები"}, status=422)

    data = mm.upload_files(location, files, upload_in_current_dir)

    return JsonResponse(data)


@require_http_methods(["PUT"])
def file_action_view(request):
    return {}
