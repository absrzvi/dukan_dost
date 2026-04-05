"""
Suppliers serializers — stub placeholders.
"""

from rest_framework import serializers

from .models import Supplier


class SupplierSerializer(serializers.ModelSerializer):
    """Stub serializer for Supplier model."""

    class Meta:
        model = Supplier
        fields = [
            "id",
            "shop",
            "name",
            "phone",
            "invoice_amount_paisa",
            "due_date",
            "is_paid",
            "is_deleted",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "shop", "created_at", "updated_at"]
