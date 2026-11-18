from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from knowledge.models import CollectorRun
from knowledge.services import collect_youtube_metadata
import time
from django.db import close_old_connections


class Command(BaseCommand):
    help = "Run one queued YouTube sync outside the HTTP request; schedule this command periodically"

    def add_arguments(self, parser):
        parser.add_argument("--watch", action="store_true", help="Poll the durable queue every five seconds")

    def handle(self, *args, **options):
        while True:
            try:
                self.run_one()
            except CommandError as exc:
                self.stderr.write(str(exc))
                if not options["watch"]:
                    raise
            finally:
                close_old_connections()
            if not options["watch"]:
                return
            time.sleep(5)

    def run_one(self):
        if not settings.YOUTUBE_API_KEY:
            raise CommandError("Set YOUTUBE_API_KEY in .env")
        with transaction.atomic():
            job = CollectorRun.objects.select_for_update(skip_locked=True).filter(status=CollectorRun.Status.PENDING).order_by("requested_at").first()
            if job is None:
                self.stdout.write("No pending sync job")
                return
            job.status = CollectorRun.Status.RUNNING
            job.save(update_fields=["status"])
        try:
            count = collect_youtube_metadata(settings.YOUTUBE_API_KEY, job.limit, incremental=job.incremental, run=job)
        except Exception as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(f"Sync job {job.pk}: processed {count} videos"))
