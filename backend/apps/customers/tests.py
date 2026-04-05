"""
Customers app tests.
Basic model instantiation tests — verifies models are valid Python.
"""

import uuid

import pytest


@pytest.mark.django_db
def test_customer_can_be_instantiated() -> None:
    """Customer model can be instantiated with required fields."""
    from apps.customers.models import Customer

    customer = Customer(
        id=uuid.uuid4(),
        name="Ahmed bhai",
        phone="+923009876543",
    )
    assert customer.name == "Ahmed bhai"
    assert customer.is_flagged is False
    assert customer.is_deleted is False


@pytest.mark.django_db
def test_customer_balance_paisa_zero_for_new_customer() -> None:
    """balance_paisa is 0 for a customer with no events."""
    from apps.shops.models import Shop
    from apps.customers.models import Customer

    shop = Shop.objects.create(phone="+923001234567", name="Test Shop")
    customer = Customer.objects.create(
        id=uuid.uuid4(),
        shop=shop,
        name="New Customer",
    )
    assert customer.balance_paisa == 0
