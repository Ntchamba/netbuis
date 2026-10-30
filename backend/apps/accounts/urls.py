"""Routes de l'app accounts (voir docs/api/openapi.yaml)."""
from django.urls import path

from .views.admin_login import AdminLoginView
from .views.me import MeView
from .views.otp import OtpRequestView, OtpVerifyView
from .views.refresh import LogoutView, RefreshView

app_name = "accounts"

urlpatterns = [
    path("auth/otp/request/", OtpRequestView.as_view(), name="otp-request"),
    path("auth/otp/verify/", OtpVerifyView.as_view(), name="otp-verify"),
    path("auth/refresh/", RefreshView.as_view(), name="token-refresh"),
    path("auth/logout/", LogoutView.as_view(), name="logout"),
    path("auth/admin/login/", AdminLoginView.as_view(), name="admin-login"),
    path("me/", MeView.as_view(), name="me"),
]
