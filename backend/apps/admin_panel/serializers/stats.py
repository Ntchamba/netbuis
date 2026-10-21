"""Chiffres du tableau de bord (T073). Aucun numéro de téléphone."""
from rest_framework import serializers


class HighTrafficSerializer(serializers.Serializer):
    id = serializers.IntegerField(help_text="Identifiant du compte business")
    name = serializers.CharField(help_text="Nom affiché du compte business")
    calls_per_day = serializers.IntegerField(help_text="Appels reçus sur les dernières 24 h")


class RevenueSerializer(serializers.Serializer):
    amount = serializers.IntegerField(help_text="0 tant que les paiements ne sont pas faits")
    currency = serializers.CharField()
    unavailable = serializers.BooleanField(
        help_text="true : chiffre non disponible (paiements non branchés), à ne pas afficher "
                  "comme un vrai zéro"
    )


class AdminStatsSerializer(serializers.Serializer):
    accounts_total = serializers.IntegerField(help_text="Comptes non supprimés")
    accounts_new_week = serializers.IntegerField(help_text="Créés sur les 7 derniers jours")
    active_businesses = serializers.IntegerField(
        help_text="Comptes business actifs (ni bloqués ni supprimés)")
    neighborhoods_covered = serializers.IntegerField(
        help_text="Quartiers distincts où se trouve au moins un compte business actif")
    pending_requests = serializers.IntegerField(help_text="Demandes business en attente")
    calls_week = serializers.IntegerField(help_text="Appels et WhatsApp, 7 derniers jours")
    searches_week = serializers.IntegerField(help_text="Recherches, 7 derniers jours")
    subscribers = serializers.IntegerField(
        help_text="Comptes business actifs avec un abonnement en cours")
    subscription_threshold = serializers.IntegerField(
        help_text="Seuil d'appels quotidiens (PlatformSetting seuil_appels_abonnement)")
    high_traffic_count = serializers.IntegerField(
        help_text="Comptes non abonnés au-dessus du seuil sur 24 h")
    high_traffic = HighTrafficSerializer(
        many=True, help_text="Les 10 plus sollicités ; numéro jamais renvoyé")
    revenue_month = RevenueSerializer()
