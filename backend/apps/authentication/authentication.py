from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.request import Request
from typing import Optional, Tuple
from .models import ShopToken
from apps.shops.models import Shop


class ShopTokenAuthentication(BaseAuthentication):
    """
    Custom token authentication for Dukaan Dost shops.
    Header format: Authorization: Token <key>
    """

    def authenticate(self, request: Request) -> Optional[Tuple[Shop, ShopToken]]:
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Token '):
            return None

        key = auth_header.split(' ', 1)[1].strip()
        if not key:
            return None

        try:
            token = ShopToken.objects.select_related('shop').get(key=key)
        except ShopToken.DoesNotExist:
            raise AuthenticationFailed('Invalid or expired token.')

        if not token.shop.is_active:
            raise AuthenticationFailed('Shop account is inactive.')

        return (token.shop, token)

    def authenticate_header(self, request: Request) -> str:
        return 'Token'
