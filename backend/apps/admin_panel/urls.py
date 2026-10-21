"""Routes de l'app admin_panel, montées sous /api/admin/."""
from django.urls import path

from .views.businesses import ApproveView, BusinessRequestListView, PrivateFileView, RejectView
from .views.me import AdminMeView

app_name = "admin_panel"

urlpatterns = [
    path("me/", AdminMeView.as_view(), name="me"),
    path("requests/", BusinessRequestListView.as_view(), name="requests"),
    path("requests/<int:pk>/approve/", ApproveView.as_view(), name="request-approve"),
    path("requests/<int:pk>/reject/", RejectView.as_view(), name="request-reject"),
    path("private-files/<str:token>/", PrivateFileView.as_view(), name="private-file"),
]
