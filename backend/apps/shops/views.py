"""
Shops views.
"""

from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import BasePermission
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.authentication.authentication import ShopTokenAuthentication

from .models import Device


class IsAuthenticatedShop(BasePermission):
    """
    Permission that works with Shop-based authentication (not Django AbstractUser).
    Checks that ShopTokenAuthentication has populated request.user and request.auth.
    """

    def has_permission(self, request: Request, view: object) -> bool:  # type: ignore[override]
        from apps.shops.models import Shop  # noqa: PLC0415
        return bool(request.auth) and isinstance(request.user, Shop)


class ShopProfileView(APIView):
    """
    GET  /api/shop/profile — retrieve shop profile
    PUT  /api/shop/profile — update shop profile
    Auth: OTP session token required.
    """

    def get(self, request: Request) -> Response:
        return Response(
            {"detail": "Not implemented yet."},
            status=status.HTTP_501_NOT_IMPLEMENTED,
        )

    def put(self, request: Request) -> Response:
        return Response(
            {"detail": "Not implemented yet."},
            status=status.HTTP_501_NOT_IMPLEMENTED,
        )


class RegisterFCMTokenView(APIView):
    """
    POST /api/devices/register-fcm/
    Registers or refreshes a device FCM token for the authenticated shop.
    Auth: ShopToken required.
    """

    authentication_classes = [ShopTokenAuthentication]
    permission_classes = [IsAuthenticatedShop]

    def post(self, request: Request) -> Response:
        fcm_token = request.data.get("fcm_token")
        device_id = request.data.get("device_id")
        platform = request.data.get("platform", "android")

        if not fcm_token or not device_id:
            return Response(
                {"error": "fcm_token and device_id required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # request.auth is the ShopToken; request.user is the Shop.
        shop = request.user
        Device.objects.update_or_create(
            shop=shop,
            device_id=device_id,
            defaults={
                "fcm_token": fcm_token,
                "platform": platform,
                "is_active": True,
                "last_seen_at": timezone.now(),
            },
        )
        return Response({"registered": True}, status=status.HTTP_200_OK)
