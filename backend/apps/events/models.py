"""
Events app models.

# APPEND-ONLY: Never update or delete Event records. This is enforced at the model layer.

The Event table is the single source of truth for all balances.
Balances are computed by replaying this log — never stored as mutable fields.
See CLAUDE.md Iron Rule #2 and #3.

MONETARY AMOUNTS: Always use BigIntegerField for PKR paisa. Never FloatField or DecimalField.
"""

import uuid

from django.db import IntegrityError, models


class Event(models.Model):
    """
    Append-only transaction event log.

    # APPEND-ONLY: Never update or delete Event records. This is enforced at the model layer.

    Each event represents a single ledger action (credit, payment, reversal, or reminder).
    The id is client-generated (same UUID as the Drift local event). Server never generates event IDs.
    Editing a transaction means creating a REVERSAL event — never modifying existing records.
    """

    EVENT_TYPE_CHOICES = [
        ("CREDIT", "Credit"),
        ("PAYMENT", "Payment"),
        ("REVERSAL", "Reversal"),
        ("REMINDER_SENT", "Reminder Sent"),
    ]

    PARTY_TYPE_CHOICES = [
        ("CUSTOMER", "Customer"),
        ("SUPPLIER", "Supplier"),
    ]

    # Client-supplied UUID — NOT default=uuid4. The client owns the ID.
    id = models.UUIDField(primary_key=True, editable=False)
    shop = models.ForeignKey(
        "shops.Shop",
        on_delete=models.PROTECT,
        related_name="events",
    )
    event_type = models.CharField(max_length=20, choices=EVENT_TYPE_CHOICES)
    party_type = models.CharField(max_length=20, choices=PARTY_TYPE_CHOICES)
    # Not a DB-level FK due to polymorphism (points to Customer or Supplier)
    party_id = models.UUIDField()
    # MONETARY AMOUNT: BigIntegerField for PKR paisa. Always positive; direction implied by event_type.
    amount_paisa = models.BigIntegerField()
    note = models.TextField(blank=True, default="")
    device_id = models.CharField(max_length=255)
    actor_label = models.CharField(max_length=255, blank=True, null=True)
    device_timestamp = models.DateTimeField()
    server_timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "events"
        ordering = ["device_timestamp"]
        indexes = [
            models.Index(fields=["shop", "device_timestamp"], name="idx_event_device_ts"),
            models.Index(fields=["party_type", "party_id"], name="idx_event_party"),
            models.Index(fields=["shop", "server_timestamp"], name="idx_event_shop_server_ts"),
        ]

    def save(self, *args, **kwargs) -> None:  # type: ignore[override]
        """
        APPEND-ONLY enforcement at the model layer.
        Every save is forced to be an INSERT. Duplicate UUIDs are caught by the
        database UNIQUE constraint (IntegrityError), not by a pre-check SELECT.
        """
        # Detect update attempt: only raise if the record is already persisted.
        # We use force_insert semantics — if kwargs indicate an update, block it.
        # Block explicit update attempts unconditionally.
        if kwargs.get("force_update"):
            raise ValueError("Event records are immutable. Use a REVERSAL event to correct mistakes.")
        # Force every save to be an INSERT, never an UPDATE, even when a PK is
        # present (client-supplied UUID). This eliminates the TOCTOU SELECT+INSERT
        # race — the database's UNIQUE constraint on pk catches duplicates atomically.
        kwargs["force_insert"] = True
        try:
            super().save(*args, **kwargs)
        except IntegrityError:
            raise ValueError("Event with this UUID already exists.")

    def delete(self, *args, **kwargs) -> tuple:  # type: ignore[override]
        """
        APPEND-ONLY enforcement at the model layer.
        Raises an exception unconditionally — Event records are never deleted.
        """
        raise ValueError("Event records cannot be deleted. The event log is append-only.")

    def __str__(self) -> str:
        return f"{self.event_type} {self.amount_paisa} paisa @ {self.device_timestamp}"
