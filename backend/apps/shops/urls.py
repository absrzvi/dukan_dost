"""
Shops URL patterns.
Mounted at /api/shop/ in config/urls.py.
Device FCM registration is mounted at /api/devices/ in config/urls.py.
"""

from django.urls import path

from .views import RegisterFCMTokenView, ShopProfileView

urlpatterns = [
    path("profile", ShopProfileView.as_view(), name="shop-profile"),
    path("devices/register-fcm/", RegisterFCMTokenView.as_view(), name="register-fcm-token"),
]
