import uuid
import time
import hmac
import hashlib
import logging
from decimal import Decimal

import httpx
from ninja import Router
from ninja.errors import HttpError
from ninja.security import HttpBearer
from django.db import transaction
from django.views.decorators.csrf import csrf_exempt
from asgiref.sync import sync_to_async
from main import settings

from apps.user.utils import decode_jwt_token
from apps.user.models import Parent
from apps.core.models import Subject
from .models import Order, Subscription
from .schema import CreateOrderRequest, BOGCallbackPayload
from .bog_client import BOGClient

router = Router()
logger = logging.getLogger(__name__)

USE_BOG_MOCK = getattr(settings, "USE_BOG_MOCK", True)
CALLBACK_SECRET = getattr(settings, "BOG_CALLBACK_SECRET", None)


class AuthBearer(HttpBearer):
    async def authenticate(self, request, token):
        account, ok = await sync_to_async(decode_jwt_token)(token)
        return account if ok else None

@router.post("/create-order/", auth=AuthBearer())
async def create_order(request, payload: CreateOrderRequest):
    parent = request.auth
    subject = await sync_to_async(Subject.objects.get)(id=payload.subject_id)

    # Use BOG mock
    if USE_BOG_MOCK:
        bog_id = f"TEST_ORDER_{subject.id}_{int(time.time())}"
        redirect_url = "https://bog.ge/test_redirect"
        await sync_to_async(Order.objects.create)(
            user=parent,
            external_id=payload.external_order_id,
            bog_id=bog_id,
            total_amount=float(subject.price),
            status="PENDING",
            redirect_url=redirect_url,
            subject=subject
        )
    else:
        bog = BOGClient()
        token = await bog.get_access_token()

        body = {
            "callback_url": payload.callback_url,
            "external_order_id": payload.external_order_id,
            "ttl": payload.ttl,
            "application_type": payload.application_type,
            "payment_method": [payload.payment_method],  
            "purchase_units": {
                "currency": "GEL",
                "total_amount": float(subject.price),
                "basket": [
                    {
                        "product_id": str(subject.id),
                        "quantity": 1,
                        "unit_price": float(subject.price)
                    }
                ]
            },
            "redirect_urls": {
                "success": settings.SITE_URL + "/success",
                "fail": settings.SITE_URL + "/fail"
            }
        }

        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Idempotency-Key": str(uuid.uuid4())
        }

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{settings.BOG_API_BASE}/ecommerce/orders",
                json=body,
                headers=headers
            )
            if resp.status_code >= 400:
                logger.error("BOG create_order error %s: %s", resp.status_code, resp.text)
            resp.raise_for_status()

        data = resp.json()
        bog_id = data["id"]
        redirect_url = data["_links"]["redirect"]["href"]

        await sync_to_async(Order.objects.create)(
            user=parent,
            external_id=payload.external_order_id,
            bog_id=bog_id,
            total_amount=float(subject.price),
            status="PENDING",
            redirect_url=redirect_url,
            subject=subject
        )

    return {
        "order_id": bog_id,
        "redirect_url": redirect_url,
        "status": "PENDING"
    }
    
    
@router.post("/callback/")
@csrf_exempt
def bog_callback(request, payload: BOGCallbackPayload):
    try:
        order_id = payload.body.order_id
        status_key = payload.body.order_status.key

        with transaction.atomic():
            order = Order.objects.select_for_update().get(bog_id=order_id)

            if status_key.upper() in ("COMPLETED", "REFUNDED", "REFUNDED_PARTIALLY"):
                order.status = "SUCCESS"
            elif status_key.upper() in ("REJECTED", "ERROR"):
                order.status = "FAILED"
            else:
                order.status = status_key.upper()

            order.save(update_fields=["status"])

            if order.status == "SUCCESS":
                Subscription.objects.get_or_create(
                    user=order.user,
                    subject=order.subject,
                    order=order
                )

    except Order.DoesNotExist:
        logger.warning("Callback for unknown order_id: %s", payload.body.order_id)
    return {"received": True}

