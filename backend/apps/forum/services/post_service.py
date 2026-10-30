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
from apps.forum.services import limits, spam_filter
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


class FeedWindow:
    """Le fil classé vu comme une liste paginable (T122).

    Le tri (abonnés d'abord, plus récentes d'abord) se fait sur des colonnes ÉTROITES (les
    identifiants seulement) et seule la page demandée est lue en entier, avec ses jointures et
    son nombre de commentaires. Avant, chaque ligne du fil portait auteur, zone et produit dans
    le tri, et le nombre de commentaires était calculé pour toutes les lignes sautées par la
    pagination (page 100 : 220 ms sur 7 200 publications)."""

    def __init__(self, user, sorted_rows):
        self.user = user
        self.sorted_rows = sorted_rows

    def __len__(self) -> int:
        return self.sorted_rows.count()

    def __getitem__(self, key):
        start, stop = key.start or 0, key.stop
        ids = list(self.sorted_rows.values_list("pk", flat=True)[start:stop])
        rows = _with_comments_count(
            _related(Post.objects.visible_for(self.user).filter(pk__in=ids)), self.user
        ).in_bulk()
        return [rows[pk] for pk in ids if pk in rows]


def feed(user, zone=None) -> FeedWindow:
    qs = Post.objects.visible_for(user)
    if zone is not None:
        qs = qs.filter(profile__zone_id__in=zone_subtree_ids(zone, zone_parents()))
    qs = qs.annotate(
        author_subscribed=Exists(
            active_subscription_queryset().filter(profile=OuterRef("profile_id"))
        )
    ).order_by("-author_subscribed", "-created_at", "-id")
    return FeedWindow(user, qs)


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
    spam_filter.check_post(profile, data.get("caption", ""), now)  # 400 spam_detected
    return Post.objects.create(profile=profile, **data)


def delete_own_post(user, pk) -> None:
    """Suppression douce ; 404 si la publication n'est pas à `user` (ou déjà supprimée)."""
    updated = Post.objects.filter(pk=pk, profile__owner=user).exclude(
        status=ContentStatus.DELETED
    ).update(status=ContentStatus.DELETED, updated_at=timezone.now())
    if not updated:
        raise NotFound()
