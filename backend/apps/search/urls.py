"""Routes de l'app search (montées sous /api/)."""
from django.urls import path

from apps.search.views.search import SearchView, VoiceSearchView
from apps.search.views.suggestions import SuggestionsView

app_name = "search"

urlpatterns = [
    path("search/", SearchView.as_view(), name="search"),
    path("search/suggestions/", SuggestionsView.as_view(), name="suggestions"),
    path("search/voice/", VoiceSearchView.as_view(), name="voice"),
]
