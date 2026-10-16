"""Émission des jetons JWT (zone sensible). Minimum posé en T006 ; durées et refresh en T007."""
from rest_framework_simplejwt.tokens import RefreshToken


def issue_tokens(user) -> dict:
    refresh = RefreshToken.for_user(user)
    return {"access": str(refresh.access_token), "refresh": str(refresh)}
