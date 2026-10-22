"""Commentaires (T090) : tout compte connecté non bloqué, 10 par 10 minutes au plus."""
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound

from apps.accounts.models import User
from apps.forum.models import Comment, Post
from apps.forum.services import limits
from apps.forum.services.errors import CommentRateLimit


def visible_comments(user, post_id):
    return (
        Comment.objects.visible_for(user).filter(post_id=post_id)
        .select_related("author", "author__business_profile")
    )


@transaction.atomic
def create_comment(user, post_id, text) -> Comment:
    if not Post.objects.visible_for(user).filter(pk=post_id).exists():
        raise NotFound()
    User.objects.select_for_update().get(pk=user.pk)  # sérialise les commentaires du compte
    recent = Comment.objects.filter(
        author=user, created_at__gte=timezone.now() - limits.COMMENT_WINDOW
    ).count()
    if recent >= limits.COMMENT_LIMIT:
        raise CommentRateLimit()
    return Comment.objects.create(post_id=post_id, author=user, text=text)
