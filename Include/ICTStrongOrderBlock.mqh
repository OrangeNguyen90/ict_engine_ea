#ifndef ICT_STRONG_ORDER_BLOCK_MQH
#define ICT_STRONG_ORDER_BLOCK_MQH
#include "OrderBlockDetector.mqh"
#include "OrderBlockScoring.mqh"
#include "FVGDetector.mqh"
#include "ICTBarSnapshot.mqh"
#include "ICTSweepSequence.mqh"

enum ENUM_ICT_OB_GRADE { ICT_OB_WEAK=0, ICT_OB_MEDIUM=1, ICT_OB_STRONG=2 };
enum ENUM_ICT_OB_LIFE { ICT_OB_CANDIDATE=0, ICT_OB_CONFIRMED=1, ICT_OB_ACTIVE=2,
   ICT_OB_TOUCHED=3, ICT_OB_PARTIAL=4, ICT_OB_MITIGATED=5, ICT_OB_INVALIDATED=6, ICT_OB_EXPIRED=7 };
struct SICTStrongOBConfig
  {
   int max_group,confirmation_bars,left,right,expiry_bars;
   int weight_sweep,weight_displacement,weight_structure,weight_fvg,weight_bias,weight_pd,weight_freshness;
   int strong_threshold,moderate_threshold,touch_penalty;
   ENUM_SRMP_OB_BOUNDS bounds;
   double displacement_atr,body_ratio,max_overlap,fvg_atr,tolerance_ticks,mitigation_fraction;
   bool require_fvg,invalidate_on_close,allow_continuation;
  };
void ICTDefaultStrongOBConfig(SICTStrongOBConfig &c)
  {
   ZeroMemory(c); c.max_group=3; c.confirmation_bars=3; c.left=2; c.right=2;
   c.expiry_bars=300; c.bounds=SRMP_OB_HYBRID; c.displacement_atr=1.2;
   c.body_ratio=0.60; c.max_overlap=0.80; c.fvg_atr=0.10;
   c.tolerance_ticks=1; c.mitigation_fraction=0.5; c.invalidate_on_close=true; c.allow_continuation=true;
   c.weight_sweep=20; c.weight_displacement=20; c.weight_structure=15; c.weight_fvg=15;
   c.weight_bias=15; c.weight_pd=10; c.weight_freshness=5;
   c.strong_threshold=80; c.moderate_threshold=60; c.touch_penalty=5;
  }
bool ICTValidStrongOBConfig(const SICTStrongOBConfig &c)
  {
   double v[]={c.displacement_atr,c.body_ratio,c.max_overlap,c.fvg_atr,c.tolerance_ticks,c.mitigation_fraction};
   for(int i=0;i<ArraySize(v);i++) if(!MathIsValidNumber(v[i]) || v[i]<0) return false;
   int weights[]={c.weight_sweep,c.weight_displacement,c.weight_structure,c.weight_fvg,c.weight_bias,c.weight_pd,c.weight_freshness};
   int total=0;
   for(int i=0;i<ArraySize(weights);i++) { if(weights[i]<0 || weights[i]>100) return false; total+=weights[i]; }
   return c.max_group>=1 && c.max_group<=10 && c.confirmation_bars>=1 && c.confirmation_bars<=10 &&
      c.left>=1 && c.right>=1 && c.expiry_bars>=1 && c.bounds>=SRMP_OB_FULL && c.bounds<=SRMP_OB_HYBRID &&
      c.displacement_atr>0 && c.body_ratio>0 && c.body_ratio<=1 && c.max_overlap<=1 &&
       c.mitigation_fraction>0 && c.mitigation_fraction<=1 && total==100 &&
       c.moderate_threshold>=1 && c.moderate_threshold<c.strong_threshold && c.strong_threshold<=100 &&
       c.touch_penalty>=0 && c.touch_penalty<=100;
  }
struct SICTStrongOrderBlock
  {
   SOrderBlock ob;
   string id,gate_reason,invalidation_reason;
   ENUM_TIMEFRAMES timeframe;
   ENUM_ICT_OB_GRADE grade,confirmation_grade;
   ENUM_ICT_OB_LIFE life;
   int candles,confirmation_score,current_context_score,touch_count,age,sweep_count;
   int sweep_points,displacement_points,structure_points,fvg_points,bias_points,pd_points,freshness_points;
   bool hard_gates,continuation,in_contact,departed;
   datetime group_end,processed_at;
   double open_reference,mitigation_depth,invalidation;
  };
string ICTOBGradeText(const ENUM_ICT_OB_GRADE g)
  { return g==ICT_OB_STRONG ? "STRONG" : (g==ICT_OB_MEDIUM ? "MODERATE" : "WEAK"); }
string ICTOBLifeText(const ENUM_ICT_OB_LIFE s)
  {
   string values[]={"CANDIDATE","CONFIRMED","ACTIVE","TOUCHED","PARTIALLY MITIGATED","MITIGATED","INVALIDATED","EXPIRED"};
   return (int)s>=0 && (int)s<8 ? values[(int)s] : "UNKNOWN";
  }
bool ICTOBActive(const SICTStrongOrderBlock &z)
  { return z.life==ICT_OB_CONFIRMED || z.life==ICT_OB_ACTIVE || z.life==ICT_OB_TOUCHED || z.life==ICT_OB_PARTIAL; }

// Scores describe evidence available at confirmation. They never change when
// a later HTF candle, retest or SMT signal appears. SMT is outside this model.
void ICTScoreStrongOBWithConfig(SICTStrongOrderBlock &z,const bool htf_match,const bool fresh,
                                 const SICTStrongOBConfig &c)
  {
   z.sweep_points=z.ob.liquidity_sweep ? c.weight_sweep : 0;
   z.displacement_points=z.ob.displacement ? c.weight_displacement : 0;
   z.structure_points=z.ob.break_confirmed ? c.weight_structure : 0;
   z.fvg_points=z.ob.fvg ? c.weight_fvg : 0; z.bias_points=htf_match ? c.weight_bias : 0;
   z.pd_points=z.ob.pd_match ? c.weight_pd : 0; z.freshness_points=fresh ? c.weight_freshness : 0;
   z.confirmation_score=z.sweep_points+z.displacement_points+z.structure_points+z.fvg_points+
      z.bias_points+z.pd_points+z.freshness_points;
   z.ob.score=z.confirmation_score; z.current_context_score=z.confirmation_score;
   z.hard_gates=z.ob.upper>z.ob.lower && z.ob.lower>0 && z.ob.displacement && z.ob.break_confirmed &&
       (z.continuation ? c.allow_continuation && htf_match : z.ob.liquidity_sweep) && (!c.require_fvg || z.ob.fvg);
   z.gate_reason=z.hard_gates ? (z.continuation ? "Continuation: displacement+BOS+HTF aligned" :
      "Reversal: sweep+displacement+MSS/BOS") : "Missing candidate/displacement/structure/sweep or continuation HTF/FVG gate";
   z.grade=(z.confirmation_score>=c.strong_threshold && z.hard_gates ? ICT_OB_STRONG :
       (z.confirmation_score>=c.moderate_threshold ? ICT_OB_MEDIUM : ICT_OB_WEAK));
   z.confirmation_grade=z.grade;
  }
// Preserve the established pure-function API and its default scoring contract.
void ICTScoreStrongOB(SICTStrongOrderBlock &z,const bool htf_match,const bool fresh,
                       const bool require_fvg,const bool allow_continuation)
  {
   SICTStrongOBConfig c; ICTDefaultStrongOBConfig(c); c.require_fvg=require_fvg; c.allow_continuation=allow_continuation;
   ICTScoreStrongOBWithConfig(z,htf_match,fresh,c);
  }
void ICTRefreshOBQuality(SICTStrongOrderBlock &z,const SICTStrongOBConfig &c)
  {
   if(z.life==ICT_OB_MITIGATED || z.life==ICT_OB_INVALIDATED || z.life==ICT_OB_EXPIRED)
     { z.current_context_score=0; z.ob.score=0; z.grade=ICT_OB_WEAK; return; }
   int penalty=(z.touch_count>0 ? z.freshness_points : 0)+c.touch_penalty*(int)MathMax(0,z.touch_count-1);
   z.current_context_score=(int)MathMax(0,z.confirmation_score-penalty); z.ob.score=z.current_context_score;
   z.grade=(z.current_context_score>=c.strong_threshold && z.hard_gates && z.touch_count==0 ? ICT_OB_STRONG :
      z.current_context_score>=c.moderate_threshold ? ICT_OB_MEDIUM : ICT_OB_WEAK);
  }

void ICTAdvanceStrongOB(const MqlRates &bar,const datetime closed,const SICTStrongOBConfig &c,
                        const double tolerance,SICTStrongOrderBlock &z)
  {
   if(!SRMPValidDetectorBar(bar) || closed<=z.processed_at || bar.time<z.ob.confirmation_time ||
      z.life==ICT_OB_INVALIDATED || z.life==ICT_OB_EXPIRED || closed<=bar.time) return;
   z.processed_at=closed; z.age++;
   double test=(c.invalidate_on_close ? bar.close : (z.ob.direction>0 ? bar.low : bar.high));
   bool invalid=(z.ob.direction>0 ? test<z.ob.lower-tolerance : test>z.ob.upper+tolerance);
   if(invalid)
     {
      z.life=ICT_OB_INVALIDATED; z.ob.state=SRMP_OB_INVALIDATED; z.ob.state_time=closed;
      z.invalidation_reason=c.invalidate_on_close ? "Closed beyond invalidation boundary" : "Wick beyond invalidation boundary";
       ICTRefreshOBQuality(z,c);
      return;
     }
   bool intersects=bar.low<=z.ob.upper && bar.high>=z.ob.lower;
   if(!intersects) { z.departed=true; z.in_contact=false; if(z.life==ICT_OB_CONFIRMED) z.life=ICT_OB_ACTIVE; }
   if(intersects && z.departed)
     {
      if(!z.in_contact) z.touch_count++;
      z.in_contact=true;
      double depth=(z.ob.direction>0 ? z.ob.upper-bar.low : bar.high-z.ob.lower)/(z.ob.upper-z.ob.lower);
      z.mitigation_depth=MathMax(z.mitigation_depth,MathMin(1.0,MathMax(0.0,depth)));
      ENUM_ICT_OB_LIFE next=(z.mitigation_depth>=c.mitigation_fraction ? ICT_OB_MITIGATED :
                              (z.mitigation_depth>0 ? ICT_OB_PARTIAL : ICT_OB_TOUCHED));
      if(next>z.life) { z.life=next; z.ob.state_time=closed; }
      if(z.life==ICT_OB_MITIGATED) z.ob.state=SRMP_OB_MITIGATED;
     }
   if(z.age>=c.expiry_bars)
     { z.life=ICT_OB_EXPIRED; z.ob.state=SRMP_OB_EXPIRED; z.ob.state_time=closed; z.invalidation_reason="Configured closed-bar age reached"; }
   ICTRefreshOBQuality(z,c);
  }

// One chronological candidate group; shared confirmed swings/FVG/sweep reducer
// supply evidence. The endpoint is the last opposing candle, never detached bars.
bool ICTStrongOBAt(const string symbol,const ENUM_TIMEFRAMES tf,const MqlRates &rates[],const int count,
                   const int end,const double tick,const SICTStrongOBConfig &c,
                   const MqlRates &higher[],const int higher_count,const ENUM_TIMEFRAMES higher_tf,
                   SICTStrongOrderBlock &z,const bool advance_lifecycle=true)
  {
   ZeroMemory(z);
   if(!ICTValidStrongOBConfig(c) || !SRMPValidDetectorRates(rates,count) || end<30 || end>=count || tick<=0 ||
      tf==PERIOD_CURRENT || higher_count<0 || higher_count>ArraySize(higher)) return false;
   int dir=(rates[end].close<rates[end].open ? 1 : rates[end].close>rates[end].open ? -1 : 0);
   if(dir==0) return false;
   if(end+1<count && (rates[end+1].close-rates[end+1].open)*dir<0) return false;
   int start=end;
   while(start>0 && end-start+1<c.max_group && (rates[start-1].close-rates[start-1].open)*dir<0) start--;
   SMarketStructure before;
   if(!SRMPAnalyzeStructureFromRates(rates,start,c.left,c.right,before)) return false;
   double lower=rates[start].low,upper=rates[start].high,body_low=MathMin(rates[start].open,rates[start].close),body_high=MathMax(rates[start].open,rates[start].close);
   for(int k=start+1;k<=end;k++)
     { lower=MathMin(lower,rates[k].low); upper=MathMax(upper,rates[k].high);
       body_low=MathMin(body_low,MathMin(rates[k].open,rates[k].close)); body_high=MathMax(body_high,MathMax(rates[k].open,rates[k].close)); }
   if(c.bounds==SRMP_OB_BODY) { lower=body_low; upper=body_high; }
   if(c.bounds==SRMP_OB_HYBRID) { if(dir>0) upper=rates[end].open; else lower=rates[end].open; }
   if(upper-lower<tick*0.5 || lower<=0) return false;
   double tolerance=c.tolerance_ticks*tick;
   for(int j=end+1;j<count && j<=end+c.confirmation_bars;j++)
     {
      if((rates[j].close-rates[j].open)*dir<0) break;
      double atr=ICTPriorATR(rates,j),body=(rates[j].close-rates[j].open)*dir,width=rates[j].high-rates[j].low;
      double overlap=MathMax(0.0,MathMin(rates[j].high,rates[j-1].high)-MathMax(rates[j].low,rates[j-1].low));
      bool displacement=atr>0 && width>0 && body>=atr*c.displacement_atr && body/width>=c.body_ratio && overlap/width<=c.max_overlap;
       bool broken=(dir>0 ? rates[j].close>before.recent_high+tolerance && rates[j-1].close<=before.recent_high+tolerance && rates[j].close>upper :
                            rates[j].close<before.recent_low-tolerance && rates[j-1].close>=before.recent_low-tolerance && rates[j].close<lower);
      if(!displacement || !broken) continue;
      bool fvg=false;
      for(int f=end+1;f<=j;f++)
        { SFairValueGap gap; if(SRMPFVGAtRates(rates,f+1,f,MathMax(tick,c.fvg_atr*atr),gap) && gap.direction==dir) fvg=true; }
      if(c.require_fvg && !fvg) continue;
      z.timeframe=tf; z.ob.direction=dir; z.ob.lower=lower; z.ob.upper=upper;
      z.ob.midpoint=(lower+upper)*0.5; z.open_reference=rates[end].open;
      z.ob.formation_time=rates[start].time; z.group_end=rates[end].time;
      z.ob.confirmation_time=ICTBarClose(tf,rates[j].time); z.ob.state_time=z.ob.confirmation_time;
      z.processed_at=z.ob.confirmation_time; z.life=ICT_OB_CONFIRMED; z.ob.state=SRMP_OB_CONFIRMED;
      z.candles=end-start+1; z.ob.displacement=true; z.ob.break_confirmed=true; z.ob.fvg=fvg;
      z.continuation=before.bias==dir;
      z.id=symbol+"|"+IntegerToString((int)tf)+"|"+IntegerToString((long)rates[start].time)+"|"+
         IntegerToString((long)rates[end].time)+"|"+IntegerToString(dir)+"|"+IntegerToString((int)c.bounds);
      z.invalidation=(dir>0 ? lower : upper); z.departed=(dir>0 ? rates[j].close>upper : rates[j].close<lower);
      SICTSweepSequence pool;
      double level=(dir>0 ? before.recent_low : before.recent_high);
      datetime pivot=(dir>0 ? before.recent_low_time : before.recent_high_time);
      datetime available=ICTBarClose(tf,dir>0 ? before.recent_low_confirmed_time : before.recent_high_confirmed_time);
      ICTSweepSequenceStart(pool,symbol+IntegerToString((int)tf)+IntegerToString((long)pivot),-dir,level,available);
      for(int k=0;k<=j;k++) ICTSweepSequenceStep(pool,rates[k],PeriodSeconds(tf),tolerance,tick*3,2,3,2,ICTBarClose(tf,rates[k].time));
      for(int k=0;k<pool.count;k++) if(pool.events[k].status==ICT_SWEEP_CONFIRMED && pool.events[k].confirmed_at<=z.ob.confirmation_time) z.sweep_count++;
      z.ob.liquidity_sweep=z.sweep_count>0;
      SMarketStructure hs; ZeroMemory(hs);
      int hn=ICTClosedPrefix(higher,higher_count,higher_tf,z.ob.confirmation_time);
      bool higher_ready=higher_tf!=PERIOD_CURRENT && SRMPAnalyzeStructureFromRates(higher,hn,c.left,c.right,hs);
      double equilibrium=(higher_ready ? (hs.recent_high+hs.recent_low)*0.5 : (before.recent_high+before.recent_low)*0.5);
      z.ob.pd_match=(dir>0 ? z.ob.midpoint<equilibrium : z.ob.midpoint>equilibrium);
      ICTScoreStrongOBWithConfig(z,higher_ready && hs.bias==dir,true,c);
      if(advance_lifecycle)
         for(int k=j+1;k<count;k++) ICTAdvanceStrongOB(rates[k],ICTBarClose(tf,rates[k].time),c,tolerance,z);
      return true;
     }
   return false;
  }
#endif
