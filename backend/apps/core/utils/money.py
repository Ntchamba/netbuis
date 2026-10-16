"""Montants FCFA (XAF) : toujours des entiers, jamais de flottants."""


def to_fcfa(amount) -> int:
    """Convertit en entier FCFA ; refuse les décimales et les négatifs."""
    if isinstance(amount, bool) or int(amount) != amount or amount < 0:
        raise ValueError("Montant FCFA invalide : entier positif attendu.")
    return int(amount)
