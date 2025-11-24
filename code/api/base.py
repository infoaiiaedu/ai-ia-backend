from ninja import NinjaAPI
from apps.core.api import router as content_router
from apps.user.api import router as user_router
from apps.payments.api import router as payments_router

api = NinjaAPI(docs_url="docs/", csrf=False)

api.add_router("/payments/", payments_router)
api.add_router("/content/", content_router)
api.add_router("/user", user_router)
