import secrets
import logging
from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
from .models import OTPRequest, ShopToken
from .serializers import OTPRequestSerializer, OTPVerifySerializer
from apps.shops.models import Shop

logger = logging.getLogger(__name__)


def generate_otp() -> str:
    """Generate a cryptographically secure 6-digit OTP."""
    return str(secrets.randbelow(900000) + 100000)


def send_sms(phone: str, otp_code: str) -> bool:
    """
    Send OTP via SMS gateway.
    In DEBUG mode only, logs OTP to console for development.
    In production, must be wired to real SMS gateway (Infobip/Avanza/TeleCom).
    """
    if settings.DEBUG:
        logger.info(f"[DEV ONLY] OTP for {phone}: {otp_code}")
    # TODO: Wire real SMS gateway here before production deployment
    # from .sms_gateway import send_via_infobip
    # return send_via_infobip(phone, otp_code)
    return True


def check_rate_limit(phone: str) -> bool:
    """Max 5 OTP requests per phone per hour."""
    one_hour_ago = timezone.now() - timezone.timedelta(hours=1)
    recent_count = OTPRequest.objects.filter(
        phone=phone,
        created_at__gte=one_hour_ago,
    ).count()
    return recent_count < 5


class OTPRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request: Request) -> Response:
        serializer = OTPRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = serializer.validated_data['phone']

        with transaction.atomic():
            if not check_rate_limit(phone):
                return Response(
                    {'error': 'Too many OTP requests. Please wait before trying again.'},
                    status=status.HTTP_429_TOO_MANY_REQUESTS,
                )

            otp_code = generate_otp()
            OTPRequest.create_for_phone(phone=phone, otp_code=otp_code)

        send_sms(phone=phone, otp_code=otp_code)

        return Response({
            'message': 'OTP sent',
            'expires_in_seconds': 300,
        }, status=status.HTTP_200_OK)


class OTPVerifyView(APIView):
    permission_classes = [AllowAny]

    def post(self, request: Request) -> Response:
        serializer = OTPVerifySerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        phone = serializer.validated_data['phone']
        otp_code = serializer.validated_data['otp']

        # Find the most recent unused, unexpired OTP for this phone
        otp_request = OTPRequest.objects.filter(
            phone=phone,
            is_used=False,
            expires_at__gte=timezone.now(),
        ).order_by('-created_at').first()

        if not otp_request or not otp_request.verify(otp_code):
            return Response(
                {'error': 'Invalid or expired OTP'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # Get or create shop
        shop, is_new = Shop.objects.get_or_create(phone=phone)

        # Generate a persistent session token
        token = ShopToken.create_for_shop(shop)

        return Response({
            'token': token.key,
            'shop_id': str(shop.id),
            'is_new_shop': is_new,
            'shop': None if is_new else {
                'name': shop.name,
                'locality': shop.locality,
                'phone': shop.phone,
            },
        }, status=status.HTTP_200_OK)
