"""
Events serializers.

Validates inbound event data for POST /api/sync/events.
Iron Rules:
  - event_type must be one of CREDIT, PAYMENT, REVERSAL, REMINDER_SENT.
  - party_type must be one of CUSTOMER, SUPPLIER.
  - amount_paisa >= 0, integer only (no floats).
  - shop and server_timestamp are read-only (set by the server, never from request body).

Serializer split:
  - EventWriteSerializer: used for POST deserialization (no server_timestamp).
  - EventReadSerializer:  used for GET serialization (adds server_timestamp as ISO 8601).
"""

from rest_framework import serializers

from .models import Event

VALID_EVENT_TYPES = {c[0] for c in Event.EVENT_TYPE_CHOICES}
VALID_PARTY_TYPES = {c[0] for c in Event.PARTY_TYPE_CHOICES}


class EventWriteSerializer(serializers.ModelSerializer):
    """
    Serializer for deserializing a single Event from the device (POST body).

    Input fields (from device):
        id, event_type, party_type, party_id, amount_paisa,
        note, device_id, actor_label, device_timestamp

    Server-controlled (excluded from input):
        shop, server_timestamp
    """

    # id is a UUIDField with editable=False on the model, so we must declare
    # it explicitly here to make it writable (the client owns the UUID).
    id = serializers.UUIDField()

    class Meta:
        model = Event
        fields = [
            "id",
            "event_type",
            "party_type",
            "party_id",
            "amount_paisa",
            "note",
            "device_id",
            "actor_label",
            "device_timestamp",
        ]

    def validate_event_type(self, value: str) -> str:
        if value not in VALID_EVENT_TYPES:
            raise serializers.ValidationError(
                f"event_type must be one of {sorted(VALID_EVENT_TYPES)}. Got: '{value}'."
            )
        return value

    def validate_party_type(self, value: str) -> str:
        if value not in VALID_PARTY_TYPES:
            raise serializers.ValidationError(
                f"party_type must be one of {sorted(VALID_PARTY_TYPES)}. Got: '{value}'."
            )
        return value

    def validate_amount_paisa(self, value: int) -> int:
        # Reject floats / non-integers submitted via JSON number with decimal part.
        if not isinstance(value, int) or isinstance(value, bool):
            raise serializers.ValidationError(
                "amount_paisa must be an integer (no floats)."
            )
        if value < 0:
            raise serializers.ValidationError(
                "amount_paisa must be >= 0."
            )
        return value


class EventReadSerializer(EventWriteSerializer):
    """
    Serializer for serializing Events returned to the device (GET response).

    Extends EventWriteSerializer with server_timestamp as a read-only ISO 8601 field.
    The Flutter client converts this to epoch millis via _isoToEpochMillis().
    """

    server_timestamp = serializers.DateTimeField(
        format='%Y-%m-%dT%H:%M:%S.%fZ',
        read_only=True,
    )

    class Meta(EventWriteSerializer.Meta):
        fields = EventWriteSerializer.Meta.fields + ["server_timestamp"]
        read_only_fields = ["server_timestamp"]


class SyncBatchResponseSerializer(serializers.Serializer):  # type: ignore[type-arg]
    """Response shape for POST /api/sync/events."""

    accepted = serializers.IntegerField()
    duplicates = serializers.IntegerField()
    server_timestamp = serializers.DateTimeField(format='%Y-%m-%dT%H:%M:%S.%fZ')
    errors = serializers.ListField(child=serializers.DictField(), required=False)
