"""Analyses (T074c) : agrégats seulement, aucun compte, aucun numéro."""
from rest_framework import serializers


class TermCountSerializer(serializers.Serializer):
    term = serializers.CharField(help_text="Terme normalisé")
    count = serializers.IntegerField()


class SearchAnalyticsSerializer(serializers.Serializer):
    days = serializers.IntegerField()
    since = serializers.DateField(help_text="Premier jour de la fenêtre (aujourd'hui compris)")
    total_searches = serializers.IntegerField()
    total_without_results = serializers.IntegerField()
    top_terms = TermCountSerializer(many=True, help_text="50 au plus, par fréquence décroissante")
    no_result_terms = TermCountSerializer(
        many=True, help_text="Termes sans résultat, 50 au plus, par fréquence décroissante")


class DayCountSerializer(serializers.Serializer):
    date = serializers.DateField()
    count = serializers.IntegerField()


class OperatorCountsSerializer(serializers.Serializer):
    orange = serializers.IntegerField()
    mtn = serializers.IntegerField()
    unknown = serializers.IntegerField()


class PlatformCountsSerializer(serializers.Serializer):
    android = serializers.IntegerField()
    ios = serializers.IntegerField()


class ChannelCountsSerializer(serializers.Serializer):
    call = serializers.IntegerField()
    whatsapp = serializers.IntegerField()


class CallAnalyticsSerializer(serializers.Serializer):
    days = serializers.IntegerField()
    since = serializers.DateField()
    total_calls = serializers.IntegerField()
    by_day = DayCountSerializer(many=True, help_text="Un élément par jour, zéros compris")
    by_operator = OperatorCountsSerializer()
    by_platform = PlatformCountsSerializer()
    by_channel = ChannelCountsSerializer()
