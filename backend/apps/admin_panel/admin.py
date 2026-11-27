"""Journal d'audit dans l'admin Django : lecture seule (jamais modifié à la main)."""
from django.contrib import admin

from .models import AuditLog


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ("created_at", "admin", "action", "target_type", "target_id")
    list_filter = ("action",)
    readonly_fields = ("admin", "action", "target_type", "target_id", "reason", "created_at")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
