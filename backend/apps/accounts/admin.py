"""Admin Django des comptes (réservé à is_staff). Le mot de passe ne s'édite pas ici :
`python manage.py changepassword <téléphone>`.

Entrée dans l'admin Django : AdminOnlyBackend (apps/accounts/backends.py) n'accepte que
les comptes is_admin qui passent user.can_login(), en plus du is_staff exigé par Django.
"""
from django.contrib import admin
from rest_framework_simplejwt.token_blacklist.admin import OutstandingTokenAdmin
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken

from .models import User


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "is_admin", "is_blocked", "is_deleted", "is_staff", "created_at")
    list_filter = ("is_admin", "is_blocked", "is_deleted", "is_staff", "is_active")
    search_fields = ("name", "phone")
    ordering = ("-created_at",)
    exclude = ("password",)
    readonly_fields = ("last_login", "created_at", "updated_at")
    filter_horizontal = ("groups", "user_permissions")


class TokenSansValeurAdmin(OutstandingTokenAdmin):
    """Jetons émis, en lecture seule, sans jamais afficher la valeur du jeton."""

    exclude = ("token",)

    def get_readonly_fields(self, *args, **kwargs):
        return [name for name in super().get_readonly_fields(*args, **kwargs) if name != "token"]


admin.site.unregister(OutstandingToken)
admin.site.register(OutstandingToken, TokenSansValeurAdmin)
