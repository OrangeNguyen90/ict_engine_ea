#ifndef ICT_STATISTICAL_LEARNING_FIXTURES_MQH
#define ICT_STATISTICAL_LEARNING_FIXTURES_MQH

void ICTStatFixtureSamples(SICTStatSample &samples[])
  {
   ArrayResize(samples,1200);
   for(int i=0;i<ArraySize(samples);i++)
     {
      SICTStatSample s; ZeroMemory(s);
      s.label=i%3; s.asof=(datetime)(1000000+i*240); s.label_end=s.asof+240;
      s.x[0]=s.label==0 ? 2.0 : s.label==1 ? -2.0 : 0.0;
      s.x[1]=s.label==2 ? 1.0 : -1.0;
      for(int k=2;k<32;k++) s.x[k]=MathSin(i*0.1+k)*0.05;
      s.mask=s.label==0 ? 85 : s.label==1 ? 170 : 0;
      samples[i]=s;
     }
  }
void ICTStatFixtureRates(MqlRates &rates[])
  {
   ArrayResize(rates,120);
   for(int i=0;i<ArraySize(rates);i++)
     {
      MqlRates r; ZeroMemory(r);
      r.time=(datetime)(1000000+i*60); r.open=100; r.close=100;
      r.high=100.5; r.low=99.5; r.spread=0; r.tick_volume=100;
      rates[i]=r;
     }
  }
void ICTLiquidityFixture(SICTRangeSnapshot &s,MqlRates &r[])
  {
   ICTStatFixtureRates(r); ZeroMemory(s);
   s.valid=true; s.schema=ICT_RANGE_SCHEMA; s.symbol="fixture"; s.ltf=PERIOD_M1;
   s.range.valid=true; s.range.id="native_range"; s.range.low=98; s.range.high=102;
   s.as_of=r[32].time+60; s.last_close=100; s.htf_bias=1; s.level_count=4;
   for(int i=0;i<4;i++)
     {
      SICTRangeLevel l; ZeroMemory(l); l.id="native_pool_"+IntegerToString(i); l.range_id=s.range.id;
      l.side=(i%2==0 ? 1 : -1); l.price=(i==0 ? 101 : i==1 ? 99 : i==2 ? 102 : 98);
      l.state=IR_UNTOUCHED; l.timeframe=(i<2 ? PERIOD_M5 : PERIOD_H1);
      l.membership=(i<2 ? IR_INTERNAL : IR_BOUNDARY); l.available_at=r[24].time;
      s.levels[i]=l;
     }
  }
void ICTLiquidityFixtureSamples(SICTStatSample &samples[])
  {
   ArrayResize(samples,600);
   for(int k=0;k<600;k++)
     {
      SICTRangeSnapshot snapshot; MqlRates r[]; ICTLiquidityFixture(snapshot,r);
      for(int i=0;i<ArraySize(r);i++) r[i].time=(datetime)((long)r[i].time+(long)k*3600);
      snapshot.as_of=r[32].time+60;
      for(int i=0;i<4;i++) snapshot.levels[i].available_at=r[24].time;
      SICTStatLiquidityPair p; ICTStatLiquiditySelectPair(snapshot,r,33,p);
      p.trend_bias=(k%3==0 ? 1 : k%3==1 ? -1 : 0); p.trend_closed_at=r[20].time;
      if(k%3==0) { r[33].high=101.2; r[33].close=101; }
      if(k%3==1) { r[33].low=98.8; r[33].close=99; }
      SICTStatSample sample; ICTStatLiquidityFeatures(r,32,60,0.01,p,sample);
      sample.label=ICTStatLiquidityLabel(r,ArraySize(r),32,4,60,p,sample.label_end);
      samples[k]=sample;
     }
  }
void RunICTLiquidityProbabilityFixtures()
  {
   SICTRangeSnapshot snapshot; MqlRates r[]; ICTLiquidityFixture(snapshot,r);
   SICTStatLiquidityPair p;
   Check("LIQ selects closest untouched native pair on both sides",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==101 && p.ssl==99 && p.bsl_id=="native_pool_0");
   SICTStatLiquidityPair parity; ICTStatLiquiditySelectPair(snapshot,r,33,parity);
   Check("LIQ replay parity checks frozen native identities",ICTStatLiquiditySamePair(p,parity));
   parity.bsl_id="different_native_pool";
   Check("LIQ same price cannot hide different native pool identity",!ICTStatLiquiditySamePair(p,parity));
   Check("LIQ retains native lifecycle semantics for renderer",ICTRangeLevelUntouched(snapshot.levels[0],snapshot.as_of));
   snapshot.levels[0].state=IR_APPROACHING;
   Check("LIQ near but not touched pool remains eligible",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==101);
   snapshot.levels[0].candidate=true;
   Check("LIQ pending breakout is not untouched",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==102);
   snapshot.levels[2].state=IR_CONSUMED;
   Check("LIQ does not invent a missing upper pool",!ICTStatLiquiditySelectPair(snapshot,r,33,p));
   ICTLiquidityFixture(snapshot,r);
   r[30].high=101;
   Check("LIQ exact wick touch excludes native-untouched pool",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==102);
   ICTLiquidityFixture(snapshot,r); r[35].high=120;
   Check("LIQ future wick cannot change historical pair",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==101 && p.ssl==99);
   ICTLiquidityFixture(snapshot,r);
   Check("LIQ respects hidden internal pool category",ICTStatLiquiditySelectPair(snapshot,r,33,p,false,true) && p.bsl==102 && p.ssl==98);
   Check("LIQ respects hidden external pool category",ICTStatLiquiditySelectPair(snapshot,r,33,p,true,false) && p.bsl==101 && p.ssl==99);
   Check("LIQ no forecast when all pool categories hidden",!ICTStatLiquiditySelectPair(snapshot,r,33,p,false,false));
   for(int i=0;i<4;i++) snapshot.levels[i].available_at=r[0].time-60;
   Check("LIQ missing pre-pool history cannot certify untouched",!ICTStatLiquiditySelectPair(snapshot,r,33,p));
   ICTLiquidityFixture(snapshot,r); r[28].time++;
   Check("LIQ missing intraday coverage cannot certify untouched",!ICTStatLiquiditySelectPair(snapshot,r,33,p));
   ICTLiquidityFixture(snapshot,r); snapshot.as_of++;
   Check("LIQ stale snapshot cannot reuse later OHLC",!ICTStatLiquiditySelectPair(snapshot,r,33,p));
   ICTLiquidityFixture(snapshot,r); snapshot.levels[0].available_at=snapshot.as_of;
   Check("LIQ newly confirmed pool starts its untouched clock at availability",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==101);
   ICTLiquidityFixture(snapshot,r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   p.trend_bias=1; p.trend_closed_at=r[20].time;
   SICTStatSample sample; SICTStatSample future;
   Check("LIQ features encode barriers and known long trend",ICTStatLiquidityFeatures(r,32,60,0.01,p,sample) && sample.x[22]==0.5 && sample.x[23]==1 && sample.asof==snapshot.as_of);
   r[40].close=1; r[40].low=0.5;
   ICTStatLiquidityFeatures(r,32,60,0.01,p,future);
   bool same=true; for(int k=0;k<32;k++) if(sample.x[k]!=future.x[k]) same=false;
   Check("LIQ post-snapshot price cannot rewrite features",same);
   p.trend_closed_at=p.asof+1;
   Check("LIQ future daily trend is forbidden",!ICTStatLiquidityFeatures(r,32,60,0.01,p,sample));
   p.trend_closed_at=r[20].time; r[20].time++;
   Check("LIQ feature window rejects unclassified gaps",!ICTStatLiquidityFeatures(r,32,60,0.01,p,sample));
   ICTLiquidityFixture(snapshot,r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   datetime end=0;
   r[33].high=101.2; r[33].close=101; r[34].low=98.8; r[34].close=99;
   Check("LIQ BSL first survives later SSL hit",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==0 && end==r[33].time+60);
   ICTLiquidityFixture(snapshot,r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   r[33].low=98.8; r[33].close=99; r[34].high=101.2; r[34].close=101;
   Check("LIQ SSL first survives later BSL hit",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==1);
   ICTLiquidityFixture(snapshot,r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   r[33].high=101; r[33].low=99;
   Check("LIQ same-bar two touches stay ambiguous",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==-2);
   r[33].open=101.1; r[33].high=101.2;
   Check("LIQ observed open precedes same-bar wicks",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==0);
   r[33].open=98.9; r[33].low=98.8;
   Check("LIQ lower observed open precedes same-bar wicks",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==1);
   ICTLiquidityFixture(snapshot,r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   r[33].high=101;
   Check("LIQ exact equality counts as first touch",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==0);
   Check("LIQ incomplete horizon excluded despite early hit",ICTStatLiquidityLabel(r,34,32,4,60,p,end)==-1);
   ICTLiquidityFixture(snapshot,r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   Check("LIQ timeout keeps third outcome",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==2 && end==r[36].time+60);
   r[34].time+=60;
   Check("LIQ gap inside target path is censored",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==-1);
   ICTLiquidityFixture(snapshot,r); ICTStatLiquiditySelectPair(snapshot,r,33,p); p.bsl=0;
   Check("LIQ invalid barrier cannot become timeout",ICTStatLiquidityLabel(r,120,32,4,60,p,end)==-1);
   SICTStatSample geometry_sample; ZeroMemory(geometry_sample); geometry_sample.x[22]=0.25;
   double geometry[3]; ICTStatLiquidityGeometry(geometry_sample,0.2,geometry);
   Check("LIQ distance baseline retains trained timeout prior",MathAbs(geometry[0]-0.2)<1e-9 && MathAbs(geometry[1]-0.6)<1e-9 && geometry[2]==0.2);

   SICTStatSample samples[]; ICTLiquidityFixtureSamples(samples);
   SICTStatConfig c; ICTStatDefaultConfig(c); c.min_train=200; c.min_evaluation=50;
   SICTStatModel model; SICTStatSnapshot metrics; SICTStatLiquidityAudit audit; ZeroMemory(audit);
   Check("LIQ native-feature first-touch samples prepare separately",ICTStatPrepare(c,samples,model,metrics));
   int steps=0; while(ICTStatTrainStep(model,samples,metrics) && steps++<100000) {}
   Check("LIQ trained first-touch network evaluates held-out labels",ICTStatFinish(model,samples,metrics) && metrics.ready);
   Check("LIQ synthetic long-trend signal beats both baselines",ICTStatLiquidityAuditModel(model,samples,metrics,audit) && audit.validation_pass);
   Check("LIQ calibration audit metrics are finite",audit.log_loss>=0 && audit.ece>=0 && audit.ece<=1 && MathIsValidNumber(audit.brier_geometry));
   SICTStatSnapshot prediction;
   Check("LIQ learned BSL-first probability comes from its own network",ICTStatPredict(model,samples[0],prediction) && prediction.dl[0]>0.75);
   Check("LIQ observed training context remains in support",ICTStatLiquidityInSupport(model,samples[0]));
   double distance=samples[0].x[20]; samples[0].x[20]+=100000;
   Check("LIQ unseen barrier geometry cannot publish clipped extrapolation",!ICTStatLiquidityInSupport(model,samples[0]));
   samples[0].x[20]=distance;
   bool calibrated=metrics.calibrated; metrics.calibrated=false;
   Check("LIQ uncalibrated model cannot publish probabilities",!ICTStatLiquidityAuditModel(model,samples,metrics,audit) && !audit.validation_pass);
   metrics.calibrated=calibrated; metrics.brier_combined=1.1;
   Check("LIQ poor first-touch model cannot pass distance baseline",!ICTStatLiquidityAuditModel(model,samples,metrics,audit));
  }

void RunICTStatisticalLearningFixtures()
  {
   SICTStatConfig c; ICTStatDefaultConfig(c);
   Check("STAT default configuration",ICTStatValidConfig(c));
   c.horizon=0; Check("STAT rejects zero horizon",!ICTStatValidConfig(c)); c.horizon=4;
   MqlRates rates[]; ICTStatFixtureRates(rates);
   Check("STAT validates ordered OHLC",ICTStatValidRates(rates));
   rates[20].time=rates[19].time; Check("STAT rejects duplicate bars",!ICTStatValidRates(rates)); ICTStatFixtureRates(rates);
   rates[20].high=99; Check("STAT rejects malformed OHLC",!ICTStatValidRates(rates)); ICTStatFixtureRates(rates);
   SICTStatSample before; SICTStatSample after;
   Check("STAT creates closed-prefix features",ICTStatFeatures(rates,32,0.01,before));
   rates[40].high=200; ICTStatFeatures(rates,32,0.01,after);
   bool unchanged=true; for(int k=0;k<32;k++) if(before.x[k]!=after.x[k]) unchanged=false;
   Check("STAT future bars cannot alter current features",unchanged && before.mask==after.mask);
   Check("STAT excludes immature labels",ICTStatLabel(rates,119,4,0.25,0.01)==-1);
   rates[36].close=101; rates[36].high=101.5;
   Check("STAT up label uses horizon close",ICTStatLabel(rates,32,4,0.25,0.01)==0);
   rates[36].close=99; rates[36].low=98.5;
   Check("STAT down label uses horizon close",ICTStatLabel(rates,32,4,0.25,0.01)==1);
   rates[36].close=100.1;
   Check("STAT flat label retains neutral class",ICTStatLabel(rates,32,4,0.25,0.01)==2);
   rates[36].close=100.3; rates[32].spread=10;
   Check("STAT recorded spread widens neutral band",ICTStatLabel(rates,32,4,0.25,0.01)==2);
   ICTStatFixtureRates(rates);
   rates[31].open=100.2; rates[31].close=99.9;
   rates[32].open=99.8; rates[32].close=100.3;
   Check("STAT bullish engulfing confirmation",(ICTStatPatternMask(rates,32) & 4)!=0);
   rates[32].low=99.2;
   Check("STAT bullish sweep reclaim confirmation",(ICTStatPatternMask(rates,32) & 1)!=0);
   rates[32].high=101; rates[32].close=100.8;
   Check("STAT breakout confirmation",(ICTStatPatternMask(rates,32) & 16)!=0);
   ICTStatFixtureRates(rates);
   rates[28].open=98.6; rates[28].close=98.8; rates[28].high=99; rates[28].low=98;
   rates[30].open=100.2; rates[30].close=100.4; rates[30].high=100.6; rates[30].low=100;
   rates[31].open=100.4; rates[31].close=100.3; rates[31].high=100.6; rates[31].low=100.1;
   rates[32].open=100.2; rates[32].close=100.5; rates[32].high=100.6; rates[32].low=100;
   Check("STAT first FVG retest",(ICTStatPatternMask(rates,32) & 64)!=0);
   rates[31].low=99.9;
   Check("STAT excludes consumed FVG retest",(ICTStatPatternMask(rates,32) & 64)==0);
   ICTStatFixtureRates(rates);
   SICTStatSample built[];
   Check("STAT builds only mature disjoint samples",ICTStatBuildSamples(rates,0.01,c,built) && ArraySize(built)>0 &&
      built[0].label_end<=built[1].asof && built[ArraySize(built)-1].label_end<=rates[119].time);
   SICTStatModel model; SICTStatModel other; SICTStatSnapshot snapshot; SICTStatSnapshot other_snapshot;
   SICTStatSample samples[],changed[]; ICTStatFixtureSamples(samples); ICTStatFixtureSamples(changed);
   Check("STAT prepares chronological partitions",ICTStatPrepare(c,samples,model,snapshot) &&
      model.train_end<model.cal_start_time && model.cal_end<model.test_start_time);
   datetime old_end=samples[model.train_n-1].label_end;
   samples[model.train_n-1].label_end=model.cal_start_time;
   Check("STAT purges boundary-crossing training labels",!ICTStatPrepare(c,samples,other,other_snapshot) && other_snapshot.status=="INVALID_SPLIT");
   samples[model.train_n-1].label_end=old_end;
   for(int i=model.test_start;i<ArraySize(changed);i++)
     { changed[i].x[0]+=100; changed[i].label=(changed[i].label+1)%3; }
   Check("STAT prepares changed future validation",ICTStatPrepare(c,changed,other,other_snapshot));
   Check("STAT scaler and priors fitted on train only",model.mean[0]==other.mean[0] && model.scale[0]==other.scale[0] && model.prior[0]==other.prior[0]);
   double initial[3],trained[3]; ICTStatForward(model,samples[0],true,1,initial);
   int steps=0;
   while(ICTStatTrainStep(model,samples,snapshot) && steps++<100000) {}
   steps=0; while(ICTStatTrainStep(other,changed,other_snapshot) && steps++<100000) {}
   ICTStatForward(model,samples[0],true,1,trained);
   Check("STAT neural backprop learns separable synthetic features",trained[0]>initial[0]+0.3 && trained[0]>0.8);
   bool same=true;
   for(int k=0;k<ICT_STAT_LR_WEIGHTS;k++) if(model.lr[k]!=other.lr[k]) same=false;
   for(int k=0;k<ICT_STAT_DNN_WEIGHTS;k++) if(model.deep[k]!=other.deep[k]) same=false;
   Check("STAT validation labels and features cannot train models",same);
   Check("STAT evaluates untouched later partition",ICTStatFinish(model,samples,snapshot) && snapshot.ready && snapshot.test_n==model.test_n);
   Check("STAT compares both trained models to climatology",snapshot.brier_ml<snapshot.brier_baseline*0.5 && snapshot.brier_dl<snapshot.brier_baseline*0.5 && snapshot.beats_baseline);
   Check("STAT calibration uses a separate partition",ICTStatFinish(other,changed,other_snapshot) && model.calibrated && other.calibrated &&
      model.lr_temperature==other.lr_temperature && model.deep_temperature==other.deep_temperature);
   Check("STAT reports validation pattern support only",snapshot.pattern_n[0]>0 && snapshot.pattern_n[0]<=model.test_n &&
      snapshot.pattern_hits[0]==snapshot.pattern_n[0] && snapshot.pattern_hits[1]==snapshot.pattern_n[1]);
   Check("STAT current probabilities normalize",ICTStatPredict(model,samples[0],snapshot) &&
      MathAbs(snapshot.combined[0]+snapshot.combined[1]+snapshot.combined[2]-1)<0.000001 && snapshot.combined[0]>0.8);
   double previous_up=snapshot.combined[0];
   Check("STAT current context changes the forecast",ICTStatPredict(model,samples[1],other_snapshot) &&
      other_snapshot.combined[1]>0.8 && other_snapshot.combined[0]<previous_up);
   SICTStatModel empty; ZeroMemory(empty);
   Check("STAT unfitted model clears readiness",!ICTStatPredict(empty,samples[0],snapshot) && !snapshot.ready);
   double low=0,high=0; ICTStatWilson(5,10,low,high);
   Check("STAT Wilson interval accounts for small support",low>0.23 && low<0.24 && high>0.76 && high<0.77);
   ICTStatWilson(0,0,low,high); Check("STAT no-support interval remains unknown",low==0 && high==1);
   double logits[3]={1000,-1000,0}; double probabilities[3]; ICTStatSoftmax(logits,1,probabilities);
   Check("STAT softmax remains finite on extreme logits",MathIsValidNumber(probabilities[0]) && MathAbs(probabilities[0]+probabilities[1]+probabilities[2]-1)<0.000001);
   ArrayResize(samples,100);
   Check("STAT insufficient samples never expose probabilities",!ICTStatPrepare(c,samples,model,snapshot) && !snapshot.ready);
   ICTStatFixtureSamples(samples);
   for(int i=0;i<ArraySize(samples);i++) samples[i].label=0;
   Check("STAT one-class training is rejected",!ICTStatPrepare(c,samples,model,snapshot) && snapshot.status=="INSUFFICIENT_CLASSES");
   RunICTLiquidityProbabilityFixtures();
  }

#endif
