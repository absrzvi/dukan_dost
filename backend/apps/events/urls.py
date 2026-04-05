"""
Events URL patterns.
Mounted at /api/sync/ in config/urls.py.
"""

from django.urls import path

from .views import EventSyncView

urlpatterns = [
    path("events", EventSyncView.as_view(), name="event-sync"),
]
