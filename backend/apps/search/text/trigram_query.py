"""Briques SQL de la tolérance aux fautes : similarité de trigrammes PostgreSQL (`pg_trgm`).

Les textes comparés sont mis en minuscules et sans accents côté base (`unaccent`), le terme
cherché l'est déjà côté Python. La similarité utilisée est `word_similarity` : « riz » est
très proche de « Riz parfumé 25 kg » (un mot du texte ressemble au terme) et « ris » reste
assez proche de « riz » pour passer le seuil.
"""
from django.contrib.postgres.lookups import Unaccent
from django.contrib.postgres.search import TrigramWordSimilarity
from django.db.models import Case, ExpressionWrapper, F, FloatField, Value, When
from django.db.models.functions import Greatest, Lower

SIMILARITY_THRESHOLD = 0.3  # seuil de départ (TASKS_PAR_AGENT A3.2)


def plain_text(field):
    """Le champ (nom de colonne ou expression) en minuscules sans accents."""
    expression = F(field) if isinstance(field, str) else field
    return Unaccent(Lower(expression))


def active_text(field, active_field):
    """Comme `plain_text`, mais NULL quand la ligne du référentiel est désactivée."""
    return plain_text(Case(When(**{active_field: True}, then=F(field)), default=None))


def term_score(term: str, weight: float, expression):
    return ExpressionWrapper(
        TrigramWordSimilarity(term, expression) * Value(float(weight)), output_field=FloatField()
    )


def best_score(terms, expression):
    """Meilleure similarité (pondérée) entre `expression` et l'un des termes `(texte, poids)`."""
    scores = [term_score(text, weight, expression) for text, weight in terms]
    return scores[0] if len(scores) == 1 else Greatest(*scores)
