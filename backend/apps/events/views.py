"""
Events views — stub placeholders.
Actual sync POST/GET implemented in STORY-005 (sync engine).
"""

from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView


class EventSyncView(APIView):
    """
    POST /api/sync/events — batch upload events from device to server
    GET  /api/sync/events — pull events since a given server timestamp
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
