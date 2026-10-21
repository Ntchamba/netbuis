"""Droits d'administration (T070, zone sensible : revue ligne par ligne).

Règle (docs/spec/DASHBOARD_ADMIN.md) : accès au dashboard = `is_admin=True` ET appartenance
à au moins un des groupes ci-dessous. Le groupe donne les permissions `peut_…`.

Les droits sont relus en base À CHAQUE requête (rien n'est mis dans le jeton) : un admin
retiré de son groupe, bloqué ou supprimé est refusé immédiatement. Les permissions
viennent UNIQUEMENT des groupes : `is_superuser` / `is_staff` ne donnent rien ici.
"""
from django.contrib.auth.models import Permission

APP_LABEL = "admin_panel"

GROUP_VALIDATEUR = "Validateur"
GROUP_ADMIN_COMPLET = "Administrateur complet"
ADMIN_GROUPS = (GROUP_VALIDATEUR, GROUP_ADMIN_COMPLET)

# Codes des permissions (modèle AuditLog porte les permissions, voir models/audit_log.py).
VOIR_DEMANDES = "peut_voir_demandes"
VOIR_COMPTES = "peut_voir_comptes"
VALIDER_DEMANDE = "peut_valider_demande"  # valider ET rejeter (avec motif) un dossier
BLOQUER_COMPTE = "peut_bloquer_compte"  # bloquer / débloquer
SUPPRIMER_COMPTE = "peut_supprimer_compte"  # supprimer / restaurer (suppression douce)
MODIFIER_REGLAGES = "peut_modifier_reglages"
EXPORTER = "peut_exporter"
GERER_ADMINS = "peut_gerer_admins"  # attribuer / retirer les rôles
ACCORDER_ABONNEMENT = "peut_accorder_abonnement"
GERER_REFERENTIELS = "peut_gerer_referentiels"  # zones, secteurs, catalogue (T074b)

PERMISSION_LABELS = {
    VOIR_DEMANDES: "Voir la file des demandes de compte business",
    VOIR_COMPTES: "Consulter les comptes (lecture)",
    VALIDER_DEMANDE: "Valider ou rejeter une demande de compte business",
    BLOQUER_COMPTE: "Bloquer ou débloquer un compte",
    SUPPRIMER_COMPTE: "Supprimer ou restaurer un compte",
    MODIFIER_REGLAGES: "Modifier les réglages de la plateforme",
    EXPORTER: "Exporter des données",
    GERER_ADMINS: "Attribuer ou retirer les rôles d'administration",
    ACCORDER_ABONNEMENT: "Accorder un abonnement",
    GERER_REFERENTIELS: "Gérer les référentiels (zones, secteurs, catalogue)",
}

GROUP_PERMISSIONS = {
    GROUP_VALIDATEUR: (VOIR_DEMANDES, VOIR_COMPTES, VALIDER_DEMANDE),
    GROUP_ADMIN_COMPLET: tuple(PERMISSION_LABELS),
}


def _is_active_admin(user) -> bool:
    return bool(
        user is not None
        and getattr(user, "is_authenticated", False)
        and user.is_admin
        and user.can_login()
    )


def admin_roles(user) -> list[str]:
    """Noms des groupes d'administration du compte (vide si pas admin actif)."""
    if not _is_active_admin(user):
        return []
    names = set(user.groups.filter(name__in=ADMIN_GROUPS).values_list("name", flat=True))
    return [name for name in ADMIN_GROUPS if name in names]


def admin_permissions(user) -> frozenset[str]:
    """Codes `peut_…` donnés par les groupes (relus en base à chaque appel)."""
    if not admin_roles(user):
        return frozenset()
    codes = Permission.objects.filter(
        group__user=user,
        group__name__in=ADMIN_GROUPS,
        content_type__app_label=APP_LABEL,
        codename__in=list(PERMISSION_LABELS),
    ).values_list("codename", flat=True)
    return frozenset(codes)


def has_dashboard_access(user) -> bool:
    return bool(admin_roles(user))


def has_admin_permission(user, codename: str) -> bool:
    return codename in admin_permissions(user)
