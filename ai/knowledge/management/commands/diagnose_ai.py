"""Read-only runtime checks; never print credentials or remote error bodies."""
import json
import traceback

import requests
from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import connection
from django.test import Client

from knowledge.models import Video, Transcript, KnowledgeChunk, YouTubeChannel, CollectorRun
from knowledge.services import ollama_embedding, retrieve, ollama_generate


class Command(BaseCommand):
    help = "Diagnose database, Ollama, retrieval and chat without importing data"

    def handle(self, *args, **options):
        def check(name, operation):
            try:
                result = operation()
                self.stdout.write(json.dumps({"step": name, "result": result}, ensure_ascii=True))
            except Exception as exc:
                # Frame locations suffice for diagnosis; omit source lines, locals,
                # exception messages and URLs which could contain credentials.
                frames = [{"file": f.filename.rsplit("\\", 1)[-1].rsplit("/", 1)[-1],
                           "line": f.lineno, "function": f.name}
                          for f in traceback.extract_tb(exc.__traceback__)]
                self.stdout.write(json.dumps({"step": name, "error": type(exc).__name__,
                                              "traceback": frames}))

        def database():
            with connection.cursor() as cursor:
                cursor.execute("SELECT version()")
                version = cursor.fetchone()[0]
            return {"version": version, "channels": YouTubeChannel.objects.count(), "videos": Video.objects.count(),
                    "youtube_key_configured": bool(settings.YOUTUBE_API_KEY),
                    "collector_runs": list(CollectorRun.objects.values("status", "created_count", "updated_count")[:5]),
                    "transcripts": Transcript.objects.count(),
                    "chunks": KnowledgeChunk.objects.count(),
                    "embedded_chunks": KnowledgeChunk.objects.filter(embedding__isnull=False).count()}

        def models():
            response = requests.get(f"{settings.OLLAMA_BASE_URL}/api/tags", timeout=15)
            response.raise_for_status()
            return {"chat": settings.OLLAMA_CHAT_MODEL, "embedding": settings.OLLAMA_EMBED_MODEL,
                    "installed": [m["name"] for m in response.json()["models"]]}

        def chat():
            response = requests.post(f"{settings.OLLAMA_BASE_URL}/api/chat", json={
                "model": settings.OLLAMA_CHAT_MODEL, "stream": False, "think": False,
                "options": {"num_predict": 160},
                "messages": [{"role": "user", "content": "Open Interest là gì? Trả lời một câu tiếng Việt."}],
            }, timeout=180)
            response.raise_for_status()
            payload = response.json()
            content = payload["message"]["content"]
            if not payload.get("done") or not isinstance(content, str) or not content.strip():
                raise ValueError("Incomplete response")
            return {"done": True, "answer": content}

        def api():
            response = Client(HTTP_HOST="localhost").post("/api/chat/", data={
                "question": "Open Interest là gì?"}, content_type="application/json")
            return {"status": response.status_code, "body": response.json()}

        check("database", database)
        check("models", models)
        check("embedding", lambda: {"dimensions": len(ollama_embedding("Open Interest"))})
        check("ollama_generate", lambda: {"answer": ollama_generate("Open Interest là gì? Trả lời ngắn gọn bằng tiếng Việt.")})
        check("retrieval", lambda: {"matches": len(retrieve("Open Interest là gì?"))})
        check("chat_api", api)
