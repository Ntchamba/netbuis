"""Routes de l'app admin_panel, montées sous /api/admin/."""
from django.urls import path

from .views.admins import AdminDetailView, AdminListCreateView
from .views.businesses import ApproveView, BusinessRequestListView, PrivateFileView, RejectView
from .views.export import AccountsCsvView
from .views.me import AdminMeView
from .views.settings import SettingDetailView, SettingListView
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
    path("settings/", SettingListView.as_view(), name="settings"),
    path("settings/<str:key>/", SettingDetailView.as_view(), name="setting-detail"),
    path("admins/", AdminListCreateView.as_view(), name="admins"),
    path("admins/<int:pk>/", AdminDetailView.as_view(), name="admin-detail"),
    path("export/accounts.csv", AccountsCsvView.as_view(), name="export-accounts"),
    path("private-files/<str:token>/", PrivateFileView.as_view(), name="private-file"),
]
