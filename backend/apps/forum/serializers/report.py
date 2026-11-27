"""Signalement (T090). La réponse ne dit JAMAIS qui a signalé."""
from rest_framework import serializers

from apps.forum.models import ReportReason, ReportTarget


class ReportCreateSerializer(serializers.Serializer):
    target_type = serializers.ChoiceField(choices=ReportTarget.choices)
    target_id = serializers.IntegerField(min_value=1)
    reason = serializers.ChoiceField(choices=ReportReason.choices)


class PostReportSerializer(serializers.Serializer):
    reason = serializers.ChoiceField(choices=ReportReason.choices)


class ReportDoneSerializer(serializers.Serializer):
    target_type = serializers.ChoiceField(choices=ReportTarget.choices)
    target_id = serializers.IntegerField()
    reason = serializers.ChoiceField(choices=ReportReason.choices)
