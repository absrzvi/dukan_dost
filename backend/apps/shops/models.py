"""
Shops app models.

Shop: The kiryana store owner entity. One shop per phone number.
Device: Tracks registered devices for a shop. Supports multi-device audit trail.

MONETARY AMOUNTS: Always use BigIntegerField for PKR paisa. Never FloatField or DecimalField.
"""

import uuid
from django.db import models


class Shop(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=20, unique=True)  # E.164 format
    name = models.CharField(max_length=255, blank=True, default='')
    locality = models.CharField(max_length=255, blank=True, null=True, default=None)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "shops"

    def __str__(self) -> str:
        return f"{self.name} ({self.phone})"


class Device(models.Model):
    PLATFORM_CHOICES = [('android', 'Android'), ('ios', 'iOS')]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='devices')
    device_id = models.CharField(max_length=100)
    actor_label = models.CharField(max_length=100, blank=True, default='')
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES, default='android')
    fcm_token = models.TextField(blank=True, default='')  # Firebase Cloud Messaging token
    last_seen_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "devices"
        unique_together = [('shop', 'device_id')]

    def __str__(self) -> str:
        return f"{self.shop.phone} — {self.device_id} ({self.actor_label or 'unlabelled'})"
