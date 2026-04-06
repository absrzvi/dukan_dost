"""
Events views.

POST /api/sync/events — batch upload events from device to server (idempotent).
GET  /api/sync/events — pull events for this shop since a given server timestamp.

Auth: OTP session token required for both endpoints.
"""

from datetime import datetime, timezone

from django.utils.dateparse import parse_datetime
from rest_framework import status
from rest_framework.permissions import BasePermission
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.authentication.authentication import ShopTokenAuthentication

from .models import Event
from .serializers import EventReadSerializer, EventWriteSerializer


class IsAuthenticatedShop(BasePermission):
    """
    Permission class for Shop-based authentication.

    DRF's built-in IsAuthenticated expects request.user.is_authenticated, which is
    a Django AbstractUser attribute. Shop is a plain Model so we check for the
    presence of a non-None user set by ShopTokenAuthentication instead.
    """

    def has_permission(self, request: Request, view: object) -> bool:  # type: ignore[override]
        return request.user is not None and request.auth is not None


class EventSyncView(APIView):
    """
    POST /api/sync/events — batch upload events from device to server.
    GET  /api/sync/events — pull events since a given server timestamp.
    """

    authentication_classes = [ShopTokenAuthentication]
    permission_classes = [IsAuthenticatedShop]

    # -------------------------------------------------------------------------
    # POST /api/sync/events
    # -------------------------------------------------------------------------

    def post(self, request: Request) -> Response:
        """
        Accept a batch of events from the device.

        Request body:
            { "events": [ {...}, ... ] }   — max 500 items

        Response:
            { "accepted": N, "duplicates": M, "server_timestamp": "..." }
        """
        events_data = request.data.get("events")
        if not isinstance(events_data, list):
            return Response(
                {"detail": "'events' must be a list."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(events_data) > 500:
            return Response(
                {"detail": "Batch exceeds 500 events."},
                status=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            )

        shop = request.user  # ShopTokenAuthentication returns the Shop instance.

        accepted = 0
        duplicates = 0
        errors = []

        for idx, event_data in enumerate(events_data):
            event_id = event_data.get("id")

            # Duplicate check — idempotent by UUID.
            if event_id and Event.objects.filter(pk=event_id).exists():
                duplicates += 1
                continue

            serializer = EventWriteSerializer(data=event_data)
            if not serializer.is_valid():
                # Skip invalid events — add to errors list and continue batch.
                errors.append({"index": idx, "errors": serializer.errors})
                continue

            # Inject server-controlled fields.
            serializer.save(shop=shop)
            accepted += 1

        server_timestamp = datetime.now(tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f') + 'Z'

        return Response(
            {
                "accepted": accepted,
                "duplicates": duplicates,
                "server_timestamp": server_timestamp,
                "errors": errors,
            },
            status=status.HTTP_200_OK,
        )

    # -------------------------------------------------------------------------
    # GET /api/sync/events
    # -------------------------------------------------------------------------

    def get(self, request: Request) -> Response:
        """
        Pull events for this shop created after a given server timestamp.

        Query params:
            since  — ISO 8601 datetime (required)
            limit  — int, default 500
        """
        since_param = request.query_params.get("since")

        # Treat missing or "0" as epoch zero — returns full event history for the shop.
        if not since_param or since_param == "0":
            since_dt = datetime(1970, 1, 1, tzinfo=timezone.utc)
        else:
            since_dt = parse_datetime(since_param)
            if since_dt is None:
                return Response(
                    {"detail": f"Invalid 'since' format: '{since_param}'. Use ISO 8601."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # Make timezone-aware if naive.
        if since_dt.tzinfo is None:
            since_dt = since_dt.replace(tzinfo=timezone.utc)

        try:
            limit = int(request.query_params.get("limit", 500))
        except (TypeError, ValueError):
            limit = 500

        shop = request.user

        qs = (
            Event.objects.filter(shop=shop, server_timestamp__gt=since_dt)
            .order_by("server_timestamp")[: limit + 1]
        )

        rows = list(qs)
        has_more = len(rows) > limit
        rows = rows[:limit]

        serializer = EventReadSerializer(rows, many=True)

        latest_ts = (
            rows[-1].server_timestamp.isoformat().replace("+00:00", "Z")
            if rows
            else since_param
        )

        return Response(
            {
                "events": serializer.data,
                "has_more": has_more,
                "latest_server_timestamp": latest_ts,
            },
            status=status.HTTP_200_OK,
        )
