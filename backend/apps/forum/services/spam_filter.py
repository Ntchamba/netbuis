"""Filtre anti-spam simple du forum (T094), appliqué à la création d'une publication (légende)
et d'un commentaire. Décision : REFUS immédiat, 400 `spam_detected` (pas de mise en file
masquée : l'auteur sait tout de suite et peut reformuler). Le message ne dit jamais quel mot
ou quelle règle a déclenché le refus.

Trois règles, dans cet ordre :
1. MOTS INTERDITS (modèle `ForbiddenWord`, géré par l'Administrateur complet) : comparaison
   sur le texte normalisé (minuscules, sans accents, ponctuation = espace, caractères invisibles
   retirés), par mots ENTIERS (« cas » n'interdit pas « cassé »).
2. LIENS : plus de `MAX_URLS` liens dans le texte, OU le même lien écrit deux fois.
3. DOUBLONS : le même texte (normalisé) déjà posté par le même compte (pour une publication :
   le même commerce) dans les `DUPLICATE_WINDOW` dernières minutes. Une légende vide n'est
   jamais un doublon.
"""
import re
import unicodedata
from collections import Counter
from datetime import timedelta

from django.utils import timezone
from rest_framework import status

from apps.core.exceptions import ApiError
from apps.forum.models import Comment, ForbiddenWord, Post

MAX_URLS = 2  # plus de 2 liens : refusé
DUPLICATE_WINDOW = timedelta(minutes=10)

_URL = re.compile(
    r"(?i)(?:https?://|www\.)[^\s]+"
    r"|\b(?:[a-z0-9-]+\.)+(?:com|net|org|info|biz|cm|me|io|co|ly|xyz|link|site|shop|online)"
    r"\b(?:/[^\s]*)?"
)
_NON_WORD = re.compile(r"[\W_]+")


class SpamDetected(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "spam_detected"
    default_detail = "Ce message ressemble à du spam et n'a pas été publié."


def normalize(text: str) -> str:
    """Minuscules, sans accents, caractères invisibles retirés, tout le reste en espaces simples."""
    text = unicodedata.normalize("NFKD", text or "")
    text = "".join(
        ch for ch in text
        if not unicodedata.combining(ch) and unicodedata.category(ch) != "Cf"
    )
    return _NON_WORD.sub(" ", text.casefold()).strip()


def _link_key(link: str) -> str:
    link = re.sub(r"(?i)^https?://", "", link.strip().rstrip(".,;:!?)»\"'"))
    link = re.sub(r"(?i)^www\.", "", link)
    return link.rstrip("/").casefold()


def links(text: str) -> list[str]:
    return [_link_key(m.group(0)) for m in _URL.finditer(text or "")]


def has_forbidden_word(text: str) -> bool:
    padded = f" {normalize(text)} "
    return any(
        f" {word} " in padded for word in ForbiddenWord.objects.values_list("word", flat=True)
    )


def has_too_many_links(text: str) -> bool:
    found = links(text)
    return len(found) > MAX_URLS or (bool(found) and max(Counter(found).values()) > 1)


def _recent_texts(queryset, field: str, now):
    return queryset.filter(created_at__gte=now - DUPLICATE_WINDOW).values_list(field, flat=True)


def is_duplicate(text: str, recent_texts) -> bool:
    key = normalize(text)
    return bool(key) and any(normalize(other) == key for other in recent_texts)


def check_text(text: str) -> None:
    """Règles sans base d'historique (mots interdits, liens). Lève `SpamDetected`."""
    if has_forbidden_word(text) or has_too_many_links(text):
        raise SpamDetected()


def check_comment(user, text: str, now=None) -> None:
    check_text(text)
    now = now or timezone.now()
    recent = _recent_texts(Comment.objects.filter(author=user), "text", now)
    if is_duplicate(text, recent):
        raise SpamDetected()


def check_post(profile, caption: str, now=None) -> None:
    check_text(caption)
    now = now or timezone.now()
    recent = _recent_texts(Post.objects.filter(profile=profile), "caption", now)
    if is_duplicate(caption, recent):
        raise SpamDetected()
