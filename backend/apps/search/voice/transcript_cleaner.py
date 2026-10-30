"""Nettoie le texte reconnu par le téléphone (la reconnaissance vocale est faite côté mobile).

« Je cherche du riz s'il vous plaît » → « riz ». On retire les formules d'introduction au début
(« je cherche », « je voudrais », « où trouver », « est-ce que vous avez »…) et les formules de
politesse à la fin (« s'il vous plaît », « merci »), puis les petits mots restants au début
(« du », « de la », « un »…) sont ôtés par la normalisation de la recherche écrite.

Le texte est d'abord normalisé (minuscules, sans accents ni ponctuation : « où » → « ou »,
« j'aimerais » → « j aimerais »), les formules ci-dessous sont donc écrites sous cette forme.
"""
import re

from apps.catalog.services.normalize import MAX_QUERY_LENGTH, normalize_query
from apps.search.text.normalize import normalize_search_term

# Début de phrase, de la plus longue à la plus courte (la première qui correspond est retirée,
# et on recommence : « bonjour je cherche … »).
LEADING_PHRASES = (
    "est ce que vous avez", "est ce que vous vendez", "est ce que vous auriez",
    "est ce qu on trouve", "est ce qu il y a", "ou est ce qu on peut trouver",
    "ou est ce qu on trouve", "ou puis je trouver", "ou puis je acheter",
    "ou est ce que je peux trouver", "ou est ce que je peux acheter",
    "ou est ce que je trouve", "ou est ce que je peux avoir",
    "je suis a la recherche", "j ai besoin", "j aimerais trouver", "j aimerais avoir",
    "j aimerais acheter", "j aimerais", "je voudrais trouver", "je voudrais acheter",
    "je voudrais avoir", "je voudrais", "je veux acheter", "je veux trouver", "je veux avoir",
    "je veux", "je souhaite trouver", "je souhaite acheter", "je souhaite", "je cherche",
    "je recherche", "je dois trouver", "je dois acheter", "il me faut", "il me faudrait",
    "on cherche", "nous cherchons", "ou trouver", "ou acheter", "ou trouve t on",
    "ou trouve t il", "ou peut on trouver", "ou peut on acheter", "ou avoir",
    "trouve moi", "trouvez moi", "cherche moi", "cherchez moi", "donne moi", "donnez moi",
    "montre moi", "montrez moi", "vous avez", "vous vendez", "avez vous", "vendez vous",
    "y a t il", "il y a", "recherche", "cherche", "trouver", "bonjour", "bonsoir", "salut",
    "allo", "euh", "s il vous plait", "s il te plait", "svp", "stp",
)
# Fin de phrase.
TRAILING_PHRASES = (
    "s il vous plait", "s il te plait", "svp", "stp", "merci beaucoup", "merci",
    "pres de moi", "pour moi", "maintenant", "aujourd hui",
)


def _compile(phrases, *, leading: bool):
    ordered = sorted(phrases, key=len, reverse=True)
    body = "|".join(re.escape(phrase) for phrase in ordered)
    return re.compile(rf"^(?:{body})\b\s*" if leading else rf"\s*\b(?:{body})$")


_LEADING = _compile(LEADING_PHRASES, leading=True)
_TRAILING = _compile(TRAILING_PHRASES, leading=False)


def clean_transcript(text: str | None) -> str:
    """Terme de recherche tiré de la phrase dite ; chaîne vide s'il n'en reste rien."""
    cleaned = normalize_query((text or "")[:MAX_QUERY_LENGTH * 3])
    previous = None
    while cleaned and cleaned != previous:
        previous = cleaned
        cleaned = _LEADING.sub("", cleaned, count=1).strip()
        cleaned = _TRAILING.sub("", cleaned, count=1).strip()
    return normalize_search_term(cleaned)[:MAX_QUERY_LENGTH]
