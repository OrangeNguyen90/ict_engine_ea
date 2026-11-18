from datetime import datetime, timezone
from unittest.mock import Mock, patch

from django.contrib.auth import get_user_model
from django.test import TestCase

from .models import CollectorRun, KnowledgeChunk, Video, YouTubeChannel
from .services import YouTubeAPIError, collect_youtube_metadata, cosine, import_transcript, index_chunks, parse_subtitles, retrieve


class ChatModeTests(TestCase):
    @patch("knowledge.services.retrieve", side_effect=AssertionError("General must not retrieve"))
    @patch("knowledge.services.ollama_generate", return_value="Open Interest là số hợp đồng đang mở.")
    def test_general_without_documents(self, generate, retrieval):
        response = self.client.post("/api/chat/", {"question": "Open Interest là gì?", "mode": "general"}, content_type="application/json")
        self.assertEqual(response.status_code, 200)
        self.assertIn("chưa được đối chiếu", response.json()["answer"])
        self.assertEqual(response.json()["citations"], [])
        self.assertFalse(response.json()["grounded"])

    @patch("knowledge.services.requests.post")
    def test_empty_ict_never_generates_sources(self, post):
        response = self.client.post("/api/chat/", {"question": "Open Interest?", "mode": "ict"}, content_type="application/json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["citations"], [])
        post.assert_not_called()

    @patch("knowledge.services.ollama_generate", side_effect=__import__("requests").Timeout)
    def test_timeout_returns_visible_error(self, generate):
        response = self.client.post("/api/chat/", {"question": "Open Interest?"}, content_type="application/json")
        self.assertEqual(response.status_code, 503)
        self.assertIn("error", response.json())

    def test_invalid_mode(self):
        response = self.client.post("/api/chat/", {"question": "Open Interest?", "mode": "fake"}, content_type="application/json")
        self.assertEqual(response.status_code, 400)

    @patch("knowledge.services.requests.post")
    @patch("knowledge.services.retrieve")
    def test_ict_rejects_invented_citation(self, retrieve_mock, post):
        chunk = Mock(text="Authorized excerpt", start_ms=7000, end_ms=9000,
                     citation_url="https://www.youtube.com/watch?v=fixture&t=7s")
        chunk.transcript.video.title = "Fixture"
        chunk.transcript.video.video_id = "fixture"
        retrieve_mock.return_value = [(0.9, chunk)]
        post.return_value.json.return_value = {"done": True, "response": "Claim [99]"}
        response = self.client.post("/api/chat/", {"question": "Example question", "mode": "ict"}, content_type="application/json")
        self.assertFalse(response.json()["grounded"])
        self.assertEqual(response.json()["citations"], [])

    @patch("knowledge.services.requests.post")
    def test_empty_generate_is_error(self, post):
        post.return_value.json.return_value = {"done": True, "response": ""}
        response = self.client.post("/api/chat/", {"question": "Open Interest?"}, content_type="application/json")
        self.assertEqual(response.status_code, 503)

    @patch("knowledge.services.requests.post")
    def test_truncated_generation_is_not_presented_as_answer(self, post):
        post.return_value.json.return_value = {"done": True, "response": "Unfinished", "done_reason": "length"}
        response = self.client.post("/api/chat/", {"question": "Open Interest?"}, content_type="application/json")
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("answer", response.json())

    @patch("knowledge.services.requests.post")
    def test_reasoning_is_not_returned_to_user(self, post):
        post.return_value.json.return_value = {"done": True, "response": "Final definition", "thinking": "Private draft"}
        response = self.client.post("/api/chat/", {"question": "Open Interest?"}, content_type="application/json")
        self.assertContains(response, "Final definition")
        self.assertNotContains(response, "Private draft")


class SubtitleTests(TestCase):
    def setUp(self):
        channel = YouTubeChannel.objects.create(channel_id="UCtest", title="Test fixture", url="https://www.youtube.com/channel/UCtest")
        self.video = Video.objects.create(channel=channel, video_id="testvideo", title="Test fixture", description="",
                                          published_at=datetime(2024, 1, 1, tzinfo=timezone.utc), url="https://www.youtube.com/watch?v=testvideo")

    def test_parse_srt_and_import_idempotently(self):
        content = "1\n00:00:01,000 --> 00:00:03,000\nA sample statement.\n\n2\n00:00:03,000 --> 00:00:05,000\nAnother statement.\n"
        self.assertEqual(len(parse_subtitles(content)), 2)
        transcript, created = import_transcript("testvideo", "en", content, "Fixture created for test")
        self.assertTrue(created)
        self.assertEqual(transcript.chunks.count(), 1)
        self.assertEqual(transcript.chunks.first().start_ms, 1000)
        self.video.refresh_from_db()
        self.assertEqual(self.video.processing_status, Video.ProcessingStatus.TRANSCRIPT_IMPORTED)
        self.assertFalse(import_transcript("testvideo", "en", content, "Fixture created for test")[1])
        self.assertEqual(KnowledgeChunk.objects.count(), 1)

    def test_rights_note_required(self):
        with self.assertRaises(ValueError):
            import_transcript("testvideo", "en", "", "")

    def test_api_when_no_index(self):
        response = self.client.post("/api/chat/", data={"question": "What is a fair value gap?", "mode": "ict"}, content_type="application/json")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()["grounded"])
        self.assertEqual(response.json()["citations"], [])


class RetrievalTests(TestCase):
    def test_cosine(self):
        self.assertAlmostEqual(cosine([1, 0], [1, 0]), 1)
        self.assertEqual(cosine([1, 0], [0, 1]), 0)
        self.assertEqual(cosine([1], [1, 0]), 0)

    @patch("knowledge.services.ollama_embedding", return_value=[1.0, 0.0])
    def test_retrieval_preserves_source_and_timestamp(self, embedding):
        channel = YouTubeChannel.objects.create(channel_id="UCfixture", title="Fixture", url="https://www.youtube.com/channel/UCfixture")
        video = Video.objects.create(channel=channel, video_id="fixture123", title="Fixture", published_at=datetime(2024, 1, 1, tzinfo=timezone.utc), url="https://www.youtube.com/watch?v=fixture123")
        transcript, _ = import_transcript("fixture123", "en", "1\n00:00:07,000 --> 00:00:09,000\nExample transcript", "Fixture")
        chunk = transcript.chunks.get()
        chunk.embedding, chunk.embedding_model = [1.0, 0.0], "nomic-embed-text"
        chunk.save()
        results = retrieve("example")
        self.assertEqual(results[0][1].citation_url, "https://www.youtube.com/watch?v=fixture123&t=7s")
        self.assertEqual(results[0][0], 1.0)

    @patch("knowledge.services.ollama_embedding", return_value=[1.0, 0.0])
    def test_index_marks_video_embedded_only_after_all_chunks(self, embedding):
        channel = YouTubeChannel.objects.create(channel_id="UCfixture", title="Fixture", url="https://www.youtube.com/channel/UCfixture")
        video = Video.objects.create(channel=channel, video_id="fixture123", title="Fixture", published_at=datetime(2024, 1, 1, tzinfo=timezone.utc), url="https://www.youtube.com/watch?v=fixture123")
        transcript, _ = import_transcript("fixture123", "en", "1\n00:00:01,000 --> 00:00:02,000\nFair value gap", "Fixture")
        self.assertEqual(index_chunks(1), 1)
        video.refresh_from_db()
        self.assertEqual(video.processing_status, Video.ProcessingStatus.EMBEDDED)
        self.assertIn("FVG", transcript.chunks.get().topics)


class CollectorTests(TestCase):
    @patch("knowledge.services.requests.get")
    def test_official_api_metadata_is_saved(self, get):
        channel_response = Mock()
        channel_response.json.return_value = {"items": [{"id": "UCofficial", "snippet": {"title": "Official"},
            "contentDetails": {"relatedPlaylists": {"uploads": "UUofficial"}}}]}
        video_response = Mock()
        video_response.json.return_value = {"items": [{"snippet": {"title": "Lecture", "description": "Description",
            "publishedAt": "2024-01-02T00:00:00Z", "resourceId": {"videoId": "video123"}},
            "contentDetails": {"videoId": "video123", "videoPublishedAt": "2024-01-01T00:00:00Z"}}]}
        get.side_effect = [channel_response, video_response]
        self.assertEqual(collect_youtube_metadata("test-key", 1), 1)
        video = Video.objects.get(video_id="video123")
        self.assertEqual(video.channel.channel_id, "UCofficial")
        self.assertEqual(video.published_at.date().isoformat(), "2024-01-01")
        self.assertEqual(get.call_args_list[0].kwargs["params"]["forHandle"], "@InnerCircleTrader")
        self.assertEqual(get.call_args_list[1].kwargs["params"]["part"], "snippet,contentDetails")
        self.assertEqual(CollectorRun.objects.latest("id").status, CollectorRun.Status.SUCCESS)

    @patch("knowledge.services.requests.get")
    def test_http_error_does_not_expose_api_key(self, get):
        response = Mock(status_code=403)
        response.json.return_value = {"error": {"errors": [{"reason": "quotaExceeded"}]}}
        get.return_value.raise_for_status.side_effect = __import__("requests").HTTPError(
            "https://www.googleapis.com/youtube/v3/channels?key=secret-key", response=response
        )
        with self.assertRaises(YouTubeAPIError) as error:
            collect_youtube_metadata("secret-key", 1)
        self.assertIn("quotaExceeded", str(error.exception))
        self.assertNotIn("secret-key", str(error.exception))
        self.assertEqual(CollectorRun.objects.latest("id").status, CollectorRun.Status.FAILED)

    @patch("knowledge.services.requests.get")
    def test_incremental_sync_does_not_duplicate(self, get):
        channel = Mock()
        channel.json.return_value = {"items": [{"id": "UCofficial", "snippet": {"title": "Official"},
            "contentDetails": {"relatedPlaylists": {"uploads": "UUofficial"}}}]}
        page = Mock()
        page.json.return_value = {"items": [{"snippet": {"title": "Liquidity lecture", "description": ""},
            "contentDetails": {"videoId": "video123", "videoPublishedAt": "2024-01-01T00:00:00Z"}}]}
        get.side_effect = [channel, page, channel, page]
        self.assertEqual(collect_youtube_metadata("test-key", 5), 1)
        self.assertEqual(collect_youtube_metadata("test-key", 5), 1)
        self.assertEqual(Video.objects.count(), 1)
        self.assertEqual(Video.objects.get().processing_status, Video.ProcessingStatus.TRANSCRIPT_UNAVAILABLE)
        self.assertIn("Liquidity", Video.objects.get().topics)
        self.assertEqual(CollectorRun.objects.latest("id").created_count, 0)

    @patch("knowledge.services.requests.get")
    def test_pages_are_followed(self, get):
        channel = Mock()
        channel.json.return_value = {"items": [{"id": "UCofficial", "snippet": {"title": "Official"},
            "contentDetails": {"relatedPlaylists": {"uploads": "UUofficial"}}}]}
        pages = []
        for index in range(2):
            page = Mock()
            page.json.return_value = {"items": [{"snippet": {"title": f"Lecture {index}"},
                "contentDetails": {"videoId": f"video{index}", "videoPublishedAt": "2024-01-01T00:00:00Z"}}]}
            if index == 0:
                page.json.return_value["nextPageToken"] = "next"
            pages.append(page)
        get.side_effect = [channel, *pages]
        self.assertEqual(collect_youtube_metadata("test-key", 5, incremental=False), 2)
        self.assertEqual(Video.objects.count(), 2)
        self.assertEqual(get.call_args_list[2].kwargs["params"]["pageToken"], "next")


class DashboardTests(TestCase):
    def test_dashboard_and_staff_queue(self):
        channel = YouTubeChannel.objects.create(channel_id="UCreal", title="Official", url="https://www.youtube.com/channel/UCreal")
        Video.objects.create(channel=channel, video_id="realvideo", title="Real API metadata", published_at=datetime(2024, 1, 1, tzinfo=timezone.utc), url="https://www.youtube.com/watch?v=realvideo")
        response = self.client.get("/")
        self.assertContains(response, "Real API metadata")
        self.assertContains(response, "TRANSCRIPT_UNAVAILABLE")
        self.assertEqual(self.client.post("/collector/sync/").status_code, 302)
        self.assertEqual(CollectorRun.objects.count(), 0)
        user = get_user_model().objects.create_user("staff", password="test-password", is_staff=True)
        self.client.force_login(user)
        self.assertEqual(self.client.post("/collector/sync/").status_code, 302)
        self.assertEqual(CollectorRun.objects.count(), 1)
        self.assertEqual(self.client.post("/collector/sync/").status_code, 302)
        self.assertEqual(CollectorRun.objects.count(), 1)
