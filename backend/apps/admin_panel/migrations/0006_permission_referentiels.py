"""Ajoute la permission `peut_gerer_referentiels` à l'Administrateur complet (T074b).

Valeurs figées ici. Le Validateur ne la reçoit pas.
"""
from django.db import migrations

CODENAME = "peut_gerer_referentiels"
LABEL = "Gérer les référentiels (zones, secteurs, catalogue)"
GROUP = "Administrateur complet"


def add_permission(apps, schema_editor):
    ContentType = apps.get_model("contenttypes", "ContentType")
    Permission = apps.get_model("auth", "Permission")
    Group = apps.get_model("auth", "Group")
    ct, _ = ContentType.objects.get_or_create(app_label="admin_panel", model="auditlog")
    perm, _ = Permission.objects.get_or_create(
        content_type=ct, codename=CODENAME, defaults={"name": LABEL}
    )
    group, _ = Group.objects.get_or_create(name=GROUP)
    group.permissions.add(perm)


def remove_permission(apps, schema_editor):
    Permission = apps.get_model("auth", "Permission")
    Permission.objects.filter(
        content_type__app_label="admin_panel", codename=CODENAME
    ).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("admin_panel", "0005_alter_auditlog_options_alter_auditlog_action"),
        ("auth", "0012_alter_user_first_name_max_length"),
        ("contenttypes", "0002_remove_content_type_name"),
    ]
    operations = [migrations.RunPython(add_permission, remove_permission)]
