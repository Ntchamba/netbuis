"""Crée les groupes « Validateur » et « Administrateur complet » avec leurs permissions (T070).

Valeurs figées ici (une migration ne doit pas changer si le code change). Les permissions
sont créées directement : le signal post_migrate ne s'est pas encore exécuté.
"""
from django.db import migrations

LABELS = {
    "peut_voir_demandes": "Voir la file des demandes de compte business",
    "peut_voir_comptes": "Consulter les comptes (lecture)",
    "peut_valider_demande": "Valider ou rejeter une demande de compte business",
    "peut_bloquer_compte": "Bloquer ou débloquer un compte",
    "peut_supprimer_compte": "Supprimer ou restaurer un compte",
    "peut_modifier_reglages": "Modifier les réglages de la plateforme",
    "peut_exporter": "Exporter des données",
    "peut_gerer_admins": "Attribuer ou retirer les rôles d'administration",
    "peut_accorder_abonnement": "Accorder un abonnement",
}
GROUPS = {
    "Validateur": ("peut_voir_demandes", "peut_voir_comptes", "peut_valider_demande"),
    "Administrateur complet": tuple(LABELS),
}


def create_groups(apps, schema_editor):
    ContentType = apps.get_model("contenttypes", "ContentType")
    Permission = apps.get_model("auth", "Permission")
    Group = apps.get_model("auth", "Group")
    ct, _ = ContentType.objects.get_or_create(app_label="admin_panel", model="auditlog")
    for codename, name in LABELS.items():
        Permission.objects.get_or_create(
            content_type=ct, codename=codename, defaults={"name": name}
        )
    for group_name, codenames in GROUPS.items():
        group, _ = Group.objects.get_or_create(name=group_name)
        group.permissions.set(Permission.objects.filter(content_type=ct, codename__in=codenames))


def delete_groups(apps, schema_editor):
    apps.get_model("auth", "Group").objects.filter(name__in=list(GROUPS)).delete()


class Migration(migrations.Migration):
    dependencies = [
        ("admin_panel", "0001_initial"),
        ("auth", "0012_alter_user_first_name_max_length"),
        ("contenttypes", "0002_remove_content_type_name"),
    ]
    operations = [migrations.RunPython(create_groups, delete_groups)]
