"""Réglages communs aux tests d'appels : Jitsi configuré avec un secret généré à la volée."""
import secrets

import pytest
from django.core.cache import cache


@pytest.fixture(autouse=True)
def jitsi_settings(settings):
    settings.JITSI_DOMAIN = "jitsi.example.test"
    settings.JITSI_APP_ID = "netbuis-test"
    settings.JITSI_JWT_SECRET = secrets.token_urlsafe(48)
    cache.clear()
    return settings


@pytest.fixture(autouse=True)
def admin_groups(db):
    """Groupes d'administration et droit « répondre aux appels ».

    Les tests `transaction=True` vident la base à la fin (y compris les données posées par les
    migrations) : on rejoue ici les mêmes fonctions de migration si le droit a disparu.
    """
    from importlib import import_module

    from django.apps import apps
    from django.contrib.auth.models import Group

    ok = Group.objects.filter(
        name="Validateur", permissions__codename="peut_repondre_aux_appels"
    ).exists() and Group.objects.filter(
        name="Administrateur complet", permissions__codename="peut_repondre_aux_appels"
    ).exists()
    if not ok:
        import_module("apps.admin_panel.migrations.0002_groupes_administration").create_groups(
            apps, None)
        import_module("apps.admin_panel.migrations.0008_repondre_aux_appels").add_permission(
            apps, None)
