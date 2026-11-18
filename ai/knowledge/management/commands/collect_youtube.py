from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from knowledge.services import collect_youtube_metadata


class Command(BaseCommand):
    help = "Collect public metadata from the official ICT channel via YouTube Data API"

    def add_arguments(self, parser):
        parser.add_argument("--limit", type=int, default=50)
        parser.add_argument("--full", action="store_true", help="Scan beyond already known videos")

    def handle(self, *args, **options):
        if not settings.YOUTUBE_API_KEY:
            raise CommandError("Set YOUTUBE_API_KEY in .env")
        try:
            count = collect_youtube_metadata(settings.YOUTUBE_API_KEY, options["limit"], incremental=not options["full"])
        except Exception as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(f"Collected {count} video records"))
