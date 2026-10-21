"""Routes de l'app calls (T050). Suite en T051 : feedback, whatsapp-report, history."""
from django.urls import path

from .views.initiate import InitiateCallView

app_name = "calls"

urlpatterns = [
    path("calls/initiate/", InitiateCallView.as_view(), name="initiate"),
]
