"""
Customers views — stub placeholders.
Actual list/create/update implemented in a later story.
"""

from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.authentication.authentication import ShopTokenAuthentication
from apps.events.views import IsAuthenticatedShop


class CustomerListView(APIView):
    """
    GET  /api/customers    — list customers with computed balances
    POST /api/customers    — create a new customer
    Auth: OTP session token required.
    """

    authentication_classes = [ShopTokenAuthentication]
    permission_classes = [IsAuthenticatedShop]

    def get(self, request: Request) -> Response:
        return Response(
            {"detail": "Not implemented yet."},
            status=status.HTTP_501_NOT_IMPLEMENTED,
        )

    def post(self, request: Request) -> Response:
        return Response(
            {"detail": "Not implemented yet."},
            status=status.HTTP_501_NOT_IMPLEMENTED,
        )


class CustomerDetailView(APIView):
    """
    PUT /api/customers/{id}         — update customer
    Auth: OTP session token required.
    """

    authentication_classes = [ShopTokenAuthentication]
    permission_classes = [IsAuthenticatedShop]

    def put(self, request: Request, pk: str) -> Response:
        return Response(
            {"detail": "Not implemented yet."},
            status=status.HTTP_501_NOT_IMPLEMENTED,
        )


class CustomerEventListView(APIView):
    """
    GET /api/customers/{id}/events — full event history for one customer
    Auth: OTP session token required.
    """

    authentication_classes = [ShopTokenAuthentication]
    permission_classes = [IsAuthenticatedShop]

    def get(self, request: Request, pk: str) -> Response:
        return Response(
            {"detail": "Not implemented yet."},
            status=status.HTTP_501_NOT_IMPLEMENTED,
        )
