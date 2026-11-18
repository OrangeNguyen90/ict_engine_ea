from django.contrib import admin
from .models import ChatQuestion, CollectorRun, ICTConcept, ICTRule, KnowledgeChunk, Transcript, Video, YouTubeChannel


@admin.register(YouTubeChannel)
class YouTubeChannelAdmin(admin.ModelAdmin):
    list_display = ("title", "channel_id", "collected_at")


@admin.register(Video)
class VideoAdmin(admin.ModelAdmin):
    list_display = ("title", "channel", "published_at")
    search_fields = ("title", "video_id")


@admin.register(Transcript)
class TranscriptAdmin(admin.ModelAdmin):
    list_display = ("video", "language", "source", "imported_at")


admin.site.register(KnowledgeChunk)
admin.site.register(ICTConcept)
admin.site.register(ICTRule)
admin.site.register(ChatQuestion)
admin.site.register(CollectorRun)
