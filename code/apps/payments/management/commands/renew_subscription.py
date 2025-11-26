# management/commands/renew_subscriptions.py
from django.core.management.base import BaseCommand
from django.utils import timezone
from apps.payments.models import Subscription
from apps.payments.bog_client import BOGClient
import asyncio
import logging
from main import settings

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = "Renew subscriptions using BOG recurrent payments"

    def handle(self, *args, **kwargs):
        subs = Subscription.objects.filter(end_date__lte=timezone.now(), active=True)
        bog = BOGClient()
        results = []

        for sub in subs:
            try:
                asyncio.run(
                    bog.recurrent_charge(
                        parent_order_id=sub.order.parent_order_id,
                        amount=sub.order.total_amount,
                        callback_url=f"{settings.SITE_URL}/api/payments/callback/"
                    )
                )
                results.append({"subscription_id": sub.id, "status": "CHARGED"})
                logger.info(f"Subscription {sub.id} recurrent charge triggered.")
            except Exception as e:
                results.append({"subscription_id": sub.id, "status": "FAILED", "error": str(e)})
                logger.error(f"Subscription {sub.id} recurrent charge failed: {str(e)}")
        
        self.stdout.write(self.style.SUCCESS(f"Processed {len(results)} subscriptions"))
