from ninja import NinjaAPI
# from apps.core.api import router as content_router
from apps.user.api import router as user_router

api = NinjaAPI(docs_url="docs/", csrf=False)


# api.add_router("/", content_router)
api.add_router("/", user_router)
