from pathlib import Path
from django.core.management.base import BaseCommand, CommandError
from knowledge.services import import_transcript


class Command(BaseCommand):
    help = "Import an authorized SRT/VTT file for a known YouTube video"

    def add_arguments(self, parser):
        parser.add_argument("video_id")
        parser.add_argument("file", type=Path)
        parser.add_argument("--language", required=True)
        parser.add_argument("--rights-note", required=True, help="Why you have permission to process this file")

    def handle(self, *args, **options):
        try:
            content = options["file"].read_text(encoding="utf-8")
            transcript, created = import_transcript(options["video_id"], options["language"], content, options["rights_note"])
        except Exception as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(f"Transcript {transcript.pk}: {'imported' if created else 'already present'}"))
