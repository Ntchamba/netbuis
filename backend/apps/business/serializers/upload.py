"""Corps et réponse de `POST /api/uploads/sign/` (T027). Le contrôle fin (type, taille) se fait
dans la vue pour renvoyer les codes stables `invalid_kind`, `invalid_type`, `too_large`."""
from rest_framework import serializers

from apps.business.services.storage_service import KINDS


class UploadSignRequestSerializer(serializers.Serializer):
    kind = serializers.CharField(
        max_length=40,
        help_text=(
            f"Nature du fichier : {', '.join(KINDS)}. cni_photo et diplome_photo sont PRIVÉS."
        ),
    )
    content_type = serializers.CharField(
        max_length=100,
        help_text="image/jpeg, image/png ou image/webp ; video/mp4 pour post_video seulement.",
    )
    size = serializers.IntegerField(
        help_text="Taille exacte du fichier en octets : 1 à 5 242 880 (images), "
                  "1 à 31 457 280 (vidéo de publication).",
    )


class UploadSignResponseSerializer(serializers.Serializer):
    key = serializers.CharField(
        help_text="Clé à mettre ensuite dans le profil (photo, cni_photo…)."
    )
    upload_url = serializers.CharField(
        help_text="Adresse où envoyer le fichier (PUT, corps binaire)."
    )
    method = serializers.CharField(help_text="Toujours PUT.")
    headers = serializers.DictField(
        child=serializers.CharField(), help_text="En-têtes à envoyer tels quels (Content-Type).",
    )
    expires_in = serializers.IntegerField(help_text="Secondes de validité de l'adresse d'envoi.")
