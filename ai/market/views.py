from datetime import datetime, timezone

from django.contrib.admin.views.decorators import staff_member_required
from django.http import HttpResponseBadRequest
from django.shortcuts import redirect, render
from django.views.decorators.http import require_POST
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import ICTAnalysisRun, ICTSignal, MarketCandle
from .services import ICTAnalysisOrchestrator, _jsonable, signal_as_of
from .timeframes import TIMEFRAME_DELTAS
from .engine import ALGORITHM_VERSION
from knowledge.services import ollama_generate
import requests


def _parse(request):
    params = request.query_params if hasattr(request, "query_params") else request.GET
    symbol = params.get("symbol", "").strip().upper()
    timeframe = params.get("timeframe", "").strip().upper()
    if not symbol or len(symbol) > 40 or timeframe not in TIMEFRAME_DELTAS:
        raise ValueError("valid symbol and timeframe are required")
    dates = {}
    for key in ("start", "end", "as_of"):
        raw = params.get(key)
        if raw:
            try:
                parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
            except ValueError as exc:
                raise ValueError(f"invalid {key} timestamp") from exc
            if parsed.tzinfo is None:
                raise ValueError(f"{key} must include a timezone offset")
            dates[key] = parsed.astimezone(timezone.utc)
    if dates.get("start") and dates.get("end") and dates["start"] > dates["end"]:
        raise ValueError("start must be before end")
    limit = params.get("limit", "500")
    try:
        limit = int(limit)
    except ValueError as exc:
        raise ValueError("limit must be an integer") from exc
    if not 1 <= limit <= 2000:
        raise ValueError("limit must be 1..2000")
    return params, symbol, timeframe, dates, limit


@api_view(["GET"])
def candles_api(request):
    try:
        params, symbol, timeframe, dates, limit = _parse(request)
    except ValueError as exc:
        return Response({"error": str(exc)}, status=400)
    query = MarketCandle.objects.filter(symbol=symbol, timeframe=timeframe)
    for field in ("data_source", "exchange", "contract", "price_type"):
        if field in params:
            query = query.filter(**{field: params[field]})
    series = list(query.order_by().values("data_source", "exchange", "contract", "price_type").distinct()[:2])
    if len(series) > 1:
        return Response({"error": "select one data_source, exchange, contract, and price_type"}, status=400)
    if dates.get("start"):
        query = query.filter(timestamp__gte=dates["start"])
    if dates.get("end"):
        query = query.filter(timestamp__lte=dates["end"])
    dates.setdefault("as_of", datetime.now(timezone.utc))
    if dates.get("as_of"):
        interval = TIMEFRAME_DELTAS[timeframe]
        if interval is None:
            query = query.filter(timestamp__lt=dates["as_of"].replace(day=1, hour=0, minute=0, second=0, microsecond=0))
        else:
            query = query.filter(timestamp__lte=dates["as_of"] - interval)
    rows = list(query.order_by("timestamp").values(
        "id", "symbol", "exchange", "contract", "timestamp", "timeframe", "open", "high",
        "low", "close", "volume", "volume_type", "data_source", "price_type")[:limit])
    return Response({"count": len(rows), "results": _jsonable(rows),
                     "message": "no market candles for this selection" if not rows else ""})


@api_view(["GET"])
def signals_api(request, category=None):
    try:
        params, symbol, timeframe, dates, limit = _parse(request)
    except ValueError as exc:
        return Response({"error": str(exc)}, status=400)
    query = ICTSignal.objects.filter(symbol=symbol, timeframe=timeframe)
    query = query.filter(algorithm_version=params.get("algorithm_version", ALGORITHM_VERSION))
    runs = ICTAnalysisRun.objects.filter(symbol=symbol, timeframe=timeframe,
                                         algorithm_version=params.get("algorithm_version", ALGORITHM_VERSION))
    if params.get("data_source"):
        runs = runs.filter(data_source=params["data_source"])
    for field in ("exchange", "contract", "price_type"):
        if field in params:
            runs = runs.filter(**{f"parameters__{field}": params[field]})
    if params.get("run_id"):
        try:
            runs = runs.filter(pk=int(params["run_id"]))
        except ValueError:
            return Response({"error": "run_id must be an integer"}, status=400)
    latest_run = runs.first()
    query = query.filter(signal_key__in=latest_run.signal_keys if latest_run else [])
    if category:
        query = query.filter(category=category)
    if params.get("data_source"):
        query = query.filter(data_source=params["data_source"])
    for field in ("exchange", "contract", "price_type", "data_revision"):
        if field in params:
            query = query.filter(**{f"payload__{field}": params[field]})
    if params.get("signal_type"):
        query = query.filter(signal_type=params["signal_type"])
    if dates.get("start"):
        query = query.filter(confirmed_at__gte=dates["start"])
    if dates.get("end"):
        query = query.filter(confirmed_at__lte=dates["end"])
    dates.setdefault("as_of", datetime.now(timezone.utc))
    query = query.filter(confirmed_at__lte=dates["as_of"])
    if not params.get("status"):
        query = query[:limit]
    results = []
    for signal in query.iterator():
        payload = signal_as_of(signal, dates["as_of"]) if dates.get("as_of") else signal.payload
        if payload and (not params.get("status") or payload["status"] == params["status"]):
            results.append({"id": signal.id, **payload})
            if len(results) == limit:
                break
    return Response({"count": len(results), "results": results, "run_id": latest_run.pk if latest_run else None,
                     "message": ("insufficient_structure" if category == "dealing_range" else "no confirmed signals for this selection") if not results else ""})


@api_view(["POST"])
def explanation_api(request):
    symbol = str(request.data.get("symbol", "")).strip().upper()
    timeframe = str(request.data.get("timeframe", "")).strip().upper()
    source = str(request.data.get("data_source", "")).strip()
    if not symbol or timeframe not in TIMEFRAME_DELTAS or not source:
        return Response({"error": "symbol, timeframe, and data_source are required"}, status=400)
    from .engine import candle_close_at
    cutoff = datetime.now(timezone.utc)
    latest = next((row for row in MarketCandle.objects.filter(
        symbol=symbol, timeframe=timeframe, data_source=source).order_by("-timestamp")
        if candle_close_at({"timestamp": row.timestamp}, timeframe) <= cutoff), None)
    if latest is None:
        return Response({"error": "no actual OHLCV available"}, status=404)
    run = ICTAnalysisRun.objects.filter(symbol=symbol, timeframe=timeframe, data_source=source,
                                        algorithm_version=ALGORITHM_VERSION).first()
    if run is None:
        return Response({"error": "run ICT analysis before requesting an explanation"}, status=409)
    signals = list(ICTSignal.objects.filter(signal_key__in=run.signal_keys, confirmed_at__lte=cutoff)
                   .order_by("-confirmed_at").values("category", "signal_type", "direction", "confirmed_at", "status", "payload")[:20])
    evidence = {"symbol": symbol, "timeframe": timeframe, "source": source,
                "last_candle": _jsonable({"timestamp": latest.timestamp, "close": latest.close}),
                "confirmed_signals": _jsonable(signals)}
    prompt = ("Giải thích bằng tiếng Việt dữ liệu cấu trúc dưới đây. Phân biệt dữ liệu thực, kết quả thuật toán hệ thống, "
              "và giả thuyết. Chỉ dùng mức giá và tín hiệu có trong JSON. Không đưa ra xác suất thắng hay lời khuyên giao dịch.\n"
              + __import__("json").dumps(evidence, ensure_ascii=False))
    try:
        narrative = ollama_generate(prompt)
    except (requests.RequestException, ValueError, KeyError, TypeError):
        return Response({"error": "Ollama unavailable"}, status=503)
    return Response({"explanation": narrative, "evidence": evidence,
                     "note": "AI explanation is a hypothesis; structured evidence is authoritative."})


def market_dashboard(request):
    symbols = list(MarketCandle.objects.order_by("symbol").values_list("symbol", flat=True).distinct()[:200])
    return render(request, "market/analysis.html", {"symbols": symbols, "timeframes": TIMEFRAME_DELTAS})


@staff_member_required
@require_POST
def run_analysis(request):
    symbol = request.POST.get("symbol", "").strip().upper()
    timeframe = request.POST.get("timeframe", "").strip().upper()
    source = request.POST.get("data_source", "").strip()
    if not symbol or timeframe not in TIMEFRAME_DELTAS or not source:
        return HttpResponseBadRequest("symbol, timeframe, and data_source are required")
    try:
        ICTAnalysisOrchestrator().analyze(symbol=symbol, timeframe=timeframe, data_source=source,
                                          exchange=request.POST.get("exchange") or None,
                                          contract=request.POST.get("contract", ""),
                                          price_type=request.POST.get("price_type", "trade"))
    except ValueError as exc:
        return HttpResponseBadRequest(str(exc))
    return redirect(f"/market/?symbol={symbol}&timeframe={timeframe}")
