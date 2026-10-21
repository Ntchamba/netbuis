"""Journal des appels : lecture seule, aucun numéro affiché."""
from django.contrib import admin

from .models import CallLog


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
