"""Routes de l'app calls : appels vers l'équipe (Jitsi), WhatsApp, retour, signalement,
historique. Les routes `admin/calls/…` sont réservées au droit `peut_repondre_aux_appels`."""
from django.urls import path

from .views import agent, sessions
from .views.feedback import FeedbackView, HistoryView
from .views.whatsapp import WhatsAppView
from .views.whatsapp_report import WhatsAppReportView

app_name = "calls"

urlpatterns = [
    path("calls/sessions/", sessions.SessionCreateView.as_view(), name="session-create"),
    path("calls/sessions/<uuid:pk>/", sessions.SessionDetailView.as_view(), name="session"),
    path("calls/sessions/<uuid:pk>/events/", sessions.SessionEventsView.as_view(),
         name="session-events"),
    path("calls/sessions/<uuid:pk>/end/", sessions.SessionEndView.as_view(), name="session-end"),
    path("calls/sessions/<uuid:pk>/cancel/", sessions.SessionCancelView.as_view(),
         name="session-cancel"),
    path("calls/whatsapp/", WhatsAppView.as_view(), name="whatsapp"),
    path("calls/whatsapp-report/", WhatsAppReportView.as_view(), name="whatsapp-report"),
    path("calls/history/", HistoryView.as_view(), name="history"),
    path("calls/<int:pk>/feedback/", FeedbackView.as_view(), name="feedback"),
    path("admin/calls/", agent.AgentCallListView.as_view(), name="admin-calls"),
    path("admin/calls/stream/", agent.AgentStreamView.as_view(), name="admin-calls-stream"),
    path("admin/calls/presence/", agent.PresenceView.as_view(), name="admin-calls-presence"),
    path("admin/calls/sessions/<uuid:pk>/accept/", agent.AcceptView.as_view(),
         name="admin-calls-accept"),
    path("admin/calls/sessions/<uuid:pk>/decline/", agent.DeclineView.as_view(),
         name="admin-calls-decline"),
    path("admin/calls/sessions/<uuid:pk>/end/", agent.AgentEndView.as_view(),
         name="admin-calls-end"),
]
