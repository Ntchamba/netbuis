"""Journal des recherches : lecture seule dans l'admin Django."""
from django.contrib import admin

from apps.search.models import SearchLog


@admin.register(SearchLog)
class SearchLogAdmin(admin.ModelAdmin):
    list_display = ("term", "mode", "zone", "results_count", "created_at")
    list_filter = ("mode",)
    search_fields = ("term",)
    date_hierarchy = "created_at"

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
