"""Routes /api/payments/… — vides jusqu'à É6.

Plus tard :
    path("", include("apps.payments.collect.urls"))   # start, status, webhook, history
    path("packs/", ...)                               # liste des packs
Le module payout/ est interne + admin (pas exposé aux clients).
"""
from django.urls import path  # noqa: F401

app_name = "payments"

urlpatterns = []
