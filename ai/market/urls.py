from django.urls import path

from . import views

urlpatterns = [
    path("market/", views.market_dashboard, name="market_dashboard"),
    path("market/analyze/", views.run_analysis, name="run_market_analysis"),
    path("api/ict/candles/", views.candles_api, name="ict_candles"),
    path("api/ict/swings/", views.signals_api, {"category": "swing"}, name="ict_swings"),
    path("api/ict/market-structure/", views.signals_api, {"category": "structure"}, name="ict_structure"),
    path("api/ict/fvg/", views.signals_api, {"category": "fvg"}, name="ict_fvg"),
    path("api/ict/liquidity/", views.signals_api, {"category": "liquidity"}, name="ict_liquidity"),
    path("api/ict/liquidity-events/", views.signals_api, {"category": "liquidity_event"}, name="ict_liquidity_events"),
    path("api/ict/premium-discount/", views.signals_api, {"category": "dealing_range"}, name="ict_ranges"),
    path("api/ict/analysis/", views.signals_api, name="ict_analysis"),
    path("api/ict/explain/", views.explanation_api, name="ict_explain"),
]
