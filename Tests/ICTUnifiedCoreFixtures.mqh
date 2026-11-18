#include "ICTConfluenceLifecycleFixtures.mqh"
#include "ICTSessionLiquidityFixtures.mqh"
#include "ICTSignalJournalLiveFixtures.mqh"
#include "ICTPositionRiskFixtures.mqh"
// Deterministic fixture data is confined to Tests. Production never creates OHLC.
void FixtureBar(MqlRates &b,const datetime t,const double open,const double high,const double low,const double close)
  { ZeroMemory(b); b.time=t; b.open=open; b.high=high; b.low=low; b.close=close; }
void FlatFixture(MqlRates &bars[],const int count)
  {
   ArrayResize(bars,count);
   for(int i=0;i<count;i++) FixtureBar(bars[i],100000+i*300,95,100,90,95);
  }
void TestUnifiedMappingCalendar()
  {
   ENUM_TIMEFRAMES chart[]={PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,PERIOD_M10,PERIOD_M12,PERIOD_M15,PERIOD_M20,
      PERIOD_M30,PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
   ENUM_TIMEFRAMES mid[]={PERIOD_M15,PERIOD_M15,PERIOD_M15,PERIOD_M15,PERIOD_H1,PERIOD_H1,PERIOD_H1,PERIOD_H1,PERIOD_H1,PERIOD_H1,
      PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_W1,PERIOD_MN1,PERIOD_CURRENT};
   ENUM_TIMEFRAMES high[]={PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,
      PERIOD_D1,PERIOD_D1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_MN1,PERIOD_CURRENT,PERIOD_CURRENT};
   SICTTimeframes f;
   for(int i=0;i<ArraySize(chart);i++)
      Check("AUTO map "+EnumToString(chart[i]),ICTMapTimeframes(chart[i],ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f) && f.ltf==chart[i] && f.mtf==mid[i] && f.htf==high[i]);
   ICTMapTimeframes(PERIOD_M5,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f);
   ICTMapTimeframes(PERIOD_M1,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f);
   Check("chart change removes old H1",f.mtf==PERIOD_M15 && f.htf==PERIOD_H4);
   ICTMapTimeframes(PERIOD_H4,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f);
   Check("chart change to H4",f.mtf==PERIOD_D1 && f.htf==PERIOD_W1);
   Check("valid manual",ICTMapTimeframes(PERIOD_M5,ICT_MTF_MANUAL,PERIOD_H2,PERIOD_W1,f));
   Check("manual wrong order",!ICTMapTimeframes(PERIOD_H1,ICT_MTF_MANUAL,PERIOD_M15,PERIOD_D1,f));
   Check("manual missing middle",!ICTMapTimeframes(PERIOD_M5,ICT_MTF_MANUAL,PERIOD_CURRENT,PERIOD_D1,f));
   Check("W1 two tier",ICTMapTimeframes(PERIOD_W1,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f) && f.status==ICT_MTF_TWO_TIER);
   Check("MN1 one tier",ICTMapTimeframes(PERIOD_MN1,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f) && f.status==ICT_MTF_ONE_TIER);
   Check("31-day month",ICTBarClose(PERIOD_MN1,D'2026.01.01')==D'2026.02.01');
   Check("leap month",ICTBarClose(PERIOD_MN1,D'2024.02.01')==D'2024.03.01');
   Check("28-day month",ICTBarClose(PERIOD_MN1,D'2026.02.01')==D'2026.03.01');
   Check("year rollover",ICTBarClose(PERIOD_MN1,D'2026.12.01')==D'2027.01.01');
   MqlRates months[2]; FixtureBar(months[0],D'2026.01.01',100,101,99,100); FixtureBar(months[1],D'2026.02.01',100,101,99,100);
   Check("HTF unfinished month excluded",ICTClosedPrefix(months,2,PERIOD_MN1,D'2026.01.31 23:59:59')==0);
   Check("HTF month available only after close",ICTClosedPrefix(months,2,PERIOD_MN1,D'2026.02.01')==1);
   Check("aligned BUY matrix",ICTTierAlignment(true,1,1,1)==ICT_TIER_ALIGNED);
   Check("aligned SELL matrix",ICTTierAlignment(true,-1,-1,-1)==ICT_TIER_ALIGNED);
   Check("counter trend WAIT",ICTTierAlignment(true,1,-1,1)==ICT_TIER_CONFLICT);
   Check("neutral no trade",ICTTierAlignment(true,0,1,1)==ICT_TIER_NEUTRAL);
   Check("missing data no trade",ICTTierAlignment(false,1,1,1)==ICT_TIER_INSUFFICIENT);
   Check("independent LTF override remaps automatic upper tiers",ICTResolveTimeframes(PERIOD_M1,true,PERIOD_M5,PERIOD_CURRENT,PERIOD_CURRENT,f) &&
      f.ltf==PERIOD_M5 && f.mtf==PERIOD_H1 && f.htf==PERIOD_D1);
   Check("independent MTF override preserves HTF",ICTResolveTimeframes(PERIOD_M5,true,PERIOD_CURRENT,PERIOD_H4,PERIOD_CURRENT,f) &&
      f.ltf==PERIOD_M5 && f.mtf==PERIOD_H4 && f.htf==PERIOD_D1);
   Check("independent HTF override preserves MTF",ICTResolveTimeframes(PERIOD_M5,true,PERIOD_CURRENT,PERIOD_CURRENT,PERIOD_W1,f) && f.mtf==PERIOD_H1 && f.htf==PERIOD_W1);
   Check("independent invalid ordering rejected",!ICTResolveTimeframes(PERIOD_M5,true,PERIOD_CURRENT,PERIOD_D1,PERIOD_H4,f));
  }
void TestUnifiedSMT()
  {
   MqlRates a[],b[]; FlatFixture(a,90); FlatFixture(b,90);
   a[51].high=110; a[65].high=115; b[52].high=112; b[66].high=111;
   SSMTDivergence s;
   Check("positive bearish mismatched but nearby confirmed pivots",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,1,0.1,0.1,-1,s) && s.direction==-1 && !s.comparator_extreme);
   string id=s.event_id;
   Check("no future right bar",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,67,b,67,2,2,2,1,0.1,0.1,-1,s));
   Check("comparator right bar must close",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,68,b,68,2,2,2,1,0.1,0.1,-1,s));
   Check("confirmed at actual prefix close",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,69,b,69,2,2,2,1,0.1,0.1,-1,s) && s.confirmation_time==ICTBarClose(PERIOD_M5,a[68].time));
   Check("gap outside tolerance rejected",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,0,1,0.1,0.1,-1,s));
   a[65].high=109; b[66].high=115;
   Check("comparator-only source is explicit",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,1,0.1,0.1,-1,s) && s.comparator_extreme);
   FlatFixture(a,90); FlatFixture(b,90); a[51].low=85; a[65].low=80; b[52].low=84; b[66].low=86;
   Check("positive bullish",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,1,0.1,0.1,1,s));
   FlatFixture(a,90); FlatFixture(b,90); a[51].high=110; a[65].high=115; b[52].low=85; b[66].low=86;
   Check("inverse HH versus LL",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,-1,0.1,0.1,-1,s));
   FlatFixture(a,90); FlatFixture(b,90); a[51].low=85; a[65].low=80; b[52].high=110; b[66].high=109;
   Check("inverse LL versus HH",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,-1,0.1,0.1,1,s));
   b[66].high=115;
   Check("inverse matching extreme is not divergence",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,-1,0.1,0.1,1,s));
   FlatFixture(a,90); FlatFixture(b,90); a[51].high=110; a[65].high=115; b[52].high=112; b[66].high=111;
   MqlRates missing[]; ArrayResize(missing,79);
   for(int i=0;i<79;i++) missing[i]=b[i<60 ? i : i+1];
   Check("missing session bar does not create SMT",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,missing,79,2,2,2,1,0.1,0.1,-1,s));
   SICTDynamicSMTConfig c; ICTDefaultDynamicSMTConfig(c); c.relation=SMT_POSITIVE;
   SICTSMTEvent events[]; bool related=false;
   ICTReplaySMT("A","B",PERIOD_M5,a,80,b,80,0.1,0.1,c,events,related);
   Check("one event, not one event per refresh/bar",ArraySize(events)==1 && !events[0].seed_context);
   datetime confirmation=(ArraySize(events)>0 ? events[0].signal.confirmation_time : 0);
   string event_id=(ArraySize(events)>0 ? events[0].signal.event_id : "");
   a[85].high=120;
   ICTReplaySMT("A","B",PERIOD_M5,a,90,b,90,0.1,0.1,c,events,related);
   Check("first confirmation and ID immutable with future suffix",ArraySize(events)>=1 && events[0].signal.confirmation_time==confirmation && events[0].signal.event_id==event_id);
   Check("display includes bar sixty boundary",ICTSMTInsideDisplayWindow(1000,1000,2000));
   Check("display excludes earlier confirmation",!ICTSMTInsideDisplayWindow(999,1000,2000));
   Check("display excludes future confirmation",!ICTSMTInsideDisplayWindow(2001,1000,2000));
   SICTTimeframes map; ICTMapTimeframes(PERIOD_M5,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,map);
   ENUM_TIMEFRAMES frames[];
   Check("AUTO_ALL three distinct frames",ICTSMTTimeframes(map,AUTO_ALL,PERIOD_H1,frames)==3 && frames[0]==PERIOD_M5 && frames[1]==PERIOD_H1 && frames[2]==PERIOD_D1);
   Check("AUTO chart override adds independent SMT source",ICTSMTTimeframes(map,AUTO_ALL,PERIOD_H1,frames,PERIOD_M1)==4 &&
      frames[0]==PERIOD_M5 && frames[1]==PERIOD_H1 && frames[2]==PERIOD_D1 && frames[3]==PERIOD_M1);
   Check("AUTO chart matching LTF reuses source",ICTSMTTimeframes(map,AUTO_ALL,PERIOD_H1,frames,PERIOD_M5)==3);
   Check("MANUAL pins SMT despite chart override",ICTSMTTimeframes(map,SMT_MANUAL,PERIOD_H2,frames,PERIOD_M1)==1 && frames[0]==PERIOD_H2);
   Check("AUTO_LTF",ICTSMTTimeframes(map,AUTO_LTF,PERIOD_H1,frames)==1 && frames[0]==PERIOD_M5);
   Check("AUTO_MTF",ICTSMTTimeframes(map,AUTO_MTF,PERIOD_H1,frames)==1 && frames[0]==PERIOD_H1);
   Check("AUTO_HTF",ICTSMTTimeframes(map,AUTO_HTF,PERIOD_H1,frames)==1 && frames[0]==PERIOD_D1);
   Check("MANUAL SMT",ICTSMTTimeframes(map,SMT_MANUAL,PERIOD_H2,frames)==1 && frames[0]==PERIOD_H2);
   ICTMapTimeframes(PERIOD_MN1,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,map);
   Check("no fabricated HTF on MN1",ICTSMTTimeframes(map,AUTO_HTF,PERIOD_H1,frames)==0);
   FlatFixture(a,160); FlatFixture(b,160);
   for(int i=0;i<160;i++)
     {
      double close=100+i*0.2+MathSin(i*0.71);
      FixtureBar(a[i],a[i].time,close,close+2,close-2,close);
      FixtureBar(b[i],b[i].time,close*2,close*2+2,close*2-2,close*2);
     }
   double rho=0; int pairs=0;
   Check("positive measured relation",SRMPAlignedCorrelationFromRates(a,160,b,160,60,0,rho,pairs) && rho>0.999 && pairs==60);
   for(int i=0;i<160;i++) { double close=10000/a[i].close; FixtureBar(b[i],b[i].time,close,close+2,close-2,close); }
   Check("inverse measured relation",SRMPAlignedCorrelationFromRates(a,160,b,160,60,0,rho,pairs) && rho< -0.999);
   FlatFixture(a,160); FlatFixture(b,160);
   Check("flat data relation unknown",!SRMPAlignedCorrelationFromRates(a,160,b,160,60,0,rho,pairs));
  }
void OBFixture(MqlRates &bars[],const int candles)
  {
   ArrayResize(bars,60);
   for(int i=0;i<60;i++)
     { double center=100+4*MathSin(i*0.8)-i*0.03; FixtureBar(bars[i],100000+i*300,center,center+1,center-1,center); }
   int start=53-candles;
   FixtureBar(bars[start-1],bars[start-1].time,98,103,97,102);
   for(int i=start;i<=52;i++)
     { double open=101+(52-i); FixtureBar(bars[i],bars[i].time,open,open+1,i==start ? 90 : 97,open-1); }
   FixtureBar(bars[53],bars[53].time,105,120,104,119);
   FixtureBar(bars[54],bars[54].time,122,125,121,123);
   FixtureBar(bars[55],bars[55].time,111,115,100,111);
   FixtureBar(bars[56],bars[56].time,100,110,95,101);
   FixtureBar(bars[57],bars[57].time,122,125,121,123);
   FixtureBar(bars[58],bars[58].time,111,115,100,111);
   FixtureBar(bars[59],bars[59].time,90,100,88,89);
  }
void TestUnifiedStrongOB()
  {
   SICTStrongOBConfig c; ICTDefaultStrongOBConfig(c); c.tolerance_ticks=0;
   MqlRates bars[],higher[]; SICTStrongOrderBlock z;
   for(int group=1;group<=3;group++)
     {
      OBFixture(bars,group);
      Check("OB group "+IntegerToString(group),ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z) && z.candles==group && z.ob.lower==90 && z.ob.upper==101);
      Check("OB waits for closed displacement "+IntegerToString(group),!ICTStrongOBAt("TEST",PERIOD_M5,bars,53,52,0.1,c,higher,0,PERIOD_CURRENT,z));
     }
   OBFixture(bars,3);
   ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z);
   string stable_id=z.id; datetime formed=z.ob.formation_time; int frozen=z.confirmation_score;
   Check("OB actual confirmation close",z.ob.confirmation_time==ICTBarClose(PERIOD_M5,bars[53].time));
   ICTAdvanceStrongOB(bars[54],ICTBarClose(PERIOD_M5,bars[54].time),c,0,z);
   Check("fresh after departure",z.life==ICT_OB_ACTIVE && z.touch_count==0);
   ICTAdvanceStrongOB(bars[55],ICTBarClose(PERIOD_M5,bars[55].time),c,0,z);
   Check("first touch partial",z.touch_count==1 && z.life==ICT_OB_PARTIAL && z.mitigation_depth>0 && z.mitigation_depth<0.5);
   ICTAdvanceStrongOB(bars[55],ICTBarClose(PERIOD_M5,bars[55].time),c,0,z);
   Check("same candle never increments touch",z.touch_count==1);
   ICTAdvanceStrongOB(bars[56],ICTBarClose(PERIOD_M5,bars[56].time),c,0,z);
   Check("50 percent mitigation, same touch",z.touch_count==1 && z.life==ICT_OB_MITIGATED && z.mitigation_depth>=0.5);
   ICTAdvanceStrongOB(bars[57],ICTBarClose(PERIOD_M5,bars[57].time),c,0,z);
   ICTAdvanceStrongOB(bars[58],ICTBarClose(PERIOD_M5,bars[58].time),c,0,z);
   Check("second touch after leaving is not sweep two",z.touch_count==2 && z.sweep_count==1);
   ICTAdvanceStrongOB(bars[59],ICTBarClose(PERIOD_M5,bars[59].time),c,0,z);
   Check("invalidation after mitigation",z.life==ICT_OB_INVALIDATED && z.ob.state_time==ICTBarClose(PERIOD_M5,bars[59].time));
   Check("ID, boundaries, formation and score immutable",z.id==stable_id && z.ob.formation_time==formed && z.confirmation_score==frozen && z.ob.lower==90 && z.ob.upper==101);
   SICTStrongOrderBlock score; ZeroMemory(score); score.ob.lower=90; score.ob.upper=101;
   score.ob.liquidity_sweep=true; score.ob.displacement=true; score.ob.break_confirmed=true; score.ob.fvg=true; score.ob.pd_match=true;
   ICTScoreStrongOB(score,true,true,false,true);
   Check("seven scores total 100",score.confirmation_score==100 && score.grade==ICT_OB_STRONG);
   score.ob.fvg=false; ICTScoreStrongOB(score,true,true,false,true);
   Check("optional FVG reduces exactly fifteen",score.confirmation_score==85 && score.grade==ICT_OB_STRONG);
   score.ob.liquidity_sweep=false; score.ob.fvg=true; ICTScoreStrongOB(score,true,true,false,true);
   Check("80 points missing reversal gate is medium",score.confirmation_score==80 && score.grade==ICT_OB_MEDIUM && !score.hard_gates);
   score.continuation=true; ICTScoreStrongOB(score,true,true,false,true);
   Check("continuation separate gates do not require reversal sweep",score.confirmation_score==80 && score.grade==ICT_OB_STRONG && score.hard_gates);
   ICTScoreStrongOB(score,true,true,false,false);
   Check("disabled continuation cannot be strong",score.grade==ICT_OB_MEDIUM && !score.hard_gates);
   OBFixture(bars,2); c.bounds=SRMP_OB_FULL;
   Check("full wick group bounds",ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z) && z.ob.lower==90 && z.ob.upper==103);
   c.bounds=SRMP_OB_BODY;
   Check("body bounds",ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z) && z.ob.lower==100 && z.ob.upper==102);
   ICTDefaultStrongOBConfig(c); c.expiry_bars=2; c.tolerance_ticks=0;
   ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z);
   ICTAdvanceStrongOB(bars[54],ICTBarClose(PERIOD_M5,bars[54].time),c,0,z); ICTAdvanceStrongOB(bars[55],ICTBarClose(PERIOD_M5,bars[55].time),c,0,z);
   Check("OB expiry by actual closed bars",z.life==ICT_OB_EXPIRED);
   ICTDefaultStrongOBConfig(c); c.invalidate_on_close=false; c.tolerance_ticks=0;
   ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z);
   MqlRates wick; FixtureBar(wick,bars[54].time,105,110,89,105);
   ICTAdvanceStrongOB(wick,ICTBarClose(PERIOD_M5,wick.time),c,0,z);
   Check("wick invalidation",z.life==ICT_OB_INVALIDATED);
   c.invalidate_on_close=true; ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z);
   ICTAdvanceStrongOB(wick,ICTBarClose(PERIOD_M5,wick.time),c,0,z);
   Check("same wick does not invalidate close mode",z.life!=ICT_OB_INVALIDATED);
   OBFixture(bars,1); bars[53].open=118; bars[53].close=119;
   Check("ordinary opposing candle is not a strong OB",!ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z));
  }
void SignalFixture(SICTSignalResult &s,const int direction=1)
  {
   ZeroMemory(s); s.symbol="TEST"; ICTMapTimeframes(PERIOD_M5,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,s.frames);
   s.asof=100300; s.trigger_bar=100000; s.source_event_time=99000;
   s.direction=direction; s.score=100;
   s.data_ready=true; s.htf_pass=true; s.mtf_pass=true; s.ltf_pass=true; s.risk_pass=true;
   s.entry=100; s.stop=direction>0 ? 95 : 105; s.tp1=direction>0 ? 115 : 85; s.rr=3;
   s.target_pool_id=direction>0 ? "BSL" : "SSL"; s.source_pool_id=direction>0 ? "SSL" : "BSL";
   s.htf_reason="HTF bias"; s.mtf_reason="MTF setup"; s.ltf_reason="LTF trigger";
  }
void TestUnifiedSignals()
  {
   SICTSignalResult s;
   SignalFixture(s); Check("closed BUY confirms all hard gates",ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_BUY_CONFIRMED && s.confirmation_time==s.asof);
   SignalFixture(s,-1); Check("closed SELL mirrors BUY",ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_SELL_CONFIRMED);
   SignalFixture(s); s.htf_pass=false; Check("100 points cannot bypass HTF",!ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_NO_TRADE);
   SignalFixture(s); s.mtf_pass=false; Check("100 points cannot bypass MTF",!ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_NO_TRADE);
   SignalFixture(s); s.ltf_pass=false; Check("100 points without trigger is WATCH only",!ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_WATCH_BUY && !s.confirmed);
   SignalFixture(s); s.data_ready=false; Check("missing data cannot confirm",!ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_NO_TRADE);
   SignalFixture(s); s.frames.status=ICT_MTF_TWO_TIER; Check("reduced tier never confirms",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.asof=s.trigger_bar; Check("forming LTF never confirms",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.source_event_time=s.asof+1; Check("future source event rejected",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.smt_required=true; Check("required missing SMT veto",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.smt_required=false; Check("optional missing SMT does not veto",ICTEvaluateSignal(s,2));
   SignalFixture(s); s.smt_required=true; s.smt_pass=true; Check("required aligned SMT passes",ICTEvaluateSignal(s,2));
   SignalFixture(s); s.target_pool_id=""; Check("no invented target",!ICTEvaluateSignal(s,2) && s.reason=="TARGET UNAVAILABLE");
   SignalFixture(s); s.stop=101; Check("invalid BUY stop rejected",!ICTEvaluateSignal(s,2));
   SignalFixture(s,-1); s.tp1=115; Check("invalid SELL target rejected",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.rr=1.99; Check("net RR below two veto",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.rr=2.5; Check("higher existing RR threshold preserved",!ICTEvaluateSignal(s,3));
   SignalFixture(s); s.risk_pass=false; Check("risk manager veto cannot be scored away",!ICTEvaluateSignal(s,2));
   SICTSignalResult original; SICTSignalResult changed; SICTSignalResult opposite;
   SignalFixture(original); ICTEvaluateSignal(original,2);
   SICTSignalResult history[];
   Check("confirmation stored once",ICTMergeConfirmedSignal(original,history,60) && ArraySize(history)==1);
   SignalFixture(changed); changed.entry=101; changed.rr=2; ICTEvaluateSignal(changed,2);
   Check("later prices cannot repaint committed candle",!ICTMergeConfirmedSignal(changed,history,60) && history[0].entry==100);
   SignalFixture(opposite,-1); ICTEvaluateSignal(opposite,2);
   Check("opposite side cannot replace same candle",!ICTMergeConfirmedSignal(opposite,history,60) && history[0].direction==1);
   Check("oldest closed candle retained inclusive",ICTSignalInsideWindow(original,original.trigger_bar,original.asof));
   Check("sixty-first older candle excluded",!ICTSignalInsideWindow(original,original.trigger_bar+300,original.asof));
   Check("future confirmation excluded from history",!ICTSignalInsideWindow(original,original.trigger_bar,original.asof-1));
   SignalFixture(s); s.tp1=101; Check("claimed RR cannot exceed actual plan geometry",!ICTEvaluateSignal(s,2));
  }

void TestCausalReactions(const int direction)
  {
   MqlRates bar;
   LiquidityFixtureBar(bar,100000,104,112,103,110,direction);
   double lower=(direction>0 ? 100 : 90),upper=(direction>0 ? 110 : 100);
   Check("closed zone reaction after prior structure "+IntegerToString(direction),
      ICTClosedZoneReaction(bar,100300,direction,lower,upper,99000,99700));
   Check("future zone cannot confirm reaction "+IntegerToString(direction),
      !ICTClosedZoneReaction(bar,100300,direction,lower,upper,100001,99700));
   Check("future structure cannot confirm reaction "+IntegerToString(direction),
      !ICTClosedZoneReaction(bar,100300,direction,lower,upper,99000,100001));
   Check("unclosed reaction rejected "+IntegerToString(direction),
      !ICTClosedZoneReaction(bar,100000,direction,lower,upper,99000,99700));
   Check("range reaction can follow displacement on an earlier bar "+IntegerToString(direction),
      ICTClosedRangeReaction(bar,100300,direction,99000,99700,100300,true,true));
   Check("range reaction without displacement rejected "+IntegerToString(direction),
      !ICTClosedRangeReaction(bar,100300,direction,99000,99700,100300,true,false));
   Check("range reaction without a valid setup rejected "+IntegerToString(direction),
      !ICTClosedRangeReaction(bar,100300,direction,99000,99700,100300,false,true));
   Check("old reaction not reissued on a later candle "+IntegerToString(direction),
      !ICTClosedRangeReaction(bar,100600,direction,99000,99700,100300,true,true));
   Check("saved MTF break survives a later quiet candle "+IntegerToString(direction),
      ICTMTFStructureReady(true,direction,0,direction,true,99700,100300));
   Check("opposite MTF break vetoes saved setup "+IntegerToString(direction),
      !ICTMTFStructureReady(true,direction,-direction,direction,true,99700,100300));
   Check("future MTF event cannot confirm setup "+IntegerToString(direction),
      !ICTMTFStructureReady(true,direction,0,direction,true,100301,100300));
   Check("legacy still requires its current MTF break "+IntegerToString(direction),
      !ICTMTFStructureReady(false,direction,0,direction,true,99700,100300));
   if(direction>0) bar.low=lower; else bar.high=upper;
   Check("fully traversed zone rejected "+IntegerToString(direction),
      !ICTClosedZoneReaction(bar,100300,direction,lower,upper,99000,99700));
  }

void TestSameBarSignalJournal()
  {
   SICTSignalResult previous; SICTSignalResult current;
   SignalFixture(previous); previous.state=ICT_SIGNAL_NO_TRADE; previous.confirmed=false;
   previous.risk_pass=false; previous.confirmation_time=0;
   SignalFixture(current); current.state=ICT_SIGNAL_WATCH_BUY; current.confirmed=false;
   Check("same bar allows an updated unconfirmed observation",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_REFRESH_UNCONFIRMED);
   SignalFixture(current); ICTEvaluateSignal(current,2);
   Check("risk recovery allows same-bar confirmation with all gates",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_COMMIT_CONFIRMED);
   current.risk_pass=false;
   Check("same-bar promotion cannot bypass risk",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_CONFLICT);
   SignalFixture(current); ICTEvaluateSignal(current,2); current.trigger_bar++;
   Check("different candle cannot replace current journal row",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_CONFLICT);
   SignalFixture(previous); ICTEvaluateSignal(previous,2);
   SignalFixture(current,-1); ICTEvaluateSignal(current,2);
   Check("confirmed candle is immutable even for opposite later evidence",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_KEEP_CONFIRMED);
   current.symbol="OTHER";
   Check("different symbol cannot reuse a confirmed record",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_CONFLICT);
  }
void TestUnifiedPeerStates()
  {
   SICTDynamicSMTConfig c; ICTDefaultDynamicSMTConfig(c); c.relation=SMT_POSITIVE; c.relation2=SMT_NEGATIVE;
   Check("peer one inherits legacy positive",ICTSMTPeerRelation(c,0)==SMT_POSITIVE);
   Check("peer two independent inverse",ICTSMTPeerRelation(c,1)==SMT_NEGATIVE);
   SICTSMTPeerSnapshot peer; ICTResetSMTPeer("PEER1","DATA INSUFFICIENT",peer);
   SICTSMTEvent events[2];
   for(int i=0;i<2;i++)
     {
      ZeroMemory(events[i]); events[i].life=ICT_SMT_CONFIRMED;
      events[i].signal.comparison="PEER1"; events[i].signal.timeframe=PERIOD_M5;
      events[i].signal.relation=1; events[i].signal.confirmation_time=100300+i*300;
      events[i].signal.primary_pivot_time=99000; events[i].signal.primary_recent=100;
      events[i].signal.event_id="P"+IntegerToString(i); events[i].signal.direction=i==0 ? 1 : -1;
     }
   ICTSummarizeSMTPeer(events,1,PERIOD_M5,100600,100000,peer);
   Check("missing peer remains NA despite historical event",peer.state==ICT_SMT_PEER_NA);
   peer.ready=true; peer.relation_known=true; peer.relation=1; peer.last_close=100600;
   ICTSummarizeSMTPeer(events,1,PERIOD_M5,100600,100000,peer);
   Check("qualified peer bullish",peer.state==ICT_SMT_PEER_BULLISH && peer.confirmation_time==100300);
   ICTSummarizeSMTPeer(events,2,PERIOD_M5,100600,100000,peer);
   Check("opposed peer events never green confluence",peer.conflict && peer.state==ICT_SMT_PEER_NONE);
   peer.comparison="OTHER";
   ICTSummarizeSMTPeer(events,2,PERIOD_M5,100600,100000,peer);
   Check("old comparator events cannot leak after mapping change",peer.state==ICT_SMT_PEER_NONE);
   peer.comparison="PEER1"; peer.relation=-1;
   Check("wrong relation cannot supply current evidence",!ICTSMTPeerEventUsable(events[0],PERIOD_M5,100600,100000,peer));
   peer.relation=1;
   Check("future SMT event unavailable",!ICTSMTPeerEventUsable(events[1],PERIOD_M5,100300,100000,peer));
   Check("wrong source timeframe unavailable",!ICTSMTPeerEventUsable(events[0],PERIOD_H1,100600,100000,peer));
   events[0].life=ICT_SMT_INVALIDATED;
   ICTSummarizeSMTPeer(events,1,PERIOD_M5,100600,100000,peer);
   Check("invalidated SMT keeps confirmation metadata without live points",peer.state==ICT_SMT_PEER_NONE && peer.confirmation_time==100300);
  }
void TestUnifiedOBQuality()
  {
   SICTStrongOBConfig c; ICTDefaultStrongOBConfig(c);
   SICTStrongOrderBlock z; ZeroMemory(z); z.ob.lower=90; z.ob.upper=100;
   z.ob.liquidity_sweep=true; z.ob.displacement=true; z.ob.break_confirmed=true; z.ob.fvg=true; z.ob.pd_match=true;
   ICTScoreStrongOBWithConfig(z,true,true,c); z.life=ICT_OB_ACTIVE;
   Check("default configured OB weights valid",ICTValidStrongOBConfig(c) && z.confirmation_score==100);
   z.touch_count=1; z.life=ICT_OB_PARTIAL; ICTRefreshOBQuality(z,c);
   Check("touched OB loses freshness but frozen score remains",z.confirmation_score==100 && z.current_context_score==95 && z.grade!=ICT_OB_STRONG);
   z.touch_count=3; ICTRefreshOBQuality(z,c);
   Check("repeat touches lower current quality",z.current_context_score==85 && z.confirmation_score==100);
   z.life=ICT_OB_INVALIDATED; ICTRefreshOBQuality(z,c);
   Check("invalidated OB is never STRONG",z.current_context_score==0 && z.grade!=ICT_OB_STRONG && z.confirmation_grade==ICT_OB_STRONG);
   c.weight_sweep=25; Check("invalid OB weight total rejected",!ICTValidStrongOBConfig(c));
   c.weight_fvg=10; Check("alternative OB weights sum 100",ICTValidStrongOBConfig(c));
   z.ob.fvg=false; ICTScoreStrongOBWithConfig(z,true,true,c);
   Check("configured FVG weight applied",z.confirmation_score==90);
  }
void LiquidityFixtureBar(MqlRates &bar,const datetime time,const double open,const double high,
                         const double low,const double close,const int side)
  {
   if(side>0) FixtureBar(bar,time,open,high,low,close);
   else FixtureBar(bar,time,200-open,200-low,200-high,200-close);
  }
void TestUnifiedLiquidity(const int side)
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.breakout_displacement_confirms=false;
   c.retest_tolerance_ticks=1; c.retest_tolerance_atr=0; c.retest_close_buffer_ticks=1;
   SICTRangeLevel pool; ZeroMemory(pool); pool.id="POOL"; pool.range_id="RANGE";
   pool.price=100; pool.side=side; pool.available_at=1000; pool.timeframe=PERIOD_H1; pool.membership=IR_INTERNAL;
   MqlRates bar;
   LiquidityFixtureBar(bar,1000,99,105,98,104,side);
   ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   Check("liquidity outside close is not breakout "+IntegerToString(side),pool.candidate && pool.last_event==IR_EVENT_NONE);
   LiquidityFixtureBar(bar,1300,104,106,103,105,side);
   ICTRangeAdvanceLevelConfigured(bar,1600,1,5,false,c,1,0,pool);
   Check("liquidity two closed holds confirm breakout "+IntegerToString(side),pool.state==IR_BREAKOUT && pool.last_event==IR_EVENT_BREAKOUT_CONFIRMED);
   SICTRangeSnapshot snapshot; ZeroMemory(snapshot); snapshot.as_of=1600; snapshot.ltf=PERIOD_M5;
   snapshot.liquidity_display_start=1000;
   ICTRangeRecordLiquidityEvent(snapshot,pool); ICTRangeRecordLiquidityEvent(snapshot,pool);
   Check("liquidity event committed once "+IntegerToString(side),snapshot.liquidity_event_count==1);
   LiquidityFixtureBar(bar,1600,100.5,104,99,103,side);
   ICTRangeAdvanceLevelConfigured(bar,1900,1,5,false,c,1,0,pool);
   Check("liquidity retest needs later hold "+IntegerToString(side),pool.last_event==IR_EVENT_RETEST_CONFIRMED && pool.breakout_at==1600 && pool.state==IR_BREAKOUT);
   snapshot.as_of=1900; ICTRangeRecordLiquidityEvent(snapshot,pool);
   Check("retest does not repaint breakout "+IntegerToString(side),snapshot.liquidity_event_count==2 && snapshot.liquidity_events[0].type==IR_EVENT_BREAKOUT_CONFIRMED && snapshot.liquidity_events[0].confirmed_at==1600);
   LiquidityFixtureBar(bar,1900,103,104,97,98,side);
   ICTRangeAdvanceLevelConfigured(bar,2200,1,5,false,c,1,0,pool);
   Check("liquidity explicit false breakout "+IntegerToString(side),pool.last_event==IR_EVENT_FALSE_BREAKOUT && pool.state==IR_CONSUMED);
   snapshot.as_of=2200; ICTRangeRecordLiquidityEvent(snapshot,pool);
   ICTRangeAdvanceLevelConfigured(bar,2200,1,5,false,c,1,0,pool); ICTRangeRecordLiquidityEvent(snapshot,pool);
   Check("duplicate false breakout does not count twice "+IntegerToString(side),snapshot.liquidity_event_count==3);
   LiquidityFixtureBar(bar,2200,99,104,98,99,side);
   ICTRangeAdvanceLevelConfigured(bar,2500,1,5,false,c,1,0,pool);
   Check("consumed pool cannot become fresh again "+IntegerToString(side),pool.state==IR_CONSUMED && pool.event_at==2200);
   ZeroMemory(pool); pool.id="SWEEP"; pool.price=100; pool.side=side; pool.available_at=1000;
   LiquidityFixtureBar(bar,1000,99,104,98,99,side);
   ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   Check("wick reclaim distinct from outside-close failure "+IntegerToString(side),pool.last_event==IR_EVENT_LIQUIDITY_SWEEP && pool.sweep_count==1);
   ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   Check("same sweep bar never recounted "+IntegerToString(side),pool.sweep_count==1);
   LiquidityFixtureBar(bar,1300,98,99,95,96,side); ICTRangeAdvanceLevelConfigured(bar,1600,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1600,97,99,95,96,side); ICTRangeAdvanceLevelConfigured(bar,1900,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1900,99,104,98,99,side); ICTRangeAdvanceLevelConfigured(bar,2200,1,5,false,c,1,0,pool);
   Check("separated second sweep same pool "+IntegerToString(side),pool.sweep_count==2 && pool.last_event==IR_EVENT_LIQUIDITY_SWEEP);

   ZeroMemory(pool); pool.id="LATE"; pool.price=100; pool.side=side; pool.available_at=1000;
   c.sweep_validation_bars=3;
   LiquidityFixtureBar(bar,1000,99,105,98,104,side); ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1300,100.5,101,100,100.5,side); ICTRangeAdvanceLevelConfigured(bar,1600,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1600,100.5,101,100,100.5,side); ICTRangeAdvanceLevelConfigured(bar,1900,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1900,100.5,101,98,99,side); ICTRangeAdvanceLevelConfigured(bar,2200,1,5,false,c,1,0,pool);
   Check("late reclaim cannot become a reversal "+IntegerToString(side),
      pool.state==IR_LEVEL_INVALIDATED && pool.last_event==IR_EVENT_NONE);

   ZeroMemory(pool); pool.id="ON_TIME"; pool.price=100; pool.side=side; pool.available_at=1000;
   LiquidityFixtureBar(bar,1000,99,105,98,104,side); ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1300,100.5,101,100,100.5,side); ICTRangeAdvanceLevelConfigured(bar,1600,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1600,100.5,101,98,99,side); ICTRangeAdvanceLevelConfigured(bar,1900,1,5,false,c,1,0,pool);
   Check("reclaim at configured window remains valid "+IntegerToString(side),
      pool.state==IR_SWEPT && pool.last_event==IR_EVENT_FALSE_BREAKOUT);
  }

void TestLiquidityHistorySeed(const int side)
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.penetration_ticks=1; c.penetration_atr=0;
   c.breakout_displacement_confirms=false;
   MqlRates bars[24];
   for(int i=0;i<24;i++) LiquidityFixtureBar(bars[i],1000+i*300,95,97,94,96,side);
   LiquidityFixtureBar(bars[5],2500,96,103,94,99,side);
   // The later breakout must not affect a prefix that ends before bar 10.
   LiquidityFixtureBar(bars[10],4000,99,104,98,103,side);
   LiquidityFixtureBar(bars[11],4300,103,105,102,104,side);
   SICTRangeLevel pool; ZeroMemory(pool); pool.id="OLD_POOL"; pool.range_id="R";
   pool.price=100; pool.side=side; pool.available_at=1600; pool.timeframe=PERIOD_H1;
   SICTSweepSequence sequence; ICTSweepSequenceStart(sequence,pool.id,side,pool.price,pool.available_at);
   SICTRangeSnapshot snapshot; ZeroMemory(snapshot); snapshot.as_of=3700; snapshot.ltf=PERIOD_M5;
   snapshot.liquidity_display_start=1000;
   Check("older pool seeded with complete closed history "+IntegerToString(side),
      ICTRangeSeedLevel(pool,sequence,true,bars,24,3700,c,1,snapshot,true));
   Check("prior sweep retained; future suffix ignored "+IntegerToString(side),
      pool.state==IR_SWEPT && pool.sweep_count==1 && pool.event_at==2800 &&
      sequence.count==1 && sequence.events[0].status==ICT_SWEEP_CONFIRMED);
   Check("seed observation stored once "+IntegerToString(side),snapshot.liquidity_event_count==1);
   SICTRangeLevel before_range; ZeroMemory(before_range); before_range.id="EARLIER";
   before_range.range_id="R"; before_range.price=100; before_range.side=side;
   before_range.available_at=1600; before_range.timeframe=PERIOD_H1;
   SICTSweepSequence earlier; ZeroMemory(earlier);
   SICTRangeSnapshot later_range; ZeroMemory(later_range); later_range.as_of=3700;
   later_range.ltf=PERIOD_M5; later_range.liquidity_display_start=1000;
   later_range.range.confirmed_at=3000;
   Check("pre-range events still update the pool lifecycle "+IntegerToString(side),
      ICTRangeSeedLevel(before_range,earlier,false,bars,24,3700,c,1,later_range,true) &&
      before_range.state==IR_SWEPT && before_range.sweep_count==1);
   Check("no event is attributed to a range before its confirmation "+IntegerToString(side),
      later_range.liquidity_event_count==0);
   SICTRangeLevel missing; ZeroMemory(missing); missing.id="MISSING"; missing.price=100;
   missing.side=side; missing.available_at=999;
   SICTSweepSequence other; ZeroMemory(other);
   Check("uncovered pool cannot be assumed fresh "+IntegerToString(side),
      !ICTRangeSeedLevel(missing,other,false,bars,24,3700,c,1,snapshot,false));
  }
void TestAdaptiveEqualityTolerance()
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c);
   c.equal_ticks=3; c.equal_atr=0.1; c.equal_spread=2;
   Check("equal tolerance uses minimum ticks",ICTRangeEqualTolerance(0.1,1,0.05,c)>=0.3-1e-9);
   Check("equal tolerance uses ATR",MathAbs(ICTRangeEqualTolerance(0.1,10,0.05,c)-1)<1e-9);
   Check("equal tolerance uses historical spread price",MathAbs(ICTRangeEqualTolerance(0.1,1,0.4,c)-0.8)<1e-9);
   Check("invalid spread cannot silently lower tolerance",ICTRangeEqualTolerance(0.1,1,-1,c)<0);
   c.liquidity_seed_bars=79; c.lookback=80;
   Check("seed history cannot be shorter than structural history",!ICTValidRangeConfig(c));
  }
void TestTargetAvailability()
  {
   MqlRates bar; FixtureBar(bar,100000,100,105,95,101);
   Check("BUY exit quote still below target",ICTRangeLiveTargetSafe(1,104,104.2,105));
   Check("BUY exit quote at target is not actionable",!ICTRangeLiveTargetSafe(1,105,105.2,105));
   Check("SELL exit quote still above target",ICTRangeLiveTargetSafe(-1,95.8,96,95));
   Check("SELL exit quote at target is not actionable",!ICTRangeLiveTargetSafe(-1,94.8,95,95));
   Check("missing or inverted quote fails closed",!ICTRangeLiveTargetSafe(1,100,99,110));
   Check("reaction candle touching BUY target is ambiguous",!ICTRangeReactionTargetSafe(1,bar,105));
   Check("reaction candle touching SELL target is ambiguous",!ICTRangeReactionTargetSafe(-1,bar,95));
   Check("BUY target beyond reaction candle is unambiguous",ICTRangeReactionTargetSafe(1,bar,106));
   Check("SELL target beyond reaction candle is unambiguous",ICTRangeReactionTargetSafe(-1,bar,94));
  }
void TestSMTDiagnosticCore()
  {
   SICTUnifiedSnapshot s; ZeroMemory(s); s.valid=true; s.asof=100300; s.layer_count=1;
   s.layers[0].last_close=s.asof; s.comparison1="PEER1";
   s.layers[0].peers[0].comparison="PEER1"; s.layers[0].peers[1].reason="DISABLED";
   Check("SMT diagnostic unavailable",StringFind(ICTUnifiedSMTDiagnostic(s,1),"UNAVAILABLE:")==0);
   s.layers[0].peers[0].ready=true; s.layers[0].peers[0].relation_known=true;
   s.layers[0].peers[0].last_close=s.asof; s.layers[0].peers[0].state=ICT_SMT_PEER_NONE;
   Check("SMT diagnostic none",StringFind(ICTUnifiedSMTDiagnostic(s,1),"NONE:")==0);
   s.layers[0].peers[0].state=ICT_SMT_PEER_BULLISH;
   Check("SMT diagnostic aligned matches gate",StringFind(ICTUnifiedSMTDiagnostic(s,1),"ALIGNED:")==0 && ICTUnifiedSMTAligned(s,1));
   Check("SMT diagnostic opposite matches gate",StringFind(ICTUnifiedSMTDiagnostic(s,-1),"OPPOSITE:")==0 && !ICTUnifiedSMTAligned(s,-1));
   s.layers[0].peers[0].conflict=true;
   Check("SMT diagnostic conflict matches veto",StringFind(ICTUnifiedSMTDiagnostic(s,1),"CONFLICT:")==0 && !ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[0].conflict=false; s.layers[0].peers[0].last_close--;
   Check("SMT diagnostic stale peer unavailable",StringFind(ICTUnifiedSMTDiagnostic(s,1),"UNAVAILABLE:")==0 && !ICTUnifiedSMTAligned(s,1));
  }
void RunUnifiedCoreFixtures()
  { TestUnifiedMappingCalendar(); TestUnifiedSMT(); TestUnifiedStrongOB(); TestUnifiedSignals(); TestSameBarSignalJournal();
      TestCausalReactions(1); TestCausalReactions(-1); TestUnifiedPeerStates(); TestUnifiedOBQuality();
    TestUnifiedLiquidity(1); TestUnifiedLiquidity(-1); TestLiquidityHistorySeed(1); TestLiquidityHistorySeed(-1);
    TestAdaptiveEqualityTolerance(); TestTargetAvailability(); TestICTConfluenceLifecycle(); TestICTSessionLiquidity(); TestSMTDiagnosticCore(); TestICTSignalJournalLive();
    TestLivePositionRisk(); TestLivePositionRiskDisplay(); }
