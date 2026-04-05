"""
Suppliers URL patterns.
Mounted at /api/suppliers/ in config/urls.py.
"""

from django.urls import path

from .views import SupplierDetailView, SupplierListView

urlpatterns = [
    path("", SupplierListView.as_view(), name="supplier-list"),
    path("<str:pk>", SupplierDetailView.as_view(), name="supplier-detail"),
]
