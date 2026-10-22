"""Modération du forum côté administration (T094) : file, actions, audit, droits, mots interdits.
Numéros de test issus des fabriques (jamais un vrai numéro)."""
import pytest
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.test import APIClient

from apps.admin_panel.models import AuditAction, AuditLog
from apps.forum.models import Comment, ContentStatus, ForbiddenWord, Post, Report
from apps.forum.tests.helpers import MINE, POSTS, connected, make_comment, make_post, merchant
from tests.factories.business_factory import make_owner

from ._t074 import COMPLET, VALIDATEUR

pytestmark = pytest.mark.django_db

REPORTS = "/api/admin/reports/"
WORDS = "/api/admin/forbidden-words/"


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def admin_in(group, **extra):
    admin = make_owner(is_admin=True, **extra)
    admin.groups.add(Group.objects.get(name=group))
    return admin


@pytest.fixture
def admin():
    return admin_in(COMPLET, name="Chef Modération")


@pytest.fixture
def api(admin):
    return connected(admin)


def flag(target, times=1, reason="spam", names=()):
    """`times` signalements de comptes distincts sur un Post, un Comment ou un BusinessProfile."""
    kind = {Post: "post", Comment: "comment"}.get(type(target), "business")
    reporters = []
    for i in range(times):
        reporter = make_owner(name=names[i] if i < len(names) else f"Signalant {i}")
        Report.objects.create(reporter=reporter, target_type=kind, reason=reason,
                              **{kind: target})
        reporters.append(reporter)
    return reporters


def url(kind, pk, action):
    return f"{REPORTS}{kind}/{pk}/{action}/"


def audit_for(obj):
    return AuditLog.objects.filter(
        action=AuditAction.MODERATION_CONTENU, target_id=obj.pk,
        target_type=obj._meta.label_lower)


# --- droits ---------------------------------------------------------------------------------


def test_permission_only_for_the_full_administrator_group():
    from django.contrib.auth.models import Permission

    perm = Permission.objects.get(codename="peut_moderer_contenu")
    assert set(perm.group_set.values_list("name", flat=True)) == {COMPLET}
    assert not Group.objects.get(name=VALIDATEUR).permissions.filter(
        codename="peut_moderer_contenu").exists()


def test_rights_matrix_on_every_route():
    profile, _ = merchant()
    post = make_post(profile)
    flag(post)
    word = ForbiddenWord.objects.create(word="mot")
    simple = connected(make_owner())
    sans_groupe = connected(make_owner(is_admin=True))
    validateur = connected(admin_in(VALIDATEUR))
    calls = [
        ("get", REPORTS, None), ("post", url("post", post.pk, "hide"), {}),
        ("post", url("post", post.pk, "restore"), {}),
        ("post", url("post", post.pk, "delete"), {"reason": "x"}),
        ("get", WORDS, None), ("post", WORDS, {"word": "zzz"}),
        ("delete", f"{WORDS}{word.pk}/", None),
    ]
    for method, path, body in calls:
        kw = {"format": "json"} if body is not None else {}
        args = [body] if body is not None else []
        assert getattr(APIClient(), method)(path, *args, **kw).status_code == 401, path
        for client in (simple, sans_groupe, validateur):
            assert getattr(client, method)(path, *args, **kw).status_code == 403, path
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE and not AuditLog.objects.filter(
        action=AuditAction.MODERATION_CONTENU).exists()


def test_blocked_full_administrator_is_refused():
    admin = admin_in(COMPLET, is_blocked=True)
    assert connected(admin).get(REPORTS).status_code in (401, 403)


# --- file des signalements ------------------------------------------------------------------


def test_queue_row_has_aggregates_masked_numbers_and_no_reporter_identity(api):
    profile, _ = merchant(name="Boutique Soleil")
    post = make_post(profile, caption="Appelez le 655012345 pour " + "x" * 200)
    reporters = flag(post, 2, "spam", names=("Awa Secrète", "Bako Caché"))
    reporters += flag(post, 1, "arnaque", names=("Cathy Cachée",))
    response = api.get(REPORTS)
    assert response.status_code == 200 and "no-store" in response["Cache-Control"]
    body = response.json()
    assert body["count"] == 1
    row = body["results"][0]
    assert row["target_type"] == "post" and row["target_id"] == post.pk
    assert row["content_status"] == "actif" and row["media_type"] == "image"
    assert row["reporters_count"] == 3
    assert {r["reason"]: r["count"] for r in row["reasons"]} == {"spam": 2, "arnaque": 1}
    assert row["business_name"] == "Boutique Soleil"
    assert row["author_phone_masked"].startswith("+237 6•• ")
    assert len(row["preview"]) <= 141 and row["preview"].endswith("…")
    assert "655012345" not in response.content.decode()
    text = response.content.decode()
    assert profile.owner.phone.lstrip("+") not in text and profile.owner.phone not in text
    for reporter in reporters:
        assert reporter.phone not in text and reporter.name not in text
        assert reporter.phone.lstrip("+") not in text
    assert "reporter" not in row and "reporters" not in row


def test_queue_covers_posts_comments_and_businesses_and_filters(api):
    profile, _ = merchant()
    post = make_post(profile, status=ContentStatus.HIDDEN)
    comment = make_comment(make_post(profile), make_owner(name="Auteur"), "Texte du commentaire")
    deleted = make_post(profile, status=ContentStatus.DELETED)
    flag(post, 3)
    flag(comment, 1)
    flag(deleted, 1)
    flag(profile, 1)
    flag(make_post(profile), 0)  # jamais signalé : absent
    rows = api.get(REPORTS).json()["results"]
    assert {(r["target_type"], r["target_id"]) for r in rows} == {
        ("post", post.pk), ("comment", comment.pk), ("post", deleted.pk),
        ("business", profile.pk)}
    comment_row = next(r for r in rows if r["target_type"] == "comment")
    assert comment_row["preview"] == "Texte du commentaire"
    assert comment_row["post_id"] == comment.post_id and comment_row["author_name"] == "Auteur"

    def ids(query):
        data = api.get(f"{REPORTS}?{query}").json()["results"]
        return {(r["target_type"], r["target_id"]) for r in data}

    assert ids("status=masque") == {("post", post.pk)}
    assert ids("status=supprime") == {("post", deleted.pk)}
    assert ids("type=comment") == {("comment", comment.pk)}
    assert ids("type=business") == {("business", profile.pk)}
    assert ids("type=post&status=actif") == set()
    assert api.get(f"{REPORTS}?status=zzz").json()["code"] == "invalid_filter"
    assert api.get(f"{REPORTS}?type=zzz").status_code == 400


def test_queue_is_paginated_and_most_recently_reported_first(api):
    profile, _ = merchant()
    posts = [make_post(profile, caption=f"p{i}") for i in range(3)]
    for i, post in enumerate(posts):
        flag(post, 1)
        Report.objects.filter(post=post).update(
            created_at=timezone.now() - timezone.timedelta(hours=3 - i))
    data = api.get(f"{REPORTS}?page_size=2").json()
    assert data["count"] == 3 and len(data["results"]) == 2 and data["next"]
    assert [r["target_id"] for r in data["results"]] == [posts[2].pk, posts[1].pk]


def test_queue_query_count_does_not_grow_with_the_rows(api):
    profile, _ = merchant()

    def count_queries():
        with CaptureQueriesContext(connection) as ctx:
            assert api.get(REPORTS).status_code == 200
        return len(ctx)

    flag(make_post(profile), 2)
    flag(make_comment(make_post(profile), make_owner()), 2)
    flag(profile, 1)
    count_queries()  # échauffement (caches de réglages, etc.)
    small = count_queries()
    for _ in range(10):
        flag(make_post(profile), 2, "arnaque")
        flag(make_comment(make_post(profile), make_owner()), 1)
    Report.objects.filter(business=profile).update(created_at=timezone.now())  # reste en page 1
    assert count_queries() == small


# --- actions --------------------------------------------------------------------------------


def test_hide_then_restore_a_post_with_audit_and_visibility(api, admin):
    profile, owner_client = merchant()
    post = make_post(profile)
    flag(post, 1)
    other = connected(make_owner())
    response = api.post(url("post", post.pk, "hide"), {}, format="json")
    assert response.status_code == 200 and "no-store" in response["Cache-Control"]
    assert response.json()["content_status"] == "masque"
    post.refresh_from_db()
    assert post.status == ContentStatus.HIDDEN
    assert post.pk not in [p["id"] for p in other.get(POSTS).json()["results"]]
    assert other.get(f"{POSTS}{post.pk}/").status_code == 404
    mine = {p["id"]: p["status"] for p in owner_client.get(MINE).json()["results"]}
    assert mine[post.pk] == "masque"
    entry = audit_for(post).get()
    assert entry.admin == admin and entry.reason == "masquer"

    response = api.post(url("post", post.pk, "restore"), {"reason": "Faux positif"},
                        format="json")
    assert response.status_code == 200 and response.json()["content_status"] == "actif"
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE and post.reports_reset_at is not None
    assert other.get(f"{POSTS}{post.pk}/").status_code == 200
    assert list(audit_for(post).values_list("reason", flat=True).order_by("id")) == [
        "masquer", "restaurer : Faux positif"]
    assert Report.objects.filter(post=post).count() == 1  # les signalements restent


def test_restored_content_is_hidden_again_only_by_three_new_distinct_reporters(api):
    profile, _ = merchant()
    post = make_post(profile)
    flag(post, 3)
    Post.objects.filter(pk=post.pk).update(status=ContentStatus.HIDDEN)
    assert api.post(url("post", post.pk, "restore"), {}, format="json").status_code == 200
    for _ in range(2):
        reporter = make_owner()
        assert connected(reporter).post(
            "/api/reports/", {"target_type": "post", "target_id": post.pk, "reason": "spam"},
            format="json").status_code == 201
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE  # 5 signalements au total, 2 comptés
    assert connected(make_owner()).post(
        "/api/reports/", {"target_type": "post", "target_id": post.pk, "reason": "spam"},
        format="json").status_code == 201
    post.refresh_from_db()
    assert post.status == ContentStatus.HIDDEN


def test_delete_requires_a_reason_and_writes_nothing_without_one(api):
    profile, _ = merchant()
    post = make_post(profile)
    flag(post, 1)
    for body in ({}, {"reason": ""}, {"reason": "   "}, None):
        kw = {"format": "json"} if body is not None else {}
        response = api.post(url("post", post.pk, "delete"), *([body] if body is not None else []),
                            **kw)
        assert response.status_code == 400 and response.json()["code"] == "reason_required", body
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE and not audit_for(post).exists()


def test_delete_a_comment_with_a_reason_is_soft_and_audited(api, admin):
    profile, _ = merchant()
    post = make_post(profile)
    comment = make_comment(post, make_owner(), "Insulte")
    keep = make_comment(post, make_owner(), "Merci")
    flag(comment, 1)
    response = api.post(url("comment", comment.pk, "delete"), {"reason": "Insulte grave"},
                        format="json")
    assert response.status_code == 200 and response.json()["content_status"] == "supprime"
    assert Comment.objects.filter(pk=comment.pk).exists()  # suppression douce
    viewer = connected(make_owner())
    ids = [c["id"] for c in viewer.get(f"{POSTS}{post.pk}/comments/").json()["results"]]
    assert ids == [keep.pk]
    entry = audit_for(comment).get()
    assert entry.admin == admin and entry.reason == "supprimer : Insulte grave"
    assert entry.target_type == "forum.comment"


def test_audit_failure_rolls_the_status_change_back(api, monkeypatch):
    from apps.admin_panel.services import moderation_service

    profile, _ = merchant()
    post = make_post(profile)
    flag(post, 1)

    def boom(*args, **kwargs):
        raise RuntimeError("audit indisponible")

    monkeypatch.setattr(moderation_service, "record_action", boom)
    client = connected(admin_in(COMPLET))
    client.raise_request_exception = False
    assert client.post(url("post", post.pk, "hide"), {}, format="json").status_code == 500
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE


def test_invalid_transitions_give_409(api):
    profile, _ = merchant()
    post = make_post(profile)
    flag(post, 1)
    assert api.post(url("post", post.pk, "restore"), {}, format="json").json()[
        "code"] == "invalid_state"  # déjà actif
    assert api.post(url("post", post.pk, "hide"), {}, format="json").status_code == 200
    assert api.post(url("post", post.pk, "hide"), {}, format="json").status_code == 409
    assert api.post(url("post", post.pk, "delete"), {"reason": "x"},
                    format="json").status_code == 200  # masqué -> supprimé
    for action, body in (("delete", {"reason": "x"}), ("restore", {}), ("hide", {})):
        response = api.post(url("post", post.pk, action), body, format="json")
        assert response.status_code == 409 and response.json()["code"] == "invalid_state"
    post.refresh_from_db()
    assert post.status == ContentStatus.DELETED
    assert audit_for(post).count() == 2  # masquer + supprimer seulement


def test_not_found_and_unsupported_targets(api):
    profile, _ = merchant()
    unreported = make_post(profile)
    flag(profile, 1)
    for action in ("hide", "restore", "delete"):
        body = {"reason": "x"}
        assert api.post(url("post", 999999, action), body, format="json").status_code == 404
        assert api.post(url("comment", 999999, action), body, format="json").status_code == 404
        assert api.post(url("post", unreported.pk, action), body,
                        format="json").status_code == 404  # jamais signalé
        assert api.post(url("zzz", 1, action), body, format="json").status_code == 404
        response = api.post(url("business", profile.pk, action), body, format="json")
        assert response.status_code == 400 and response.json()["code"] == "unsupported_target"
    profile.refresh_from_db()
    assert profile.status == "actif" and not AuditLog.objects.filter(
        action=AuditAction.MODERATION_CONTENU).exists()


# --- mots interdits -------------------------------------------------------------------------


def test_forbidden_words_crud_with_audit_and_effect_on_the_filter(api, admin):
    response = api.post(WORDS, {"word": "  GRATUIT ÉNORME "}, format="json")
    assert response.status_code == 201 and "no-store" in response["Cache-Control"]
    assert response.json()["word"] == "gratuit enorme"
    word = ForbiddenWord.objects.get()
    assert audit_for(word).get().admin == admin
    assert api.post(WORDS, {"word": "Gratuit Enorme"}, format="json").json()[
        "code"] == "word_exists"
    for bad in ({}, {"word": ""}, {"word": "a"}, {"word": "!!"}, {"word": "x" * 61}):
        assert api.post(WORDS, bad, format="json").status_code == 400, bad
    listing = api.get(WORDS).json()
    assert listing["count"] == 1 and listing["results"][0]["word"] == "gratuit enorme"

    profile, _ = merchant()
    post = make_post(profile)
    commenter = connected(make_owner())
    refused = commenter.post(f"{POSTS}{post.pk}/comments/",
                             {"text": "C'est GRATUIT, énorme !"}, format="json")
    assert refused.status_code == 400 and refused.json()["code"] == "spam_detected"

    assert api.delete(f"{WORDS}{word.pk}/").status_code == 204
    assert api.delete(f"{WORDS}{word.pk}/").status_code == 404
    assert not ForbiddenWord.objects.exists()
    assert AuditLog.objects.filter(
        action=AuditAction.MODERATION_CONTENU, reason="mot interdit retiré").count() == 1
    assert commenter.post(f"{POSTS}{post.pk}/comments/",
                          {"text": "C'est GRATUIT, énorme !"}, format="json").status_code == 201
