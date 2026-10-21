"""Routes de l'app calls : appel / WhatsApp, retour, signalement, historique."""
from django.urls import path

from .views.feedback import FeedbackView, HistoryView
from .views.initiate import InitiateCallView
from .views.whatsapp_report import WhatsAppReportView

app_name = "calls"

urlpatterns = [
    path("calls/initiate/", InitiateCallView.as_view(), name="initiate"),
    path("calls/whatsapp-report/", WhatsAppReportView.as_view(), name="whatsapp-report"),
    path("calls/history/", HistoryView.as_view(), name="history"),
    path("calls/<int:pk>/feedback/", FeedbackView.as_view(), name="feedback"),
]
