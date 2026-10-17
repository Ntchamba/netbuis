"""Routes publiques des zones (T020). Le composant « proches de moi » viendra avec sa tâche."""
from django.urls import path

from .views.zone import ZoneDetailView, ZoneListView

app_name = "geo"

urlpatterns = [
    path("zones/", ZoneListView.as_view(), name="zone-list"),
    path("zones/<int:pk>/", ZoneDetailView.as_view(), name="zone-detail"),
]
