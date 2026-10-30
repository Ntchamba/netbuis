"""Admin Django des zones : le référentiel se corrige ici (la validation du modèle s'applique)."""
from django.contrib import admin

from .models import Zone


@admin.register(Zone)
class ZoneAdmin(admin.ModelAdmin):
    list_display = ("name", "level", "parent", "is_active", "order")
    list_filter = ("level", "is_active")
    search_fields = ("name", "normalized_name", "official_code")
    ordering = ("level", "order", "normalized_name")
    list_select_related = ("parent",)
    autocomplete_fields = ("parent",)
    readonly_fields = ("normalized_name", "created_at", "updated_at")
