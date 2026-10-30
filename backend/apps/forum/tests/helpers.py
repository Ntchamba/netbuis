"""Aides de test du forum : clients connectés, commerces actifs, publications, commentaires."""
from datetime import timedelta
from itertools import count

from django.core.cache import cache
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessStatus
from apps.forum.models import Comment, ContentStatus, MediaType, Post
from tests.factories.business_factory import make_owner, make_profile
from tests.factories.storage_factory import make_stored_file

POSTS = "/api/forum/posts/"
MINE = "/api/forum/mine/"
REPORTS = "/api/reports/"


def clear_cache():
    cache.clear()


def connected(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def merchant(**extra):
    """(profil ACTIF, client connecté de son propriétaire)."""
    extra.setdefault("status", BusinessStatus.ACTIVE)
    profile = make_profile(**extra)
    return profile, connected(profile.owner)


def simple_client(name="Jeff Nguebou"):
    user = make_owner(name=name)
    return user, connected(user)


def make_post(profile, caption="Riz disponible", status=ContentStatus.ACTIVE, age=None, **extra):
    post = Post.objects.create(
        profile=profile, media_type=MediaType.IMAGE, media=make_stored_file(
            profile.owner, "post_image"), caption=caption, status=status, **extra,
    )
    if age is not None:
        Post.objects.filter(pk=post.pk).update(created_at=timezone.now() - age)
        post.refresh_from_db()
    return post


def make_comment(post, author, text="Encore disponible ?", **extra):
    return Comment.objects.create(post=post, author=author, text=text, **extra)


_COUNTER = count(1)


def payload(owner, **extra):
    """Corps valide de création d'une publication (le fichier existe dans le stockage de test).
    La légende est différente à chaque appel : le filtre anti-doublons (T094) refuse deux fois
    le même texte en quelques minutes."""
    body = {"media": make_stored_file(owner, "post_image"),
            "caption": f"Nouveau lot de riz n°{next(_COUNTER)}"}
    body.update(extra)
    return body


HOUR = timedelta(hours=1)
