"""Routes publiques des zones (T020). Le composant « proches de moi » viendra avec sa tâche."""
from django.urls import path

from .views.map import MapAreaBusinessesView, MapAreasView, MapCitiesView
from .views.zone import ZoneDetailView, ZoneListView

app_name = "geo"

urlpatterns = [
    path("zones/", ZoneListView.as_view(), name="zone-list"),
    path("zones/<int:pk>/", ZoneDetailView.as_view(), name="zone-detail"),
    path("map/cities/", MapCitiesView.as_view(), name="map-cities"),
    path("map/cities/<int:pk>/areas/", MapAreasView.as_view(), name="map-city-areas"),
    path("map/areas/<int:pk>/businesses/", MapAreaBusinessesView.as_view(),
         name="map-area-businesses"),
]
