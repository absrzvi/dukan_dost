"""
Events serializers — stub placeholders.
"""

from rest_framework import serializers

from .models import Event


class EventSerializer(serializers.ModelSerializer):
    """Stub serializer for Event model."""

    class Meta:
        model = Event
        fields = [
            "id",
            "shop",
            "event_type",
            "party_type",
            "party_id",
            "amount_paisa",
            "note",
            "device_id",
            "actor_label",
            "device_timestamp",
            "server_timestamp",
        ]
        read_only_fields = ["server_timestamp"]
