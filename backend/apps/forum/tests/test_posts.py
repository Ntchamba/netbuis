"""Publications (T090) : création, fil, détail, suppression, mes publications, sécurité."""
import re
from datetime import timedelta

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext

from apps.business.models import BusinessStatus, Offer
from apps.forum.models import ContentStatus, Post
from apps.forum.tests.helpers import (
    HOUR,
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
from tests.factories.business_factory import make_owner, make_profile, make_subscription
from tests.factories.storage_factory import make_stored_file
from tests.factories.zone_factory import make_maroua_chain, make_zone

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _cache():
    clear_cache()
    yield
    clear_cache()


# --- création ---------------------------------------------------------------------------


def test_active_merchant_publishes_image():
    profile, client = merchant()
    response = client.post(POSTS, payload(profile.owner), format="json")
    assert response.status_code == 201
    body = response.json()
    assert body["media_type"] == "image" and body["caption"].startswith("Nouveau lot de riz")
    assert body["author"]["business_id"] == profile.pk and body["author"]["name"] == profile.name
    assert body["author"]["zone"]["name"] == profile.zone.name
    assert body["comments_count"] == 0 and body["is_mine"] is True and body["offer"] is None
    assert Post.objects.get(pk=body["id"]).profile == profile


def test_video_key_gives_video_type():
    profile, client = merchant()
    media = make_stored_file(profile.owner, "post_video", "video/mp4")
    response = client.post(POSTS, {"media": media, "caption": "Visite"}, format="json")
    assert response.status_code == 201 and response.json()["media_type"] == "video"


def test_pending_rejected_and_simple_accounts_cannot_publish():
    for status in (BusinessStatus.PENDING, BusinessStatus.REJECTED):
        profile, client = merchant(status=status)
        response = client.post(POSTS, payload(profile.owner), format="json")
        assert response.status_code == 403 and response.json()["code"] == "business_not_active"
    user, client = simple_client()
    response = client.post(POSTS, payload(user), format="json")
    assert response.status_code == 404 and response.json()["code"] == "no_business"
    assert Post.objects.count() == 0


def test_anonymous_is_refused_everywhere():
    from rest_framework.test import APIClient

    client = APIClient()
    assert client.get(POSTS).status_code == 401
    assert client.post(POSTS, {}, format="json").status_code == 401
    assert client.get(MINE).status_code == 401


def test_profile_id_in_body_is_ignored_post_goes_to_own_profile():
    other = make_profile(status=BusinessStatus.ACTIVE)
    profile, client = merchant()
    body = payload(profile.owner, profile=other.pk, profile_id=other.pk)
    response = client.post(POSTS, body, format="json")
    assert response.status_code == 201
    assert Post.objects.get(pk=response.json()["id"]).profile == profile
    assert not Post.objects.filter(profile=other).exists()


def test_media_must_be_a_stored_file_of_the_account():
    profile, client = merchant()
    stranger = make_owner()
    cases = [
        make_stored_file(stranger, "post_image"),                    # clé d'un autre compte
        f"u{profile.owner.pk}/post_image/{'a' * 32}.jpg",             # fichier jamais envoyé
        make_stored_file(profile.owner, "photo"),                    # mauvaise nature
        "../../etc/passwd", "https://exemple.org/x.jpg", "",
    ]
    for media in cases:
        response = client.post(POSTS, {"media": media, "caption": "x"}, format="json")
        assert response.status_code == 400, media
        assert response.json()["code"] == "invalid" and "media" in response.json()["fields"]
    assert client.post(POSTS, {"caption": "x"}, format="json").status_code == 400
    assert Post.objects.count() == 0


def test_caption_limit_500():
    profile, client = merchant()
    ok = client.post(POSTS, payload(profile.owner, caption="é" * 500), format="json")
    assert ok.status_code == 201
    too_long = client.post(POSTS, payload(profile.owner, caption="é" * 501), format="json")
    assert too_long.status_code == 400 and "caption" in too_long.json()["fields"]


def test_text_is_stored_and_returned_as_is_never_interpreted():
    profile, client = merchant()
    text = '<script>alert(1)</script> <b>gras</b> & "q"'
    created = client.post(POSTS, payload(profile.owner, caption=text), format="json").json()
    assert Post.objects.get(pk=created["id"]).caption == text
    assert created["caption"] == text
    reader = connected(make_owner())
    assert reader.get(POSTS).json()["results"][0]["caption"] == text
    assert reader.get(POSTS).headers["Content-Type"].startswith("application/json")


def test_offer_must_belong_to_the_same_profile():
    profile, client = merchant()
    mine_offer = Offer.objects.create(profile=profile, name="Riz 25 kg")
    other_offer = Offer.objects.create(
        profile=make_profile(status=BusinessStatus.ACTIVE), name="Huile"
    )
    good = client.post(POSTS, payload(profile.owner, offer=mine_offer.pk), format="json")
    assert good.status_code == 201 and good.json()["offer"] == {"id": mine_offer.pk,
                                                                "name": "Riz 25 kg"}
    bad = client.post(POSTS, payload(profile.owner, offer=other_offer.pk), format="json")
    assert bad.status_code == 400 and "offer" in bad.json()["fields"]
    missing = client.post(POSTS, payload(profile.owner, offer=999999), format="json")
    assert missing.status_code == 400
    assert Post.objects.count() == 1


def test_model_refuses_offer_of_another_profile():
    from django.core.exceptions import ValidationError

    profile = make_profile(status=BusinessStatus.ACTIVE)
    foreign = Offer.objects.create(
        profile=make_profile(status=BusinessStatus.ACTIVE), name="Huile"
    )
    with pytest.raises(ValidationError):
        make_post(profile, offer=foreign)


# --- fil --------------------------------------------------------------------------------


def test_feed_most_recent_first_and_excludes_hidden_deleted():
    reader = connected(make_owner())
    a, _ = merchant()
    old = make_post(a, "ancienne", age=3 * HOUR)
    new = make_post(a, "récente", age=HOUR)
    make_post(a, "masquée", status=ContentStatus.HIDDEN)
    make_post(a, "supprimée", status=ContentStatus.DELETED)
    results = reader.get(POSTS).json()["results"]
    assert [r["id"] for r in results] == [new.pk, old.pk]
    assert reader.get(POSTS)["Cache-Control"] == "no-store"


def test_feed_excludes_non_visible_profiles_and_blocked_or_deleted_accounts():
    reader = connected(make_owner())
    ok, _ = merchant()
    make_post(ok, "visible")
    pending = make_profile(status=BusinessStatus.PENDING)
    rejected = make_profile(status=BusinessStatus.REJECTED)
    blocked = make_profile(status=BusinessStatus.ACTIVE)
    deleted = make_profile(status=BusinessStatus.ACTIVE)
    inactive = make_profile(status=BusinessStatus.ACTIVE)
    for p in (pending, rejected, blocked, deleted, inactive):
        make_post(p)
    blocked.owner.is_blocked = True
    blocked.owner.save()
    deleted.owner.is_deleted = True
    deleted.owner.save()
    inactive.owner.is_active = False
    inactive.owner.save()
    results = reader.get(POSTS).json()["results"]
    assert [r["caption"] for r in results] == ["visible"]


def test_blocked_merchant_posts_are_masked_and_cannot_publish():
    profile, client = merchant()
    make_post(profile)
    reader = connected(make_owner())
    assert len(reader.get(POSTS).json()["results"]) == 1
    profile.owner.is_blocked = True
    profile.owner.save()
    assert reader.get(POSTS).json()["results"] == []
    response = client.post(POSTS, payload(profile.owner), format="json")
    assert response.status_code == 403 and response.json()["code"] == "account_blocked"


def test_feed_subscribers_first_then_most_recent():
    reader = connected(make_owner())
    plain, _ = merchant()
    subscribed, _ = merchant()
    make_subscription(subscribed)
    recent_plain = make_post(plain, "récente non abonnée", age=HOUR)
    old_sub = make_post(subscribed, "ancienne abonnée", age=5 * HOUR)
    older_sub = make_post(subscribed, "plus ancienne abonnée", age=9 * HOUR)
    ids = [r["id"] for r in reader.get(POSTS).json()["results"]]
    assert ids == [old_sub.pk, older_sub.pk, recent_plain.pk]


def test_feed_zone_filter_includes_sub_zones():
    reader = connected(make_owner())
    _, _, departement, ville, quartier = make_maroua_chain()
    elsewhere = make_zone("Mokolo", "ville_village", departement)
    in_quartier, _ = merchant(zone=quartier)
    in_ville, _ = merchant(zone=ville)
    far, _ = merchant(zone=elsewhere)
    p1, p2, p3 = (make_post(in_quartier), make_post(in_ville), make_post(far))
    by_ville = {r["id"] for r in reader.get(f"{POSTS}?zone={ville.pk}").json()["results"]}
    assert by_ville == {p1.pk, p2.pk}
    by_quartier = {r["id"] for r in reader.get(f"{POSTS}?zone={quartier.pk}").json()["results"]}
    assert by_quartier == {p1.pk}
    assert {r["id"] for r in reader.get(POSTS).json()["results"]} == {p1.pk, p2.pk, p3.pk}


def test_feed_unknown_or_malformed_zone_is_400():
    reader = connected(make_owner())
    for value in ("999999", "abc"):
        response = reader.get(f"{POSTS}?zone={value}")
        assert response.status_code == 400 and response.json()["code"] == "invalid"


def test_feed_has_no_phone_number_anywhere():
    owner_phone_digits = None
    profile, _ = merchant()
    make_post(profile)
    owner_phone_digits = profile.owner.phone.lstrip("+")
    anchor_digits = profile.phone_anchor.lstrip("+")
    reader = connected(make_owner())
    post = Post.objects.get()
    make_comment(post, profile.owner)
    for url in (POSTS, f"{POSTS}{post.pk}/", f"{POSTS}{post.pk}/comments/", MINE):
        text = connected(profile.owner).get(url).content.decode()
        assert owner_phone_digits not in text and anchor_digits not in text, url
        assert not re.search(r"\+?237\s?6\d{8}", text), url
    text = reader.get(f"{POSTS}{post.pk}/").content.decode()
    assert "phone" not in text and "owner" not in text


def test_feed_query_count_does_not_grow_with_posts():
    reader = connected(make_owner())
    zone_owner, _ = merchant()
    subscribed, _ = merchant()
    make_subscription(subscribed)

    def count_queries():
        with CaptureQueriesContext(connection) as ctx:
            response = reader.get(POSTS)
        assert response.status_code == 200
        return len(ctx), response.json()

    make_post(zone_owner)
    few, _ = count_queries()
    for i in range(12):
        author, _ = merchant()
        post = make_post(author if i % 2 else subscribed, f"p{i}")
        for _ in range(2):
            make_comment(post, make_owner(name=f"Compte {i}"))
    many, body = count_queries()
    assert len(body["results"]) == 13
    assert many == few
    assert sum(r["comments_count"] for r in body["results"]) == 24


def test_feed_is_paginated_20_per_page():
    reader = connected(make_owner())
    for _ in range(3):
        profile, _ = merchant()
        for i in range(4):
            make_post(profile, f"p{i}")
    page = reader.get(POSTS).json()
    assert page["count"] == 12 and len(page["results"]) == 12
    small = reader.get(f"{POSTS}?page_size=5").json()
    assert len(small["results"]) == 5 and small["next"]


# --- détail -----------------------------------------------------------------------------


def test_detail_with_paginated_comments():
    profile, owner_client = merchant()
    post = make_post(profile)
    commenter = make_owner(name="Jeff Nguebou")
    for i in range(25):
        make_comment(post, commenter, f"c{i}")
    reader = connected(make_owner())
    body = reader.get(f"{POSTS}{post.pk}/").json()
    assert body["id"] == post.pk and body["comments_count"] == 25
    assert body["comments"]["count"] == 25 and len(body["comments"]["results"]) == 20
    assert body["comments"]["next"]
    assert body["comments"]["results"][0]["text"] == "c0"
    assert body["comments"]["results"][0]["author"]["name"] == "Jeff N."
    page2 = reader.get(f"{POSTS}{post.pk}/?page=2").json()
    assert [c["text"] for c in page2["comments"]["results"]] == [f"c{i}" for i in range(20, 25)]
    assert reader.get(f"{POSTS}{post.pk}/")["Cache-Control"] == "no-store"


def test_detail_404_when_not_visible():
    profile, _ = merchant()
    reader = connected(make_owner())
    for status in (ContentStatus.HIDDEN, ContentStatus.DELETED):
        post = make_post(profile, status=status)
        response = reader.get(f"{POSTS}{post.pk}/")
        assert response.status_code == 404 and response.json()["code"] == "not_found"
    pending = make_post(make_profile(status=BusinessStatus.PENDING))
    assert reader.get(f"{POSTS}{pending.pk}/").status_code == 404
    assert reader.get(f"{POSTS}999999/").status_code == 404


def test_comment_of_business_shows_business_name_and_blocked_authors_are_masked():
    profile, _ = merchant()
    post = make_post(profile)
    reply = make_comment(post, profile.owner, "Oui, livraison possible")
    spammer = make_owner(name="Spam Mer")
    make_comment(post, spammer, "acheter ici")
    spammer.is_blocked = True
    spammer.save()
    body = connected(make_owner()).get(f"{POSTS}{post.pk}/").json()
    assert [c["id"] for c in body["comments"]["results"]] == [reply.pk]
    author = body["comments"]["results"][0]["author"]
    assert author["name"] == profile.name and author["is_business"] is True
    assert body["comments_count"] == 1


# --- suppression ------------------------------------------------------------------------


def test_delete_own_post_is_soft_and_leaves_the_feed():
    profile, client = merchant()
    post = make_post(profile)
    reader = connected(make_owner())
    assert client.delete(f"{POSTS}{post.pk}/").status_code == 204
    post.refresh_from_db()
    assert post.status == ContentStatus.DELETED  # la ligne existe toujours
    assert reader.get(POSTS).json()["results"] == []
    assert reader.get(f"{POSTS}{post.pk}/").status_code == 404
    assert client.delete(f"{POSTS}{post.pk}/").status_code == 404  # déjà supprimée


def test_cannot_delete_someone_elses_post():
    owner_profile, _ = merchant()
    post = make_post(owner_profile)
    _, intruder = merchant()
    simple = connected(make_owner())
    for client in (intruder, simple):
        response = client.delete(f"{POSTS}{post.pk}/")
        assert response.status_code == 404 and response.json()["code"] == "not_found"
    post.refresh_from_db()
    assert post.status == ContentStatus.ACTIVE


# --- mes publications --------------------------------------------------------------------


def test_mine_lists_own_non_deleted_posts_with_status_and_comment_count():
    profile, client = merchant()
    shown = make_post(profile, "visible", age=HOUR)
    hidden = make_post(profile, "masquée", status=ContentStatus.HIDDEN, age=2 * HOUR)
    make_post(profile, "supprimée", status=ContentStatus.DELETED)
    make_post(merchant()[0], "d'un autre")
    make_comment(shown, make_owner(), "a")
    make_comment(shown, make_owner(), "b")
    body = client.get(MINE).json()
    assert [(r["id"], r["status"], r["comments_count"]) for r in body["results"]] == [
        (shown.pk, "actif", 2), (hidden.pk, "masque", 0),
    ]
    assert client.get(MINE)["Cache-Control"] == "no-store"


def test_mine_requires_an_active_business():
    _, pending = merchant(status=BusinessStatus.PENDING)
    assert pending.get(MINE).status_code == 403
    _, simple = simple_client()
    assert simple.get(MINE).status_code == 404


def test_old_post_is_still_listed_with_age():
    profile, _ = merchant()
    make_post(profile, age=timedelta(days=40))
    assert len(connected(make_owner()).get(POSTS).json()["results"]) == 1
