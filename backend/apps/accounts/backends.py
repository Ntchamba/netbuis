"""Connexion par mot de passe (zone sensible) : admin-login et admin Django.

Les clients et commerçants se connectent par code SMS et n'ont pas de mot de passe
utilisable ; seul un administrateur (is_admin) qui passe user.can_login() peut
s'authentifier ici. La même règle est revérifiée à chaque requête de l'admin Django
(get_user) : un admin bloqué, supprimé ou retiré perd sa session aussitôt.
"""
from django.contrib.auth.backends import ModelBackend


class AdminOnlyBackend(ModelBackend):
    def user_can_authenticate(self, user):
        return bool(user.is_admin and user.can_login())
