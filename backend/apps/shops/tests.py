"""
Shops app tests.
Basic model instantiation tests — verifies models are valid Python.
FCM token registration endpoint tests (STORY-016).
"""

import uuid

import pytest
from django.urls import reverse
from rest_framework.test import APIClient


@pytest.mark.django_db
def test_shop_can_be_instantiated() -> None:
    """Shop model can be instantiated with required fields."""
    from apps.shops.models import Shop

    shop = Shop(
        id=uuid.uuid4(),
        phone="+923001234567",
        name="Kareem General Store",
        locality="Orangi Town",
    )
    assert shop.phone == "+923001234567"
    assert shop.name == "Kareem General Store"
    assert shop.is_active is True


@pytest.mark.django_db
def test_device_can_be_instantiated() -> None:
    """Device model can be instantiated with required fields."""
    from apps.shops.models import Device, Shop

    shop = Shop.objects.create(
        phone="+923001234567",
        name="Test Shop",
    )
    device = Device(
        shop=shop,
        device_id="device-abc-123",
        actor_label="Main phone",
    )
    assert device.device_id == "device-abc-123"
    assert device.actor_label == "Main phone"
    assert device.is_active is True


# ---------------------------------------------------------------------------
# STORY-016: FCM token registration endpoint tests
# ---------------------------------------------------------------------------

FCM_URL = "/api/shop/devices/register-fcm/"


def _make_shop_with_token():
    """Helper: create a Shop + ShopToken, return (shop, token_key)."""
    from apps.authentication.models import ShopToken
    from apps.shops.models import Shop

    shop = Shop.objects.create(phone="+923009876543", name="FCM Test Shop")
    token = ShopToken.create_for_shop(shop)
    return shop, token.key


@pytest.mark.django_db
def test_register_fcm_token_returns_200_with_valid_data() -> None:
    """POST /api/shop/devices/register-fcm/ with valid data returns 200 and registered=True."""
    _, token_key = _make_shop_with_token()

    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Token {token_key}")

    response = client.post(
        FCM_URL,
        data={
            "fcm_token": "fake-fcm-token-abc123",
            "device_id": "device-xyz-001",
            "platform": "android",
        },
        format="json",
    )

    assert response.status_code == 200
    assert response.data["registered"] is True


@pytest.mark.django_db
def test_register_fcm_token_returns_400_without_token() -> None:
    """POST /api/shop/devices/register-fcm/ without fcm_token returns 400."""
    _, token_key = _make_shop_with_token()

    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Token {token_key}")

    response = client.post(
        FCM_URL,
        data={"device_id": "device-xyz-001"},
        format="json",
    )

    assert response.status_code == 400
    assert "fcm_token" in response.data.get("error", "")


@pytest.mark.django_db
def test_register_fcm_token_returns_401_unauthenticated() -> None:
    """POST /api/shop/devices/register-fcm/ without auth returns 401."""
    client = APIClient()
    # No credentials set.

    response = client.post(
        FCM_URL,
        data={
            "fcm_token": "fake-fcm-token-abc123",
            "device_id": "device-xyz-001",
        },
        format="json",
    )

    assert response.status_code == 401
