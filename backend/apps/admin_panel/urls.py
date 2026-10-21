"""Routes de l'app admin_panel, montées sous /api/admin/."""
from django.urls import path

from .views.businesses import ApproveView, BusinessRequestListView, PrivateFileView, RejectView
from .views.me import AdminMeView
from .views.stats import AdminStatsView
from .views.users import (
    AccountDetailView,
    AccountListView,
    BlockView,
    RestoreView,
    UnblockView,
)

app_name = "admin_panel"

urlpatterns = [
    path("me/", AdminMeView.as_view(), name="me"),
    path("stats/", AdminStatsView.as_view(), name="stats"),
    path("requests/", BusinessRequestListView.as_view(), name="requests"),
    path("requests/<int:pk>/approve/", ApproveView.as_view(), name="request-approve"),
    path("requests/<int:pk>/reject/", RejectView.as_view(), name="request-reject"),
    path("accounts/", AccountListView.as_view(), name="accounts"),
    path("accounts/<int:pk>/", AccountDetailView.as_view(), name="account-detail"),
    path("accounts/<int:pk>/block/", BlockView.as_view(), name="account-block"),
    path("accounts/<int:pk>/unblock/", UnblockView.as_view(), name="account-unblock"),
    path("accounts/<int:pk>/restore/", RestoreView.as_view(), name="account-restore"),
    path("private-files/<str:token>/", PrivateFileView.as_view(), name="private-file"),
]
