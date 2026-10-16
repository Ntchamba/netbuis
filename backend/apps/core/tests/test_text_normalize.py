from apps.core.utils.text_normalize import normalize_text


def test_minuscules_sans_accents_ni_ponctuation():
    assert normalize_text("  Crème   BRÛLÉE, à Yaoundé ! ") == "creme brulee a yaounde"


def test_texte_vide():
    assert normalize_text("") == ""
    assert normalize_text(None) == ""
