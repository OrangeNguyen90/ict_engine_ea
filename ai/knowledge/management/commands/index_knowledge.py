from django.core.management.base import BaseCommand, CommandError
from knowledge.services import index_chunks


class Command(BaseCommand):
    help = "Embed unindexed transcript chunks using local Ollama"

    def add_arguments(self, parser):
        parser.add_argument("--limit", type=int, default=100)

    def handle(self, *args, **options):
        if options["limit"] < 1:
            raise CommandError("--limit must be positive")
        try:
            count = index_chunks(options["limit"])
        except Exception as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(f"Indexed {count} chunks"))
