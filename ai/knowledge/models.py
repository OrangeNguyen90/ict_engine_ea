from django.db import models
from django.db.models import Q


class YouTubeChannel(models.Model):
    channel_id = models.CharField(max_length=64, unique=True)
    title = models.CharField(max_length=255)
    url = models.URLField()
    collected_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.title


class Video(models.Model):
    class ProcessingStatus(models.TextChoices):
        TRANSCRIPT_UNAVAILABLE = "TRANSCRIPT_UNAVAILABLE", "Transcript unavailable"
        TRANSCRIPT_IMPORTED = "TRANSCRIPT_IMPORTED", "Transcript imported"
        EMBEDDED = "EMBEDDED", "Embedded"

    channel = models.ForeignKey(YouTubeChannel, on_delete=models.PROTECT, related_name="videos")
    video_id = models.CharField(max_length=32, unique=True)
    title = models.CharField(max_length=500)
    description = models.TextField(blank=True)
    published_at = models.DateTimeField()
    playlist_id = models.CharField(max_length=64, blank=True)
    url = models.URLField()
    collected_at = models.DateTimeField(auto_now=True)
    processing_status = models.CharField(max_length=24, choices=ProcessingStatus.choices, default=ProcessingStatus.TRANSCRIPT_UNAVAILABLE)
    topics = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ["-published_at"]
        indexes = [models.Index(fields=["published_at"])]

    def __str__(self):
        return self.title


class Transcript(models.Model):
    video = models.ForeignKey(Video, on_delete=models.CASCADE, related_name="transcripts")
    language = models.CharField(max_length=16)
    source = models.CharField(max_length=32, choices=[("authorized_import", "Authorized import"), ("authorized_whisper", "Authorized Whisper")])
    rights_note = models.TextField()
    imported_at = models.DateTimeField(auto_now_add=True)
    content_sha256 = models.CharField(max_length=64)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["video", "language", "content_sha256"], name="unique_transcript_content")]


class KnowledgeChunk(models.Model):
    transcript = models.ForeignKey(Transcript, on_delete=models.CASCADE, related_name="chunks")
    start_ms = models.PositiveIntegerField()
    end_ms = models.PositiveIntegerField()
    text = models.TextField()
    topics = models.JSONField(default=list, blank=True)
    embedding = models.JSONField(null=True, blank=True)
    embedding_model = models.CharField(max_length=100, blank=True)
    indexed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["transcript_id", "start_ms"]
        constraints = [models.CheckConstraint(condition=Q(end_ms__gt=models.F("start_ms")), name="chunk_positive_duration")]
        indexes = [models.Index(fields=["transcript", "start_ms"])]

    @property
    def citation_url(self):
        return f"{self.transcript.video.url}&t={self.start_ms // 1000}s"


class ICTConcept(models.Model):
    name = models.CharField(max_length=160, unique=True)
    definition = models.TextField()
    source_chunk = models.ForeignKey(KnowledgeChunk, on_delete=models.PROTECT, related_name="concepts")
    verified = models.BooleanField(default=False)


class ICTRule(models.Model):
    concept = models.ForeignKey(ICTConcept, on_delete=models.CASCADE, related_name="rules")
    statement = models.TextField()
    source_chunk = models.ForeignKey(KnowledgeChunk, on_delete=models.PROTECT, related_name="rules")
    is_system_interpretation = models.BooleanField(default=True)


class ChatQuestion(models.Model):
    question = models.TextField()
    answer = models.TextField()
    citations = models.JSONField(default=list)
    model = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]


class CollectorRun(models.Model):
    class Status(models.TextChoices):
        PENDING = "PENDING", "Pending"
        RUNNING = "RUNNING", "Running"
        SUCCESS = "SUCCESS", "Success"
        FAILED = "FAILED", "Failed"

    status = models.CharField(max_length=8, choices=Status.choices, default=Status.PENDING)
    incremental = models.BooleanField(default=True)
    limit = models.PositiveSmallIntegerField(default=50)
    requested_at = models.DateTimeField(auto_now_add=True)
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)
    channel_id = models.CharField(max_length=64, blank=True)
    created_count = models.PositiveIntegerField(default=0)
    updated_count = models.PositiveIntegerField(default=0)
    error = models.TextField(blank=True)

    class Meta:
        ordering = ["-requested_at"]
