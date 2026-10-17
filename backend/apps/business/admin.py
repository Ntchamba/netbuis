"""Admin Django des comptes business (T025).

Le numéro ancré n'apparaît que masqué (`mask_phone`) et en lecture seule ; le chemin de la CNI
n'est jamais affiché (sa consultation par URL temporaire viendra avec T027). Les compteurs sont
en lecture seule. Les comptes se créent par l'API : pas d'ajout depuis l'admin.
"""
from django import forms
from django.contrib import admin
from django.core.exceptions import NON_FIELD_ERRORS, ValidationError

from apps.core.utils.phone import mask_phone

from .models import BusinessProfile

SECRET_FIELDS = ("phone_anchor", "cni_photo")
FORM_FIELDS = [
    field.name
    for field in [*BusinessProfile._meta.fields, *BusinessProfile._meta.many_to_many]
    if field.editable and field.name not in SECRET_FIELDS
]


class BusinessProfileAdminForm(forms.ModelForm):
    class Meta:
        model = BusinessProfile
        fields = FORM_FIELDS

    def _update_errors(self, errors):
        # Les champs absents du formulaire (numéro, CNI, lecture seule) ne peuvent pas porter
        # une erreur : elle devient une erreur générale.
        if hasattr(errors, "error_dict"):
            merged: dict[str, list] = {}
            for field, field_errors in errors.error_dict.items():
                target = field if field in self.fields else NON_FIELD_ERRORS
                merged.setdefault(target, []).extend(field_errors)
            errors = ValidationError(merged)
        super()._update_errors(errors)


@admin.register(BusinessProfile)
class BusinessProfileAdmin(admin.ModelAdmin):
    form = BusinessProfileAdminForm
    list_display = ("name", "type_compte", "status", "zone")
    list_filter = ("type_compte", "status")
    search_fields = ("name",)
    list_select_related = ("zone",)
    autocomplete_fields = ("zone",)
    readonly_fields = (
        "owner", "phone_masque", "cni_verifiee", "calls_count", "views_count",
        "created_at", "updated_at",
    )

    @admin.display(description="numéro ancré (masqué)")
    def phone_masque(self, obj):
        return mask_phone(obj.phone_anchor) if obj.phone_anchor else "—"

    def has_add_permission(self, request):
        return False
