"""
Customers app models.

MONETARY AMOUNTS: Always use BigIntegerField for PKR paisa. Never FloatField or DecimalField.
Balances are computed by replaying the event log — never stored as a mutable field (CLAUDE.md #3).
"""

import uuid

from django.db import models


class Customer(models.Model):
    """
    A customer of a kiryana store. Tracks credit (udhaar) relationships.
    balance_paisa is a computed property — it is never stored as a DB field.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey(
        "shops.Shop",
        on_delete=models.CASCADE,
        related_name="customers",
    )
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20, blank=True, null=True)
    is_flagged = models.BooleanField(default=False)
    last_reminder_at = models.DateTimeField(blank=True, null=True)
    is_deleted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "customers"
        indexes = [
            models.Index(fields=["shop"], name="idx_customer_shop"),
        ]

    @property
    def balance_paisa(self) -> int:
        """
        Computed balance by replaying the event log for this customer.
        CREDIT and REMINDER_SENT events add to balance (positive direction).
        PAYMENT and REVERSAL events reduce balance (negative direction).

        This is never stored as a DB field — always recomputed from events.
        See CLAUDE.md Iron Rule #3.
        """
        from apps.events.models import Event

        events = Event.objects.filter(
            party_type="CUSTOMER",
            party_id=self.id,
        )
        total: int = 0
        for event in events:
            if event.event_type in ("CREDIT",):
                total += event.amount_paisa
            elif event.event_type in ("PAYMENT", "REVERSAL"):
                total -= event.amount_paisa
            # REMINDER_SENT events do not affect the monetary balance
        return total

    def __str__(self) -> str:
        return f"{self.name} ({self.shop})"
