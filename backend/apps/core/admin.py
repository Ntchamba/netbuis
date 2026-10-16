"""Admin Django du noyau : réglages de plateforme (T008b).
La clé se choisit dans la liste ; « modifié par » = l'utilisateur connecté."""
from django.contrib import admin

from .models import DEFAULTS, PlatformSetting


@admin.register(PlatformSetting)
class PlatformSettingAdmin(admin.ModelAdmin):
    list_display = ("key", "libelle", "value", "valeur_par_defaut", "modified_by", "updated_at")
    fields = ("key", "value", "valeur_par_defaut", "modified_by", "updated_at")
    readonly_fields = ("valeur_par_defaut", "modified_by", "updated_at")
    ordering = ("key",)

    @admin.display(description="libellé")
    def libelle(self, obj):
        return obj.get_key_display()

    @admin.display(description="valeur par défaut")
    def valeur_par_defaut(self, obj):
        return DEFAULTS.get(obj.key, "—") if obj and obj.key else "—"

    def get_readonly_fields(self, request, obj=None):
        fields = super().get_readonly_fields(request, obj)
        return (*fields, "key") if obj else fields  # la clé ne change plus après création

    def save_model(self, request, obj, form, change):
        obj.modified_by = request.user
        super().save_model(request, obj, form, change)
