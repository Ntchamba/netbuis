"""Routes du fil (T090).

GET/POST /api/forum/posts/, GET/DELETE /api/forum/posts/<id>/, GET /api/forum/mine/,
GET/POST /api/forum/posts/<id>/comments/.
Toutes : compte connecté non bloqué. Publier : profil `actif` du compte (jamais de profil dans le
corps). Supprimer : seulement ses publications (404 sinon).
"""
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.generics import GenericAPIView
from rest_framework.response import Response

from apps.business.services import offer_service
from apps.forum.serializers.comment import CommentCreateSerializer, CommentSerializer
from apps.forum.serializers.post import (
    MyPostSerializer,
    PostCreateSerializer,
    PostDetailSerializer,
    PostSerializer,
)
from apps.forum.services import comment_service, post_service
from apps.forum.views.common import (
    ERR_400,
    ERR_401,
    ERR_403,
    ERR_404,
    ERR_429,
    NoStoreMixin,
)

_COMMON = {401: ERR_401, 403: ERR_403}
_PAGE_PARAMS = [
    OpenApiParameter("page", OpenApiTypes.INT, description="Numéro de page (20 par page)."),
    OpenApiParameter("page_size", OpenApiTypes.INT, description="Taille de page (50 au plus)."),
]


class PostListCreateView(NoStoreMixin, GenericAPIView):
    serializer_class = PostSerializer

    @extend_schema(
        tags=["forum"], operation_id="forum_posts_list",
        parameters=[
            OpenApiParameter(
                "zone", OpenApiTypes.INT,
                description="Identifiant d'une zone : la zone ET ses sous-zones. "
                            "Absent = toutes les zones.",
            ),
            *_PAGE_PARAMS,
        ],
        responses={200: PostSerializer(many=True), 400: ERR_400, **_COMMON},
    )
    def get(self, request):
        zone = request.query_params.get("zone")
        queryset = post_service.feed(
            request.user, post_service.parse_zone(zone) if zone not in (None, "") else None
        )
        page = self.paginate_queryset(queryset)
        return self.get_paginated_response(
            PostSerializer(page, many=True, context=self.get_serializer_context()).data
        )

    @extend_schema(
        tags=["forum"], operation_id="forum_posts_create",
        request=PostCreateSerializer,
        responses={201: PostSerializer, 400: ERR_400, 404: ERR_404, 429: ERR_429, **_COMMON},
    )
    def post(self, request):
        profile = offer_service.active_profile(request.user)
        context = {**self.get_serializer_context(), "profile": profile}
        serializer = PostCreateSerializer(data=request.data, context=context)
        serializer.is_valid(raise_exception=True)
        post = post_service.create_post(
            request.user, profile, serializer.validated_post_values()
        )
        post = post_service.detail(request.user, post.pk)
        return Response(
            PostSerializer(post, context=self.get_serializer_context()).data,
            status=status.HTTP_201_CREATED,
        )


class PostDetailView(NoStoreMixin, GenericAPIView):
    serializer_class = PostDetailSerializer

    @extend_schema(
        tags=["forum"], operation_id="forum_posts_retrieve", parameters=_PAGE_PARAMS,
        responses={200: PostDetailSerializer, 404: ERR_404, **_COMMON},
    )
    def get(self, request, pk):
        post = post_service.detail(request.user, pk)
        comments = comment_service.visible_comments(request.user, post.pk)
        page = self.paginate_queryset(comments)
        paged = self.get_paginated_response(
            CommentSerializer(page, many=True, context=self.get_serializer_context()).data
        ).data
        context = {**self.get_serializer_context(), "comments_page": paged}
        return Response(PostDetailSerializer(post, context=context).data)

    @extend_schema(
        tags=["forum"], operation_id="forum_posts_destroy",
        responses={204: None, 404: ERR_404, **_COMMON},
    )
    def delete(self, request, pk):
        post_service.delete_own_post(request.user, pk)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MyPostsView(NoStoreMixin, GenericAPIView):
    serializer_class = MyPostSerializer

    @extend_schema(
        tags=["forum"], operation_id="forum_mine_list", parameters=_PAGE_PARAMS,
        responses={200: MyPostSerializer(many=True), 404: ERR_404, **_COMMON},
    )
    def get(self, request):
        profile = offer_service.active_profile(request.user)
        page = self.paginate_queryset(post_service.mine(profile))
        return self.get_paginated_response(
            MyPostSerializer(page, many=True, context=self.get_serializer_context()).data
        )


class PostCommentsView(NoStoreMixin, GenericAPIView):
    serializer_class = CommentSerializer

    @extend_schema(
        tags=["forum"], operation_id="forum_post_comments_list", parameters=_PAGE_PARAMS,
        responses={200: CommentSerializer(many=True), 404: ERR_404, **_COMMON},
    )
    def get(self, request, pk):
        post_service.detail(request.user, pk)  # 404 si la publication n'est pas visible
        page = self.paginate_queryset(comment_service.visible_comments(request.user, pk))
        return self.get_paginated_response(
            CommentSerializer(page, many=True, context=self.get_serializer_context()).data
        )

    @extend_schema(
        tags=["forum"], operation_id="forum_post_comments_create",
        request=CommentCreateSerializer,
        responses={
            201: CommentSerializer, 400: ERR_400, 404: ERR_404, 429: ERR_429, **_COMMON,
        },
    )
    def post(self, request, pk):
        serializer = CommentCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        comment = comment_service.create_comment(
            request.user, pk, serializer.validated_data["text"]
        )
        return Response(
            CommentSerializer(comment, context=self.get_serializer_context()).data,
            status=status.HTTP_201_CREATED,
        )
