"""Journal des appels : lecture seule, aucun numéro affiché."""
from django.contrib import admin

from .models import (
    AgentPresence,
    CallFeedback,
    CallLog,
    CallSession,
    CallSessionDecline,
    WhatsAppReport,
)


@admin.register(CallLog)
class CallLogAdmin(admin.ModelAdmin):
    list_display = ("id", "caller", "profile", "channel", "platform", "operator", "billing_type",
                    "created_at")
    list_filter = ("channel", "platform", "billing_type")
    readonly_fields = [f.name for f in CallLog._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.action(description="Marquer comme examinés (ne comptent plus pour le seuil)")
def mark_reviewed(modeladmin, request, queryset):
    queryset.update(reviewed=True)


@admin.register(WhatsAppReport)
class WhatsAppReportAdmin(admin.ModelAdmin):
    """Revue par un admin. Pour réactiver WhatsApp : cocher « WhatsApp disponible » sur le
    compte business, puis marquer les signalements comme examinés."""

    list_display = ("id", "profile", "reporter", "reviewed", "created_at")
    list_filter = ("reviewed",)
    actions = [mark_reviewed]
    readonly_fields = ("reporter", "profile", "created_at", "updated_at")

    def has_add_permission(self, request):
        return False


@admin.register(CallFeedback)
class CallFeedbackAdmin(admin.ModelAdmin):
    list_display = ("id", "call", "outcome", "updated_at")
    list_filter = ("outcome",)
    readonly_fields = [f.name for f in CallFeedback._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


class ReadOnlyAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(CallSession)
class CallSessionAdmin(ReadOnlyAdmin):
    """Le nom de salle (secret) n'est affiché nulle part."""

    list_display = ("id", "caller", "business", "state", "agent", "created_at", "ended_at")
    list_filter = ("state",)
    exclude = ("room",)


@admin.register(CallSessionDecline)
class CallSessionDeclineAdmin(ReadOnlyAdmin):
    list_display = ("session", "agent", "created_at")


@admin.register(AgentPresence)
class AgentPresenceAdmin(ReadOnlyAdmin):
    list_display = ("agent", "available", "open_streams", "last_seen")
