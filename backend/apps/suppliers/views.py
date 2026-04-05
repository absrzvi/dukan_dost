"""
Suppliers views — stub placeholders.
Actual list/create/update/delete implemented in a later story.
"""

from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


class SupplierListView(APIView):
    """
    GET  /api/suppliers — list suppliers with balances and due dates
    POST /api/suppliers — create a new supplier
    Auth: OTP session token required.
    """

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


class SupplierDetailView(APIView):
    """
    PUT    /api/suppliers/{id} — update supplier details or mark paid
    DELETE /api/suppliers/{id} — soft-delete supplier
    Auth: OTP session token required.
    """

    def put(self, request: Request, pk: str) -> Response:
        return Response(
            {"detail": "Not implemented yet."},
            status=status.HTTP_501_NOT_IMPLEMENTED,
        )

    def delete(self, request: Request, pk: str) -> Response:
        return Response(
            {"detail": "Not implemented yet."},
            status=status.HTTP_501_NOT_IMPLEMENTED,
        )
