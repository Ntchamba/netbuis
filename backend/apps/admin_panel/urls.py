"""Routes de l'app admin_panel, montées sous /api/admin/."""
from django.urls import path

from .views.admins import AdminDetailView, AdminListCreateView
from .views.analytics import CallAnalyticsView, SearchAnalyticsView
from .views.audit import AuditListView
from .views.businesses import ApproveView, BusinessRequestListView, PrivateFileView, RejectView
from .views.export import AccountsCsvView
from .views.me import AdminMeView
from .views.moderation import (
    DeleteView,
    ForbiddenWordDetailView,
    ForbiddenWordListCreateView,
    HideView,
    ReportListView,
)
from .views.moderation import (
    RestoreView as ReportRestoreView,
)
from .views.referentials import FreeValuesView, build_views
from .views.settings import SettingDetailView, SettingListView
from .views.stats import AdminStatsView
from .views.subscriptions import SubscriptionListView
from .views.users import (
    AccountDetailView,
    AccountListView,
    BlockView,
    RestoreView,
    UnblockView,
)

app_name = "admin_panel"

_REF_PATHS = []
for _slug in ("zones", "sectors", "subcategories", "service-categories", "structure-types",
              "products", "synonyms"):
    _v = build_views(_slug)
    _name = _slug.replace("-", "_")
    _REF_PATHS += [
        path(f"referentials/{_slug}/", _v["list"].as_view(), name=f"ref-{_name}"),
        path(f"referentials/{_slug}/<int:pk>/", _v["detail"].as_view(),
             name=f"ref-{_name}-detail"),
    ]
    if "deactivate" in _v:
        _REF_PATHS += [
            path(f"referentials/{_slug}/<int:pk>/deactivate/", _v["deactivate"].as_view(),
                 name=f"ref-{_name}-deactivate"),
            path(f"referentials/{_slug}/<int:pk>/reactivate/", _v["reactivate"].as_view(),
                 name=f"ref-{_name}-reactivate"),
        ]

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
    path("analytics/searches/", SearchAnalyticsView.as_view(), name="analytics-searches"),
    path("analytics/calls/", CallAnalyticsView.as_view(), name="analytics-calls"),
    path("subscriptions/", SubscriptionListView.as_view(), name="subscriptions"),
    path("audit/", AuditListView.as_view(), name="audit"),
    path("reports/", ReportListView.as_view(), name="reports"),
    path("reports/<str:target_type>/<int:pk>/hide/", HideView.as_view(), name="report-hide"),
    path("reports/<str:target_type>/<int:pk>/restore/", ReportRestoreView.as_view(),
         name="report-restore"),
    path("reports/<str:target_type>/<int:pk>/delete/", DeleteView.as_view(),
         name="report-delete"),
    path("forbidden-words/", ForbiddenWordListCreateView.as_view(), name="forbidden-words"),
    path("forbidden-words/<int:pk>/", ForbiddenWordDetailView.as_view(),
         name="forbidden-word-detail"),
    path("export/accounts.csv", AccountsCsvView.as_view(), name="export-accounts"),
    path("referentials/free-values/", FreeValuesView.as_view(), name="ref-free-values"),
    *_REF_PATHS,
    path("private-files/<str:token>/", PrivateFileView.as_view(), name="private-file"),
]
