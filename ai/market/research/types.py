"""Small immutable contracts shared by the offline research pipeline."""
from dataclasses import dataclass, field
from datetime import datetime
import math


TIMEFRAME_SECONDS = {"M1": 60, "M5": 300, "M15": 900, "H1": 3600,
                     "H4": 14400, "D1": 86400}


@dataclass(frozen=True)
class Bar:
    time: datetime
    open: float
    high: float
    low: float
    close: float
    spread: float
    volume: float = 0.0


@dataclass(frozen=True)
class Candidate:
    id: str
    symbol: str
    timeframe: str
    family: str
    direction: int
    confirmed_at: datetime
    bar_index: int
    stop: float
    source_id: str
    features: dict[str, float | str | None] = field(default_factory=dict)


@dataclass(frozen=True)
class ResearchConfig:
    symbol: str
    timeframe: str
    timeframe_seconds: int
    tick_size: float
    point: float
    atr_period: int = 14
    pivot_left: int = 2
    pivot_right: int = 2
    tolerance_ticks: float = 1.0
    stop_buffer_ticks: float = 1.0
    min_gap_atr: float = 0.1
    impulse_atr: float = 1.2
    impulse_body_ratio: float = 0.6
    max_setup_bars: int = 16
    horizon_bars: int = 16
    target_r: float = 2.0
    commission_r: float = 0.0
    slippage_ticks: float = 1.0

    def __post_init__(self):
        if not self.symbol.strip() or TIMEFRAME_SECONDS.get(self.timeframe) != self.timeframe_seconds:
            raise ValueError("symbol and a matching supported timeframe are required")
        for name in ("tick_size", "point", "min_gap_atr", "impulse_atr", "target_r"):
            value = getattr(self, name)
            if not math.isfinite(value) or value <= 0:
                raise ValueError(f"{name} must be positive and finite")
        for name in ("tolerance_ticks", "stop_buffer_ticks", "commission_r", "slippage_ticks"):
            value = getattr(self, name)
            if not math.isfinite(value) or value < 0:
                raise ValueError(f"{name} must be nonnegative and finite")
        if not math.isfinite(self.impulse_body_ratio) or not 0 < self.impulse_body_ratio <= 1:
            raise ValueError("impulse_body_ratio must be in (0, 1]")
        for name in ("atr_period", "pivot_left", "pivot_right", "max_setup_bars", "horizon_bars"):
            value = getattr(self, name)
            if isinstance(value, bool) or not isinstance(value, int) or value < 1:
                raise ValueError(f"{name} must be a positive integer")
