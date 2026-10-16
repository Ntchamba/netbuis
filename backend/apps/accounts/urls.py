"""Routes de l'app accounts (voir docs/api/openapi.yaml)."""
from django.urls import path

from .views.otp import OtpRequestView, OtpVerifyView

app_name = "accounts"

urlpatterns = [
    path("auth/otp/request/", OtpRequestView.as_view(), name="otp-request"),
    path("auth/otp/verify/", OtpVerifyView.as_view(), name="otp-verify"),
]
