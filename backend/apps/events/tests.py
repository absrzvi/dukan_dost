"""
Events app tests.
Verifies append-only enforcement and model instantiation.
"""

import uuid
from datetime import datetime, timezone

import pytest


@pytest.mark.django_db
def test_event_can_be_instantiated() -> None:
    """Event model can be instantiated with required fields."""
    from apps.events.models import Event

    event_id = uuid.uuid4()
    event = Event(
        id=event_id,
        event_type="CREDIT",
        party_type="CUSTOMER",
        party_id=uuid.uuid4(),
        amount_paisa=50000,
        device_id="device-abc",
        device_timestamp=datetime(2026, 4, 5, 10, 0, 0, tzinfo=timezone.utc),
    )
    assert event.id == event_id
    assert event.event_type == "CREDIT"
    assert event.amount_paisa == 50000


@pytest.mark.django_db
def test_event_delete_raises() -> None:
    """Event.delete() raises ValueError unconditionally."""
    from apps.shops.models import Shop
    from apps.events.models import Event

    shop = Shop.objects.create(phone="+923001234567", name="Test Shop")
    event = Event.objects.create(
        id=uuid.uuid4(),
        shop=shop,
        event_type="CREDIT",
        party_type="CUSTOMER",
        party_id=uuid.uuid4(),
        amount_paisa=10000,
        device_id="device-test",
        device_timestamp=datetime(2026, 4, 5, 10, 0, 0, tzinfo=timezone.utc),
    )
    with pytest.raises(ValueError, match="append-only"):
        event.delete()


@pytest.mark.django_db
def test_event_save_existing_raises() -> None:
    """Event.save() raises ValueError when attempting to update an existing event."""
    from apps.shops.models import Shop
    from apps.events.models import Event

    shop = Shop.objects.create(phone="+923009999999", name="Test Shop 2")
    event_id = uuid.uuid4()
    Event.objects.create(
        id=event_id,
        shop=shop,
        event_type="CREDIT",
        party_type="CUSTOMER",
        party_id=uuid.uuid4(),
        amount_paisa=20000,
        device_id="device-test",
        device_timestamp=datetime(2026, 4, 5, 11, 0, 0, tzinfo=timezone.utc),
    )
    # Attempting to save the same event again should raise
    duplicate = Event(
        id=event_id,
        shop=shop,
        event_type="CREDIT",
        party_type="CUSTOMER",
        party_id=uuid.uuid4(),
        amount_paisa=20000,
        device_id="device-test",
        device_timestamp=datetime(2026, 4, 5, 11, 0, 0, tzinfo=timezone.utc),
    )
    with pytest.raises(ValueError, match="append-only"):
        duplicate.save()
