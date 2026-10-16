"""Corps des requêtes et réponses des routes de jetons et de connexion administrateur."""
from rest_framework import serializers


class RefreshRequestSerializer(serializers.Serializer):
    refresh = serializers.CharField(
        required=False,
        help_text=(
            "Application mobile : jeton de rafraîchissement. Dashboard : laisser vide, "
            "le jeton est lu dans le cookie HttpOnly netbuis_refresh."
        ),
    )


class RefreshResponseSerializer(serializers.Serializer):
    access = serializers.CharField(help_text="Jeton d'accès, valable 15 min")
    refresh = serializers.CharField(
        required=False,
        help_text=(
            "Nouveau jeton de rafraîchissement (30 jours) ; l'ancien n'est plus valable. "
            "Absent pour le dashboard : il est reposé dans le cookie."
        ),
    )


class AdminLoginSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20, help_text="6XXXXXXXX, avec ou sans +237")
    password = serializers.CharField(
        max_length=128, trim_whitespace=False, style={"input_type": "password"}, write_only=True
    )


class AccessResponseSerializer(serializers.Serializer):
    access = serializers.CharField(
        help_text=(
            "Jeton d'accès, valable 15 min. Le jeton de rafraîchissement est posé dans "
            "le cookie HttpOnly netbuis_refresh."
        )
    )
