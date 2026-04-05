"""
Suppliers app models.

MONETARY AMOUNTS: Always use BigIntegerField for PKR paisa. Never FloatField or DecimalField.
"""

import uuid

from django.db import models


class Supplier(models.Model):
    """
    A supplier (distributor) that the kiryana store owes money to.
    Tracks invoice amounts and due dates.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey(
        "shops.Shop",
        on_delete=models.CASCADE,
        related_name="suppliers",
    )
    name = models.CharField(max_length=255)
    phone = models.CharField(max_length=20, blank=True, null=True)
    # MONETARY AMOUNT: BigIntegerField for PKR paisa. Never FloatField or DecimalField.
    invoice_amount_paisa = models.BigIntegerField()
    due_date = models.DateField(blank=True, null=True)
    is_paid = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "suppliers"
        indexes = [
            models.Index(fields=["shop"], name="idx_supplier_shop"),
            models.Index(fields=["shop", "due_date"], name="idx_supplier_due"),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.shop})"
