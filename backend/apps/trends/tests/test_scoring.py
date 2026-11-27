"""Seuil et classement (fonctions pures)."""
from apps.trends.services.scoring import MAX_ENTRIES, Candidate, passes_threshold, rank


def cand(key, hits, accounts, label=None):
    return Candidate(key=key, hits=hits, accounts=accounts, label=label or f"p{key}")


def test_seuil_5_recherches_3_comptes():
    assert passes_threshold(5, 3, min_hits=5, min_accounts=3)
    assert not passes_threshold(4, 3, min_hits=5, min_accounts=3)  # trop peu de recherches
    assert not passes_threshold(9, 2, min_hits=5, min_accounts=3)  # trop peu de comptes


def test_classement_trie_et_coupe():
    items = [cand(i, 5 + i, 3) for i in range(15)] + [cand(99, 50, 1)]
    ranked = rank(items, min_hits=5, min_accounts=3)
    assert len(ranked) == MAX_ENTRIES
    assert [c.key for c in ranked][:2] == [14, 13]
    assert 99 not in [c.key for c in ranked]


def test_egalite_departagee_par_comptes_puis_nom():
    ranked = rank([cand(1, 6, 3, "b"), cand(2, 6, 4, "z"), cand(3, 6, 3, "a")],
                  min_hits=5, min_accounts=3)
    assert [c.key for c in ranked] == [2, 3, 1]
