from django.db import models
from django.db.models import Q


class MarketCandle(models.Model):
    class VolumeType(models.TextChoices):
        BASE = "base", "Base asset"
        QUOTE = "quote", "Quote asset"
        TICK = "tick", "Tick volume"
        CONTRACTS = "contracts", "Contracts"
        UNKNOWN = "unknown", "Unknown"

    class PriceType(models.TextChoices):
        TRADE = "trade", "Trade"
        BID = "bid", "Bid"
        ASK = "ask", "Ask"
        MID = "mid", "Mid"

    symbol = models.CharField(max_length=40)
    exchange = models.CharField(max_length=80)
    contract = models.CharField(max_length=80, blank=True)
    timestamp = models.DateTimeField(help_text="Candle open time, normalized to UTC")
    timeframe = models.CharField(max_length=8)
    open = models.DecimalField(max_digits=24, decimal_places=10)
    high = models.DecimalField(max_digits=24, decimal_places=10)
    low = models.DecimalField(max_digits=24, decimal_places=10)
    close = models.DecimalField(max_digits=24, decimal_places=10)
    volume = models.DecimalField(max_digits=30, decimal_places=10, null=True, blank=True)
    volume_type = models.CharField(max_length=12, choices=VolumeType.choices, default=VolumeType.UNKNOWN)
    data_source = models.CharField(max_length=100)
    price_type = models.CharField(max_length=8, choices=PriceType.choices, default=PriceType.TRADE)
    provenance = models.ForeignKey("ImportBatch", on_delete=models.PROTECT, related_name="candles")

    class Meta:
        ordering = ["timestamp"]
        constraints = [
            models.UniqueConstraint(fields=["symbol", "exchange", "contract", "timestamp", "timeframe", "data_source", "price_type"], name="market_candle_unique_key"),
            models.CheckConstraint(condition=Q(high__gte=models.F("low")), name="market_high_gte_low"),
            models.CheckConstraint(condition=Q(volume__isnull=True) | Q(volume__gte=0), name="market_volume_nonnegative"),
        ]
        indexes = [models.Index(fields=["symbol", "timeframe", "timestamp"])]


class ImportBatch(models.Model):
    source_file = models.CharField(max_length=500)
    file_sha256 = models.CharField(max_length=64)
    data_source = models.CharField(max_length=100)
    imported_at = models.DateTimeField(auto_now_add=True)
    rows_read = models.PositiveIntegerField(default=0)
    rows_created = models.PositiveIntegerField(default=0)
    rows_updated = models.PositiveIntegerField(default=0)
    rows_skipped = models.PositiveIntegerField(default=0)
    warnings = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ["-imported_at"]


class ICTAnalysisRun(models.Model):
    symbol = models.CharField(max_length=40)
    timeframe = models.CharField(max_length=8)
    data_source = models.CharField(max_length=100)
    algorithm_version = models.CharField(max_length=40)
    parameters = models.JSONField(default=dict)
    candle_count = models.PositiveIntegerField()
    last_candle_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    signal_keys = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ["-created_at"]


class ICTSignal(models.Model):
    """Versioned confirmed signal; state_history preserves later changes."""
    signal_key = models.CharField(max_length=64, unique=True)
    category = models.CharField(max_length=24)
    signal_type = models.CharField(max_length=24, blank=True)
    direction = models.CharField(max_length=12, blank=True)
    symbol = models.CharField(max_length=40)
    timeframe = models.CharField(max_length=8)
    data_source = models.CharField(max_length=100)
    algorithm_version = models.CharField(max_length=40)
    parameters = models.JSONField(default=dict)
    formed_at = models.DateTimeField()
    confirmed_at = models.DateTimeField()
    status = models.CharField(max_length=24)
    state_history = models.JSONField(default=list)
    evidence_ids = models.JSONField(default=list)
    payload = models.JSONField(default=dict)
    first_run = models.ForeignKey(ICTAnalysisRun, on_delete=models.PROTECT, related_name="signals")

    class Meta:
        ordering = ["confirmed_at", "id"]
        indexes = [
            models.Index(fields=["symbol", "timeframe", "category", "confirmed_at"]),
            models.Index(fields=["data_source", "algorithm_version"]),
        ]
