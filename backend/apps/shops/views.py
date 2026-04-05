"""
Shops views — stub placeholders.
Actual shop profile GET/PUT implemented in a later story.
"""

from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


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
