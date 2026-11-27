"""Envoi de fichiers (T027) : `POST /api/uploads/sign/` puis `PUT /api/uploads/local/<token>/`.

ZONE SENSIBLE (relue ligne par ligne par Jeff).

1. `sign` (compte connecté, non bloqué, 60 demandes / heure) contrôle `kind`, `content_type` et
   `size`, puis donne une clé générée par le serveur et une adresse d'envoi à durée courte.
2. `local` (stockage de développement) reçoit le fichier. Pas de jeton d'accès : l'autorisation
   est le jeton SIGNÉ de l'adresse (15 min, un seul envoi). Le jeton est vérifié AVANT de lire
   le corps ; le corps est lu par morceaux avec une limite stricte.
Aucune réponse ni aucun journal ne contient le contenu d'un fichier ni une clé complète.
"""
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from rest_framework.views import APIView

from apps.accounts.models import User
from apps.accounts.serializers.otp import ErrorSerializer
from apps.business.serializers.upload import (
    UploadSignRequestSerializer,
    UploadSignResponseSerializer,
)
from apps.business.services import storage_service
from apps.business.services.storage_service import CHUNK_SIZE, KINDS, get_storage
from apps.core.exceptions import ApiError


class UploadRateThrottle(UserRateThrottle):
    """Demandes d'adresse d'envoi, par compte (taux `uploads`)."""

    scope = "uploads"


class InvalidKind(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_kind"
    default_detail = "Ce type d'envoi n'existe pas."


class InvalidType(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_type"
    default_detail = "Ce type de fichier n'est pas accepté (JPEG, PNG ou WebP ; MP4 pour la vidéo)."


class TooLarge(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "too_large"
    default_detail = "Le fichier est trop gros (5 Mo au plus pour une image, 30 Mo pour une vidéo)."


class InvalidSize(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid"
    default_detail = "La taille du fichier doit être un nombre d'octets supérieur à zéro."


class InvalidContent(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_content"
    default_detail = "Le contenu du fichier ne correspond pas à son type ou à sa taille."


class UploadTooLarge(ApiError):
    status_code = status.HTTP_413_REQUEST_ENTITY_TOO_LARGE
    default_code = "too_large"
    default_detail = "Le fichier est plus gros que prévu."


class InvalidUploadLink(ApiError):
    status_code = status.HTTP_403_FORBIDDEN
    default_code = "invalid_token"
    default_detail = "Lien d'envoi invalide ou expiré."


class UploadAlreadyUsed(ApiError):
    status_code = status.HTTP_403_FORBIDDEN
    default_code = "already_used"
    default_detail = "Ce lien d'envoi a déjà servi."


_SIGN_ERRORS = {
    401: OpenApiResponse(
        response=ErrorSerializer,
        description="not_authenticated / token_not_valid : jeton d'accès absent, faux ou expiré",
    ),
    403: OpenApiResponse(
        response=ErrorSerializer,
        description="account_blocked / account_deleted : « Contactez le support »",
    ),
    429: OpenApiResponse(
        response=ErrorSerializer,
        description="throttled : 60 demandes par heure et par compte",
    ),
}


class UploadSignView(APIView):
    throttle_classes = [UploadRateThrottle]

    @extend_schema(
        tags=["uploads"], operation_id="uploads_sign",
        request=UploadSignRequestSerializer,
        responses={
            200: UploadSignResponseSerializer,
            400: OpenApiResponse(
                response=ErrorSerializer,
                description=(
                    "invalid_kind : type d'envoi inconnu · invalid_type : type de fichier "
                    "refusé (SVG, GIF, HTML…) · too_large : plus de 5 Mo (images) ou 30 Mo "
                    "(vidéo) · invalid : taille absente, nulle ou pas un nombre entier"
                ),
            ),
            **_SIGN_ERRORS,
        },
        description=(
            "Donne l'adresse où envoyer UN fichier (PUT, corps binaire, en-têtes `headers`), "
            "puis `key` à mettre dans le profil. `cni_photo` et `diplome_photo` vont dans un "
            "espace privé, sans adresse publique."
        ),
    )
    def post(self, request):
        serializer = UploadSignRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        kind = serializer.validated_data["kind"]
        content_type = serializer.validated_data["content_type"]
        size = serializer.validated_data["size"]
        if kind not in KINDS:
            raise InvalidKind()
        if content_type not in storage_service.allowed_types(kind):
            raise InvalidType()
        if size < 1:
            raise InvalidSize()
        if size > storage_service.max_size(kind):
            raise TooLarge()
        ticket = get_storage().create_upload(kind, request.user.pk, content_type, size)
        url = ticket.upload_url
        if url.startswith("/"):
            url = request.build_absolute_uri(url)
        return Response({
            "key": ticket.key, "upload_url": url, "method": ticket.method,
            "headers": ticket.headers, "expires_in": ticket.expires_in,
        })


def _chunks(stream, limit: int):
    """Lit le corps par morceaux ; s'arrête dès que `limit` octets sont dépassés."""
    if stream is None:  # corps vide
        return
    received = 0
    while True:
        chunk = stream.read(min(CHUNK_SIZE, limit + 1 - received))
        if not chunk:
            return
        received += len(chunk)
        yield chunk
        if received > limit:
            return


class UploadLocalView(APIView):
    """Réception du fichier par le stockage LOCAL (développement). Pas d'authentification par
    jeton d'accès : le jeton signé de l'adresse fait foi."""

    authentication_classes = []
    permission_classes = [AllowAny]
    http_method_names = ["put", "options"]

    @extend_schema(
        tags=["uploads"], operation_id="uploads_local_put",
        request={"application/octet-stream": OpenApiTypes.BINARY},
        responses={
            204: OpenApiResponse(description="Fichier enregistré."),
            400: OpenApiResponse(
                response=ErrorSerializer,
                description=(
                    "invalid_type : Content-Type différent de celui annoncé · invalid_content : "
                    "les octets ne sont pas ceux du type annoncé, ou taille différente"
                ),
            ),
            403: OpenApiResponse(
                response=ErrorSerializer,
                description=(
                    "invalid_token : adresse falsifiée ou expirée · already_used : déjà servie"
                ),
            ),
            413: OpenApiResponse(
                response=ErrorSerializer,
                description="too_large : plus gros que la taille annoncée",
            ),
        },
        description=(
            "Corps binaire du fichier, avec le `Content-Type` donné par `uploads/sign/`. "
            "Réservé au stockage local de développement. Une adresse ne sert qu'une fois."
        ),
    )
    def put(self, request, token):
        storage = get_storage()
        claims = storage.read_upload_token(token)  # avant de lire le corps
        owner = User.objects.filter(pk=claims["o"]).first()
        if owner is None or not owner.can_login():
            raise InvalidUploadLink()
        try:
            declared = int(request.META.get("CONTENT_LENGTH") or 0)
        except ValueError:
            declared = 0
        if declared > claims["s"]:
            raise UploadTooLarge()
        media_type = (request.content_type or "").split(";")[0].strip().lower()
        storage.save_upload(token, media_type, _chunks(request.stream, claims["s"]))
        return Response(status=status.HTTP_204_NO_CONTENT)

    def handle_exception(self, exc):
        if isinstance(exc, storage_service.StorageError):
            exc = _translate(exc)
        return super().handle_exception(exc)


def _translate(error: storage_service.StorageError) -> ApiError:
    if isinstance(error, storage_service.InvalidToken):
        return InvalidUploadLink()
    if isinstance(error, storage_service.AlreadyUploaded):
        return UploadAlreadyUsed()
    if isinstance(error, storage_service.TooLarge):
        return UploadTooLarge()
    if isinstance(error, storage_service.InvalidType):
        return InvalidType(error.message)
    return InvalidContent()
