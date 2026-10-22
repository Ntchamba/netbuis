"""Publications (T090) : lecture du fil et règles d'écriture.

Fil : publications visibles pour l'appelant (`Post.objects.visible_for`), abonnés d'abord puis
plus récentes d'abord. Écriture : verrou sur la ligne du compte pour que deux requêtes
simultanées ne dépassent ni le plafond ni la limite du jour.
Deux règles DISTINCTES :
- plafond de publications ACTIVES sans abonnement (PlatformSetting, 5) -> SUBSCRIPTION_REQUIRED ;
- au plus 5 publications par 24 h (anti-spam, supprimées comprises) -> daily_post_limit.
"""
from django.db import transaction
from django.db.models import Count, Exists, IntegerField, OuterRef, Subquery
from django.db.models.functions import Coalesce
from django.utils import timezone
from rest_framework.exceptions import NotFound, ValidationError

from apps.accounts.models import User
from apps.business.services.profile_service import SubscriptionRequired
from apps.business.services.subscription import active_subscription_queryset, is_subscribed
from apps.core.services.settings_service import get_setting
from apps.forum.models import Comment, ContentStatus, Post
from apps.forum.services import limits
from apps.forum.services.errors import DailyPostLimit
from apps.search.services.filters import zone_parents, zone_subtree_ids

CAP_SETTING = "plafond_publications_non_abonne"


def _with_comments_count(queryset, user):
    """Ajoute `comments_count` (commentaires visibles pour `user`) SANS requête par ligne."""
    counted = (
        Comment.objects.visible_for(user).filter(post=OuterRef("pk"))
        .order_by().values("post").annotate(n=Count("pk")).values("n")
    )
    return queryset.annotate(
        comments_count=Coalesce(Subquery(counted, output_field=IntegerField()), 0)
    )


def _related(queryset):
    return queryset.select_related("profile", "profile__zone", "offer")


def parse_zone(raw):
    """Identifiant de zone du paramètre `zone` ; 400 si ce n'est pas un nombre ou si inconnue."""
    from apps.geo.models import Zone

    try:
        zone = Zone.objects.filter(pk=int(raw)).first()
    except (TypeError, ValueError):
        zone = None
    if zone is None:
        raise ValidationError({"zone": ["Zone inconnue."]})
    return zone


def feed(user, zone=None):
    qs = Post.objects.visible_for(user)
    if zone is not None:
        qs = qs.filter(profile__zone_id__in=zone_subtree_ids(zone, zone_parents()))
    qs = qs.annotate(
        author_subscribed=Exists(
            active_subscription_queryset().filter(profile=OuterRef("profile_id"))
        )
    )
    return _with_comments_count(_related(qs), user).order_by(
        "-author_subscribed", "-created_at", "-id"
    )


def detail(user, pk):
    post = _with_comments_count(_related(Post.objects.visible_for(user)), user).filter(
        pk=pk
    ).first()
    if post is None:
        raise NotFound()
    return post


def mine(profile):
    """Publications du commerce, supprimées exclues (les masquées restent visibles de leur
    auteur, avec leur statut)."""
    qs = _related(Post.objects.filter(profile=profile).exclude(status=ContentStatus.DELETED))
    return _with_comments_count(qs, profile.owner)


@transaction.atomic
def create_post(user, profile, data) -> Post:
    User.objects.select_for_update().get(pk=user.pk)  # sérialise les publications du compte
    now = timezone.now()
    cap = get_setting(CAP_SETTING)
    active = Post.objects.filter(profile=profile, status=ContentStatus.ACTIVE).count()
    if active >= cap and not is_subscribed(profile, now):
        raise SubscriptionRequired(
            f"Abonnez-vous pour avoir plus de {cap} publications actives."
        )
    recent = Post.objects.filter(
        profile=profile, created_at__gte=now - limits.POST_WINDOW
    ).count()
    if recent >= limits.POST_DAILY_LIMIT:
        raise DailyPostLimit()
    return Post.objects.create(profile=profile, **data)


def delete_own_post(user, pk) -> None:
    """Suppression douce ; 404 si la publication n'est pas à `user` (ou déjà supprimée)."""
    updated = Post.objects.filter(pk=pk, profile__owner=user).exclude(
        status=ContentStatus.DELETED
    ).update(status=ContentStatus.DELETED, updated_at=timezone.now())
    if not updated:
        raise NotFound()
