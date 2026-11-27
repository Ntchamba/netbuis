"""Publications et commentaires de démonstration (T090), pour `seed_demo`.

- Tout est fictif : légendes visiblement fictives, médias = clés au format du serveur qui ne
  pointent vers aucun fichier, commentaires écrits par les comptes « Responsable Démo » (aucun
  numéro réel, aucun vrai compte).
- Seuls les commerces de démonstration ACTIFS reçoivent des publications (1 à 3 chacun, donc
  sous le plafond de 5). Déterministe, aucun hasard.
- Idempotent : un commerce de démonstration qui a déjà une publication (même supprimée) n'en
  reçoit pas de nouvelle ; les commentaires ne sont ajoutés qu'aux publications créées par cet
  appel. `seed_demo --flush` supprime les publications avec le commerce (cascade).
- Peu de requêtes (écritures groupées) : prévu pour `--count 5000`.
"""
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from apps.business.models import BusinessProfile, BusinessStatus
from apps.business.services.demo_data import DEMO_PREFIX, PHONE_BLOCK_REGEX
from apps.business.services.storage_service import JPEG, MP4, new_key
from apps.forum.models import Comment, ContentStatus, MediaType, Post

CAPTIONS = (
    "Nouvel arrivage de démonstration, venez voir (fiche fictive).",
    "Promotion imaginaire ce week-end, dans la limite des stocks fictifs.",
    "Message de démonstration : horaires élargis cette semaine (donnée fictive).",
    "Publication fictive pour montrer le fil du forum.",
)
COMMENTS = (
    "Commentaire de démonstration : c'est encore disponible ?",
    "Commentaire fictif : vous livrez aussi dans mon quartier ?",
    "Bonjour, ceci est un message de démonstration.",
)


def seed(count: int) -> tuple[int, int]:
    """Ajoute les publications et commentaires des `count` premiers commerces de démonstration.
    Retourne (publications créées, commentaires créés)."""
    profiles = list(
        BusinessProfile.objects.filter(
            name__startswith=DEMO_PREFIX, owner__phone__regex=PHONE_BLOCK_REGEX,
            status=BusinessStatus.ACTIVE,
        ).select_related("owner").order_by("owner__phone", "pk")[:count]
    )
    if not profiles:
        return 0, 0
    already = set(
        Post.objects.filter(profile__in=[p.pk for p in profiles]).order_by()
        .values_list("profile_id", flat=True).distinct()
    )
    authors = [p.owner for p in profiles]
    now = timezone.now()
    posts: list[Post] = []
    for n, profile in enumerate(p for p in profiles if p.pk not in already):
        for k in range(1 + n % 3):
            video = (n + k) % 7 == 0
            kind, ctype = ("post_video", MP4) if video else ("post_image", JPEG)
            posts.append(Post(
                profile=profile, media_type=MediaType.VIDEO if video else MediaType.IMAGE,
                media=new_key(profile.owner_id, kind, ctype),
                caption=CAPTIONS[(n + k) % len(CAPTIONS)], status=ContentStatus.ACTIVE,
            ))
    with transaction.atomic():
        for post in posts:
            post.clean()  # mêmes règles que l'API (bulk_create n'appelle pas save())
        Post.objects.bulk_create(posts)
        # created_at est auto_now_add : on étale les dates après coup (déterministe).
        for index, post in enumerate(posts):
            post.created_at = now - timedelta(hours=1 + index % 72)
        Post.objects.bulk_update(posts, ["created_at"], batch_size=500)
        comments = []
        for index, post in enumerate(posts):
            for j in range(index % 3):  # 0 à 2 commentaires, par d'autres comptes de démonstration
                author = authors[(index + j + 1) % len(authors)]
                comment = Comment(
                    post=post, author=author, text=COMMENTS[(index + j) % len(COMMENTS)]
                )
                comment.clean()
                comments.append(comment)
        Comment.objects.bulk_create(comments)
    return len(posts), len(comments)
