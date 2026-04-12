import os
import uuid

from django.conf import settings
from django.contrib.admin.views.decorators import staff_member_required
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods


@staff_member_required
@require_http_methods(["POST"])
def tinymce_upload_image(request):
    """Handle image uploads from TinyMCE editor."""
    file = request.FILES.get("file")
    if not file:
        return JsonResponse({"error": "No file uploaded"}, status=400)

    ext = os.path.splitext(file.name)[1].lower()
    allowed = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg"}
    if ext not in allowed:
        return JsonResponse({"error": "File type not allowed"}, status=400)

    filename = f"{uuid.uuid4().hex}{ext}"
    upload_dir = os.path.join(settings.MEDIA_ROOT, "uploads", "tinymce")
    os.makedirs(upload_dir, exist_ok=True)

    filepath = os.path.join(upload_dir, filename)
    with open(filepath, "wb+") as dest:
        for chunk in file.chunks():
            dest.write(chunk)

    url = f"{settings.MEDIA_URL}uploads/tinymce/{filename}"
    return JsonResponse({"location": url})
