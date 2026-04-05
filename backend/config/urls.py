"""
URL configuration for Dukaan Dost Django backend.

All endpoints are prefixed with /api/.
Auth endpoints do not require a session token.
All other endpoints require Authorization: Token {session_token}.
"""

from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/auth/", include("apps.authentication.urls")),
    path("api/shop/", include("apps.shops.urls")),
    path("api/sync/", include("apps.events.urls")),
    path("api/customers/", include("apps.customers.urls")),
    path("api/suppliers/", include("apps.suppliers.urls")),
]
