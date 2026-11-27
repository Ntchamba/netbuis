"""Plafond de publications actives, anti-spam (publications du jour, commentaires), compte
bloqué (T090). Les deux règles « 5 » sont indépendantes."""
from datetime import timedelta

import pytest
from django.utils import timezone

from apps.business.models import Subscription, SubscriptionStatus
from apps.core.models.platform_setting import PlatformSetting
from apps.forum.models import Comment, ContentStatus, Post
from apps.forum.tests.helpers import (
    POSTS,
    clear_cache,
    connected,
    make_post,
    merchant,
    payload,
    simple_client,
)
from tests.factories.business_factory import make_owner, make_subscription

pytestmark = pytest.mark.django_db

DAYS = timedelta(days=2)


@pytest.fixture(autouse=True)
def _cache():
    clear_cache()
    yield
    clear_cache()


def publish(profile, client):
    return client.post(POSTS, payload(profile.owner), format="json")


# --- règle 1 : 5 publications ACTIVES sans abonnement -------------------------------------


def test_sixth_active_post_without_subscription_is_refused_subscription_required():
    profile, client = merchant()
    for _ in range(5):  # publications d'il y a 2 jours : la limite du jour n'est pas en jeu
        make_post(profile, age=DAYS)
    response = publish(profile, client)
    assert response.status_code == 400
    assert response.json()["code"] == "SUBSCRIPTION_REQUIRED"
    assert Post.objects.filter(profile=profile).count() == 5


def test_fifth_post_is_accepted_and_deleting_one_frees_a_place():
    profile, client = merchant()
    for _ in range(4):
        make_post(profile, age=DAYS)
    assert publish(profile, client).status_code == 201  # la 5e passe
    assert publish(profile, client).json()["code"] == "SUBSCRIPTION_REQUIRED"
    victim = Post.objects.filter(profile=profile).first()
    assert client.delete(f"{POSTS}{victim.pk}/").status_code == 204
    assert publish(profile, client).status_code == 201


def test_hidden_and_deleted_posts_do_not_count_as_active():
    profile, client = merchant()
    for status in (ContentStatus.HIDDEN, ContentStatus.DELETED):
        for _ in range(3):
            make_post(profile, status=status, age=DAYS)
    for _ in range(4):
        make_post(profile, age=DAYS)
    assert publish(profile, client).status_code == 201


def test_subscribed_merchant_has_no_active_cap():
    profile, client = merchant()
    make_subscription(profile)
    for _ in range(8):
        make_post(profile, age=DAYS)
    assert publish(profile, client).status_code == 201


def test_expired_subscription_deletes_nothing_but_blocks_new_posts():
    profile, client = merchant()
    now = timezone.now()
    make_subscription(profile, start=now - timedelta(days=60), end=now - timedelta(days=1))
    for _ in range(7):
        make_post(profile, age=DAYS)
    assert Post.objects.filter(profile=profile, status=ContentStatus.ACTIVE).count() == 7
    reader = connected(make_owner())
    assert len(reader.get(POSTS).json()["results"]) == 7  # tout est toujours visible
    assert publish(profile, client).json()["code"] == "SUBSCRIPTION_REQUIRED"
    Subscription.objects.filter(profile=profile).update(status=SubscriptionStatus.EXPIRED)
    assert publish(profile, client).json()["code"] == "SUBSCRIPTION_REQUIRED"
    assert Post.objects.filter(profile=profile).count() == 7


def test_cap_comes_from_platform_setting():
    profile, client = merchant()
    PlatformSetting.objects.create(key="plafond_publications_non_abonne", value=2)
    clear_cache()
    for _ in range(2):
        make_post(profile, age=DAYS)
    assert publish(profile, client).json()["code"] == "SUBSCRIPTION_REQUIRED"


# --- règle 2 : 5 publications par jour (anti-spam) ---------------------------------------


def test_sixth_post_of_the_day_is_refused_even_with_subscription():
    profile, client = merchant()
    make_subscription(profile)  # pas de plafond d'actives : seule la limite du jour s'applique
    for _ in range(5):
        assert publish(profile, client).status_code == 201
    response = publish(profile, client)
    assert response.status_code == 429 and response.json()["code"] == "daily_post_limit"
    assert Post.objects.filter(profile=profile).count() == 5


def test_daily_limit_counts_deleted_posts_and_resets_after_24h():
    profile, client = merchant()
    make_subscription(profile)
    posts = [make_post(profile) for _ in range(5)]
    assert client.delete(f"{POSTS}{posts[0].pk}/").status_code == 204
    assert publish(profile, client).json()["code"] == "daily_post_limit"  # supprimée = comptée
    Post.objects.filter(pk=posts[0].pk).update(created_at=timezone.now() - timedelta(hours=25))
    assert publish(profile, client).status_code == 201


def test_the_two_rules_are_distinct_errors():
    """Non abonné, 4 actives + 1 supprimée aujourd'hui : actives < 5 mais 5 aujourd'hui ->
    limite du jour (pas SUBSCRIPTION_REQUIRED). Non abonné, 5 actives d'il y a 2 jours :
    SUBSCRIPTION_REQUIRED (pas la limite du jour)."""
    profile, client = merchant()
    for _ in range(4):
        make_post(profile)
    make_post(profile, status=ContentStatus.DELETED)
    assert publish(profile, client).json()["code"] == "daily_post_limit"
    other, other_client = merchant()
    for _ in range(5):
        make_post(other, age=DAYS)
    assert publish(other, other_client).json()["code"] == "SUBSCRIPTION_REQUIRED"


# --- commentaires : 10 par 10 minutes ------------------------------------------------------


def comment(client, post, text="Bonjour"):
    return client.post(f"{POSTS}{post.pk}/comments/", {"text": text}, format="json")


def test_any_connected_account_can_comment():
    profile, owner_client = merchant()
    post = make_post(profile)
    user, client = simple_client("Sali Abdou")
    response = comment(client, post, "Vous livrez ?")
    assert response.status_code == 201
    body = response.json()
    assert body["text"] == "Vous livrez ?" and body["is_mine"] is True
    assert body["author"] == {
        "name": "Sali A.", "initials": "SA", "photo": None, "is_business": False,
    }
    assert comment(owner_client, post, "Oui").status_code == 201  # le commerçant aussi
    assert Comment.objects.filter(post=post).count() == 2


def test_eleventh_comment_in_ten_minutes_is_refused_then_allowed_later():
    profile, _ = merchant()
    post = make_post(profile)
    user, client = simple_client()
    for i in range(10):
        assert comment(client, post, f"c{i}").status_code == 201
    response = comment(client, post, "trop")
    assert response.status_code == 429 and response.json()["code"] == "comment_rate_limit"
    assert Comment.objects.filter(author=user).count() == 10
    _, other = simple_client()
    assert comment(other, post).status_code == 201  # la limite est par compte
    Comment.objects.filter(author=user).update(created_at=timezone.now() - timedelta(minutes=11))
    assert comment(client, post, "ok").status_code == 201


def test_comment_text_rules():
    profile, _ = merchant()
    post = make_post(profile)
    _, client = simple_client()
    assert comment(client, post, "é" * 300).status_code == 201
    for bad in ("é" * 301, "", "   "):
        response = comment(client, post, bad)
        assert response.status_code == 400 and "text" in response.json()["fields"]
    html = '<img src=x onerror=alert(1)> & "'
    created = comment(client, post, html).json()
    assert created["text"] == html  # tel quel
    assert Comment.objects.get(pk=created["id"]).text == html


def test_cannot_comment_on_an_invisible_post():
    profile, _ = merchant()
    _, client = simple_client()
    for status in (ContentStatus.HIDDEN, ContentStatus.DELETED):
        post = make_post(profile, status=status)
        assert comment(client, post).status_code == 404
    assert client.post(f"{POSTS}999999/comments/", {"text": "x"}, format="json").status_code == 404


# --- compte bloqué ------------------------------------------------------------------------


def test_blocked_account_cannot_publish_nor_comment_and_its_content_is_masked():
    profile, merchant_client = merchant()
    post = make_post(profile)
    user, client = simple_client()
    assert comment(client, post).status_code == 201
    reader = connected(make_owner())
    assert reader.get(f"{POSTS}{post.pk}/").json()["comments_count"] == 1
    user.is_blocked = True
    user.save()
    # le jeton est encore valable, mais le compte est refusé
    response = comment(client, post)
    assert response.status_code == 403 and response.json()["code"] == "account_blocked"
    assert reader.get(f"{POSTS}{post.pk}/").json()["comments_count"] == 0
    assert reader.get(f"{POSTS}{post.pk}/comments/").json()["results"] == []
    profile.owner.is_blocked = True
    profile.owner.save()
    response = merchant_client.post(POSTS, payload(profile.owner), format="json")
    assert response.status_code == 403 and response.json()["code"] == "account_blocked"
    assert reader.get(f"{POSTS}{post.pk}/").status_code == 404
