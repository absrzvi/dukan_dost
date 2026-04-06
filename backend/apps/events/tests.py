"""
Events app tests.

Covers:
  - Existing model-layer tests (append-only enforcement).
  - POST /api/sync/events — batch upload (valid, duplicate, invalid event_type, negative amount).
  - GET  /api/sync/events — pull since timestamp, auth required.
"""

import uuid
from datetime import datetime, timezone

import pytest
from django.urls import reverse


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_shop(phone: str = "+923001234567", name: str = "Test Shop"):
    from apps.shops.models import Shop
    return Shop.objects.create(phone=phone, name=name)


def _make_token(shop):
    from apps.authentication.models import ShopToken
    return ShopToken.create_for_shop(shop)


def _auth_client(client, token):
    client.defaults["HTTP_AUTHORIZATION"] = f"Token {token.key}"
    return client


def _event_payload(
    *,
    event_id=None,
    event_type="CREDIT",
    party_type="CUSTOMER",
    party_id=None,
    amount_paisa=50000,
    device_id="device-test",
    device_timestamp="2026-04-05T09:30:00Z",
):
    return {
        "id": str(event_id or uuid.uuid4()),
        "event_type": event_type,
        "party_type": party_type,
        "party_id": str(party_id or uuid.uuid4()),
        "amount_paisa": amount_paisa,
        "device_id": device_id,
        "device_timestamp": device_timestamp,
    }


# ---------------------------------------------------------------------------
# Model-layer tests (preserved from original)
# ---------------------------------------------------------------------------


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
    with pytest.raises(ValueError, match="already exists"):
        duplicate.save()


# ---------------------------------------------------------------------------
# API tests — POST /api/sync/events
# ---------------------------------------------------------------------------


@pytest.mark.django_db
def test_post_sync_events_valid_batch(client) -> None:
    """POST /api/sync/events with a valid batch returns accepted count."""
    shop = _make_shop("+923010000001")
    token = _make_token(shop)
    _auth_client(client, token)

    payload = {
        "events": [
            _event_payload(amount_paisa=10000),
            _event_payload(amount_paisa=20000),
            _event_payload(event_type="PAYMENT", amount_paisa=5000),
        ]
    }
    response = client.post(
        "/api/sync/events",
        data=payload,
        content_type="application/json",
    )
    assert response.status_code == 200, response.data
    assert response.data["accepted"] == 3
    assert response.data["duplicates"] == 0
    assert "server_timestamp" in response.data


@pytest.mark.django_db
def test_post_sync_events_duplicate_uuid(client) -> None:
    """POST /api/sync/events with a duplicate UUID — duplicates count is correct."""
    shop = _make_shop("+923010000002")
    token = _make_token(shop)
    _auth_client(client, token)

    existing_id = uuid.uuid4()
    first_payload = {"events": [_event_payload(event_id=existing_id)]}

    # First upload — should be accepted.
    r1 = client.post(
        "/api/sync/events",
        data=first_payload,
        content_type="application/json",
    )
    assert r1.status_code == 200
    assert r1.data["accepted"] == 1

    # Second upload with the same UUID — should be a duplicate.
    r2 = client.post(
        "/api/sync/events",
        data=first_payload,
        content_type="application/json",
    )
    assert r2.status_code == 200
    assert r2.data["accepted"] == 0
    assert r2.data["duplicates"] == 1


@pytest.mark.django_db
def test_post_sync_events_invalid_event_type(client) -> None:
    """POST /api/sync/events with invalid event_type — skip-invalid: returns 200 with errors."""
    shop = _make_shop("+923010000003")
    token = _make_token(shop)
    _auth_client(client, token)

    payload = {"events": [_event_payload(event_type="BOGUS")]}
    response = client.post(
        "/api/sync/events",
        data=payload,
        content_type="application/json",
    )
    assert response.status_code == 200
    assert response.data["accepted"] == 0
    assert len(response.data["errors"]) == 1


@pytest.mark.django_db
def test_post_sync_events_negative_amount(client) -> None:
    """POST /api/sync/events with amount_paisa < 0 — skip-invalid: returns 200 with errors."""
    shop = _make_shop("+923010000004")
    token = _make_token(shop)
    _auth_client(client, token)

    payload = {"events": [_event_payload(amount_paisa=-100)]}
    response = client.post(
        "/api/sync/events",
        data=payload,
        content_type="application/json",
    )
    assert response.status_code == 200
    assert response.data["accepted"] == 0
    assert len(response.data["errors"]) == 1


# ---------------------------------------------------------------------------
# API tests — GET /api/sync/events
# ---------------------------------------------------------------------------


@pytest.mark.django_db
def test_get_sync_events_since_timestamp(client) -> None:
    """GET /api/sync/events?since= returns only events after the given timestamp."""
    from apps.events.models import Event

    shop = _make_shop("+923010000005")
    token = _make_token(shop)
    _auth_client(client, token)

    # Create one event directly (server_timestamp is auto_now_add).
    Event.objects.create(
        id=uuid.uuid4(),
        shop=shop,
        event_type="CREDIT",
        party_type="CUSTOMER",
        party_id=uuid.uuid4(),
        amount_paisa=25000,
        device_id="device-test",
        device_timestamp=datetime(2026, 4, 5, 10, 0, 0, tzinfo=timezone.utc),
    )

    # Pull since a timestamp in the past — should return the event.
    response = client.get(
        "/api/sync/events?since=2020-01-01T00:00:00Z",
    )
    assert response.status_code == 200, response.data
    assert len(response.data["events"]) == 1
    assert "has_more" in response.data
    assert "latest_server_timestamp" in response.data


@pytest.mark.django_db
def test_get_sync_events_requires_auth(client) -> None:
    """GET /api/sync/events returns 401 without a valid token."""
    response = client.get("/api/sync/events?since=2020-01-01T00:00:00Z")
    assert response.status_code == 401


@pytest.mark.django_db
def test_post_sync_events_requires_auth(client) -> None:
    """POST /api/sync/events returns 401 without a valid token."""
    payload = {"events": [_event_payload()]}
    response = client.post(
        "/api/sync/events",
        data=payload,
        content_type="application/json",
    )
    assert response.status_code == 401


@pytest.mark.django_db
def test_post_sync_events_partial_invalid_batch(client) -> None:
    """POST /api/sync/events with mixed valid/invalid — 200, accepted=2, errors has 1 entry, DB has 2 rows."""
    from apps.events.models import Event

    shop = _make_shop("+923010000006")
    token = _make_token(shop)
    _auth_client(client, token)

    valid_id_1 = uuid.uuid4()
    valid_id_2 = uuid.uuid4()
    payload = {
        "events": [
            _event_payload(event_id=valid_id_1, amount_paisa=10000),
            _event_payload(event_id=valid_id_2, amount_paisa=20000),
            _event_payload(event_type="INVALID_TYPE", amount_paisa=5000),
        ]
    }
    response = client.post(
        "/api/sync/events",
        data=payload,
        content_type="application/json",
    )
    assert response.status_code == 200, response.data
    assert response.data["accepted"] == 2
    assert len(response.data["errors"]) == 1
    assert Event.objects.filter(id__in=[valid_id_1, valid_id_2]).count() == 2


@pytest.mark.django_db
def test_post_sync_events_persisted_to_db(client) -> None:
    """After valid batch POST, all events are persisted to the DB."""
    from apps.events.models import Event

    shop = _make_shop("+923010000007")
    token = _make_token(shop)
    _auth_client(client, token)

    batch = [
        _event_payload(event_id=uuid.uuid4(), amount_paisa=10000),
        _event_payload(event_id=uuid.uuid4(), amount_paisa=20000),
        _event_payload(event_id=uuid.uuid4(), event_type="PAYMENT", amount_paisa=5000),
    ]
    event_ids = [e["id"] for e in batch]

    response = client.post(
        "/api/sync/events",
        data={"events": batch},
        content_type="application/json",
    )
    assert response.status_code == 200, response.data
    assert response.data["accepted"] == len(batch)
    assert Event.objects.filter(id__in=event_ids).count() == len(batch)
