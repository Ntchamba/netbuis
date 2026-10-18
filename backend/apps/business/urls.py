"""Routes de l'app business.

`me/` est déclarée avant toute future route `business/<id>/` (T047b) pour ne pas être capturée.
Routes à venir (voir docs/api/openapi.yaml) : business/me/offers/, business/<id>/.
"""
from django.urls import path

from apps.business.views.merchant_profile import BusinessCreateView, MerchantProfileView
from apps.business.views.uploads_sign import UploadLocalView, UploadSignView

app_name = "business"

urlpatterns = [
    path("business/", BusinessCreateView.as_view(), name="create"),
    path("business/me/", MerchantProfileView.as_view(), name="me"),
    path("uploads/sign/", UploadSignView.as_view(), name="upload-sign"),
    path("uploads/local/<str:token>/", UploadLocalView.as_view(), name="upload-local"),
]
