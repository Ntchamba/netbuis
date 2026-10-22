"""Filtre anti-spam et masquage automatique (T094)."""
from datetime import timedelta

import pytest
from django.utils import timezone

from apps.forum.models import Comment, ContentStatus, ForbiddenWord, Post, Report
from apps.forum.services import report_service, spam_filter
from apps.forum.tests.helpers import (
    MINE,
    POSTS,
    clear_cache,
    connected,
    make_comment,
    make_post,
    merchant,
    payload,
    simple_client,
)
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _cache():
    clear_cache()
    yield
    clear_cache()


def comment(client, post, text):
    return client.post(f"{POSTS}{post.pk}/comments/", {"text": text}, format="json")


def publish(profile, client, caption):
    return client.post(POSTS, payload(profile.owner, caption=caption), format="json")


def report(client, target_type, target_id, reason="spam"):
    return client.post(
        "/api/reports/", {"target_type": target_type, "target_id": target_id, "reason": reason},
        format="json",
    )


def assert_spam(response):
    assert response.status_code == 400, response.content
    assert response.json()["code"] == "spam_detected"
    assert "message" in response.json()


# --- normalisation -------------------------------------------------------------------------


def test_normalize_removes_accents_case_punctuation_and_invisible_characters():
    assert spam_filter.normalize("  GRATUIT!!  Café​  ") == "gratuit cafe"
    assert spam_filter.normalize("a-b_c") == "a b c"
    assert spam_filter.normalize(None) == ""


# --- mots interdits ------------------------------------------------------------------------


def test_forbidden_word_refuses_comment_and_caption_ignoring_case_and_accents():
    ForbiddenWord.objects.create(word="cadeau")
    profile, owner_client = merchant()
    post = make_post(profile)
    _, client = simple_client()
    for text in ("Un CADÉAU pour vous", "cadeau", "Super.cadeau!", "ca​deau gratuit"):
        assert_spam(comment(client, post, text))
        assert_spam(publish(profile, owner_client, text))
    assert Comment.objects.count() == 0 and Post.objects.count() == 1


def test_forbidden_word_matches_whole_words_and_phrases_only():
    ForbiddenWord.objects.create(word="cadeau")
    ForbiddenWord.objects.create(word="gagner argent")
    profile, owner_client = merchant()
    post = make_post(profile)
    _, client = simple_client()
    assert comment(client, post, "Des cadeaux pour tous").status_code == 201  # mot entier
    assert comment(client, post, "Pour gagner du bon argent").status_code == 201
    assert_spam(comment(client, post, "Venez GAGNER   argent vite"))
    assert publish(profile, owner_client, "Riz parfumé disponible").status_code == 201


# --- liens ---------------------------------------------------------------------------------


def test_links_up_to_the_limit_are_accepted():
    profile, _ = merchant()
    post = make_post(profile)
    _, client = simple_client()
    assert comment(client, post, "Voir https://exemple.org/riz").status_code == 201
    assert comment(client, post, "Voir www.exemple.org et https://autre.cm/prix").status_code == 201


def test_too_many_links_or_a_repeated_link_is_refused():
    profile, owner_client = merchant()
    post = make_post(profile)
    _, client = simple_client()
    three = "https://a.org/1 https://b.org/2 https://c.org/3"
    assert_spam(comment(client, post, three))
    assert_spam(comment(client, post, "Voir https://a.org/x puis HTTP://www.A.org/x/"))
    assert_spam(comment(client, post, "wa.me/237600000001 ou wa.me/237600000001"))
    assert_spam(publish(profile, owner_client, three))
    assert Comment.objects.count() == 0


# --- doublons ------------------------------------------------------------------------------


def test_same_comment_again_by_same_account_is_refused_within_the_window_only():
    profile, _ = merchant()
    post = make_post(profile)
    author, client = simple_client()
    assert comment(client, post, "Encore disponible ?").status_code == 201
    assert_spam(comment(client, post, "encore  DISPONIBLE ?!"))  # même texte normalisé
    assert comment(client, post, "Quel est le prix ?").status_code == 201  # autre texte
    _, other = simple_client()
    assert comment(other, post, "Encore disponible ?").status_code == 201  # autre compte
    Comment.objects.filter(author=author, text="Encore disponible ?").update(
        created_at=timezone.now() - timedelta(minutes=11))
    assert comment(client, post, "Encore disponible ?").status_code == 201  # hors fenêtre


def test_same_caption_again_by_same_business_is_refused_but_empty_captions_are_not():
    profile, client = merchant()
    assert publish(profile, client, "Promo sur le riz").status_code == 201
    assert_spam(publish(profile, client, "promo sur le RIZ"))
    other_profile, other_client = merchant()
    assert publish(other_profile, other_client, "Promo sur le riz").status_code == 201
    assert publish(profile, client, "").status_code == 201
    assert publish(profile, client, "").status_code == 201
    assert Post.objects.filter(profile=profile).count() == 3


# --- masquage automatique ------------------------------------------------------------------


def test_post_is_hidden_at_the_third_distinct_reporter_not_before():
    profile, owner_client = merchant()
    post = make_post(profile)
    clients = [simple_client()[1] for _ in range(3)]
    for client in clients[:2]:
        assert report(client, "post", post.pk).status_code == 201
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE
    assert report(clients[2], "post", post.pk, "arnaque").status_code == 201
    post.refresh_from_db()
    assert post.status == ContentStatus.HIDDEN
    # disparu du fil, du détail et des commentaires pour un autre compte
    _, other = simple_client()
    assert post.pk not in [p["id"] for p in other.get(POSTS).json()["results"]]
    assert other.get(f"{POSTS}{post.pk}/").status_code == 404
    assert other.get(f"{POSTS}{post.pk}/comments/").status_code == 404
    # le propriétaire le voit dans /mine/ avec le statut masque
    mine = {p["id"]: p["status"] for p in owner_client.get(MINE).json()["results"]}
    assert mine[post.pk] == "masque"


def test_three_reports_by_the_same_account_never_hide():
    profile, _ = merchant()
    post = make_post(profile)
    _, client = simple_client()
    assert report(client, "post", post.pk, "spam").status_code == 201
    assert report(client, "post", post.pk, "arnaque").status_code == 409
    assert report(client, "post", post.pk, "autre").status_code == 409
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE and Report.objects.count() == 1


def test_comment_is_hidden_at_the_third_distinct_reporter_and_leaves_the_list():
    profile, _ = merchant()
    post = make_post(profile)
    author, author_client = simple_client()
    target = make_comment(post, author, "Message douteux")
    keep = make_comment(post, make_owner(), "Message normal")
    clients = [simple_client()[1] for _ in range(3)]
    for client in clients[:2]:
        report(client, "comment", target.pk)
    target.refresh_from_db()
    assert target.status == ContentStatus.ACTIVE
    report(clients[2], "comment", target.pk)
    target.refresh_from_db()
    assert target.status == ContentStatus.HIDDEN
    _, other = simple_client()
    ids = [c["id"] for c in other.get(f"{POSTS}{post.pk}/comments/").json()["results"]]
    assert ids == [keep.pk]
    assert other.get(f"{POSTS}{post.pk}/").json()["comments_count"] == 1
    assert author_client.get(f"{POSTS}{post.pk}/comments/").status_code == 200


def test_a_reported_business_is_never_hidden_automatically():
    profile, _ = merchant()
    make_post(profile)
    for _ in range(4):
        assert report(simple_client()[1], "business", profile.pk).status_code == 201
    profile.refresh_from_db()
    assert profile.status == "actif"
    assert Post.objects.get(profile=profile).status == ContentStatus.ACTIVE
    _, other = simple_client()
    assert len(other.get(POSTS).json()["results"]) == 1


def test_reports_of_blocked_or_deleted_accounts_do_not_count():
    profile, _ = merchant()
    post = make_post(profile)
    blocked, deleted = make_owner(is_blocked=True), make_owner(is_deleted=True)
    for reporter in (blocked, deleted, make_owner()):
        Report.objects.create(reporter=reporter, target_type="post", post=post, reason="spam")
    assert report_service.distinct_valid_reporters("post", post) == 1
    assert report(simple_client()[1], "post", post.pk).status_code == 201  # 2 comptes valides
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE
    assert report(simple_client()[1], "post", post.pk).status_code == 201  # 3 comptes valides
    post.refresh_from_db()
    assert post.status == ContentStatus.HIDDEN


def test_after_a_restore_only_new_reports_count_and_deleted_content_is_not_revived():
    profile, _ = merchant()
    post = make_post(profile)
    for _ in range(2):
        Report.objects.create(reporter=make_owner(), target_type="post", post=post,
                              reason="spam")
    Post.objects.filter(pk=post.pk).update(
        status=ContentStatus.ACTIVE, reports_reset_at=timezone.now())  # restauré par un admin
    for _ in range(2):  # 2 anciens + 2 nouveaux = 4 signalements, mais 2 comptent
        assert report(simple_client()[1], "post", post.pk).status_code == 201
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE
    assert report(simple_client()[1], "post", post.pk).status_code == 201
    post.refresh_from_db()
    assert post.status == ContentStatus.HIDDEN
    # un contenu supprimé n'est jamais « remasqué » : il n'est plus signalable (404)
    Post.objects.filter(pk=post.pk).update(status=ContentStatus.DELETED)
    assert report(connected(make_owner()), "post", post.pk).status_code == 404
    post.refresh_from_db()
    assert post.status == ContentStatus.DELETED
