"""
Shops serializers — stub placeholders.
"""

from rest_framework import serializers

from .models import Device, Shop


class ShopSerializer(serializers.ModelSerializer):
    """Stub serializer for Shop model."""

    class Meta:
        model = Shop
        fields = ["id", "phone", "name", "locality", "is_active", "created_at", "updated_at"]
        read_only_fields = ["id", "phone", "created_at", "updated_at"]


class DeviceSerializer(serializers.ModelSerializer):
    """Stub serializer for Device model."""

    class Meta:
        model = Device
        fields = ["id", "shop", "device_id", "actor_label", "platform", "registered_at"]
        read_only_fields = ["id", "registered_at"]
