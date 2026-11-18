#property strict
#property description "Chronological IRL/ERL fixtures and snapshot roundtrip; no trade requests."
#include "../Include/ICTRangeEngine.mqh"
#include "../Include/ICTRangeBridge.mqh"
#include "../Include/ICTBalancedPriceRange.mqh"

int g_failures=0,g_assertions=0;
void Check(const bool result,const string name)
  { g_assertions++; if(!result) { g_failures++; Print("FAIL: ",name); } }
void Bar(MqlRates &b,const datetime t,const double o,const double h,const double l,const double close)
  { ZeroMemory(b); b.time=t; b.open=o; b.high=h; b.low=l; b.close=close; }

void TestHistoryClock()
  {
   const datetime close=100000;
   Check(ICTRangeHistoryError(close,close,PERIOD_M5,0.1)=="","closed candle accepted at broker time");
   Check(ICTRangeHistoryError(close,close+600,PERIOD_M5,0.1)=="","history age boundary accepted");
   Check(StringFind(ICTRangeHistoryError(close,close+601,PERIOD_M5,0.1),"Stale LTF history")==0,"stale history still blocked");
   Check(StringFind(ICTRangeHistoryError(close,close-1,PERIOD_M5,0.1),"LTF close is ahead")==0,"future candle still blocked");
   Check(StringFind(ICTRangeHistoryError(close,0,PERIOD_M5,0.1),"Broker quote time unavailable")==0,"missing broker clock blocked");
   Check(StringFind(ICTRangeHistoryError(close,close,PERIOD_M5,0),"Invalid SYMBOL_TRADE_TICK_SIZE")==0,"invalid tick has distinct diagnostic");
   Check(ICTRangeHistoryError(0,close,PERIOD_M5,0.1)!="","missing candle time blocked");
  }

void TestRangeAndMembership()
  {
   SMarketStructure structure; ZeroMemory(structure);
   structure.recent_high=140; structure.recent_low=90;
   structure.recent_high_time=2000; structure.recent_low_time=1000;
   structure.recent_high_confirmed_time=3000; structure.recent_low_confirmed_time=2000;
   structure.bias=1; SICTDealingRange r;
   Check(!ICTRangeFromStructure("TEST",PERIOD_M5,structure,20,3299,r),"right confirmation not yet closed");
   Check(ICTRangeFromStructure("TEST",PERIOD_M5,structure,20,3300,r),"confirmed opposite swing pair");
   Check(r.high==140 && r.low==90 && r.midpoint==115 && r.width==50 && r.direction==1,"range geometry and direction");
   string id=r.id;
   structure.latest_closed_bar=9999;
   Check(ICTRangeFromStructure("TEST",PERIOD_M5,structure,20,10000,r) && r.id==id,"identity independent of observation clock");
   Check(ICTRangeMembership(r,100,110,1)==IR_INTERNAL,"fully internal PD array");
   Check(ICTRangeMembership(r,135,145,1)==IR_CROSSING,"cross-boundary array not IRL");
   Check(ICTRangeMembership(r,150,150,1)==IR_OUTSIDE,"external period high");
   Check(ICTRangeMembership(r,140,140,1)==IR_BOUNDARY,"boundary BSL");
   Check(ICTRangeLocation(r,150)=="OUTSIDE" && ICTRangeLocation(r,105)=="DISCOUNT","current location");
   SICTRangeSnapshot s; ZeroMemory(s); s.range=r; s.as_of=10000;
   ICTRangeAddLevel(s,"PDH",120,1,2000,1);
   ICTRangeAddLevel(s,"PWH",160,1,2000,1);
   Check(s.levels[0].membership==IR_INTERNAL && !ICTRangeExternal(s.levels[0],r),"PDH inside range is internal pool");
   Check(ICTRangeExternal(s.levels[1],r),"outside PWH is ERL");
   s.levels[1].range_id="OTHER";
   Check(!ICTRangeExternal(s.levels[1],r),"range ownership veto");
   MqlRates htf[3];
   for(int i=0;i<3;i++) Bar(htf[i],1000+i*3600,100,110,90,100);
   Check(ICTRangeClosedCount(htf,3,PERIOD_H1,4599)==0,"HTF forming candle excluded");
   Check(ICTRangeClosedCount(htf,3,PERIOD_H1,4600)==1,"HTF usable exactly after close");
   s.level_count=0; s.direction=1;
   ICTRangeAddLevel(s,"CLOSE",150,1,2000,1); ICTRangeAddLevel(s,"FAR",170,1,2000,1);
   s.levels[0].state=IR_CONSUMED;
   ICTRangeSelectTargets(s,100);
   Check(s.tp1==170 && s.tp2==0,"consumed nearest target excluded");
   s.levels[1].range_id="OTHER"; ICTRangeSelectTargets(s,100);
   Check(s.tp1==0,"foreign-range ERL cannot become target");
   SICTConfluenceConfig scoring; ICTDefaultConfluenceConfig(scoring);
   Check(ICTRangeQualityConfluence(ICT_E_HTF|ICT_E_SWEEP|ICT_E_MSS|ICT_E_DISPLACEMENT,80,scoring)==79,
         "IRL quality continuously scales configurable FVG/OB/PD group");
  }

void TestSweepBreakout()
  {
   SICTRangeLevel l; ZeroMemory(l); l.side=1; l.price=140; l.available_at=1000;
   MqlRates b; Bar(b,1000,139,142,138,139);
   ICTRangeAdvanceLevel(b,1300,3,5,false,2,l);
   Check(l.state!=IR_SWEPT,"noise excursion is not sweep");
   Bar(b,1300,139,145,137,139); ICTRangeAdvanceLevel(b,1600,3,5,false,2,l);
   Check(l.state==IR_SWEPT && l.event_at==1600,"penetration and closed reclaim confirms sweep");
   Check(l.last_event==IR_EVENT_LIQUIDITY_SWEEP && l.event_bar_time==1300 && l.event_wick_time==1300 &&
         l.event_wick==145 && l.event_close==139 && l.sweep_count==1,"sweep stores its closed wick/close observation");
   Bar(b,1600,140,146,140,145); ICTRangeAdvanceLevel(b,1900,3,5,false,2,l);
   Check(l.state==IR_CONSUMED,"failed sweep not a fresh pool");
   Bar(b,1900,140,141,138,139); ICTRangeAdvanceLevel(b,2200,3,5,false,2,l);
   Check(l.state==IR_CONSUMED,"consumption remains sticky");
   ZeroMemory(l); l.side=-1; l.price=90; l.available_at=1000;
   Bar(b,1000,90,91,84,85); ICTRangeAdvanceLevel(b,1300,3,5,false,2,l);
   Check(l.candidate && l.state!=IR_SWEPT && l.state!=IR_BREAKOUT,"one outside close is a candidate");
   Bar(b,1300,85,87,83,84); ICTRangeAdvanceLevel(b,1600,3,5,false,2,l);
   Check(l.state==IR_BREAKOUT && !l.candidate,"two closed continuations confirm breakout");
   Check(l.last_event==IR_EVENT_BREAKOUT_CONFIRMED && l.breakout_at==1600 && l.retest_pending,
         "broken lifecycle and pending retest are distinct from the breakout event");
   ZeroMemory(l); l.side=-1; l.price=90; l.available_at=1000;
   Bar(b,1000,95,96,84,85); ICTRangeAdvanceLevel(b,1300,3,5,true,2,l);
   Check(l.state==IR_BREAKOUT,"displacement continuation is breakout not reversal");
  }

void LevelBar(MqlRates &b,const datetime t,const double o,const double h,const double l,const double close,const int side)
  {
   if(side>0) Bar(b,t,o,h,l,close);
   else Bar(b,t,200-o,200-l,200-h,200-close);
  }
void LevelPool(SICTRangeLevel &l,const int side)
  {
   ZeroMemory(l); l.id=(side>0 ? "POOL_BSL" : "POOL_SSL"); l.range_id="EVENT_RANGE";
   l.name=(side>0 ? "HIGH" : "LOW"); l.side=side; l.price=100; l.available_at=1000;
   l.timeframe=PERIOD_H1; l.membership=IR_INTERNAL;
  }

void TestFalseBreakoutRetest(const int side)
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.breakout_displacement_confirms=false;
   c.retest_tolerance_ticks=1; c.retest_tolerance_atr=0; c.retest_close_buffer_ticks=1;
   SICTRangeLevel l; LevelPool(l,side); MqlRates b;
   LevelBar(b,1000,99,105,98,104,side);
   ICTRangeAdvanceLevelConfigured(b,1300,1,5,false,c,1,0,l);
   Check(l.candidate && l.last_event==IR_EVENT_NONE,"outside close alone remains an unconfirmed excursion");
   LevelBar(b,1300,104,106,98,99,side);
   ICTRangeAdvanceLevelConfigured(b,1600,1,5,false,c,1,0,l);
   Check(l.state==IR_SWEPT && l.last_event==IR_EVENT_FALSE_BREAKOUT && l.event_at==1600 &&
         l.event_bar_time==1300 && l.event_wick_time==1300 && (l.event_wick-100)*side==6 &&
         (l.event_close-100)*side==-1,"outside-close candidate reclaim is an explicit false breakout");
   Check(l.sweep_count==0 && !l.candidate,"false breakout is not silently relabeled as a wick-only sweep");

   LevelPool(l,side);
   LevelBar(b,1000,99,105,98,104,side); ICTRangeAdvanceLevelConfigured(b,1300,1,5,false,c,1,0,l);
   LevelBar(b,1300,104,106,103,105,side); ICTRangeAdvanceLevelConfigured(b,1600,1,5,false,c,1,0,l);
   Check(l.state==IR_BREAKOUT && l.last_event==IR_EVENT_BREAKOUT_CONFIRMED && l.event_at==1600,
         "configured close count confirms both breakout directions");
   SICTRangeSnapshot s; ZeroMemory(s); s.schema=ICT_RANGE_SCHEMA; s.range.id=l.range_id;
   s.as_of=1600; s.ltf=PERIOD_M5; s.liquidity_display_start=1000;
   ICTRangeRecordLiquidityEvent(s,l); ICTRangeRecordLiquidityEvent(s,l);
   Check(s.liquidity_event_count==1,"a level event is appended once per pool/type/confirmation");
   SICTRangeLiquidityEvent breakout=s.liquidity_events[0];
   LevelBar(b,1600,105,106,99,100.5,side); ICTRangeAdvanceLevelConfigured(b,1900,1,5,false,c,1,0,l);
   Check(l.last_event==IR_EVENT_BREAKOUT_CONFIRMED && l.retest_pending,"touch without a buffered directional hold is not a retest");
   LevelBar(b,1900,100.5,104,99,103,side); ICTRangeAdvanceLevelConfigured(b,2200,1,5,false,c,1,0,l);
   Check(l.state==IR_BREAKOUT && l.last_event==IR_EVENT_RETEST_CONFIRMED && l.event_at==2200 &&
         l.breakout_at==1600 && !l.retest_pending && (l.event_wick-100)*side==-1,
         "later touched level and buffered directional close confirm a retest without refreshing the broken pool");
   s.as_of=2200; ICTRangeRecordLiquidityEvent(s,l);
   Check(s.liquidity_event_count==2 && s.liquidity_events[0].id==breakout.id && s.liquidity_events[0].type==breakout.type &&
         s.liquidity_events[0].confirmed_at==breakout.confirmed_at && s.liquidity_events[0].wick==breakout.wick,
         "retest leaves the earlier confirmed breakout record unchanged");
   ICTRangeAdvanceLevelConfigured(b,2200,1,5,false,c,1,0,l); ICTRangeRecordLiquidityEvent(s,l);
   Check(s.liquidity_event_count==2 && l.event_at==2200,"duplicate closed retest cannot add or revise an event");
   LevelBar(b,2200,103,104,97,98,side); ICTRangeAdvanceLevelConfigured(b,2500,1,5,false,c,1,0,l);
   Check(l.state==IR_CONSUMED && l.last_event==IR_EVENT_FALSE_BREAKOUT && l.event_at==2500,
         "buffered close reclaim within the window records failure of an already confirmed breakout");
   s.as_of=2500; ICTRangeRecordLiquidityEvent(s,l);
   LevelBar(b,2500,99,105,98,99,side); ICTRangeAdvanceLevelConfigured(b,2800,1,5,false,c,1,0,l);
   Check(l.state==IR_CONSUMED && l.event_at==2500,"failed broken pool stays consumed and cannot create a fresh sweep");

   s.symbol="TEST"; s.level_count=1; s.levels[0]=l;
   s.source_pool_id=l.id; s.source_pool_tf=l.timeframe; s.source_event=IR_EVENT_BREAKOUT_CONFIRMED; s.source_event_at=1600;
   s.target1_pool_id="TARGET_HIGHER"; s.target1_pool_tf=PERIOD_H4; s.tp1=(side>0 ? 120 : 80);
   s.target2_pool_id="TARGET_SECOND"; s.target2_pool_tf=PERIOD_D1; s.tp2=(side>0 ? 130 : 70);
   s.as_of=2800;
   double numbers[]; string strings[]; ICTRangePack(s,numbers,strings); SICTRangeSnapshot decoded;
   Check(ICTRangeUnpack(numbers,strings,decoded) && decoded.liquidity_event_count==3 &&
         decoded.source_pool_id==s.source_pool_id && decoded.source_pool_tf==PERIOD_H1 &&
         decoded.target1_pool_id==s.target1_pool_id && decoded.target1_pool_tf==PERIOD_H4 &&
         decoded.target2_pool_id==s.target2_pool_id && decoded.target2_pool_tf==PERIOD_D1 &&
         decoded.levels[0].last_event==IR_EVENT_FALSE_BREAKOUT && decoded.levels[0].event_close==l.event_close &&
         decoded.liquidity_events[1].type==IR_EVENT_RETEST_CONFIRMED && decoded.liquidity_events[1].wick_time==1900 &&
         decoded.liquidity_events[1].id==s.liquidity_events[1].id,
         "schema preserves source/target IDs, source TFs, level events and immutable wick/close records");
   SICTRangeSnapshot invalid=s; invalid.liquidity_events[0].confirmed_at=s.as_of+1;
   ICTRangePack(invalid,numbers,strings);
   Check(!ICTRangeUnpack(numbers,strings,decoded),"bridge rejects future liquidity event confirmation");
   invalid=s; invalid.liquidity_events[0].id="WRONG_EVENT_ID"; ICTRangePack(invalid,numbers,strings);
   Check(!ICTRangeUnpack(numbers,strings,decoded),"bridge rejects mismatched liquidity event ID");
   invalid=s; invalid.liquidity_events[0].type=(ENUM_IR_LEVEL_EVENT)99; ICTRangePack(invalid,numbers,strings);
   Check(!ICTRangeUnpack(numbers,strings,decoded),"bridge rejects unknown liquidity event types");
   invalid=s; invalid.schema=ICT_RANGE_SCHEMA-1; ICTRangePack(invalid,numbers,strings);
   Check(!ICTRangeUnpack(numbers,strings,decoded),"bridge refuses the previous schema rather than guessing new fields");
  }

void TestBreakoutConfiguration()
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.breakout_displacement_confirms=false;
   c.breakout_require_displacement=true;
   SICTRangeLevel l; LevelPool(l,1); MqlRates b;
   SICTSweepSequence sequence; ICTSweepSequenceStart(sequence,l.id,l.side,l.price,l.available_at);
   Bar(b,1000,99,105,98,104); ICTRangeAdvanceLevelConfigured(b,1300,1,5,false,c,1,0,l);
   ICTRangeAdvanceBoundarySequence(sequence,l,b,1300,c,1,1);
   Bar(b,1300,104,106,103,105); ICTRangeAdvanceLevelConfigured(b,1600,1,5,false,c,1,0,l);
   ICTRangeAdvanceBoundarySequence(sequence,l,b,1600,c,1,1);
   Check(l.candidate && l.last_event==IR_EVENT_NONE,"required displacement cannot be bought by enough outside closes");
   Check(sequence.valid,"legacy sweep records cannot declare a breakout before the configured level gates pass");
   Bar(b,1600,105,109,104,108); ICTRangeAdvanceLevelConfigured(b,1900,1,5,true,c,1,0,l);
   ICTRangeAdvanceBoundarySequence(sequence,l,b,1900,c,1,1);
   Check(l.state==IR_BREAKOUT && l.event_at==1900,"displacement during the confirmed outside sequence satisfies its explicit gate");
   Check(!sequence.valid,"configured confirmed breakout closes the boundary sweep sequence");
   LevelPool(l,1); c.breakout_require_displacement=false;
   Bar(b,1000,99,105,98,104); ICTRangeAdvanceLevelConfigured(b,1300,1,5,true,c,1,0,l);
   Check(l.candidate && l.state!=IR_BREAKOUT,"disabled displacement shortcut still waits for the configured close count");
   c.breakout_buffer_ticks=3; LevelPool(l,1);
   Bar(b,1000,99,103,98,102); ICTRangeAdvanceLevelConfigured(b,1300,1,5,false,c,1,0,l);
   Check(!l.candidate && l.last_event==IR_EVENT_NONE,"additional breakout buffer excludes a shallow outside close");
   c.breakout_buffer_ticks=0; c.retest_window_bars=1; c.retest_tolerance_ticks=1; c.retest_tolerance_atr=0;
   LevelPool(l,1);
   Bar(b,1000,99,105,98,104); ICTRangeAdvanceLevelConfigured(b,1300,1,5,false,c,1,0,l);
   Bar(b,1300,104,106,103,105); ICTRangeAdvanceLevelConfigured(b,1600,1,5,false,c,1,0,l);
   Bar(b,1600,104,107,103,106); ICTRangeAdvanceLevelConfigured(b,1900,1,5,false,c,1,0,l);
   Bar(b,1900,100,105,99,104); ICTRangeAdvanceLevelConfigured(b,2200,1,5,false,c,1,0,l);
   Check(l.last_event==IR_EVENT_BREAKOUT_CONFIRMED && !l.retest_pending && l.state==IR_BREAKOUT,
         "touch after the closed-bar retest window does not backdate a retest");
   Bar(b,2200,104,105,97,98); ICTRangeAdvanceLevelConfigured(b,2500,1,5,false,c,1,0,l);
   Check(l.state==IR_CONSUMED && l.last_event==IR_EVENT_FALSE_BREAKOUT,
         "expired retest window cannot hide a later failed source breakout");
   c.retest_window_bars=8; c.breakout_failure_ticks=2; LevelPool(l,1);
   Bar(b,1000,99,105,98,104); ICTRangeAdvanceLevelConfigured(b,1300,1,5,false,c,1,0,l);
   Bar(b,1300,104,106,103,105); ICTRangeAdvanceLevelConfigured(b,1600,1,5,false,c,1,0,l);
   Bar(b,1600,104,105,98,99); ICTRangeAdvanceLevelConfigured(b,1900,1,5,false,c,1,0,l);
   Check(l.state==IR_BREAKOUT && l.last_event==IR_EVENT_BREAKOUT_CONFIRMED,"failure buffer ignores a shallow inside close");
   Bar(b,1900,99,101,96,97); ICTRangeAdvanceLevelConfigured(b,2200,1,5,false,c,1,0,l);
   Check(l.state==IR_CONSUMED && l.last_event==IR_EVENT_FALSE_BREAKOUT,"buffered inside close marks confirmed breakout failure");
   c.retest_window_bars=0; Check(!ICTValidRangeConfig(c),"zero retest window is rejected");
   c.retest_window_bars=8; c.retest_tolerance_ticks=-1; Check(!ICTValidRangeConfig(c),"negative retest buffer is rejected");
  }

void TestRepeatedLevelSweeps()
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.sweep_min_bars=2; c.sweep_rejection_ticks=1;
   SICTRangeLevel l; LevelPool(l,1); MqlRates b;
   Bar(b,1000,99,104,98,99); ICTRangeAdvanceLevelConfigured(b,1300,1,5,false,c,1,0,l);
   SICTRangeLevel first=l;
   Bar(b,1300,99,105,98,99); ICTRangeAdvanceLevelConfigured(b,1600,1,5,false,c,1,0,l);
   Check(l.sweep_count==1 && l.event_at==first.event_at,"adjacent penetrating candles do not count as independent sweeps");
   Bar(b,1600,98,99,97,98); ICTRangeAdvanceLevelConfigured(b,1900,1,5,false,c,1,0,l);
   Check(l.sweep_armed && l.sweep_count==1,"separate rejection and minimum bar spacing rearm the same pool");
   Bar(b,1900,99,106,98,99); ICTRangeAdvanceLevelConfigured(b,2200,1,5,false,c,1,0,l);
   Check(l.sweep_count==2 && l.id==first.id && l.event_at==2200 && l.event_wick==106,
         "a second independent sweep retains source pool identity");
   SICTRangeSnapshot s; ZeroMemory(s); s.as_of=2200; s.ltf=PERIOD_M5;
   ICTRangeRecordLiquidityEvent(s,first); ICTRangeRecordLiquidityEvent(s,l);
   Check(s.liquidity_event_count==2 && s.liquidity_events[0].sweep_number==1 &&
         s.liquidity_events[0].wick==104 && s.liquidity_events[0].confirmed_at==1300 &&
         s.liquidity_events[1].sweep_number==2,"later sweep leaves the first wick and confirmation immutable");
  }

void TestSweepSequence()
  {
   SICTSweepSequence s; ICTSweepSequenceStart(s,"POOL_BSL",1,100,1000);
   MqlRates b; Bar(b,1000,99,103,98,99);
   ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.count==1 && s.events[0].status==ICT_SWEEP_CONFIRMED &&
         s.events[0].confirmed_at==1300,"first BSL sweep confirmed once on close");
   SICTSweepRecord first=s.events[0];
   ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.count==1,"same candle never counted twice");
   Bar(b,1300,99,104,97,98); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.count==1 && !s.armed,"repeated penetration cannot rearm on first bar");
   Bar(b,1600,98,99,96,98); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.armed && s.count==1,"separate rejection re-arms pool");
   Bar(b,1900,99,105,98,99); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.count==2 && s.events[1].number==2 && s.events[1].pool_id==first.pool_id &&
         s.events[1].status==ICT_SWEEP_CONFIRMED,"second independent sweep uses same pool");
   Check(s.events[0].event_time==first.event_time && s.events[0].extreme==first.extreme &&
         s.events[0].confirmed_at==first.confirmed_at,"second sweep does not repaint first");
   Bar(b,2200,98,99,97,98); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Bar(b,2500,98,99,97,98); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Bar(b,2800,99,106,98,99); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.count==3 && s.events[2].number==3,"third sweep retained");
   Bar(b,3100,101,104,100,103); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Bar(b,3400,103,105,102,104); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(!s.valid && s.count==3,"confirmed breakout invalidates pool");
   Bar(b,3700,99,108,98,99); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.count==3 && s.events[0].confirmed_at==first.confirmed_at,"invalidated pool cannot count or revise history");
   ICTSweepSequenceStart(s,"POOL_SSL",-1,100,1000);
   Bar(b,1000,100,101,97,98); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.count==1 && s.events[0].status==ICT_SWEEP_CANDIDATE,"outside close creates candidate");
   Bar(b,1300,99,102,96,101); ICTSweepSequenceStep(s,b,300,1,2,2,3,2);
   Check(s.count==1 && s.events[0].status==ICT_SWEEP_CONFIRMED && s.events[0].extreme==96,
         "delayed reclaim confirms one SSL event with lowest excursion");
  }

void TestBPR()
  {
   MqlRates bars[6];
   Bar(bars[0],1000,99,100,98,99); Bar(bars[1],1300,100,101,99,100);
   Bar(bars[2],1600,103,104,102,103); Bar(bars[3],1900,102,104,101,102);
   Bar(bars[4],2200,100,101,99,100); Bar(bars[5],2500,101,104,100,103);
   SICTBalancedPriceRange b;
   Check(!ICTFindBPRFromRates("TEST",PERIOD_M5,bars,4,0.5,0.5,b),"BPR needs both FVGs");
   Check(ICTFindBPRFromRates("TEST",PERIOD_M5,bars,5,0.5,0.5,b) &&
         b.lower==101 && b.upper==102 && b.direction==-1 && b.state==ICT_BPR_CONFIRMED &&
         b.confirmed_at==2500,"BPR overlap confirmed only after newer opposite FVG closes");
   string id=b.id;
   Check(ICTFindBPRFromRates("TEST",PERIOD_M5,bars,6,0.5,0.5,b) &&
         b.id==id && b.state==ICT_BPR_INVALIDATED && b.invalidated_at==2800,
         "later closed breakout invalidates existing BPR without backdating");
  }

void TestRotation(const int direction)
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.require_displacement=false; c.tolerance_ticks=0;
   c.tolerance_atr=0; c.penetration_atr=0; c.lookback=80; c.max_zone_age=48; c.use_ob=false;
   const datetime start=100000; const datetime asof=start+30*300;
   MqlRates low[40],mid[44];
   for(int i=0;i<40;i++) Bar(low[i],start+i*300,120,122,118,120);
   for(int i=0;i<44;i++) Bar(mid[i],asof-600-40*900+i*900,100,102,98,100);
   Bar(low[29],start+29*300,98,103,85,95);
   Bar(low[30],start+30*300,120,122,117,120);
   Bar(low[31],start+31*300,106,113,105,111);
   Bar(low[32],start+32*300,120,151,118,149);
   // Latest MTF break and the FVG's third candle close at asof + 300.
   Bar(mid[38],mid[38].time,98,100,96,99);
   Bar(mid[39],mid[39].time,96,115,95,113);
   Bar(mid[40],mid[40].time,112,120,108,118);
   SMarketStructure ms,ls; ZeroMemory(ms); ZeroMemory(ls);
   SICTDealingRange r; ZeroMemory(r);
   r.valid=true; r.id="TEST_RANGE"; r.high=150; r.low=90; r.width=60; r.midpoint=120;
   r.bias=direction; r.direction=direction; r.timeframe=c.htf;
   r.high_time=start-900; r.low_time=start-1800; r.confirmed_at=asof-600;
   SICTRangeLevel periods[2]; ZeroMemory(periods);
   periods[0].name="PWH"; periods[0].price=160; periods[0].side=1; periods[0].available_at=start;
   periods[1].name="PWL"; periods[1].price=70; periods[1].side=-1; periods[1].available_at=start;
   if(direction<0)
     {
      for(int i=0;i<40;i++) { MqlRates b=low[i]; Bar(low[i],b.time,240-b.open,240-b.low,240-b.high,240-b.close); }
      for(int i=0;i<44;i++) { MqlRates b=mid[i]; Bar(mid[i],b.time,240-b.open,240-b.low,240-b.high,240-b.close); }
      r.high_time=start-1800; r.low_time=start-900;
     }
   CICTRangeEngine engine; SICTRangeSnapshot s;
   CICTRangeEngine missing;
   Check(!missing.Step("TEST",c,r,ms,ls,mid,40,low,15,periods,2,1),"missing LTF data rejected");
   missing.Snapshot(s); Check(!s.valid && !s.technical_ready && s.reason_code==IR_DATA,"missing data yields no actionable setup");
   Check(engine.Step("TEST",c,r,ms,ls,mid,40,low,30,periods,2,1),"initial rotation step");
   engine.Snapshot(s);
   Check(s.phase==IR_SWEEP_CONFIRMED && s.direction==direction && !s.technical_ready,"sweep alone does not confirm entry");
   ms.bos_direction=direction; ms.mss=true; ms.bos_time=mid[40].time;
   Check(engine.Step("TEST",c,r,ms,ls,mid,41,low,31,periods,2,1),"post sweep structure step");
   engine.Snapshot(s);
   Check(s.phase==IR_STRUCTURE_SHIFT && s.active_zone.id!="" && s.active_zone.membership==IR_INTERNAL,"select confirmed internal FVG");
   CICTRangeEngine ambiguous;
   SMarketStructure before_shift; ZeroMemory(before_shift);
   ambiguous.Step("TEST",c,r,before_shift,ls,mid,40,low,30,periods,2,1);
   ambiguous.Step("TEST",c,r,ms,ls,mid,41,low,31,periods,2,1);
   MqlRates original_reaction=low[31];
   if(direction>0) low[31].high=150; else low[31].low=90;
   ambiguous.Step("TEST",c,r,ms,ls,mid,41,low,32,periods,2,1);
   ambiguous.Snapshot(s);
   Check(s.phase==IR_SETUP_INVALIDATED && !s.technical_ready,"target touch in reaction candle invalidates ambiguous setup");
   CICTRangeEngine swept_target;
   low[31]=original_reaction;
   swept_target.Step("TEST",c,r,before_shift,ls,mid,40,low,30,periods,2,1);
   swept_target.Step("TEST",c,r,ms,ls,mid,41,low,31,periods,2,1);
   if(direction>0) low[31].high=151; else low[31].low=89;
   swept_target.Step("TEST",c,r,ms,ls,mid,41,low,32,periods,2,1);
   swept_target.Snapshot(s);
   Check(s.phase==IR_SETUP_INVALIDATED && !s.technical_ready,"swept near target cannot silently rotate to a farther target");
   low[31]=original_reaction;
   Check(engine.Step("TEST",c,r,ms,ls,mid,41,low,32,periods,2,1),"closed IRL reaction step");
   engine.Snapshot(s);
   Check(s.phase==IR_TARGETING && s.technical_ready && s.direction==direction,"confirmed bullish/bearish rotation");
   Check(s.tp1==(direction>0 ? 150 : 90) && s.tp2==(direction>0 ? 160 : 70),"unconsumed external targets ranked");
   Check(s.source_pool_id!="" && s.source_pool_tf==c.htf && s.source_event==IR_EVENT_LIQUIDITY_SWEEP &&
         s.source_reason==ICTRangeSourceExplanation(s) && s.target1_pool_id!="" && s.target1_pool_tf==c.htf &&
         s.target2_pool_id!="" && s.target2_pool_tf==PERIOD_W1,
         "rotation carries actual source and target pool identities/timeframes");
   Check(ICTRangePlanGeometry(s,2),"valid BUY/SELL gross RR geometry");
   SICTRangeSnapshot bad=s; bad.tp1=bad.entry+(bad.entry-bad.stop)*0.5;
   Check(!ICTRangePlanGeometry(bad,2),"RR below two vetoes plan");
   bad=s; bad.valid=false; Check(!ICTRangePlanGeometry(bad,2),"missing data vetoes plan");
   bad=s; bad.active_zone.range_id="OTHER"; Check(!ICTRangePlanGeometry(bad,2),"mixed-range plan veto");
   int events=engine.EventCount(); datetime confirmed=s.reaction_at;
   // A future suffix must never influence the same historical observation.
   low[39].high=1000000;
   engine.Step("TEST",c,r,ms,ls,mid,41,low,32,periods,2,1); engine.Snapshot(s);
   Check(engine.EventCount()==events && s.reaction_at==confirmed,"duplicate close leaves event timestamps unchanged");
   CICTRangeEngine prefix_engine;
   prefix_engine.Step("TEST",c,r,ms,ls,mid,40,low,30,periods,2,1);
   prefix_engine.Step("TEST",c,r,ms,ls,mid,41,low,31,periods,2,1);
   prefix_engine.Step("TEST",c,r,ms,ls,mid,41,low,32,periods,2,1);
   SICTRangeSnapshot prefix_snapshot; prefix_engine.Snapshot(prefix_snapshot);
   Check(prefix_snapshot.phase==s.phase && prefix_snapshot.reaction_at==s.reaction_at &&
         prefix_snapshot.tp1==s.tp1 && prefix_snapshot.active_zone.id==s.active_zone.id,
         "fresh chronological replay ignores modified future suffix");
   double numbers[]; string strings[]; ICTRangePack(s,numbers,strings);
   SICTRangeSnapshot decoded;
   Check(ICTRangeUnpack(numbers,strings,decoded),"snapshot pack/unpack");
   Check(decoded.range.id==s.range.id && decoded.active_zone.id==s.active_zone.id &&
          decoded.tp1==s.tp1 && decoded.reaction_at==s.reaction_at && decoded.levels[0].id==s.levels[0].id &&
          decoded.source_pool_id==s.source_pool_id && decoded.target1_pool_id==s.target1_pool_id &&
          decoded.source_reason==s.source_reason && decoded.target_reason==s.target_reason &&
          decoded.liquidity_event_count==s.liquidity_event_count,
         "EA and indicator consume identical range/entry/target identity");
   SICTRangeSnapshot with_sweeps=s;
   with_sweeps.sweep_event_count=2;
   for(int j=0;j<2;j++)
     {
      ZeroMemory(with_sweeps.sweep_events[j]);
      with_sweeps.sweep_events[j].pool_id="SAME_POOL";
      with_sweeps.sweep_events[j].side=1; with_sweeps.sweep_events[j].number=j+1;
      with_sweeps.sweep_events[j].status=ICT_SWEEP_CONFIRMED;
      with_sweeps.sweep_events[j].level=150; with_sweeps.sweep_events[j].extreme=152+j;
      with_sweeps.sweep_events[j].depth=2+j;
      with_sweeps.sweep_events[j].event_time=s.as_of-900+j*300;
      with_sweeps.sweep_events[j].confirmed_at=s.as_of-600+j*300;
     }
   ICTRangePack(with_sweeps,numbers,strings);
   Check(ICTRangeUnpack(numbers,strings,decoded) && decoded.sweep_event_count==2 &&
         decoded.sweep_events[0].pool_id==decoded.sweep_events[1].pool_id &&
         decoded.sweep_events[0].number==1 && decoded.sweep_events[1].number==2 &&
         decoded.sweep_events[0].extreme==152 && decoded.sweep_events[1].extreme==153,
         "shared snapshot preserves both same-pool sweeps");
   ICTRangePack(s,numbers,strings);
   if(MQLInfoInteger(MQL_TESTER))
     {
      Check(ICTPublishRange("TEST",s) && ICTReadRange("TEST",decoded),"binary snapshot seqlock roundtrip");
       Check(!ICTReadRange("TEST",decoded,15,PERIOD_M1),"reader refuses a fresh snapshot from the previous chart timeframe");
      double seq=GlobalVariableGet(SRMPAdviceKey("TEST","IRSEQ"));
      GlobalVariableSet(SRMPAdviceKey("TEST","IRSEQ"),seq+1);
      Check(!ICTReadRange("TEST",decoded),"reader refuses in-progress publication");
      GlobalVariableSet(SRMPAdviceKey("TEST","IRSEQ"),seq);
     }
   ArrayResize(numbers,ArraySize(numbers)-1);
   Check(!ICTRangeUnpack(numbers,strings,decoded),"truncated snapshot rejected safely");
   engine.Step("TEST",c,r,ms,ls,mid,41,low,33,periods,2,1); engine.Snapshot(s);
   Check(s.phase==IR_TARGET_REACHED && !s.technical_ready,"later closed target touch ends readiness");
   SICTRangeLevel retained_boundary=s.levels[1];
   SICTRangeLiquidityEvent retained_event=s.liquidity_events[0];
   SICTDealingRange next=r; next.id="NEXT_RANGE"; next.confirmed_at=asof+1200;
   next.high_time=start+10000; next.high=160; next.midpoint=125; next.width=70;
   engine.Step("TEST",c,next,ms,ls,mid,41,low,34,periods,2,1);
   Check(engine.HistoryCount()==1,"retired range version retained");
   engine.Snapshot(s);
   Check(s.levels[1].id==retained_boundary.id && s.levels[1].state==retained_boundary.state &&
         s.levels[1].sweep_count==retained_boundary.sweep_count,"opposite range endpoint change preserves the surviving pool and sweep count");
   Check(s.liquidity_event_count>0 && s.liquidity_events[0].pool_id==retained_event.pool_id &&
         s.liquidity_events[0].range_id==retained_event.range_id && s.liquidity_events[0].confirmed_at==retained_event.confirmed_at,
         "range replacement retains the original event's observed range owner and confirmation");
   SICTRangeEvent e; bool monotonic=true; datetime prior=0;
   for(int i=0;i<engine.EventCount();i++)
     { engine.Event(i,e); if(e.confirmed_at<prior) monotonic=false; prior=e.confirmed_at; }
   Check(monotonic,"transition confirmation times never backdated");
   SICTRangeConfig changed=c; changed.ltf=PERIOD_M1;
   Check(!engine.Step("TEST",changed,next,ms,ls,mid,41,low,15,periods,2,1),"new LTF with insufficient history fails closed");
   engine.Snapshot(s);
   Check(s.ltf==PERIOD_M1 && !s.valid && engine.HistoryCount()==0 && engine.EventCount()==0 &&
         s.liquidity_event_count==0 && s.level_count==0 && s.source_pool_id=="" && s.target1_pool_id=="",
         "timeframe switch clears old range, pool, event and plan histories before data validation");
   Check(!engine.Step("OTHER",c,r,ms,ls,mid,41,low,15,periods,2,1),"new symbol with insufficient history fails closed");
   engine.Snapshot(s);
   Check(s.symbol=="OTHER" && s.ltf==c.ltf && !s.valid && s.liquidity_event_count==0 && s.level_count==0,
         "symbol switch cannot expose the previous context's liquidity history");
  }

void TestInternalSweepContinuation(const int direction)
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.require_displacement=false; c.use_ob=false;
   c.tolerance_ticks=0; c.tolerance_atr=0; c.penetration_atr=0; c.lookback=80;
   const datetime start=100000,asof=start+30*300;
   MqlRates low[40],mid[44];
   for(int i=0;i<40;i++) Bar(low[i],start+i*300,120,122,118,120);
   for(int i=0;i<44;i++) Bar(mid[i],asof-600-40*900+i*900,100,102,98,100);
   Bar(low[29],start+29*300,112,116,105,113);
   Bar(low[30],start+30*300,120,122,117,120);
   Bar(low[31],start+31*300,106,113,105,111);
   Bar(low[32],start+32*300,120,151,118,149);
   Bar(low[33],start+33*300,112,116,105,113);
   Bar(mid[38],mid[38].time,98,100,96,99);
   Bar(mid[39],mid[39].time,96,115,95,113);
   Bar(mid[40],mid[40].time,112,120,108,118);
   if(direction<0)
     {
      for(int i=0;i<40;i++) { MqlRates b=low[i]; Bar(low[i],b.time,240-b.open,240-b.low,240-b.high,240-b.close); }
      for(int i=0;i<44;i++) { MqlRates b=mid[i]; Bar(mid[i],b.time,240-b.open,240-b.low,240-b.high,240-b.close); }
     }
   SICTDealingRange r; ZeroMemory(r); r.valid=true; r.id="INTERNAL_SWEEP_RANGE";
   r.high=150; r.low=90; r.midpoint=120; r.width=60; r.bias=direction; r.direction=direction;
   r.timeframe=c.htf; r.high_time=start-900; r.low_time=start-1800; r.confirmed_at=asof-600;
   SMarketStructure ms,ls; ZeroMemory(ms); ZeroMemory(ls);
   ms.bos_direction=direction; ms.bos_time=mid[39].time;
   if(direction>0) { ls.recent_low=110; ls.recent_low_confirmed_time=start+26*300; }
   else { ls.recent_high=130; ls.recent_high_confirmed_time=start+26*300; }
   SICTRangeLevel periods[1]; ZeroMemory(periods);
   CICTRangeEngine engine; SICTRangeSnapshot s;
   Check(engine.Step("TEST",c,r,ms,ls,mid,40,low,30,periods,0,1),"internal sweep prefix accepted");
   engine.Snapshot(s);
   Check(s.scenario==IR_CONTINUATION && s.phase==IR_SWEEP_CONFIRMED &&
         s.direction==direction && s.sweep_at==asof && !s.structure_confirmed,
         "internal sweep starts continuation but prior MTF BOS cannot confirm it");
   ms.bos_direction=direction; ms.bos_time=mid[40].time;
   engine.Step("TEST",c,r,ms,ls,mid,41,low,31,periods,0,1); engine.Snapshot(s);
   Check(s.phase==IR_STRUCTURE_SHIFT && s.structure_at>s.sweep_at,
         "internal continuation waits for later aligned MTF structure");
   engine.Step("TEST",c,r,ms,ls,mid,41,low,32,periods,0,1); engine.Snapshot(s);
   Check(s.phase==IR_TARGETING && s.technical_ready && s.target1_pool_id!="",
         "internal continuation requires a closed IRL reaction and external target");
   engine.Step("TEST",c,r,ms,ls,mid,41,low,33,periods,0,1); engine.Snapshot(s);
   Check(s.phase==IR_TARGET_REACHED,"first internal continuation reaches its target");
   engine.Step("TEST",c,r,ms,ls,mid,41,low,34,periods,0,1); engine.Snapshot(s);
   Check(s.phase==IR_SWEEP_CONFIRMED && s.scenario==IR_CONTINUATION &&
         s.sweep_at==asof+1200 && !s.technical_ready,
         "later distinct internal sweep rearms same range without replaying old signal");
  }

void TestBreakoutSourceFailure(const int direction)
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.require_displacement=false; c.use_ob=false;
   c.breakout_displacement_confirms=false; c.penetration_atr=0;
   const datetime start=100000,asof=start+30*300;
   MqlRates low[32],mid[40];
   for(int i=0;i<32;i++) Bar(low[i],start+i*300,120,122,118,120);
   for(int i=0;i<40;i++) Bar(mid[i],asof-600-40*900+i*900,120,122,118,120);
   Bar(low[29],start+29*300,149,155,148,154);
   Bar(low[30],start+30*300,154,156,153,155);
   Bar(low[31],start+31*300,155,156,147,148);
   if(direction<0)
      for(int i=0;i<32;i++) { MqlRates b=low[i]; Bar(low[i],b.time,240-b.open,240-b.low,240-b.high,240-b.close); }
   SICTDealingRange r; ZeroMemory(r); r.id="BREAKOUT_RANGE"; r.valid=true; r.timeframe=c.htf;
   r.high=150; r.low=90; r.midpoint=120; r.width=60; r.bias=direction; r.direction=direction;
   r.high_time=start-900; r.low_time=start-1800; r.confirmed_at=asof-600;
   SMarketStructure ms,ls; ZeroMemory(ms); ZeroMemory(ls); SICTRangeLevel periods[1]; ZeroMemory(periods);
   CICTRangeEngine engine; SICTRangeSnapshot s;
   Check(engine.Step("TEST",c,r,ms,ls,mid,40,low,30,periods,0,1),"breakout source candidate prefix accepted");
   Check(engine.Step("TEST",c,r,ms,ls,mid,40,low,31,periods,0,1),"breakout source confirmation prefix accepted");
   engine.Snapshot(s);
   Check(s.source_pool_id!="" && s.source_event==IR_EVENT_BREAKOUT_CONFIRMED &&
         s.source_reason==ICTRangeSourceExplanation(s) && s.scenario==IR_BREAKOUT_CONTINUATION,
         "confirmed breakout source identity and reason alias agree");
   SICTRangeLiquidityEvent original=s.liquidity_events[0];
   Check(engine.Step("TEST",c,r,ms,ls,mid,40,low,32,periods,0,1),"breakout failure prefix accepted as an observation");
   engine.Snapshot(s);
   Check(s.phase==IR_SETUP_INVALIDATED && !s.technical_ready && s.source_event==IR_EVENT_FALSE_BREAKOUT &&
         s.source_event_at==asof+600 && s.source_reason==ICTRangeSourceExplanation(s) &&
         StringFind(s.target_reason,"TARGET UNAVAILABLE: source breakout failed")==0 &&
         s.tp1==0 && s.tp2==0 && s.target1_pool_id=="" && s.target2_pool_id=="",
         "source false breakout invalidates readiness and updates both source/target explanations");
   Check(s.liquidity_events[0].type==original.type && s.liquidity_events[0].confirmed_at==original.confirmed_at &&
         s.liquidity_events[0].wick==original.wick,"source failure cannot rewrite the earlier breakout observation");
  }

int OnInit()
  {
   TestHistoryClock(); TestRangeAndMembership(); TestSweepBreakout(); TestSweepSequence(); TestBPR();
   TestFalseBreakoutRetest(1); TestFalseBreakoutRetest(-1); TestBreakoutConfiguration(); TestRepeatedLevelSweeps();
   TestRotation(1); TestRotation(-1);
   TestInternalSweepContinuation(1); TestInternalSweepContinuation(-1);
   TestBreakoutSourceFailure(1); TestBreakoutSourceFailure(-1);
   PrintFormat("ICTRangeTests RESULT assertions=%d failures=%d",g_assertions,g_failures);
   return g_failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
  }
void OnTick() {}
double OnTester()
  { PrintFormat("ICTRangeTests RESULT assertions=%d failures=%d",g_assertions,g_failures); return g_failures; }
