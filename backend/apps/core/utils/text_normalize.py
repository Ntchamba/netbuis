"""Minuscules, sans accents, sans ponctuation, espaces réduits (partagé par la recherche)."""
import re
import unicodedata


def normalize_text(text: str) -> str:
    decomposed = unicodedata.normalize("NFKD", text or "")
    no_accents = "".join(c for c in decomposed if not unicodedata.combining(c))
    no_punct = re.sub(r"[^\w\s]", " ", no_accents.lower())
    return " ".join(no_punct.split())
