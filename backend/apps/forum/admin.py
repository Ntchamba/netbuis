from django.contrib import admin

from apps.forum.models import Comment, Post, Report


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ("id", "profile", "media_type", "status", "created_at")
    list_filter = ("status", "media_type")
    raw_id_fields = ("profile", "offer")


@admin.register(Comment)
class CommentAdmin(admin.ModelAdmin):
    list_display = ("id", "post", "author", "status", "created_at")
    list_filter = ("status",)
    raw_id_fields = ("post", "author")


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ("id", "target_type", "reason", "created_at")
    list_filter = ("target_type", "reason")
    raw_id_fields = ("reporter", "post", "comment", "business")
