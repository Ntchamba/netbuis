"""Compte de l'utilisateur connecté : GET / PATCH /api/me/ (T008).

Le numéro n'est jamais renvoyé en entier : seulement `phone_masked` (« +237 6•• •• •• 12 »,
maquette Profil). Seuls `name` et `language` sont modifiables.
"""
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.accounts.models import User
from apps.core.utils.phone import mask_phone


class MeSerializer(serializers.ModelSerializer):
    phone_masked = serializers.SerializerMethodField(
        help_text="Numéro masqué : seuls le premier et les deux derniers chiffres restent"
    )
    has_business = serializers.SerializerMethodField(
        help_text="Vrai si le compte a un compte business (quel que soit son statut)"
    )
    free_call_available = serializers.SerializerMethodField(
        help_text="Appels gratuits restants aujourd'hui ; null tant que CREDITS_ENABLED=False"
    )
    credits_balance = serializers.SerializerMethodField(
        help_text="Solde de crédits en FCFA ; null tant que CREDITS_ENABLED=False"
    )

    class Meta:
        model = User
        fields = (
            "id",
            "name",
            "phone_masked",
            "language",
            "has_business",
            "free_call_available",
            "credits_balance",
        )
        read_only_fields = ("id",)
        extra_kwargs = {"name": {"help_text": "Facultatif ; 120 caractères au plus"}}

    def get_phone_masked(self, user) -> str:
        return mask_phone(user.phone)

    def get_has_business(self, user) -> bool:
        return user.business_profile_or_none is not None

    # Paiements et crédits reportés (D-03, V08) : aucun quota ni solde n'existe encore,
    # donc ces blocs sont masqués par l'application (valeur null).
    @extend_schema_field(serializers.IntegerField(allow_null=True))
    def get_free_call_available(self, user):
        return None

    @extend_schema_field(serializers.IntegerField(allow_null=True))
    def get_credits_balance(self, user):
        return None
