from django.core.management.base import BaseCommand, CommandError

from market.data import import_market_file


class Command(BaseCommand):
    help = "Incrementally import real OHLCV records from a CSV or Parquet file"

    def add_arguments(self, parser):
        parser.add_argument("path")
        parser.add_argument("--symbol", required=True)
        parser.add_argument("--exchange", required=True)
        parser.add_argument("--timeframe", required=True)
        parser.add_argument("--data-source", required=True)
        parser.add_argument("--source-timezone", default="UTC")
        parser.add_argument("--contract", default="")
        parser.add_argument("--volume-type", default="unknown")
        parser.add_argument("--price-type", default="trade")
        parser.add_argument("--update-existing", action="store_true")

    def handle(self, *args, **options):
        try:
            batch = import_market_file(
                options["path"], symbol=options["symbol"], exchange=options["exchange"],
                timeframe=options["timeframe"], data_source=options["data_source"],
                source_timezone=options["source_timezone"], contract=options["contract"],
                volume_type=options["volume_type"], price_type=options["price_type"],
                update_existing=options["update_existing"],
            )
        except (OSError, ValueError) as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(
            f"Imported batch {batch.pk}: read={batch.rows_read}, created={batch.rows_created}, "
            f"updated={batch.rows_updated}, skipped={batch.rows_skipped}, invalid={len(batch.warnings)}"
        ))
        for warning in batch.warnings[:20]:
            self.stdout.write(self.style.WARNING(warning))
