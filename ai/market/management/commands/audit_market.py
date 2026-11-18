"""Read-only evidence for market-data acceptance; never prints credentials."""
import json

from django.core.management.base import BaseCommand
from django.db import connection
from django.db.models import Count, Max, Min

from market.models import ImportBatch, MarketCandle


class Command(BaseCommand):
    help = "Report actual stored series, source provenance, and database backend"

    def handle(self, *args, **options):
        series = list(MarketCandle.objects.order_by().values(
            "symbol", "timeframe", "data_source", "exchange", "contract", "price_type"
        ).annotate(candles=Count("id"), first_open=Min("timestamp"), last_open=Max("timestamp")))
        report = {
            "database_backend": connection.vendor,
            "candle_count": MarketCandle.objects.count(),
            "series": series,
            "recent_imports": list(ImportBatch.objects.values(
                "id", "source_file", "data_source", "imported_at", "file_sha256",
                "rows_read", "rows_created", "rows_updated", "rows_skipped", "warnings")[:10]),
        }
        self.stdout.write(json.dumps(report, default=str, ensure_ascii=False, indent=2))
