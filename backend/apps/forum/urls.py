"""Routes du forum (T090) : /api/forum/... et /api/reports/."""
from django.urls import path

from apps.forum.views.posts import (
    MyPostsView,
    PostCommentsView,
    PostDetailView,
    PostListCreateView,
)
from apps.forum.views.report import PostReportView, ReportCreateView

app_name = "forum"

urlpatterns = [
    path("forum/posts/", PostListCreateView.as_view(), name="posts"),
    path("forum/posts/<int:pk>/", PostDetailView.as_view(), name="post-detail"),
    path("forum/posts/<int:pk>/comments/", PostCommentsView.as_view(), name="post-comments"),
    path("forum/posts/<int:pk>/report/", PostReportView.as_view(), name="post-report"),
    path("forum/mine/", MyPostsView.as_view(), name="mine"),
    path("reports/", ReportCreateView.as_view(), name="reports"),
]
