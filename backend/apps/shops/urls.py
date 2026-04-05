"""
Shops URL patterns.
Mounted at /api/shop/ in config/urls.py.
"""

from django.urls import path

from .views import ShopProfileView

urlpatterns = [
    path("profile", ShopProfileView.as_view(), name="shop-profile"),
]
