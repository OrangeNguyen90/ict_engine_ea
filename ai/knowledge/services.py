"""Authorized ingestion and local retrieval. No transcript scraping or audio download."""
import hashlib
import math
import re
from datetime import datetime

import requests
from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import ChatQuestion, CollectorRun, KnowledgeChunk, Transcript, Video, YouTubeChannel

ICT_CHANNEL_HANDLE = "@InnerCircleTrader"
YOUTUBE_API = "https://www.googleapis.com/youtube/v3"


class YouTubeAPIError(Exception):
    """Safe error text that never includes a URL containing the API key."""


def _youtube_get(resource, api_key, params):
    try:
        response = requests.get(
            f"{YOUTUBE_API}/{resource}",
            params={**params, "key": api_key},
            timeout=settings.YOUTUBE_API_TIMEOUT,
        )
        response.raise_for_status()
        return response.json()
    except requests.HTTPError as exc:
        status = exc.response.status_code if exc.response is not None else "unknown"
        try:
            error = exc.response.json()["error"]
            reason = error.get("message") or error["errors"][0]["reason"]
            reason = str(reason).replace(api_key, "[REDACTED]")
            reason = re.sub(r"https?://\S+", "[URL REDACTED]", reason)[:400]
        except (AttributeError, KeyError, IndexError, TypeError, ValueError):
            reason = "request rejected"
        raise YouTubeAPIError(f"YouTube Data API HTTP {status}: {reason}") from None
    except requests.RequestException:
        raise YouTubeAPIError("Could not reach YouTube Data API") from None


TOPIC_TERMS = {
    "ICT Mentorship 2016": ("2016 mentorship", "mentorship 2016"),
    "ICT Mentorship 2022": ("2022 mentorship", "mentorship 2022"),
    "Market Structure": ("market structure", "structure shift", " mss "),
    "Liquidity": ("liquidity", "buy side liquidity", "sell side liquidity"),
    "FVG": ("fair value gap", " fvg "),
    "Order Block": ("order block", "breaker block"),
    "Silver Bullet": ("silver bullet",),
    "Premium/Discount": ("premium", "discount", "dealing range"),
}


def classify_topics(text):
    """Keyword labels for review; these are not verified ICT claims."""
    searchable = f" {text.casefold()} "
    return [topic for topic, terms in TOPIC_TERMS.items() if any(term in searchable for term in terms)]


def collect_youtube_metadata(api_key, max_videos=50, incremental=True, run=None):
    """Use the official Data API. No guesswork about channel identity or content."""
    if not api_key:
        raise ValueError("YOUTUBE_API_KEY is required")
    if not 1 <= max_videos <= 500:
        raise ValueError("max_videos must be between 1 and 500")
    run = run or CollectorRun.objects.create(limit=max_videos, incremental=incremental)
    run.status, run.started_at, run.error = CollectorRun.Status.RUNNING, timezone.now(), ""
    run.save(update_fields=["status", "started_at", "error"])
    try:
        items = _youtube_get("channels", api_key, {
            "part": "snippet,contentDetails", "forHandle": ICT_CHANNEL_HANDLE,
        }).get("items", [])
        if len(items) != 1:
            raise YouTubeAPIError("Official channel handle did not resolve uniquely")
        item = items[0]
        channel, _ = YouTubeChannel.objects.update_or_create(channel_id=item["id"], defaults={
            "title": item["snippet"]["title"], "url": f"https://www.youtube.com/channel/{item['id']}",
        })
        run.channel_id = channel.channel_id
        playlist_id = item["contentDetails"]["relatedPlaylists"]["uploads"]
        count, page_token, seen_pages, stop = 0, None, set(), False
        while count < max_videos and not stop:
            params = {"part": "snippet,contentDetails", "playlistId": playlist_id, "maxResults": min(50, max_videos - count)}
            if page_token:
                params["pageToken"] = page_token
            payload = _youtube_get("playlistItems", api_key, params)
            for entry in payload.get("items", []):
                snippet = entry.get("snippet", {})
                details = entry.get("contentDetails", {})
                video_id = details.get("videoId") or snippet.get("resourceId", {}).get("videoId")
                published_at = details.get("videoPublishedAt")
                if not video_id or not published_at or not snippet.get("title"):
                    continue
                existed = Video.objects.filter(video_id=video_id).exists()
                _, created = Video.objects.update_or_create(video_id=video_id, defaults={
                    "channel": channel, "title": snippet["title"], "description": snippet.get("description", ""),
                    "published_at": datetime.fromisoformat(published_at.replace("Z", "+00:00")),
                    "playlist_id": playlist_id, "url": f"https://www.youtube.com/watch?v={video_id}",
                    "topics": classify_topics(snippet["title"] + " " + snippet.get("description", "")),
                })
                run.created_count += int(created)
                run.updated_count += int(not created)
                count += 1
                if incremental and existed:
                    stop = True
                    break
                if count >= max_videos:
                    break
            page_token = payload.get("nextPageToken")
            if not page_token or page_token in seen_pages:
                break
            seen_pages.add(page_token)
        run.status, run.finished_at = CollectorRun.Status.SUCCESS, timezone.now()
        run.save(update_fields=["channel_id", "created_count", "updated_count", "status", "finished_at"])
        return count
    except Exception as exc:
        run.status, run.finished_at = CollectorRun.Status.FAILED, timezone.now()
        run.error = str(exc)[:500]
        run.save(update_fields=["channel_id", "created_count", "updated_count", "status", "finished_at", "error"])
        raise


TIMESTAMP = re.compile(r"(?:(\d+):)?(\d{2}):(\d{2})[.,](\d{3})")


def _milliseconds(value):
    match = TIMESTAMP.fullmatch(value.strip())
    if not match:
        raise ValueError(f"Invalid subtitle timestamp: {value}")
    hours, minutes, seconds, millis = match.groups()
    return ((int(hours or 0) * 60 + int(minutes)) * 60 + int(seconds)) * 1000 + int(millis)


def parse_subtitles(content):
    """Parse SRT or simple WebVTT cues; reject malformed or empty content."""
    content = content.lstrip("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    if content.startswith("WEBVTT"):
        content = content.split("\n", 1)[1]
    cues = []
    for block in re.split(r"\n\s*\n", content.strip()):
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        timing = next((i for i, line in enumerate(lines) if "-->" in line), None)
        if timing is None:
            continue
        start, end = [part.strip().split(" ")[0] for part in lines[timing].split("-->", 1)]
        text = " ".join(re.sub(r"<[^>]+>", "", line) for line in lines[timing + 1:]).strip()
        text = re.sub(r"\s+", " ", text)
        start_ms, end_ms = _milliseconds(start), _milliseconds(end)
        if text and end_ms > start_ms:
            cues.append((start_ms, end_ms, text))
    if not cues:
        raise ValueError("No valid subtitle cues found")
    return cues


@transaction.atomic
def import_transcript(video_id, language, content, rights_note):
    if not rights_note.strip():
        raise ValueError("A rights note confirming permission is required")
    video = Video.objects.get(video_id=video_id)
    cues = parse_subtitles(content)
    digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
    transcript, created = Transcript.objects.get_or_create(
        video=video, language=language, content_sha256=digest,
        defaults={"source": "authorized_import", "rights_note": rights_note},
    )
    if created:
        # Group adjacent cues into searchable passages, preserving their original times.
        group = []
        for cue in cues:
            if group and (sum(len(part[2]) for part in group) + len(cue[2]) > 850 or cue[0] - group[-1][1] > 10000):
                text = " ".join(p[2] for p in group)
                KnowledgeChunk.objects.create(transcript=transcript, start_ms=group[0][0], end_ms=group[-1][1], text=text, topics=classify_topics(text))
                group = []
            group.append(cue)
        if group:
            text = " ".join(p[2] for p in group)
            KnowledgeChunk.objects.create(transcript=transcript, start_ms=group[0][0], end_ms=group[-1][1], text=text, topics=classify_topics(text))
    if created:
        video.processing_status = Video.ProcessingStatus.TRANSCRIPT_IMPORTED
        video.save(update_fields=["processing_status"])
    return transcript, created


def ollama_embedding(text):
    response = requests.post(f"{settings.OLLAMA_BASE_URL}/api/embed", json={
        "model": settings.OLLAMA_EMBED_MODEL, "input": text,
    }, timeout=settings.OLLAMA_TIMEOUT)
    response.raise_for_status()
    vector = response.json()["embeddings"][0]
    if not vector or not all(isinstance(x, (int, float)) and math.isfinite(x) for x in vector):
        raise ValueError("Ollama returned an invalid embedding")
    return vector


def index_chunks(limit=100):
    from django.db.models import Q
    chunks = KnowledgeChunk.objects.filter(Q(embedding__isnull=True) | ~Q(embedding_model=settings.OLLAMA_EMBED_MODEL)).order_by("id")[:limit]
    count = 0
    for chunk in chunks:
        chunk.embedding = ollama_embedding(chunk.text)
        chunk.embedding_model = settings.OLLAMA_EMBED_MODEL
        chunk.indexed_at = timezone.now()
        chunk.save(update_fields=["embedding", "embedding_model", "indexed_at"])
        video = chunk.transcript.video
        if not KnowledgeChunk.objects.filter(transcript__video=video).filter(Q(indexed_at__isnull=True) | Q(embedding__isnull=True) | ~Q(embedding_model=settings.OLLAMA_EMBED_MODEL)).exists():
            video.processing_status = Video.ProcessingStatus.EMBEDDED
            video.save(update_fields=["processing_status"])
        count += 1
    return count


def cosine(a, b):
    if len(a) != len(b):
        return 0.0
    denominator = math.sqrt(sum(x*x for x in a) * sum(y*y for y in b))
    return sum(x*y for x, y in zip(a, b)) / denominator if denominator else 0.0


def retrieve(query, limit=5):
    candidates = KnowledgeChunk.objects.filter(embedding_model=settings.OLLAMA_EMBED_MODEL).select_related("transcript__video")
    if not candidates.exists():
        return []
    vector = ollama_embedding(query)
    ranked = sorted(((cosine(vector, chunk.embedding), chunk) for chunk in candidates if chunk.embedding), key=lambda pair: pair[0], reverse=True)
    return [(score, chunk) for score, chunk in ranked[:limit] if score >= settings.RAG_MIN_SCORE]


GENERAL_NOTICE = "Đây là giải thích từ mô hình AI, chưa được đối chiếu với tài liệu ICT đã nhập."


def ollama_generate(prompt):
    reasoning_model = settings.OLLAMA_CHAT_MODEL.startswith("qwen3")
    payload = {
        "model": settings.OLLAMA_CHAT_MODEL, "stream": False, "think": reasoning_model,
        "prompt": prompt,
        "options": {"num_ctx": 2048, "num_predict": 1024 if reasoning_model else 256, "num_thread": 4},
    }
    response = requests.post(f"{settings.OLLAMA_BASE_URL}/api/generate", json=payload, timeout=settings.OLLAMA_TIMEOUT)
    response.raise_for_status()
    payload = response.json()
    answer = payload.get("response")
    if not payload.get("done") or not isinstance(answer, str) or not answer.strip():
        raise ValueError("Ollama returned an empty or incomplete answer")
    if payload.get("done_reason") == "length":
        raise ValueError("Ollama did not finish within the token budget")
    return answer.strip()


def ollama_status():
    try:
        response = requests.get(f"{settings.OLLAMA_BASE_URL}/api/tags", timeout=3)
        response.raise_for_status()
        names = [item["name"] for item in response.json()["models"]]
        def installed(name):
            return name in names or (":" not in name and name + ":latest" in names)
        return {"available": True, "chat_model": settings.OLLAMA_CHAT_MODEL,
                "embedding_model": settings.OLLAMA_EMBED_MODEL,
                "chat_installed": installed(settings.OLLAMA_CHAT_MODEL),
                "embedding_installed": installed(settings.OLLAMA_EMBED_MODEL)}
    except (requests.RequestException, ValueError, KeyError, TypeError):
        return {"available": False, "error": "Không kết nối được Ollama hoặc phản hồi không hợp lệ."}


def answer_question(question, mode="general"):
    if mode not in ("general", "ict"):
        raise ValueError("mode must be general or ict")
    if mode == "general":
        answer = ollama_generate(
            "Giải thích ngắn gọn trong 2-3 câu bằng tiếng Việt kiến thức phổ thông cho câu hỏi sau. "
            "Không nhận đã đọc tài liệu ICT, không tạo trích dẫn hoặc URL nguồn.\n" + question
        )
        answer = GENERAL_NOTICE + "\n\n" + answer
        ChatQuestion.objects.create(question=question, answer=answer, citations=[], model=settings.OLLAMA_CHAT_MODEL)
        return {"answer": answer, "citations": [], "grounded": False, "mode": mode}
    matches = retrieve(question)
    if not matches:
        return {"answer": "Chưa có nội dung ICT được lập chỉ mục phù hợp để trả lời.", "citations": [], "grounded": False, "mode": mode}
    citations = [{"video_title": chunk.transcript.video.title, "video_id": chunk.transcript.video.video_id, "url": chunk.citation_url,
                  "start_ms": chunk.start_ms, "end_ms": chunk.end_ms, "score": round(score, 3)} for score, chunk in matches]
    excerpts = "\n".join(f"[{i}] {chunk.text}" for i, (_, chunk) in enumerate(matches, 1))
    prompt = (
        "Trả lời bằng tiếng Việt chỉ dựa trên các trích đoạn được cung cấp. "
        "Gắn [số] cho từng nhận định có nguồn. Nếu nguồn không đủ, nói rõ chưa đủ bằng chứng. "
        "Phân biệt điều tác giả nói với suy luận của hệ thống. Không đưa ra lời khuyên giao dịch chắc chắn.\n"
        f"Câu hỏi: {question}\nNguồn:\n{excerpts}"
    )
    answer = ollama_generate(prompt)
    if not isinstance(answer, str) or not answer.strip():
        raise ValueError("Ollama returned an empty answer")
    # Only render reference numbers that correspond to retrieved sources.
    if any(int(number) > len(citations) or int(number) < 1 for number in re.findall(r"\[(\d+)\]", answer)) or re.search(r"https?://", answer):
        return {"answer": "Phản hồi chứa nguồn không hợp lệ; chưa đủ bằng chứng để trả lời.", "citations": [], "grounded": False, "mode": mode}
    ChatQuestion.objects.create(question=question, answer=answer, citations=citations, model=settings.OLLAMA_CHAT_MODEL)
    return {"answer": answer, "citations": citations, "grounded": True, "mode": mode}
