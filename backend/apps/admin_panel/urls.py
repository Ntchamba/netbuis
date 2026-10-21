"""Routes de l'app admin_panel, montées sous /api/admin/."""
from django.urls import path

from .views.me import AdminMeView

app_name = "admin_panel"

urlpatterns = [
    path("me/", AdminMeView.as_view(), name="me"),
]
