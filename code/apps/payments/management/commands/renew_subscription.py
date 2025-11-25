from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from apps.payments.models import Subscription
from apps.payments.bog_client import BOGClient
import asyncio
from main import settings

SITE_URL = settings.SITE_URL

class Command(BaseCommand):
    help = "Auto-renew expired subscriptions using BOG saved-card"

    def handle(self, *args, **options):
        asyncio.run(self.renew_subscriptions())

    async def renew_subscriptions(self):
        client = BOGClient()
        now = timezone.now()
        subs = Subscription.objects.filter(active=True, end_date__lte=now)
        for sub in subs:
            try:
                await client.recurrent_charge(
                    parent_order_id=sub.order.parent_order_id,
                    amount=sub.order.total_amount,
                    callback_url=f"{SITE_URL}/api/payments/callback/"
                )
                sub.end_date += timedelta(days=30)
                sub.save(update_fields=["end_date"])
            except Exception as e:
                sub.active = False
                sub.save(update_fields=["active"])
