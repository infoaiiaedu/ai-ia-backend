import uuid
import logging
from datetime import timedelta
from ninja import Router
from ninja.security import HttpBearer
from django.db import transaction
from django.views.decorators.csrf import csrf_exempt
from asgiref.sync import sync_to_async
from django.utils import timezone
import httpx
from main import settings
from apps.user.utils import decode_jwt_token
from apps.user.models import Parent
from apps.core.models import Subject
from .models import Order, Subscription
from .schema import CreateOrderRequest, BOGCallbackPayload
from .bog_client import BOGClient

router = Router()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

USE_BOG_MOCK = getattr(settings, "USE_BOG_MOCK", True)
SITE_URL = settings.SITE_URL


class AuthBearer(HttpBearer):
    async def authenticate(self, request, token):
        logger.info("Authenticating request with token: %s", token)
        try:
            account, ok = await sync_to_async(decode_jwt_token)(token)
            if ok:
                logger.info("Authentication successful for account_id: %s", getattr(account, "id", None))
                return account
            else:
                logger.warning("Authentication failed For token: %s", token)
                return None
        except Exception as e:
            logger.error("Authentication error: %s", str(e), exc_info=True)
            return None


@router.post("/create-order/", auth=AuthBearer())
async def create_order(request, payload: CreateOrderRequest):
    parent = request.auth
    logger.info("Creating order for user_id: %s, subject_id: %s", parent.id, payload.subject_id)

    try:
        subject = await sync_to_async(Subject.objects.get)(id=payload.subject_id)
        price = float(subject.price)
        if price <= 0:
            logger.error("Invalid subject price: %s for subject_id: %s", price, subject.id)
            raise ValueError("Subject price must be > 0")
        logger.info("Subject price: %s", price)
    except Subject.DoesNotExist:
        logger.error("Subject not found with id: %s", payload.subject_id)
        raise

    try:
        if USE_BOG_MOCK:
            bog_id = f"TEST_ORDER_{subject.id}_{uuid.uuid4().hex}"
            redirect_url = f"{SITE_URL}/success"
            await sync_to_async(Order.objects.create)(
                user=parent,
                external_id=payload.external_order_id,
                bog_id=bog_id,
                parent_order_id=bog_id,
                total_amount=price,
                status="PENDING",
                redirect_url=redirect_url,
                subject=subject
            )
            logger.info("Created mock order with bog_id: %s", bog_id)
        else:
            bog = BOGClient()
            token = await bog.get_access_token()
            logger.info("Obtained BOG access token")

            external_order_id = f"{payload.external_order_id}_{uuid.uuid4().hex}"
            ttl_minutes = payload.ttl if payload.ttl and payload.ttl >= 2 else 15

            body = {
                "callback_url": f"{SITE_URL}/api/payments/callback/",
                "external_order_id": external_order_id,
                "ttl": ttl_minutes,
                "application_type": payload.application_type.lower(),
                "payment_method": [payload.payment_method.lower()],
                "save_card": "recurrent",
                "purchase_units": {
                    "currency": "GEL",
                    "total_amount": price,
                    "basket": [
                        {"product_id": str(subject.id), "quantity": 1, "unit_price": price}
                    ]
                },
                "redirect_urls": {
                    "success": f"{SITE_URL}/success",
                    "fail": f"{SITE_URL}/fail"
                }
            }

            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "Idempotency-Key": str(uuid.uuid4())
            }

            logger.info("Sending BOG create_order request: %s", body)

            async with httpx.AsyncClient() as client:
                try:
                    resp = await client.post(f"{settings.BOG_API_BASE}/ecommerce/orders", json=body, headers=headers)
                    resp.raise_for_status()
                    data = resp.json()
                    logger.info("Received BOG response: %s", data)
                except httpx.HTTPError as e:
                    logger.error("BOG API request failed: %s", str(e), exc_info=True)
                    raise

            bog_id = data["id"]
            redirect_url = data["_links"]["redirect"]["href"]

            await sync_to_async(Order.objects.create)(
                user=parent,
                external_id=external_order_id,
                bog_id=bog_id,
                parent_order_id=bog_id,
                total_amount=price,
                status="PENDING",
                redirect_url=redirect_url,
                subject=subject
            )
            logger.info("Order created with bog_id: %s", bog_id)

        return {"order_id": bog_id, "redirect_url": redirect_url, "status": "PENDING"}

    except Exception as e:
        logger.error("Error creating order: %s", str(e), exc_info=True)
        raise


@router.post("/callback/")
@csrf_exempt
def bog_callback(request, payload: BOGCallbackPayload):
    logger.info("Received BOG callback payload: %s", payload.dict())

    try:
        order_id = payload.body.order_id
        status_key = payload.body.order_status.key.upper()
        logger.info("Processing callback for order_id: %s with status: %s", order_id, status_key)

        with transaction.atomic():
            order = Order.objects.select_for_update().get(bog_id=order_id)
            logger.info("Locked order for update: %s", order.bog_id)

            if status_key in ("COMPLETED", "REFUNDED", "REFUNDED_PARTIALLY"):
                order.status = "SUCCESS"
            elif status_key in ("REJECTED", "ERROR"):
                order.status = "FAILED"
            else:
                order.status = status_key

            order.save(update_fields=["status"])
            logger.info("Order status updated to: %s", order.status)

            if order.status == "SUCCESS":
                sub, created = Subscription.objects.get_or_create(
                    user=order.user,
                    subject=order.subject,
                    order=order,
                    defaults={"end_date": timezone.now() + timedelta(days=30)}
                )
                if created:
                    logger.info("Created new subscription for user_id: %s, subject_id: %s", order.user.id, order.subject.id)
                else:
                    sub.end_date += timedelta(days=30)
                    sub.save()
                    logger.info("Extended existing subscription for user_id: %s, new end_date: %s", order.user.id, sub.end_date)

    except Order.DoesNotExist:
        logger.warning("Callback received for unknown order_id: %s", payload.body.order_id)
    except Exception as e:
        logger.error("Error processing callback: %s", str(e), exc_info=True)

    return {"received": True}
