import uuid
import hmac
import logging
from decimal import Decimal, ROUND_HALF_UP
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

router = Router(tags=["Payments"])
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

USE_BOG_MOCK = getattr(settings, "USE_BOG_MOCK", True)
SITE_URL = settings.SITE_URL
BOG_WEBHOOK_SECRET = getattr(settings, "BOG_WEBHOOK_SECRET", None)
BOG_WEBHOOK_SIGNATURE_HEADER = getattr(settings, "BOG_WEBHOOK_SIGNATURE_HEADER", "X-BOG-SIGNATURE")
BOG_HTTP_TIMEOUT_SECONDS = getattr(settings, "BOG_HTTP_TIMEOUT_SECONDS", 15)


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


def _quantize_amount(amount: Decimal) -> Decimal:
    return amount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _build_idempotency_key(external_order_id: str) -> str:
    return external_order_id


def _verify_bog_signature(request) -> bool:
    if not BOG_WEBHOOK_SECRET:
        logger.warning("BOG webhook secret not configured; skipping signature verification")
        return True

    signature = request.headers.get(BOG_WEBHOOK_SIGNATURE_HEADER)
    if not signature:
        logger.warning("Missing BOG webhook signature header: %s", BOG_WEBHOOK_SIGNATURE_HEADER)
        return False

    expected = hmac.new(
        BOG_WEBHOOK_SECRET.encode("utf-8"),
        request.body,
        "sha256",
    ).hexdigest()
    if not hmac.compare_digest(signature, expected):
        logger.warning("Invalid BOG webhook signature")
        return False
    return True


def _map_order_status(status_key: str) -> str:
    if status_key == "COMPLETED":
        return "SUCCESS"
    if status_key in ("REFUNDED", "REFUNDED_PARTIALLY"):
        return "FAILED"
    if status_key in ("REJECTED", "ERROR"):
        return "FAILED"
    return "PENDING"


@router.post("/create-order/", auth=AuthBearer())
async def create_order(request, payload: CreateOrderRequest):
    parent = request.auth
    logger.info("Creating order for user_id: %s, subject_id: %s", parent.id, payload.subject_id)

    external_order_id = (payload.external_order_id or "").strip()
    if not external_order_id:
        raise ValueError("external_order_id is required")

    existing_order = await sync_to_async(Order.objects.filter(external_id=external_order_id).first)()
    if existing_order:
        logger.info("Reusing existing order external_id=%s", external_order_id)
        return {
            "order_id": existing_order.bog_id,
            "redirect_url": existing_order.redirect_url,
            "status": existing_order.status,
        }

    try:
        subject = await sync_to_async(Subject.objects.get)(id=payload.subject_id)
        price = _quantize_amount(Decimal(str(subject.price)))
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
                total_amount=float(price),
                status="PENDING",
                redirect_url=redirect_url,
                subject=subject
            )
            logger.info("Created mock order with bog_id: %s", bog_id)
        else:
            bog = BOGClient()
            token = await bog.get_access_token()
            logger.info("Obtained BOG access token")

            ttl_minutes = payload.ttl if payload.ttl and payload.ttl >= 2 else 15
            callback_url = payload.callback_url or f"{SITE_URL}/api/payments/callback/"

            body = {
                "callback_url": callback_url,
                "external_order_id": external_order_id,
                "ttl": ttl_minutes,
                "application_type": payload.application_type.lower(),
                "payment_method": [payload.payment_method.lower()],
                "save_card": "recurrent",
                "purchase_units": {
                    "currency": "GEL",
                    "total_amount": float(price),
                    "basket": [
                        {"product_id": str(subject.id), "quantity": 1, "unit_price": float(price)}
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
                "Idempotency-Key": _build_idempotency_key(external_order_id)
            }

            logger.info("Sending BOG create_order request: %s", body)

            timeout = httpx.Timeout(BOG_HTTP_TIMEOUT_SECONDS)
            async with httpx.AsyncClient(timeout=timeout) as client:
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
                total_amount=float(price),
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
    if not _verify_bog_signature(request):
        logger.warning("Rejected BOG callback due to signature verification failure")
        return {"received": False}

    logger.info("Received BOG callback payload: %s", payload.dict())

    try:
        order_id = payload.body.order_id
        status_key = payload.body.order_status.key.upper()
        logger.info("Processing callback for order_id: %s with status: %s", order_id, status_key)

        with transaction.atomic():
            order = Order.objects.select_for_update().get(bog_id=order_id)
            logger.info("Locked order for update: %s", order.bog_id)

            previous_status = order.status
            new_status = _map_order_status(status_key)
            if new_status != order.status:
                order.status = new_status
                order.save(update_fields=["status"])
                logger.info("Order status updated to: %s", order.status)

            if order.status == "SUCCESS" and previous_status != "SUCCESS":
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
