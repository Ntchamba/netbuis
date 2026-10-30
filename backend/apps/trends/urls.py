"""Routes de l'app trends : GET /api/trends/?zone="""
from django.urls import path

from apps.trends.views.trends import TrendsView

app_name = "trends"

urlpatterns = [
    path("trends/", TrendsView.as_view(), name="trends"),
]
