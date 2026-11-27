"""seed_demo étendu (T090) : publications et commentaires fictifs, idempotence, flush."""
from io import StringIO

import pytest
from django.core.management import call_command

from apps.accounts.models import User
from apps.business.models import BusinessStatus
from apps.business.services import demo_data
from apps.business.services.storage_service import parse_key
from apps.forum.models import Comment, Post

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def referentials(settings):
    settings.DEBUG = True  # pytest-django force DEBUG=False
    call_command("load_zones", stdout=StringIO())
    call_command("seed_referentials", stdout=StringIO())


def run(*args) -> str:
    out = StringIO()
    call_command("seed_demo", *args, stdout=out)
    return out.getvalue()


def test_seed_creates_fictional_posts_and_comments_only_for_active_profiles():
    output = run()
    assert "Forum de démonstration" in output
    posts = Post.objects.select_related("profile__owner")
    assert posts.count() > 10 and Comment.objects.count() > 5
    for post in posts:
        assert post.profile.status == BusinessStatus.ACTIVE
        assert post.profile.name.startswith(demo_data.DEMO_PREFIX)
        assert any(word in post.caption.lower() for word in ("fictif", "fictive", "démonstration"))
        assert parse_key(post.media).kind in ("post_image", "post_video")
        assert len(post.caption) <= 500
    per_profile = {}
    for post in posts:
        per_profile[post.profile_id] = per_profile.get(post.profile_id, 0) + 1
    assert max(per_profile.values()) <= 3  # sous le plafond de 5
    for comment in Comment.objects.select_related("author"):
        assert demo_data.is_demo_phone(comment.author.phone)
        assert len(comment.text) <= 300


def test_seed_is_idempotent():
    run()
    posts, comments = Post.objects.count(), Comment.objects.count()
    again = run()
    assert Post.objects.count() == posts and Comment.objects.count() == comments
    assert "0 publications et 0 commentaires" in again


def test_seeded_posts_appear_in_the_feed():
    from apps.forum.tests.helpers import POSTS, connected

    run()
    reader = User.objects.filter(phone=demo_data.demo_phone(1)).get()  # un compte de démo
    body = connected(reader).get(POSTS).json()
    assert body["count"] == Post.objects.count() and body["count"] > 10


def test_flush_removes_posts_and_comments_with_the_demo_businesses():
    run()
    assert Post.objects.exists() and Comment.objects.exists()
    call_command("seed_demo", "--flush", stdout=StringIO())
    assert Post.objects.count() == 0 and Comment.objects.count() == 0
    assert not User.objects.filter(name__startswith=demo_data.OWNER_PREFIX).exists()
