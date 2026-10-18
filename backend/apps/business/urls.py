"""Routes de l'app business.

`me/` est déclarée avant toute future route `business/<id>/` (T047b) pour ne pas être capturée.
Routes à venir (voir docs/api/openapi.yaml) : business/me/offers/, business/<id>/, uploads/sign/.
"""
from django.urls import path

from apps.business.views.merchant_profile import BusinessCreateView, MerchantProfileView

app_name = "business"

urlpatterns = [
    path("business/", BusinessCreateView.as_view(), name="create"),
    path("business/me/", MerchantProfileView.as_view(), name="me"),
]
