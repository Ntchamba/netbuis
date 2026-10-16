"""Admin Django des comptes (réservé à is_staff). Le mot de passe ne s'édite pas ici :
`python manage.py changepassword <téléphone>`."""
from django.contrib import admin

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
