"""
Customers URL patterns.
Mounted at /api/customers/ in config/urls.py.
"""

from django.urls import path

from .views import CustomerDetailView, CustomerEventListView, CustomerListView

urlpatterns = [
    path("", CustomerListView.as_view(), name="customer-list"),
    path("<str:pk>", CustomerDetailView.as_view(), name="customer-detail"),
    path("<str:pk>/events", CustomerEventListView.as_view(), name="customer-events"),
]
