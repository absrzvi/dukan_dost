"""
Management command: send_supplier_reminders

Finds all unpaid supplier invoices due within 2 days and sends FCM push
notifications to the shop's active devices.

Usage:
    python manage.py send_supplier_reminders

Schedule: Run daily at 09:00 PKT via cron or django-celery-beat.

TODO: Integrate real FCM via firebase-admin SDK.
"""

import logging
from datetime import date, timedelta

from django.core.management.base import BaseCommand

from apps.shops.models import Device
from apps.suppliers.models import Supplier

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Send FCM push notifications for supplier invoices due in 2 days."

    def handle(self, *args, **options) -> None:
        target_date = date.today() + timedelta(days=2)
        self.stdout.write(f"[send_supplier_reminders] Checking due date: {target_date}")

        due_suppliers = Supplier.objects.filter(
            due_date=target_date,
            is_paid=False,
            is_deleted=False,
        ).select_related("shop")

        self.stdout.write(f"Found {due_suppliers.count()} supplier(s) due on {target_date}.")

        for supplier in due_suppliers:
            active_devices = Device.objects.filter(
                shop=supplier.shop,
                is_active=True,
            ).exclude(fcm_token="")

            if not active_devices.exists():
                logger.info(
                    "No active devices for shop %s — skipping supplier %s.",
                    supplier.shop_id,
                    supplier.id,
                )
                continue

            amount_pkr = supplier.invoice_amount_paisa // 100
            notification_payload = {
                "title": "Supplier payment jald aane wali hai",
                "body": (
                    f"{supplier.name} ko PKR {amount_pkr:,} ki payment "
                    f"{supplier.due_date} tak karni hai."
                ),
                "data": {
                    "supplier_id": str(supplier.id),
                    "shop_id": str(supplier.shop_id),
                },
            }

            for device in active_devices:
                # TODO: Integrate real FCM via firebase-admin SDK.
                # Example (once firebase-admin is installed):
                #   from firebase_admin import messaging
                #   message = messaging.Message(
                #       notification=messaging.Notification(
                #           title=notification_payload["title"],
                #           body=notification_payload["body"],
                #       ),
                #       data=notification_payload["data"],
                #       token=device.fcm_token,
                #   )
                #   messaging.send(message)
                logger.info(
                    "[FCM STUB] Would send to device %s: %s",
                    device.device_id,
                    notification_payload,
                )
                self.stdout.write(
                    f"  [FCM STUB] Supplier={supplier.name}, "
                    f"Device={device.device_id}"
                )

        self.stdout.write("[send_supplier_reminders] Done.")
