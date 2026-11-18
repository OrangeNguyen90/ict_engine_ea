from django.core.management.base import BaseCommand, CommandError

from market.services import ICTAnalysisOrchestrator


class Command(BaseCommand):
    help = "Calculate and store confirmed ICT research signals from imported OHLCV"

    def add_arguments(self, parser):
        parser.add_argument("--symbol", required=True)
        parser.add_argument("--timeframe", required=True)
        parser.add_argument("--data-source", required=True)
        parser.add_argument("--exchange")
        parser.add_argument("--contract", default="")
        parser.add_argument("--price-type", default="trade")
        parser.add_argument("--left-bars", type=int, default=2)
        parser.add_argument("--right-bars", type=int, default=2)
        parser.add_argument("--min-break", default="0")
        parser.add_argument("--fvg-min-gap", default="0")
        parser.add_argument("--liquidity-tolerance", default="0")
        parser.add_argument("--mitigation", choices=["touch", "half", "full"], default="full")
        parser.add_argument("--require-displacement", action="store_true")

    def handle(self, *args, **options):
        try:
            run = ICTAnalysisOrchestrator().analyze(
                symbol=options["symbol"].upper(), timeframe=options["timeframe"].upper(),
                data_source=options["data_source"], exchange=options["exchange"],
                contract=options["contract"], price_type=options["price_type"],
                left_bars=options["left_bars"], right_bars=options["right_bars"],
                min_break=options["min_break"], fvg_min_gap=options["fvg_min_gap"],
                liquidity_tolerance=options["liquidity_tolerance"],
                mitigation=options["mitigation"], require_displacement=options["require_displacement"])
        except ValueError as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(self.style.SUCCESS(
            f"Analysis run {run.pk}: {run.candle_count} actual candles, {run.signals.count()} new signals"))
