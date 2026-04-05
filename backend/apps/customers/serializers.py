"""
Customers serializers — stub placeholders.
"""

from rest_framework import serializers

from .models import Customer


class CustomerSerializer(serializers.ModelSerializer):
    """Stub serializer for Customer model."""

    class Meta:
        model = Customer
        fields = [
            "id",
            "shop",
            "name",
            "phone",
            "is_flagged",
            "last_reminder_at",
            "is_deleted",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "shop", "created_at", "updated_at"]
