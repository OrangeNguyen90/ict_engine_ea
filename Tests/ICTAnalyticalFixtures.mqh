#ifndef ICT_ANALYTICAL_FIXTURES_MQH
#define ICT_ANALYTICAL_FIXTURES_MQH
void AnalyticalFixture(SICTAnalyticalContext &c,SICTAnalyticalVotes &v)
  {
   ZeroMemory(c); ZeroMemory(v); c.symbol="TEST"; c.valid=true;
   c.ltf=PERIOD_M5; c.mtf=PERIOD_M15; c.htf=PERIOD_H1;
   c.asof=100300; c.ltf_closed=c.asof; c.mtf_closed=99900; c.htf_closed=97200;
   c.htf_bias=1; c.mtf_bias=1;
   for(int i=0;i<4;i++) v.available[i]=true;
   v.value[ICT_A_PATH]=0.8; v.value[ICT_A_CANDLE]=0.5;
  }
void TestAnalyticalConsensus()
  {
   SICTAnalyticalContext c; SICTAnalyticalVotes v; SICTAnalyticalConfig config; SICTAnalyticalResult s;
   AnalyticalFixture(c,v); ICTAnalyticalDefaults(config);
   Check("analysis defaults are valid",ICTAnalyticalValidConfig(config));
   Check("early analysis accepts partial evidence without requiring all six groups",ICTAnalyticalEvaluate(config,c,v,s) &&
      s.signal && s.groups==4 && s.supporters==2 && !s.deep_used && MathAbs(s.score-66.25)<1e-9);
   Check("analysis does not change native context",c.htf_bias==1 && c.mtf_bias==1 && c.asof==100300);
   config.minimum_score=70;
   Check("higher analysis threshold suppresses the same candidate",!ICTAnalyticalEvaluate(config,c,v,s) && !s.signal);
   config.minimum_score=60; config.require_deep=true;
   Check("explicit deep requirement withholds technical-only signals",!ICTAnalyticalEvaluate(config,c,v,s) && !s.deep_used);
   v.available[ICT_A_DEEP]=true; v.value[ICT_A_DEEP]=0.6;
   Check("validated deep evidence participates once",ICTAnalyticalEvaluate(config,c,v,s) && s.deep_used && s.groups==5 &&
      MathAbs(s.score-69)<1e-9);
   AnalyticalFixture(c,v); ICTAnalyticalDefaults(config); v.value[ICT_A_LIQUIDITY]=-1; v.value[ICT_A_ZONES]=-1;
   Check("opposing evidence reduces mean instead of disappearing",!ICTAnalyticalEvaluate(config,c,v,s) &&
      s.opponents==2 && s.score<50);
   AnalyticalFixture(c,v); v.available[ICT_A_LIQUIDITY]=false; v.available[ICT_A_ZONES]=false;
   Check("too little coverage cannot inflate the mean",!ICTAnalyticalEvaluate(config,c,v,s) && !s.ready && s.groups==2);
   AnalyticalFixture(c,v); v.value[ICT_A_CANDLE]=0;
   Check("one strong group cannot replace the supporting quorum",!ICTAnalyticalEvaluate(config,c,v,s) && s.supporters==1);
   AnalyticalFixture(c,v); v.value[ICT_A_PATH]=0; v.value[ICT_A_CANDLE]=0;
   Check("observed neutrality stays at fifty and creates no signal",!ICTAnalyticalEvaluate(config,c,v,s) && s.score==50);
   AnalyticalFixture(c,v); v.value[ICT_A_PATH]=0.4; v.value[ICT_A_CANDLE]=0.4;
   Check("inclusive score boundary is deterministic",ICTAnalyticalEvaluate(config,c,v,s) && MathAbs(s.score-60)<1e-9);
   AnalyticalFixture(c,v); c.htf_bias=-1; c.mtf_bias=-1; v.value[ICT_A_PATH]*=-1; v.value[ICT_A_CANDLE]*=-1;
   Check("bearish analysis is symmetric",ICTAnalyticalEvaluate(config,c,v,s) && s.direction==-1 && MathAbs(s.score-66.25)<1e-9);
   c.mtf_bias=1;
   Check("lower threshold never overrides opposite MTF",!ICTAnalyticalEvaluate(config,c,v,s) && !s.ready);
   c.mtf_bias=0;
   Check("neutral MTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   c.mtf_bias=-1; c.htf_bias=0;
   Check("neutral HTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.htf_closed=c.asof+1;
   Check("future HTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.mtf_closed=0;
   Check("missing MTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.ltf_closed=c.asof-1;
   Check("stale LTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.mtf=c.ltf;
   Check("duplicate tiers remain blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.valid=false;
   Check("invalid native context remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); v.value[ICT_A_PATH]=1.01;
   Check("invalid evidence cannot be renormalized into a signal",!ICTAnalyticalEvaluate(config,c,v,s) && !s.signal);
   v.value[ICT_A_PATH]=0.8; config.minimum_groups=1;
   Check("invalid coverage configuration is rejected",!ICTAnalyticalEvaluate(config,c,v,s));
   ICTAnalyticalDefaults(config); config.minimum_supporters=4;
   Check("supporting quorum cannot exceed required coverage",!ICTAnalyticalValidConfig(config));
   ICTAnalyticalDefaults(config); config.minimum_score=50;
   Check("neutral-score threshold is not an analysis preset",!ICTAnalyticalValidConfig(config));
   int loose=0,strict=0;
   for(int i=0;i<=10;i++)
     {
      AnalyticalFixture(c,v); v.value[ICT_A_PATH]=i/10.0; v.value[ICT_A_CANDLE]=i/10.0;
      ICTAnalyticalDefaults(config); if(ICTAnalyticalEvaluate(config,c,v,s)) loose++;
      config.minimum_score=70; if(ICTAnalyticalEvaluate(config,c,v,s)) strict++;
     }
   Check("lower advisory threshold increases coverage on the fixed synthetic cohort",loose==7 && strict==3);
  }
void TestAnalyticalCausalityAndDeep()
  {
   MqlRates bars[]; ArrayResize(bars,40);
   for(int i=0;i<40;i++) FixtureBar(bars[i],100000+i*300,100+i*0.2,100.5+i*0.2,99.8+i*0.2,100.3+i*0.2);
   datetime asof=bars[39].time+300; SICTAnalyticalVotes v; ZeroMemory(v); double atr=0;
   Check("closed price path produces two bounded groups",ICTAnalyticalPriceVotes(bars,PERIOD_M5,asof,0.01,v,atr) &&
      v.available[ICT_A_PATH] && v.available[ICT_A_CANDLE] && MathAbs(v.value[ICT_A_PATH])<=1 && MathAbs(v.value[ICT_A_CANDLE])<=1);
   double path=v.value[ICT_A_PATH],candle=v.value[ICT_A_CANDLE];
   ArrayResize(bars,41); FixtureBar(bars[40],asof,1,9999,0,5000);
   Check("invalid unfinished future bar cannot change past evidence",ICTAnalyticalPriceVotes(bars,PERIOD_M5,asof,0.01,v,atr) &&
      MathAbs(v.value[ICT_A_PATH]-path)<1e-9 && MathAbs(v.value[ICT_A_CANDLE]-candle)<1e-9);
   Check("stale price prefix is not current analysis",!ICTAnalyticalPriceVotes(bars,PERIOD_M5,asof-1,0.01,v,atr));
   ICTAnalyticalPriceVotes(bars,PERIOD_M5,asof,0.01,v,atr);
   SICTStatModel model; SICTStatSnapshot stat; ZeroMemory(model); ZeroMemory(stat);
   model.fitted=true; model.calibrated=true; model.train_end=bars[5].time; model.cal_end=bars[15].time; model.test_end=bars[30].time;
   for(int i=0;i<ICT_STAT_FEATURES;i++) model.scale[i]=100;
   stat.ready=true; stat.calibrated=true; stat.horizon=4; stat.asof=bars[39].time;
   stat.dl[0]=0.7; stat.dl[1]=0.2; stat.dl[2]=0.1; stat.brier_dl=0.4; stat.brier_baseline=0.6;
   Check("calibrated current DNN contributes its directional probability difference",
      ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v) && MathAbs(v.value[ICT_A_DEEP]-0.5)<1e-9);
   Check("DNN from a different timeframe is excluded",
      !ICTAnalyticalDeepVote(model,stat,bars,PERIOD_H1,PERIOD_M5,asof,0.01,v) && !v.available[ICT_A_DEEP]);
   stat.asof-=300;
   Check("stale DNN is excluded",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   stat.asof+=600;
   Check("future DNN is excluded",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   stat.asof=bars[39].time; model.calibrated=false;
   Check("uncalibrated DNN is excluded",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   model.calibrated=true; stat.brier_dl=0.6;
   Check("DNN must beat baseline in its own metric",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   SICTAnalyticalDeepState advisory;
   Check("calibrated non-winning DNN is explicitly experimental in early mode",
      ICTAnalyticalDeepEvidence(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,advisory,v) &&
      advisory.ready && !advisory.validated && advisory.weight==0.35);
   stat.brier_dl=0.4; model.test_end=asof;
   Check("future evaluation labels cannot admit DNN",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   Check("early experimental mode still rejects future evaluation labels",
      !ICTAnalyticalDeepEvidence(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,advisory,v));
   model.test_end=bars[30].time; model.mean[0]=1000000; model.scale[0]=1;
   Check("out of domain features cannot admit DNN",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   Check("early domain warning is explicit and receives experimental weight",
      ICTAnalyticalDeepEvidence(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,advisory,v) && !advisory.domain_ok && !advisory.validated);
   model.mean[0]=0; model.scale[0]=100; stat.dl[2]=0.9;
   Check("invalid probability mass cannot admit DNN",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   Check("early experimental mode never accepts invalid probability mass",
      !ICTAnalyticalDeepEvidence(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,advisory,v));
   SICTRangeSnapshot r; ZeroMemory(r); r.symbol="TEST"; r.valid=true; r.as_of=asof; r.ltf=PERIOD_M5;
   r.liquidity_event_count=1; r.liquidity_events[0].side=-1; r.liquidity_events[0].type=IR_EVENT_LIQUIDITY_SWEEP;
   r.liquidity_events[0].confirmed_at=asof;
   ZeroMemory(v); ICTAnalyticalLiquidityVote(r,"TEST",asof,PERIOD_M5,12,v);
   Check("native SSL reclaim supports bullish analysis",v.available[ICT_A_LIQUIDITY] && v.value[ICT_A_LIQUIDITY]==1);
   r.liquidity_event_count=2; r.liquidity_events[1].side=1;
   r.liquidity_events[1].type=IR_EVENT_LIQUIDITY_SWEEP; r.liquidity_events[1].confirmed_at=asof;
   ICTAnalyticalLiquidityVote(r,"TEST",asof,PERIOD_M5,12,v);
   Check("simultaneous opposing native events cancel",v.value[ICT_A_LIQUIDITY]==0);
   r.liquidity_event_count=1; r.liquidity_events[0].confirmed_at=asof+1;
   ICTAnalyticalLiquidityVote(r,"TEST",asof,PERIOD_M5,12,v);
   Check("future native event cannot support analysis",v.value[ICT_A_LIQUIDITY]==0);
   r.as_of--; ZeroMemory(v); ICTAnalyticalLiquidityVote(r,"TEST",asof,PERIOD_M5,12,v);
   Check("stale native liquidity is missing rather than neutral",!v.available[ICT_A_LIQUIDITY]);
   r.as_of=asof; r.range.id="R"; r.zone_count=1; r.zones[0].range_id="R";
   r.zones[0].direction=1; r.zones[0].lower=bars[39].low; r.zones[0].upper=bars[39].close;
   r.zones[0].quality=80; r.zones[0].state=IR_FRESH; r.zones[0].confirmed_at=bars[38].time;
   ZeroMemory(v); ICTAnalyticalRangeZonesVote(r,"TEST",asof,bars[39],atr,v);
   Check("closed reaction to an available native zone supports analysis",v.available[ICT_A_ZONES] && v.value[ICT_A_ZONES]>0.8);
   double zone_score=v.value[ICT_A_ZONES]; r.zone_count=2;
   r.zones[1].range_id="R"; r.zones[1].direction=1; r.zones[1].lower=bars[39].low; r.zones[1].upper=bars[39].close;
   r.zones[1].quality=80; r.zones[1].state=IR_FRESH; r.zones[1].confirmed_at=bars[38].time;
   ICTAnalyticalRangeZonesVote(r,"TEST",asof,bars[39],atr,v);
   Check("duplicated zones do not multiply a family vote",MathAbs(v.value[ICT_A_ZONES]-zone_score)<1e-9);
   r.zone_count=1; r.zones[0].state=IR_ZONE_INVALIDATED; ICTAnalyticalRangeZonesVote(r,"TEST",asof,bars[39],atr,v);
   Check("invalidated zones do not support analysis",v.value[ICT_A_ZONES]==0);
   r.zones[0].state=IR_FRESH; r.zones[0].confirmed_at=asof;
   ICTAnalyticalRangeZonesVote(r,"TEST",asof,bars[39],atr,v);
   Check("zone created at the reaction close cannot be a prior retest",v.value[ICT_A_ZONES]==0);
   SICTUnifiedSnapshot u; ZeroMemory(u); u.valid=true; u.symbol="TEST"; u.asof=asof;
   u.layer_count=1; u.layers[0].last_close=asof; u.comparison1="PEER";
   u.layers[0].peers[0].comparison="PEER"; u.layers[0].peers[0].last_close=asof;
   u.layers[0].peers[0].ready=true; u.layers[0].peers[0].relation_known=true;
   u.layers[0].peers[0].state=ICT_SMT_PEER_BEARISH;
   ZeroMemory(v); ICTAnalyticalUnifiedVotes(u,bars[39],atr,v);
   Check("opposite SMT remains negative evidence",v.available[ICT_A_SMT] && v.value[ICT_A_SMT]==-1);
   u.layers[0].peers[0].ready=false; ZeroMemory(v); ICTAnalyticalUnifiedVotes(u,bars[39],atr,v);
   Check("unavailable SMT is not counted as no divergence",!v.available[ICT_A_SMT]);
  }
void RunICTAnalyticalFixtures()
  { TestAnalyticalConsensus(); TestAnalyticalCausalityAndDeep(); TestAnalyticalEarlyPolicy(); }

void TestAnalyticalEarlyPolicy()
  {
   SICTAnalyticalContext c; SICTAnalyticalVotes v; AnalyticalFixture(c,v);
   SICTAnalyticalPolicy p; ICTAnalyticalPolicyDefaults(p); SICTAnalyticalResult result;
   SICTAnalyticalDeepState deep; ZeroMemory(deep); deep.ready=true; deep.validated=true; deep.domain_ok=true;
   deep.weight=1; deep.direction=1; deep.probability[0]=0.6; deep.probability[1]=0.2; deep.probability[2]=0.2;
   v.available[ICT_A_DEEP]=true; v.value[ICT_A_DEEP]=0.4;
   Check("early defaults request actual DL with a lower advisory threshold",ICTAnalyticalPolicyValid(p) && p.require_deep &&
      p.minimum_score==55 && p.minimum_groups==2 && p.minimum_supporters==1);
   Check("current trained DL plus price produces analysis",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) && result.deep_used);
   c.htf_bias=0; c.mtf_bias=0;
   Check("neutral native MTF can accompany explicitly early DL",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) && !result.context_aligned);
   Check("strict native context still rejects the same neutral tiers",!ICTAnalyticalContextReady(c));
   c.htf_bias=1; c.mtf_bias=-1;
   Check("conflicting MTF is disclosed rather than preventing all DL analysis",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) &&
      !result.context_aligned && StringFind(result.reason,"chưa xác nhận")>=0);
   p.strict_context=true;
   Check("optional strict early mode keeps the original MTF veto",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   p.strict_context=false; c.mtf_closed=0; c.htf_closed=0; c.htf_bias=0; c.mtf_bias=0;
   Check("missing upper structure does not pretend alignment",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) && !result.context_aligned);
   c.htf_closed=c.asof+1;
   Check("future upper timestamps still reject early analysis",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   c.htf_closed=0; c.ltf_closed=c.asof-1;
   Check("stale LTF still rejects early analysis",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   c.ltf_closed=c.asof; deep.ready=false;
   Check("required DL cannot be replaced by technical heuristics",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   deep.ready=true; deep.direction=0;
   Check("neutral dominant DNN does not become a directional arrow",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   deep.direction=1; v.value[ICT_A_DEEP]=0.03;
   Check("nearly tied DNN directions remain a watch state",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   v.value[ICT_A_DEEP]=0.4; deep.validated=false; deep.weight=0.35;
   Check("experimental DL is explicitly identified",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) && result.experimental);
   double experimental_score=result.score; deep.validated=true; deep.weight=1;
   ICTAnalyticalEvaluateEarly(p,c,v,deep,result);
   Check("experimental evidence receives a score discount",experimental_score<result.score);
   deep.validated=false; deep.weight=0.35; p.allow_experimental=false;
   Check("experimental DL can be excluded without changing native rules",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   p.allow_experimental=true; v.value[ICT_A_PATH]=-0.8; v.value[ICT_A_CANDLE]=-0.5;
   Check("price opposition still defeats a weak experimental DNN",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   v.value[ICT_A_PATH]=0.8; v.value[ICT_A_CANDLE]=0.5; v.value[ICT_A_LIQUIDITY]=0; v.value[ICT_A_ZONES]=0;
   ICTAnalyticalEvaluateEarly(p,c,v,deep,result); double neutral_score=result.score;
   v.available[ICT_A_LIQUIDITY]=false; v.available[ICT_A_ZONES]=false;
   ICTAnalyticalEvaluateEarly(p,c,v,deep,result);
   Check("observed no-event groups do not dilute directional evidence",MathAbs(result.score-neutral_score)<1e-9 && result.groups==3);
   Check("early analysis never alters the original context",c.htf_bias==0 && c.mtf_bias==0 && c.asof==100300);
  }
#endif
