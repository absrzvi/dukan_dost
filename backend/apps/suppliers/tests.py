"""
Suppliers app tests.
Basic model instantiation tests — verifies models are valid Python.
"""

import uuid

import pytest


@pytest.mark.django_db
def test_supplier_can_be_instantiated() -> None:
    """Supplier model can be instantiated with required fields."""
    from apps.suppliers.models import Supplier

    supplier = Supplier(
        id=uuid.uuid4(),
        name="Tapal Tea Distributor",
        phone="+923005551234",
        invoice_amount_paisa=250000,
    )
    assert supplier.name == "Tapal Tea Distributor"
    # MONETARY AMOUNT: stored as BigIntegerField (paisa), never float
    assert supplier.invoice_amount_paisa == 250000
    assert supplier.is_paid is False
    assert supplier.is_deleted is False
