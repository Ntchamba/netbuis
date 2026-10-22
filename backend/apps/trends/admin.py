"""Administration Django des tendances (lecture seule : le calcul vient de `compute_trends`)."""
from django.contrib import admin

from apps.trends.models import TrendEntry, TrendSnapshot


class TrendEntryInline(admin.TabularInline):
    model = TrendEntry
    extra = 0
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(TrendSnapshot)
class TrendSnapshotAdmin(admin.ModelAdmin):
    list_display = ("zone", "period_end", "window_days")
    inlines = [TrendEntryInline]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
