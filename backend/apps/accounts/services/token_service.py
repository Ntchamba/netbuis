"""Jetons JWT (zone sensible : relue ligne par ligne).

- Accès : 15 min ; rafraîchissement : 30 jours (SIMPLE_JWT, config/settings/base.py).
- Chaque jeton de rafraîchissement émis est enregistré (OutstandingToken). Il ne sert
  qu'une fois : le rafraîchir l'invalide et en émet un nouveau (rotation) ; la
  déconnexion l'invalide (BlacklistedToken).
- Un compte qui ne passe plus user.can_login() ne peut plus rafraîchir.
- Dashboard (D-01) : le jeton de rafraîchissement voyage dans un cookie HttpOnly,
  SameSite=Lax, Secure quand DEBUG=False, limité aux routes /api/auth/.
- Aucun jeton n'est jamais écrit dans un journal.
"""
from django.conf import settings
from django.db import transaction
from rest_framework import status
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import User
from apps.accounts.services.otp_service import AccountBlocked, AccountDeleted
from apps.core.exceptions import ApiError


class TokenInvalid(ApiError):
    status_code = status.HTTP_401_UNAUTHORIZED
    default_code = "token_invalid"
    default_detail = "Votre session a expiré. Reconnectez-vous."


def check_can_login(user) -> None:
    """Lève 403 account_blocked / account_deleted, ou 401 si le compte est inactif."""
    if user.can_login():
        return
    if user.is_deleted:
        raise AccountDeleted()
    if user.is_blocked:
        raise AccountBlocked()
    raise TokenInvalid()


def issue_tokens(user) -> dict:
    """Nouveau couple de jetons pour `user` (le jeton de rafraîchissement est enregistré)."""
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


def _validated(raw: str) -> RefreshToken:
    """Signature, type, expiration et liste noire vérifiés ; sinon 401 token_invalid."""
    try:
        return RefreshToken(raw)
    except TokenError:
        raise TokenInvalid() from None


def _consume(raw: str) -> OutstandingToken:
    """Invalide le jeton de rafraîchissement `raw` et renvoie sa ligne enregistrée.

    À appeler dans une transaction : la ligne est verrouillée, donc deux requêtes
    simultanées avec le même jeton ne peuvent pas l'utiliser toutes les deux.
    """
    token = _validated(raw)
    outstanding = (
        OutstandingToken.objects.select_for_update()
        .filter(jti=token[api_settings.JTI_CLAIM])
        .first()
    )
    # Jeton non enregistré (jamais émis par nous) ou déjà invalidé : refusé.
    if outstanding is None or BlacklistedToken.objects.filter(token=outstanding).exists():
        raise TokenInvalid()
    BlacklistedToken.objects.create(token=outstanding)
    return outstanding


def rotate_refresh(raw: str) -> dict:
    """Rafraîchit : l'ancien jeton est invalidé, un nouveau couple est émis."""
    with transaction.atomic():
        outstanding = _consume(raw)
        user = User.objects.filter(pk=outstanding.user_id).first()
        if user is not None and user.can_login():
            return issue_tokens(user)
    # Refus levé hors de la transaction : l'ancien jeton reste invalidé.
    if user is None:
        raise TokenInvalid()
    check_can_login(user)
    raise TokenInvalid()  # garde-fou : check_can_login a déjà levé l'erreur


def revoke_refresh(raw: str) -> None:
    """Déconnexion : le jeton de rafraîchissement ne pourra plus servir."""
    with transaction.atomic():
        _consume(raw)


def set_refresh_cookie(response, refresh: str) -> None:
    response.set_cookie(
        settings.REFRESH_COOKIE_NAME,
        refresh,
        max_age=int(api_settings.REFRESH_TOKEN_LIFETIME.total_seconds()),
        path=settings.REFRESH_COOKIE_PATH,
        secure=not settings.DEBUG,
        httponly=True,
        samesite="Lax",
    )


def delete_refresh_cookie(response) -> None:
    response.delete_cookie(
        settings.REFRESH_COOKIE_NAME, path=settings.REFRESH_COOKIE_PATH, samesite="Lax"
    )
