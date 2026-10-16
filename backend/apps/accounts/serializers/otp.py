"""Corps des requêtes et réponses des routes OTP. Le numéro est validé par le service."""
from rest_framework import serializers


class OtpRequestSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20, help_text="6XXXXXXXX, avec ou sans +237")


class OtpRequestResponseSerializer(serializers.Serializer):
    expires_in = serializers.IntegerField(help_text="Validité du code, en secondes")


class OtpVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=20, help_text="6XXXXXXXX, avec ou sans +237")
    code = serializers.CharField(max_length=6, help_text="Code à 6 chiffres reçu par SMS")


class OtpVerifyResponseSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()
    is_new = serializers.BooleanField(help_text="Vrai si le compte vient d'être créé")


class ErrorSerializer(serializers.Serializer):
    code = serializers.CharField()
    message = serializers.CharField()
