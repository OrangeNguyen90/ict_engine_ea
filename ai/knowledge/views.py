import requests
from django.conf import settings
from django.db import DatabaseError
from django.contrib.admin.views.decorators import staff_member_required
from django.http import HttpResponseRedirect
from django.shortcuts import render
from django.urls import reverse
from django.views.decorators.http import require_POST
from rest_framework import status
from rest_framework.decorators import api_view, throttle_classes
from rest_framework.throttling import AnonRateThrottle
from rest_framework.response import Response

from .models import CollectorRun, KnowledgeChunk, Transcript, Video
from .services import answer_question, retrieve, ollama_status
from market.models import ICTAnalysisRun, ICTSignal, MarketCandle


class ChatThrottle(AnonRateThrottle):
    rate = "10/hour"


def dashboard(request):
    latest_run = CollectorRun.objects.first()
    latest_error = CollectorRun.objects.filter(status=CollectorRun.Status.FAILED).first()
    last_success = CollectorRun.objects.filter(status=CollectorRun.Status.SUCCESS).first()
    return render(request, "knowledge/dashboard.html", {
        "videos": Video.objects.select_related("channel")[:50],
        "video_count": Video.objects.count(),
        "transcript_count": Transcript.objects.count(),
        "chunk_count": KnowledgeChunk.objects.count(),
        "embedded_chunk_count": KnowledgeChunk.objects.filter(embedding_model=settings.OLLAMA_EMBED_MODEL, embedding__isnull=False).count(),
        "indexed_count": Video.objects.filter(processing_status=Video.ProcessingStatus.EMBEDDED).count(),
        "latest_run": latest_run,
        "latest_error": latest_error,
        "last_success": last_success,
        "youtube_connection": "Kết nối thành công" if last_success else "Chưa có đồng bộ thành công",
        "youtube_key_configured": bool(settings.YOUTUBE_API_KEY),
        "market_candle_count": MarketCandle.objects.count(),
        "market_signal_count": ICTSignal.objects.count(),
        "market_run_count": ICTAnalysisRun.objects.count(),
        "market_latest_candle": MarketCandle.objects.order_by("-timestamp").first(),
    })


@staff_member_required
@require_POST
def queue_youtube_sync(request):
    if not CollectorRun.objects.filter(status__in=[CollectorRun.Status.PENDING, CollectorRun.Status.RUNNING]).exists():
        CollectorRun.objects.create(limit=5, incremental=True)
    return HttpResponseRedirect(reverse("dashboard"))


@api_view(["GET"])
def videos_api(request):
    videos = Video.objects.select_related("channel")[:100]
    return Response([{"id": v.video_id, "title": v.title, "published_at": v.published_at,
                      "channel": v.channel.title, "url": v.url} for v in videos])


@api_view(["GET"])
def search_api(request):
    query = request.query_params.get("q", "").strip()
    if not 2 <= len(query) <= 500:
        return Response({"error": "q must be 2–500 characters"}, status=status.HTTP_400_BAD_REQUEST)
    try:
        matches = retrieve(query)
    except (requests.RequestException, ValueError, KeyError, IndexError, TypeError) as exc:
        return Response({"error": f"Embedding service unavailable: {type(exc).__name__}"}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    return Response([{"text": chunk.text, "start_ms": chunk.start_ms, "citation_url": chunk.citation_url,
                      "score": round(score, 3)} for score, chunk in matches])


@api_view(["POST"])
@throttle_classes([ChatThrottle])
def chat_api(request):
    question = request.data.get("question", "")
    if not isinstance(question, str) or not 2 <= len(question.strip()) <= 1000:
        return Response({"error": "question must be 2–1000 characters"}, status=status.HTTP_400_BAD_REQUEST)
    mode = request.data.get("mode", "general")
    if mode not in ("general", "ict"):
        return Response({"error": "mode must be general or ict"}, status=400)
    try:
        return Response(answer_question(question.strip(), mode=mode))
    except requests.Timeout:
        return Response({"error": "Ollama phản hồi quá thời gian chờ. Hãy thử câu hỏi ngắn hơn hoặc kiểm tra tài nguyên máy."}, status=503)
    except DatabaseError:
        return Response({"error": "Không kết nối được cơ sở dữ liệu. Vui lòng thử lại."}, status=503)
    except (requests.RequestException, ValueError, KeyError, IndexError, TypeError) as exc:
        return Response({"error": f"AI service unavailable: {type(exc).__name__}"}, status=status.HTTP_503_SERVICE_UNAVAILABLE)


@api_view(["GET"])
def health_api(request):
    return Response(ollama_status())
