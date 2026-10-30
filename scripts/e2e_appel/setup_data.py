"""Prépare les données FICTIVES de l'essai de bout en bout T134 (base de développement jetable).
Usage (depuis backend/, DEBUG=True) : python ../scripts/e2e_appel/setup_data.py
Écrit sur la sortie un JSON : comptes agents (mot de passe tiré au hasard), jeton de l'appelant, commerce."""
import json
import os
import secrets
import sys

sys.path.insert(0, os.getcwd())
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")
import django  # noqa: E402

django.setup()
from django.contrib.auth.models import Group  # noqa: E402

from apps.accounts.models import User  # noqa: E402
from apps.accounts.services.token_service import issue_tokens  # noqa: E402
from apps.calls.models import AgentPresence, CallSession  # noqa: E402
from tests.factories.business_factory import make_profile, make_subscription  # noqa: E402


def agent(number: int, name: str) -> dict:
    phone = f"+23760099{9000 + number:04d}"
    password = secrets.token_urlsafe(18)
    user, _ = User.objects.get_or_create(phone=phone, defaults={"is_admin": True, "name": name})
    user.is_admin, user.name = True, name
    user.set_password(password)
    user.save()
    user.groups.set([Group.objects.get(name="Validateur")])
    AgentPresence.objects.filter(agent=user).delete()
    return {"id": user.pk, "phone": phone, "password": password, "name": name}


from apps.core.models.platform_setting import PlatformSetting, SettingKey  # noqa: E402
from apps.core.services.settings_service import invalidate_setting  # noqa: E402

# Limites relevées pour l'essai (100 appels de mesure en quelques minutes), base jetable seulement.
for key in (SettingKey.LIMITE_APPELS_PAR_MINUTE, SettingKey.LIMITE_APPELS_PAR_JOUR):
    PlatformSetting.objects.update_or_create(key=key, defaults={"value": 1000})
    invalidate_setting(key)
CallSession.objects.filter(caller__phone__startswith="+23760099").delete()
agents = [agent(1, "Agent Un"), agent(2, "Agent Deux")]
caller = User.objects.filter(phone="+237600990001").first() or User.objects.create(
    phone="+237600990001", name="Awa Appelante")
owner, _ = User.objects.get_or_create(phone="+237600991001")
from apps.business.models import BusinessProfile  # noqa: E402

BusinessProfile.objects.filter(owner=owner).delete()
profile = make_profile(owner=owner, name="Boutique Essai Bout-en-bout", status="actif")
make_subscription(profile)
print(json.dumps({
    "agents": agents,
    "caller": {"phone": caller.phone, "access": issue_tokens(caller)["access"]},
    "business": {"id": profile.pk, "name": profile.name, "phone": profile.phone_anchor},
}))
