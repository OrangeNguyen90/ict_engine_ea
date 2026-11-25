#ifndef ICT_SWEEP_FOCUS_FIXTURES_MQH
#define ICT_SWEEP_FOCUS_FIXTURES_MQH
void ICTFocusFixture(MqlRates &r[],SICTRangeLiquidityEvent &e,SICTSweepFocusConfig &c)
  {
   ArrayResize(r,70);
   double wave[8]={0,0.5,1,1.5,1,0.5,0,-0.5};
   for(int i=0;i<70;i++)
     {
      MqlRates b; ZeroMemory(b); b.time=(datetime)(1000000+i*60);
      double center=100+i*0.1+wave[i%8];
      b.open=center-0.1; b.close=center; b.high=center+0.3; b.low=center-0.3;
      r[i]=b;
     }
   r[40].open=104.5; r[40].close=104.3; r[40].high=106; r[40].low=103.8;
   r[41].open=104.4; r[41].close=101.5; r[41].high=104.5; r[41].low=101.2;
   ZeroMemory(e); e.id="focus-bsl"; e.pool_id="native-pool"; e.side=1;
   e.type=IR_EVENT_LIQUIDITY_SWEEP; e.membership=IR_BOUNDARY;
   e.source_tf=PERIOD_M5; e.event_tf=PERIOD_M1; e.sweep_number=1;
   e.bar_time=r[40].time; e.wick_time=e.bar_time; e.confirmed_at=e.bar_time+60;
   e.level=r[35].high; e.wick=r[40].high; e.close=r[40].close;
   c.left=2; c.right=2; c.max_bars=12; c.buffer_ticks=1;
   c.require_displacement=true; c.body_atr=1; c.body_fraction=0.6;
  }
void ICTFocusH1Fixture(MqlRates &r[],SICTSweepFocus &v)
  {
   ArrayResize(r,124);
   double wave[8]={0,0.5,1,1.5,1,0.5,0,-0.5};
   datetime start=D'2026.11.02';
   for(int i=0;i<124;i++)
     {
      MqlRates b; ZeroMemory(b); b.time=start+i*3600;
      double center=100+i*0.1+wave[i%8];
      b.open=center-0.1; b.close=center; b.high=center+0.3; b.low=center-0.3;
      r[i]=b;
     }
   ZeroMemory(v); v.valid=true; v.event.side=-1;
   v.event.confirmed_at=r[119].time+3600;
  }
void RunICTSweepFocusH1Fixtures()
  {
   MqlRates h1[]; SICTSweepFocus v;
   ICTFocusH1Fixture(h1,v);
   Check("FOCUS H1 uses confirmed bullish swing structure",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_ready && v.h1_bias==1);
   Check("FOCUS SSL arrow aligns with bullish H1",ICTSweepFocusAlignedH1(v));
   Check("FOCUS H1 includes candle closing exactly at reclaim",v.h1_closed_at==v.event.confirmed_at);
   datetime frozen=v.h1_closed_at;
   h1[120].high=0; // Forming/future H1 values are unobservable at reclaim.
   Check("FOCUS H1 ignores malformed future OHLC",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_bias==1 && v.h1_closed_at==frozen);
   v.event.confirmed_at+=1800;
   Check("FOCUS H1 excludes containing half-closed candle",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_closed_at==frozen);
   v.event.side=1;
   Check("FOCUS BSL arrow opposes bullish H1",!ICTSweepFocusAlignedH1(v));
   v.event.confirmed_at+=1800;
   Check("FOCUS H1 rejects invalid OHLC after its close",!ICTSweepFocusH1Context(h1,124,2,2,v) && !v.h1_ready && v.h1_bias==0 && v.h1_closed_at==0);
   ICTFocusH1Fixture(h1,v);
   Check("FOCUS H1 requires full 120-bar lookback",!ICTSweepFocusH1Context(h1,119,2,2,v) && !v.h1_ready);
   Check("FOCUS H1 rejects count beyond history",!ICTSweepFocusH1Context(h1,125,2,2,v));
   v.event.confirmed_at+=3600;
   Check("FOCUS H1 missing latest closed hour cannot retain old bias",!ICTSweepFocusH1Context(h1,120,2,2,v) && !v.h1_ready);
   ICTFocusH1Fixture(h1,v);
   for(int i=0;i<124;i++)
     { h1[i].open-=i*0.1; h1[i].close-=i*0.1; h1[i].high-=i*0.1; h1[i].low-=i*0.1; }
   Check("FOCUS H1 neutral structure is not directional approval",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_ready && v.h1_bias==0 && !ICTSweepFocusAlignedH1(v));
   ICTFocusH1Fixture(h1,v);
   for(int i=0;i<124;i++)
     {
      double high=h1[i].high; h1[i].high=300-h1[i].low; h1[i].low=300-high;
      h1[i].open=300-h1[i].open; h1[i].close=300-h1[i].close;
     }
   v.event.side=1;
   Check("FOCUS bearish H1 prioritizes BSL downward arrow",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_bias==-1 && ICTSweepFocusAlignedH1(v));
   v.valid=false;
   Check("FOCUS H1 invalid event clears old alignment",!ICTSweepFocusH1Context(h1,124,2,2,v) && !ICTSweepFocusAlignedH1(v));

   SICTSweepFocus older; SICTSweepFocus newer; ZeroMemory(older); ZeroMemory(newer);
   older.valid=true; older.h1_ready=true; older.h1_bias=1;
   older.event.side=-1; older.event.confirmed_at=100; older.event.source_tf=PERIOD_M5;
   newer.valid=true; newer.h1_ready=true; newer.h1_bias=1;
   newer.event.side=1; newer.event.confirmed_at=200; newer.event.source_tf=PERIOD_H4;
   Check("FOCUS aligned H1 outranks newer countertrend arrow",ICTSweepFocusPrefer(older,newer,true) && !ICTSweepFocusPrefer(newer,older,true));
   Check("FOCUS optional H1 preference restores chronological order",ICTSweepFocusPrefer(newer,older,false) && !ICTSweepFocusPrefer(older,newer,false));
   newer.h1_ready=false;
   Check("FOCUS missing H1 cannot outrank verified alignment",ICTSweepFocusPrefer(older,newer,true) && !ICTSweepFocusAlignedH1(newer));
   newer.h1_ready=true; newer.h1_bias=0;
   Check("FOCUS neutral H1 cannot outrank verified alignment",ICTSweepFocusPrefer(older,newer,true) && !ICTSweepFocusAlignedH1(newer));
   newer.h1_bias=1; newer.event.side=-1;
   Check("FOCUS newest aligned arrow wins within aligned group",ICTSweepFocusPrefer(newer,older,true));
   newer.event.confirmed_at=older.event.confirmed_at;
   Check("FOCUS same-time alignment prefers higher source timeframe",ICTSweepFocusPrefer(newer,older,true) && !ICTSweepFocusPrefer(older,newer,true));
   older.h1_bias=0; newer.h1_ready=false; newer.event.confirmed_at=200;
   Check("FOCUS no directional H1 falls back to newest arrow",ICTSweepFocusPrefer(newer,older,true));
   newer.valid=false;
   Check("FOCUS invalid event cannot take a priority slot",!ICTSweepFocusPrefer(newer,older,true));
   older.valid=false; newer.valid=true;
   Check("FOCUS valid event replaces empty priority slot",ICTSweepFocusPrefer(newer,older,true));
  }
void RunICTSweepFocusFixtures()
  {
   MqlRates r[]; SICTRangeLiquidityEvent e; SICTSweepFocusConfig c;
   ICTFocusFixture(r,e,c); SICTSweepFocus v;
   Check("FOCUS accepts only confirmed native sweep",ICTSweepFocusEligible(e,e.confirmed_at,1,PERIOD_M1,true,true));
   Check("FOCUS rejects not-yet-confirmed event",!ICTSweepFocusEligible(e,e.confirmed_at-1,1,PERIOD_M1,true,true));
   Check("FOCUS respects chart timeframe",!ICTSweepFocusEligible(e,e.confirmed_at,1,PERIOD_M5,true,true));
   Check("FOCUS respects hidden external liquidity",!ICTSweepFocusEligible(e,e.confirmed_at,1,PERIOD_M1,true,false));
   e.type=IR_EVENT_FALSE_BREAKOUT;
   Check("FOCUS keeps false breakout distinct",!ICTSweepFocusEligible(e,e.confirmed_at,1,PERIOD_M1,true,true));
   ICTFocusFixture(r,e,c);
   Check("FOCUS waits at sweep close",ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v) && v.status==ICT_FOCUS_WAIT);
   Check("FOCUS freezes confirmed prior low",v.pivot_time==r[31].time && MathAbs(v.pivot_level-r[31].low)<0.000001 && v.prior_bias==1);
   double frozen=v.pivot_level;
   r[41].high=0; // Even malformed future OHLC must not contaminate the prefix.
   Check("FOCUS never reads future candle values",ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v) && v.status==ICT_FOCUS_WAIT && v.pivot_level==frozen);
   ICTFocusFixture(r,e,c);
   Check("FOCUS confirms bearish MSS after sweep",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_MSS && v.mss_time==r[41].time);
   Check("FOCUS timestamps MSS at closed candle",v.mss_confirmed_at==r[41].time+60 && v.mss_confirmed_at>e.confirmed_at);
   r[41].close=103; r[41].open=104;
   Check("FOCUS wick-only structure break is insufficient",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_WAIT);
   ICTFocusFixture(r,e,c); r[41].open=101.6;
   Check("FOCUS requires displacement on first close break",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_WEAK_BREAK);
   c.require_displacement=false;
   Check("FOCUS optional displacement changes explanation only",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_MSS);
   ICTFocusFixture(r,e,c); r[38].low=101; r[38].close=102;
   Check("FOCUS rejects pre-sweep broken swing",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_PREBROKEN);
   ICTFocusFixture(r,e,c); r[40].close=101.5; r[40].low=101; e.close=r[40].close;
   Check("FOCUS does not call same-candle break post-sweep MSS",ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v) && v.status==ICT_FOCUS_PREBROKEN);
   ICTFocusFixture(r,e,c); r[41].close=106.2; r[41].high=106.5;
   Check("FOCUS closes beyond sweep invalidate pending MSS",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_INVALIDATED);
   ICTFocusFixture(r,e,c); c.max_bars=2;
   for(int i=41;i<=42;i++) { r[i].open=104.5; r[i].close=104.3; r[i].high=105; r[i].low=103.8; }
   Check("FOCUS expires on trading candle count",ICTSweepFocusAnalyze(r,70,e,r[42].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_EXPIRED && v.closed_after==2);
   ICTFocusFixture(r,e,c);
   for(int i=0;i<40;i++) { r[i].open-=i*0.1; r[i].close-=i*0.1; r[i].high-=i*0.1; r[i].low-=i*0.1; }
   r[41].close=97; r[41].low=96;
   Check("FOCUS neutral prior structure yields break, not MSS",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_BOS && v.prior_bias==0);
   ICTFocusFixture(r,e,c);
   for(int i=0;i<70;i++)
     {
      double high=r[i].high; r[i].high=200-r[i].low; r[i].low=200-high;
      r[i].open=200-r[i].open; r[i].close=200-r[i].close;
     }
   e.side=-1; e.level=200-e.level; e.wick=200-e.wick; e.close=200-e.close;
   Check("FOCUS bullish SSL/MSS mirrors bearish rules",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_MSS && v.prior_bias==-1);
   ICTFocusFixture(r,e,c); e.wick+=0.1;
   Check("FOCUS rejects revised native wick",!ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v));
   ICTFocusFixture(r,e,c); c.buffer_ticks=-1;
   Check("FOCUS rejects invalid MSS configuration",!ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v));
   ICTFocusFixture(r,e,c); ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v);
   SICTStatModel model; ZeroMemory(model);
   Check("FOCUS no synthetic probability before fit",!ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v) && !v.forecast_ready);
   model.fitted=true; model.train_end=r[20].time; model.cal_end=r[30].time;
   model.lr_temperature=1; model.deep_temperature=1;
   for(int k=0;k<32;k++) model.scale[k]=1;
   model.lr[0]=0.5;
   Check("FOCUS forecasts from confirmation prefix",ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v) && v.forecast_ready && v.forecast_asof==e.confirmed_at);
   double prob=v.ml[0]; r[41].close=1; r[41].low=0.5;
   Check("FOCUS post-sweep price cannot rewrite forecast features",ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v) && v.ml[0]==prob);
   Check("FOCUS rejects other-timeframe model",!ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M5,v) && !v.forecast_ready);
   model.cal_end=e.bar_time;
   Check("FOCUS rejects calibration including event outcomes",!ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v) && !v.forecast_ready);
   model.train_end=e.bar_time+60; model.cal_end=e.bar_time+120;
   Check("FOCUS rejects training after historical event",!ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v));
   RunICTSweepFocusH1Fixtures();
  }
#endif
