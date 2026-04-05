"""
Shops app tests.
Basic model instantiation tests — verifies models are valid Python.
"""

import uuid

import pytest


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
