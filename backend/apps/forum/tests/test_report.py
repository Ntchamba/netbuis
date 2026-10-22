"""Signalements (T090) : motifs, unicité, exclusion côté serveur, alias, confidentialité."""
import pytest
from django.db import IntegrityError, transaction

from apps.forum.models import Report
from apps.forum.tests.helpers import (
    POSTS,
    REPORTS,
    clear_cache,
    connected,
    make_comment,
    make_post,
    merchant,
    simple_client,
)
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _cache():
    clear_cache()
    yield
    clear_cache()


def report(client, target_type, target_id, reason="spam"):
    return client.post(
        REPORTS, {"target_type": target_type, "target_id": target_id, "reason": reason},
        format="json",
    )


def test_report_post_comment_and_business_succeeds():
    profile, _ = merchant()
    post = make_post(profile)
    comment = make_comment(post, make_owner(name="Autre Compte"))
    user, client = simple_client()
    for target_type, target_id in (
        ("post", post.pk), ("comment", comment.pk), ("business", profile.pk),
    ):
        response = report(client, target_type, target_id, "arnaque")
        assert response.status_code == 201
        assert response.json() == {
            "target_type": target_type, "target_id": target_id, "reason": "arnaque",
        }
    assert Report.objects.filter(reporter=user).count() == 3


def test_response_never_reveals_the_reporter():
    profile, _ = merchant()
    post = make_post(profile)
    user, client = simple_client("Sali Abdou")
    body = report(client, "post", post.pk).content.decode()
    assert "reporter" not in body and "Sali" not in body and user.phone.lstrip("+") not in body
    for url in (POSTS, f"{POSTS}{post.pk}/"):
        text = connected(profile.owner).get(url).content.decode()
        assert "reporter" not in text and "report" not in text.lower()


def test_four_reasons_only():
    profile, _ = merchant()
    post = make_post(profile)
    _, client = simple_client()
    for bad in ("harcèlement", "", "SPAM", None):
        response = report(client, "post", post.pk, bad)
        assert response.status_code == 400 and "reason" in response.json()["fields"]
    assert report(client, "livre", post.pk).status_code == 400
    assert Report.objects.count() == 0
    for reason in ("spam", "arnaque", "contenu_inapproprie", "autre"):
        other_post = make_post(profile)
        assert report(client, "post", other_post.pk, reason).status_code == 201


def test_one_report_per_account_and_target():
    profile, _ = merchant()
    post = make_post(profile)
    _, client = simple_client()
    assert report(client, "post", post.pk, "spam").status_code == 201
    again = report(client, "post", post.pk, "arnaque")
    assert again.status_code == 409 and again.json()["code"] == "already_reported"
    assert Report.objects.count() == 1
    _, other = simple_client()
    assert report(other, "post", post.pk).status_code == 201  # un autre compte peut signaler
    # même règle pour un commerce
    assert report(client, "business", profile.pk).status_code == 201
    assert report(client, "business", profile.pk).status_code == 409


def test_database_enforces_uniqueness_and_single_target():
    profile, _ = merchant()
    post = make_post(profile)
    user = make_owner()
    Report.objects.create(reporter=user, target_type="post", post=post, reason="spam")
    with pytest.raises(IntegrityError), transaction.atomic():
        Report.objects.create(reporter=user, target_type="post", post=post, reason="autre")
    with pytest.raises(IntegrityError), transaction.atomic():  # deux cibles à la fois
        Report.objects.create(
            reporter=make_owner(), target_type="post", post=post, business=profile, reason="spam"
        )
    with pytest.raises(IntegrityError), transaction.atomic():  # aucune cible
        Report.objects.create(reporter=make_owner(), target_type="post", reason="spam")


def test_cannot_report_own_content_or_invisible_targets():
    profile, owner_client = merchant()
    post = make_post(profile)
    own_comment = make_comment(post, profile.owner)
    assert report(owner_client, "post", post.pk).json()["code"] == "own_content"
    assert report(owner_client, "comment", own_comment.pk).json()["code"] == "own_content"
    assert report(owner_client, "business", profile.pk).json()["code"] == "own_content"
    _, client = simple_client()
    hidden = make_post(profile, status="masque")
    assert report(client, "post", hidden.pk).status_code == 404
    assert report(client, "post", 999999).status_code == 404
    assert report(client, "business", 999999).status_code == 404
    pending, _ = merchant(status="en_attente_validation")
    assert report(client, "business", pending.pk).status_code == 404
    assert Report.objects.count() == 0


def test_requires_login_and_unblocked_account():
    from rest_framework.test import APIClient

    assert APIClient().post(REPORTS, {}, format="json").status_code == 401
    profile, _ = merchant()
    post = make_post(profile)
    user, client = simple_client()
    user.is_blocked = True
    user.save()
    assert report(client, "post", post.pk).status_code == 403


def test_reported_post_is_excluded_from_the_reporters_feed_only():
    profile, _ = merchant()
    kept = make_post(profile, "reste")
    gone = make_post(profile, "signalée")
    _, client = simple_client()
    _, other = simple_client()
    assert report(client, "post", gone.pk).status_code == 201
    assert [r["id"] for r in client.get(POSTS).json()["results"]] == [kept.pk]
    assert client.get(f"{POSTS}{gone.pk}/").status_code == 404
    assert {r["id"] for r in other.get(POSTS).json()["results"]} == {kept.pk, gone.pk}
    assert other.get(f"{POSTS}{gone.pk}/").status_code == 200


def test_reported_comment_is_excluded_from_the_reporters_comments_and_count():
    profile, _ = merchant()
    post = make_post(profile)
    bad = make_comment(post, make_owner(name="Mauvais Plan"), "pub")
    good = make_comment(post, make_owner(name="Bon Client"), "merci")
    _, client = simple_client()
    _, other = simple_client()
    assert report(client, "comment", bad.pk).status_code == 201
    mine = client.get(f"{POSTS}{post.pk}/").json()
    assert [c["id"] for c in mine["comments"]["results"]] == [good.pk]
    assert mine["comments_count"] == 1
    assert [c["id"] for c in client.get(f"{POSTS}{post.pk}/comments/").json()["results"]] == [
        good.pk
    ]
    theirs = other.get(f"{POSTS}{post.pk}/").json()
    assert theirs["comments_count"] == 2 and len(theirs["comments"]["results"]) == 2


def test_reported_business_posts_leave_the_reporters_feed():
    profile, _ = merchant()
    other_profile, _ = merchant()
    make_post(profile)
    survivor = make_post(other_profile)
    _, client = simple_client()
    assert report(client, "business", profile.pk).status_code == 201
    assert [r["id"] for r in client.get(POSTS).json()["results"]] == [survivor.pk]


def test_alias_on_post_route_is_the_same_report():
    profile, _ = merchant()
    post = make_post(profile)
    user, client = simple_client()
    url = f"{POSTS}{post.pk}/report/"
    response = client.post(url, {"reason": "contenu_inapproprie"}, format="json")
    assert response.status_code == 201
    assert response.json() == {
        "target_type": "post", "target_id": post.pk, "reason": "contenu_inapproprie",
    }
    report_row = Report.objects.get()
    assert report_row.reporter == user and report_row.post == post
    assert client.post(url, {"reason": "spam"}, format="json").status_code == 409
    assert report(client, "post", post.pk).status_code == 409  # même contrainte que /api/reports/
    assert client.post(url, {"reason": "nimporte"}, format="json").status_code == 400
    assert client.post(f"{POSTS}999999/report/", {"reason": "spam"}, format="json"
                       ).status_code == 404
