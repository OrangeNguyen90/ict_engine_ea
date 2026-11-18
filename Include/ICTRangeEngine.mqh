#ifndef ICT_RANGE_ENGINE_MQH
#define ICT_RANGE_ENGINE_MQH
#include "ICTRangeTypes.mqh"
#include "MarketStructure.mqh"
#include "LiquidityDetector.mqh"
#include "FVGDetector.mqh"
#include "OrderBlockDetector.mqh"
#include "ICTConfluenceScore.mqh"
#include "ICTBarSnapshot.mqh"
#include "ICTStrongOrderBlock.mqh"

string ICTRangeCSV(string value)
  { StringReplace(value,"\"","\"\""); return "\""+value+"\""; }

// History timestamps and TimeCurrent share the broker clock. TimeTradeServer
// is extrapolated using the PC clock and must not reject otherwise current bars.
string ICTRangeHistoryError(const datetime latest,const datetime broker_now,
                             const ENUM_TIMEFRAMES ltf,const double tick)
  {
   int seconds=PeriodSeconds(ltf);
   if(!MathIsValidNumber(tick) || tick<=0) return "Invalid SYMBOL_TRADE_TICK_SIZE";
   if(seconds<=0 || latest<=0) return "Closed LTF candle time unavailable";
   if(broker_now<=0) return "Broker quote time unavailable; waiting for connection/data";
   string details=" | "+EnumToString(ltf)+" close="+TimeToString(latest,TIME_DATE|TIME_SECONDS)+
                  " broker="+TimeToString(broker_now,TIME_DATE|TIME_SECONDS);
   if(latest>broker_now) return "LTF close is ahead of broker quote time"+details;
   if(broker_now-latest>seconds*2) return "Stale LTF history; waiting for synchronized candles"+details;
   return "";
  }

int ICTRangeClosedCount(const MqlRates &rates[],const int count,
                         const ENUM_TIMEFRAMES tf,const datetime asof)
  {
   if(count<1 || count>ArraySize(rates) || PeriodSeconds(tf)<=0) return 0;
   int n=0;
   while(n<count && ICTBarClose(tf,rates[n].time)<=asof) n++;
   return n;
  }

double ICTRangeATR(const MqlRates &rates[],const int count,const int period=14)
  {
   if(count<=period) return 0;
   double sum=0;
   for(int i=count-period;i<count;i++)
      sum+=MathMax(rates[i].high-rates[i].low,
           MathMax(MathAbs(rates[i].high-rates[i-1].close),MathAbs(rates[i].low-rates[i-1].close)));
   return sum/period; // Explicit rolling true-range mean; no future buffer access.
  }

bool ICTRangeDisplacement(const MqlRates &rates[],const int index,const int direction,
                            const SICTRangeConfig &c)
  {
   if(index<15 || index>=ArraySize(rates)) return false;
   double atr=ICTRangeATR(rates,index); // Baseline excludes the displacement candle.
   double body=(rates[index].close-rates[index].open)*direction;
   double width=rates[index].high-rates[index].low;
   return atr>0 && width>0 && body>=c.displacement_atr*atr && body/width>=c.displacement_fraction;
  }

bool ICTRangeFromStructure(const string symbol,const ENUM_TIMEFRAMES tf,
                            const SMarketStructure &s,const double min_width,
                            const datetime asof,SICTDealingRange &r)
  {
   ZeroMemory(r);
   datetime high_confirm=ICTBarClose(tf,s.recent_high_confirmed_time);
   datetime low_confirm=ICTBarClose(tf,s.recent_low_confirmed_time);
   if(!MathIsValidNumber(s.recent_high) || !MathIsValidNumber(s.recent_low) || min_width<=0 ||
      s.recent_high_time<=0 || s.recent_low_time<=0 ||
      s.recent_high_confirmed_time<=0 || s.recent_low_confirmed_time<=0 ||
      s.recent_high_time==s.recent_low_time || high_confirm>asof || low_confirm>asof ||
      s.recent_high-s.recent_low<min_width || s.recent_low<=0) return false;
   r.high=s.recent_high; r.low=s.recent_low;
   r.width=r.high-r.low; r.midpoint=(r.high+r.low)/2;
   r.high_time=s.recent_high_time; r.low_time=s.recent_low_time;
   r.direction=(r.high_time>r.low_time ? 1 : -1); r.bias=s.bias; r.timeframe=tf;
   r.confirmed_at=(datetime)MathMax(high_confirm,low_confirm); r.valid=true;
   r.id=symbol+"_"+IntegerToString((int)tf)+"_"+IntegerToString((long)r.high_time)+"_"+IntegerToString((long)r.low_time);
   return true;
  }

ENUM_IR_MEMBERSHIP ICTRangeMembership(const SICTDealingRange &r,const double low,
                                      const double high,const double tolerance)
  {
   if(!r.valid || high<low) return IR_OUTSIDE;
   if(high<r.low-tolerance || low>r.high+tolerance) return IR_OUTSIDE;
   if(low==high && (MathAbs(low-r.low)<=tolerance || MathAbs(high-r.high)<=tolerance)) return IR_BOUNDARY;
   if(low>r.low+tolerance && high<r.high-tolerance) return IR_INTERNAL;
   return IR_CROSSING; // No clipping a PD array across an owner boundary.
  }

void ICTRangeAddLevel(SICTRangeSnapshot &s,const string name,const double price,
                        const int side,const datetime available,const double tolerance,
                        const ENUM_TIMEFRAMES source_tf=PERIOD_CURRENT)
  {
   if(s.level_count>=ICT_RANGE_LEVELS || !MathIsValidNumber(price) || price<=0 || available>s.as_of || available<=0) return;
   SICTRangeLevel level; ZeroMemory(level);
   level.id=name+"_"+IntegerToString((long)available)+"_"+DoubleToString(price,8);
   for(int i=0;i<s.level_count;i++) if(s.levels[i].id==level.id) return;
   level.range_id=s.range.id; level.name=name; level.price=price; level.side=side;
   level.timeframe=source_tf;
   if(level.timeframe==PERIOD_CURRENT)
      level.timeframe=(StringFind(name,"PD")==0 ? PERIOD_D1 : StringFind(name,"PW")==0 ? PERIOD_W1 :
                       StringFind(name,"PM")==0 ? PERIOD_MN1 : s.ltf);
   level.available_at=available; level.membership=ICTRangeMembership(s.range,price,price,tolerance);
   s.levels[s.level_count++]=level;
  }

void ICTRangeSetLevelEvent(SICTRangeLevel &l,const ENUM_IR_LEVEL_EVENT event,
                          const MqlRates &bar,const datetime close_time,
                          const datetime wick_time,const double wick)
  {
   l.last_event=event; l.event_at=close_time; l.event_bar_time=bar.time;
   l.event_wick_time=wick_time; l.event_wick=wick; l.event_close=bar.close;
  }
void ICTRangeClearLevelCandidate(SICTRangeLevel &l)
  {
   l.candidate=false; l.outside_closes=0; l.candidate_displacement=false;
   l.candidate_wick=0; l.candidate_wick_time=0; l.breakout_age=0;
  }

// Pure closed-bar reducer. No symbol, account, indicator, clock or GUI calls.
// A confirmed breakout remains a broken pool while retest/failure observations
// are recorded separately. A consumed pool is never made a fresh target again.
void ICTRangeAdvanceLevelConfigured(const MqlRates &bar,const datetime close_time,
                                   const double penetration,const double approach,const bool displacement,
                                   const SICTRangeConfig &c,const double tick,const double atr,SICTRangeLevel &l)
  {
   double values[12]={penetration,approach,tick,atr,c.breakout_buffer_ticks,c.breakout_buffer_atr,
      c.breakout_failure_ticks,c.retest_tolerance_ticks,c.retest_tolerance_atr,c.retest_close_buffer_ticks,
      c.sweep_rejection_ticks,c.sweep_tolerance_ticks};
   for(int i=0;i<12;i++) if(!MathIsValidNumber(values[i]) || values[i]<0) return;
   if(tick<=0 || c.breakout_bars<1 || c.sweep_min_bars<1 || c.sweep_validation_bars<1 || c.retest_window_bars<1 ||
      !SRMPValidDetectorBar(bar) || !MathIsValidNumber(l.price) || l.price<=0 ||
      (l.side!=1 && l.side!=-1) || bar.time<l.available_at || bar.time<=l.last_bar || close_time<=bar.time) return;
   if(l.last_bar==0 && l.last_event==IR_EVENT_NONE) l.sweep_armed=true;
   l.last_bar=bar.time;
   if(l.state==IR_CONSUMED || l.state==IR_LEVEL_INVALIDATED) return;
   double extreme=(l.side>0 ? bar.high : bar.low);
   double excursion=(extreme-l.price)*l.side;
   double outside=(bar.close-l.price)*l.side;
   double breakout_buffer=MathMax(penetration,MathMax(c.breakout_buffer_ticks*tick,c.breakout_buffer_atr*atr));
   double failure_buffer=c.breakout_failure_ticks*tick;
   if(l.state==IR_BREAKOUT)
     {
      l.breakout_age++;
      if(outside<-failure_buffer)
        {
         // The retest window limits entry observations, not failure detection.
         ICTRangeSetLevelEvent(l,IR_EVENT_FALSE_BREAKOUT,bar,close_time,bar.time,extreme);
         l.state=IR_CONSUMED; l.retest_pending=false; return;
        }
      if(l.breakout_age>c.retest_window_bars) { l.retest_pending=false; return; }
      double tolerance=MathMax(c.retest_tolerance_ticks*tick,c.retest_tolerance_atr*atr);
      bool touched=bar.low<=l.price+tolerance && bar.high>=l.price-tolerance;
      if(l.retest_pending && bar.time>=l.breakout_at && touched &&
         outside>c.retest_close_buffer_ticks*tick && (bar.close-bar.open)*l.side>0)
        {
         ICTRangeSetLevelEvent(l,IR_EVENT_RETEST_CONFIRMED,bar,close_time,bar.time,
                               l.side>0 ? bar.low : bar.high);
         l.retest_pending=false;
        }
      return;
     }
   if(l.state==IR_SWEPT)
     {
      if(outside>breakout_buffer) { l.state=IR_CONSUMED; return; }
     }
   // A separate closed rejection and a minimum number of LTF observations must
   // rearm a swept pool. A rearm bar cannot also count as another sweep.
   if(!l.sweep_armed && !l.candidate)
     {
      l.sweep_wait_bars++;
      if(l.sweep_wait_bars>=c.sweep_min_bars && outside<=-c.sweep_rejection_ticks*tick)
         l.sweep_armed=true;
      return;
     }
   if(l.candidate && (l.candidate_wick_time<=0 || (extreme-l.candidate_wick)*l.side>0))
     { l.candidate_wick=extreme; l.candidate_wick_time=bar.time; }
   if(l.candidate) l.breakout_age++; // Candidate age until it becomes a confirmed breakout.
   if(outside>breakout_buffer)
     {
      if(!l.candidate) { l.candidate_wick=extreme; l.candidate_wick_time=bar.time; l.breakout_age=1; }
      l.candidate=true; l.outside_closes++;
      l.candidate_displacement=l.candidate_displacement || displacement;
      bool closes=l.outside_closes>=c.breakout_bars;
      bool impulse=c.breakout_displacement_confirms && displacement;
      if((closes || impulse) && (!c.breakout_require_displacement || l.candidate_displacement))
        {
         l.state=IR_BREAKOUT; l.breakout_at=close_time; l.breakout_age=0; l.retest_pending=true;
         ICTRangeSetLevelEvent(l,IR_EVENT_BREAKOUT_CONFIRMED,bar,close_time,l.candidate_wick_time,l.candidate_wick);
         ICTRangeClearLevelCandidate(l);
        }
      return;
     }
   if(l.candidate && outside<-failure_buffer)
     {
      if(l.breakout_age>c.sweep_validation_bars)
        {
         // An unresolved excursion that returns too late is neither a valid
         // sweep nor a fresh pool. Do not create a reversal setup from it.
         l.state=IR_LEVEL_INVALIDATED; ICTRangeClearLevelCandidate(l); return;
        }
      l.state=IR_SWEPT;
      ICTRangeSetLevelEvent(l,IR_EVENT_FALSE_BREAKOUT,bar,close_time,l.candidate_wick_time,l.candidate_wick);
      l.sweep_armed=false; l.sweep_wait_bars=0; ICTRangeClearLevelCandidate(l); return;
     }
   if(!l.candidate && l.sweep_armed && excursion>penetration+c.sweep_tolerance_ticks*tick && outside<0)
     {
      l.state=IR_SWEPT; l.sweep_count++;
      ICTRangeSetLevelEvent(l,IR_EVENT_LIQUIDITY_SWEEP,bar,close_time,bar.time,extreme);
      l.sweep_armed=false; l.sweep_wait_bars=0; ICTRangeClearLevelCandidate(l); return;
     }
   l.outside_closes=0; l.candidate_displacement=false;
   if(l.state!=IR_SWEPT) l.state=(MathAbs(bar.close-l.price)<=approach ? IR_APPROACHING : IR_UNTOUCHED);
  }

// Compatibility entry point for existing consumers and reducer fixtures.
void ICTRangeAdvanceLevel(const MqlRates &bar,const datetime close_time,
                         const double penetration,const double approach,
                         const bool displacement,const int breakout_bars,SICTRangeLevel &l)
  {
   SICTRangeConfig c; ICTDefaultRangeConfig(c); c.breakout_bars=breakout_bars;
   ICTRangeAdvanceLevelConfigured(bar,close_time,penetration,approach,displacement,c,1.0,0.0,l);
  }

void ICTRangeRecordLiquidityEvent(SICTRangeSnapshot &s,const SICTRangeLevel &l)
  {
   if(l.last_event==IR_EVENT_NONE || l.event_at<=0 || l.event_at>s.as_of ||
      l.event_at<s.range.confirmed_at || l.event_bar_time<s.liquidity_display_start) return;
   for(int i=0;i<s.liquidity_event_count;i++)
      if(s.liquidity_events[i].pool_id==l.id && s.liquidity_events[i].confirmed_at==l.event_at &&
         s.liquidity_events[i].type==l.last_event) return;
   SICTRangeLiquidityEvent e; ZeroMemory(e);
   e.pool_id=l.id; e.range_id=l.range_id; e.pool_name=l.name; e.type=l.last_event;
   e.id=l.id+"|"+IntegerToString((int)l.last_event)+"|"+IntegerToString((long)l.event_at);
   e.membership=l.membership; e.source_tf=l.timeframe; e.event_tf=s.ltf;
   e.side=l.side; e.sweep_number=l.sweep_count; e.bar_time=l.event_bar_time;
   e.wick_time=l.event_wick_time; e.confirmed_at=l.event_at;
   e.level=l.price; e.wick=l.event_wick; e.close=l.event_close;
   if(s.liquidity_event_count==ICT_RANGE_LIQUIDITY_EVENTS)
     {
      if(e.confirmed_at<s.liquidity_events[0].confirmed_at) return;
      for(int i=1;i<s.liquidity_event_count;i++) s.liquidity_events[i-1]=s.liquidity_events[i];
      s.liquidity_event_count--;
     }
   int at=s.liquidity_event_count;
   while(at>0 && s.liquidity_events[at-1].confirmed_at>e.confirmed_at)
     { s.liquidity_events[at]=s.liquidity_events[at-1]; at--; }
   s.liquidity_events[at]=e; s.liquidity_event_count++;
  }

// Keep the existing boundary sweep records, but let the configured level
// reducer decide when this pool has broken/been consumed. This prevents the
// older sequence's fixed close-count rule from bypassing new buffer/impulse inputs.
void ICTRangeAdvanceBoundarySequence(SICTSweepSequence &sequence,const SICTRangeLevel &level,
                                     const MqlRates &bar,const datetime close_time,const SICTRangeConfig &c,
                                     const double penetration,const double tick)
  {
   if(!sequence.valid) return;
   ICTSweepSequenceStep(sequence,bar,PeriodSeconds(c.ltf),penetration+c.sweep_tolerance_ticks*tick,
      c.sweep_rejection_ticks*tick,c.sweep_min_bars,c.sweep_validation_bars,2147483647,close_time);
   if(level.state==IR_BREAKOUT || level.state==IR_CONSUMED || level.state==IR_LEVEL_INVALIDATED)
     {
      if(sequence.candidate && sequence.count>0) sequence.events[sequence.count-1].status=ICT_SWEEP_INVALIDATED;
      sequence.valid=false; sequence.candidate=false;
     }
  }

// Reconstruct a newly observed pool only from bars closed before the current
// replay candle. If its birth predates retained history, fail closed instead
// of silently assuming that the pool was never swept or broken.
bool ICTRangeSeedLevel(SICTRangeLevel &level,SICTSweepSequence &sequence,const bool track_sequence,
                       const MqlRates &rates[],const int count,const datetime before,
                       const SICTRangeConfig &c,const double tick,SICTRangeSnapshot &snapshot,
                       const bool record_events)
  {
   if(count<1 || count>ArraySize(rates) || level.available_at<=0 ||
      level.available_at<rates[0].time || before<=0 || tick<=0) return false;
   int first=0,last_index=count;
   while(first<last_index)
     {
      int middle=(first+last_index)/2;
      if(rates[middle].time<level.available_at) first=middle+1; else last_index=middle;
     }
   datetime last=0;
   for(int j=first;j<count && rates[j].time<before;j++)
     {
      if(!SRMPValidDetectorBar(rates[j]) || (last>0 && rates[j].time<=last)) return false;
      last=rates[j].time;
      datetime prior_close=ICTBarClose(c.ltf,rates[j].time);
      if(prior_close<=0 || prior_close>before) continue;
      double atr=ICTRangeATR(rates,j+1);
      double penetration=MathMax(c.penetration_ticks*tick,c.penetration_atr*atr);
      ICTRangeAdvanceLevelConfigured(rates[j],prior_close,penetration,c.approach_atr*atr,
         ICTRangeDisplacement(rates,j,level.side,c),c,tick,atr,level);
      if(record_events) ICTRangeRecordLiquidityEvent(snapshot,level);
      if(track_sequence) ICTRangeAdvanceBoundarySequence(sequence,level,rates[j],prior_close,c,penetration,tick);
     }
   return true;
  }

bool ICTRangeZoneEligible(const SICTRangeZone &z,const SICTRangeSnapshot &s)
  {
   return z.range_id==s.range.id && z.membership==IR_INTERNAL &&
      z.direction==s.direction && (z.state==IR_FRESH || z.state==IR_TOUCHED) &&
      z.confirmed_at<=s.as_of && z.confirmed_at>=s.structure_at &&
      (z.direction>0 ? z.midpoint<=s.range.midpoint : z.midpoint>=s.range.midpoint);
  }

int ICTRangeZoneQuality(const SICTRangeZone &z,const int bias,const bool confluence,const bool pd_match)
  {
   if(z.membership!=IR_INTERNAL || z.state>IR_TOUCHED) return 0;
   return (z.structure_match ? 20 : 0)+(z.displacement ? 15 : 0)+
      (z.state==IR_FRESH ? 15 : (z.state==IR_TOUCHED ? 5 : 0))+
      (z.direction==bias ? 10 : 0)+(confluence ? 20 : 0)+(pd_match ? 20 : 0);
  }

void ICTRangeAddZone(SICTRangeSnapshot &s,SICTRangeZone &z,const double tolerance)
  {
   if(s.zone_count>=ICT_RANGE_ZONES || z.lower<=0 || z.upper<=z.lower || z.confirmed_at>s.as_of) return;
   z.range_id=s.range.id; z.midpoint=(z.upper+z.lower)/2;
   z.membership=ICTRangeMembership(s.range,z.lower,z.upper,tolerance);
   z.invalidation=(z.direction>0 ? z.lower : z.upper);
   s.zones[s.zone_count++]=z;
  }

// Both arrays must still be usable within the same dealing range. Recompute
// from scratch so an invalidated or foreign array cannot retain score points.
void ICTRangeUpdateZoneConfluence(SICTRangeSnapshot &s)
  {
   for(int i=0;i<s.zone_count;i++) s.zones[i].confluence=false;
   if(!s.range.valid || s.range.id=="") return;
   for(int i=0;i<s.zone_count;i++)
      for(int j=i+1;j<s.zone_count;j++)
        {
         if(s.zones[i].range_id!=s.range.id || s.zones[j].range_id!=s.range.id ||
            s.zones[i].membership!=IR_INTERNAL || s.zones[j].membership!=IR_INTERNAL ||
            (s.zones[i].state!=IR_FRESH && s.zones[i].state!=IR_TOUCHED) ||
            (s.zones[j].state!=IR_FRESH && s.zones[j].state!=IR_TOUCHED) ||
            s.zones[i].confirmed_at<=0 || s.zones[j].confirmed_at<=0 ||
            s.zones[i].confirmed_at>s.as_of || s.zones[j].confirmed_at>s.as_of ||
            s.zones[i].type==s.zones[j].type ||
            (s.zones[i].direction!=1 && s.zones[i].direction!=-1) ||
            s.zones[i].direction!=s.zones[j].direction ||
            s.zones[i].lower>s.zones[j].upper || s.zones[i].upper<s.zones[j].lower) continue;
         s.zones[i].confluence=true; s.zones[j].confluence=true;
        }
  }

void ICTRangeDetectZones(const MqlRates &rates[],const int count,const SMarketStructure &structure,
                          const SICTRangeConfig &c,const double tick,const double tolerance,SICTRangeSnapshot &s,const bool detect_ob=true)
  {
   double atr=ICTRangeATR(rates,count);
   double minimum=MathMax(c.min_fvg_ticks*tick,c.min_fvg_atr*atr);
   // Retain both directional candidates; inspect lifecycle before selecting.
   for(int i=count-1;i>=MathMax(2,count-c.max_zone_age) && s.zone_count<12;i--)
     {
      SFairValueGap fvg;
      if(!SRMPFVGAtRates(rates,count,i,minimum,fvg)) continue;
      SICTRangeZone z; ZeroMemory(z);
      z.type=IR_FVG; z.timeframe=c.mtf; z.direction=fvg.direction;
      z.lower=fvg.lower; z.upper=fvg.upper; z.formed_at=fvg.formed_time;
      z.confirmed_at=z.formed_at+PeriodSeconds(c.mtf);
      z.id="F_"+IntegerToString((long)z.formed_at)+"_"+IntegerToString(z.direction);
      z.state=(fvg.status==SRMP_FVG_ACTIVE ? IR_FRESH :
         (fvg.status==SRMP_FVG_PARTIALLY_FILLED ? IR_TOUCHED :
         (fvg.status==SRMP_FVG_FULLY_FILLED ? IR_MITIGATED : IR_ZONE_INVALIDATED)));
      z.displacement=ICTRangeDisplacement(rates,i-1,z.direction,c);
      z.structure_match=structure.bos_direction==z.direction;
      ICTRangeAddZone(s,z,tolerance);
     }
   if(!c.use_ob || !detect_ob) return;
   for(int direction=-1;direction<=1;direction+=2)
     {
      SOrderBlock block;
      if(!SRMPFindOrderBlockFromRates(rates,count,SRMP_OB_HYBRID,1.2,3,block,direction,true,c.max_zone_age))
        {
         if(!SRMPFindOrderBlockFromRates(rates,count,SRMP_OB_HYBRID,1.2,3,block,direction,false,c.max_zone_age) ||
            block.state!=SRMP_OB_CONFIRMED) continue;
         SRMPValidateOrderBlockFromRates(rates,count,SRMP_OB_TOUCH,SRMP_OB_CLOSE,c.max_zone_age,block);
        }
      SICTRangeZone z; ZeroMemory(z);
      z.type=IR_OB; z.direction=block.direction; z.lower=block.lower; z.upper=block.upper;
      z.formed_at=block.formation_time; z.confirmed_at=block.confirmation_time+PeriodSeconds(c.mtf);
      z.timeframe=c.mtf;
      z.state=(block.state==SRMP_OB_CONFIRMED ? IR_FRESH :
         (block.state==SRMP_OB_MITIGATED ? IR_TOUCHED : IR_ZONE_INVALIDATED));
      int b=0; while(b<count && rates[b].time<block.confirmation_time) b++;
      z.displacement=b<count && ICTRangeDisplacement(rates,b,z.direction,c);
      z.structure_match=block.break_confirmed && structure.bos_direction==z.direction;
      if(block.state==SRMP_OB_INVALIDATED && structure.bos_direction==-block.direction &&
         structure.bos_time>=block.state_time)
        {
         z.type=IR_BREAKER; z.direction=-block.direction;
         z.confirmed_at=structure.bos_time+PeriodSeconds(c.mtf); z.state=IR_FRESH;
         int event=0; while(event<count && rates[event].time<structure.bos_time) event++;
         z.displacement=event<count && ICTRangeDisplacement(rates,event,z.direction,c);
         z.structure_match=true;
        }
      z.id=IntegerToString((int)z.type)+"_"+IntegerToString((long)z.formed_at)+"_"+IntegerToString(z.direction);
      ICTRangeAddZone(s,z,tolerance);
     }
   ICTRangeUpdateZoneConfluence(s);
  }

void ICTRangeSelectTargets(SICTRangeSnapshot &s,const double entry)
  {
   s.tp1=0; s.tp2=0; s.target1_index=-1; s.target2_index=-1;
   s.target1_pool_id=""; s.target2_pool_id=""; s.target1_pool_tf=PERIOD_CURRENT; s.target2_pool_tf=PERIOD_CURRENT;
   for(int i=0;i<s.level_count;i++)
     {
      SICTRangeLevel l=s.levels[i];
      if(!ICTRangeExternal(l,s.range) || (l.state!=IR_UNTOUCHED && l.state!=IR_APPROACHING) ||
         l.side!=s.direction || (l.price-entry)*s.direction<=0) continue;
      if(s.tp1<=0 || (l.price-s.tp1)*s.direction<0)
        { s.tp2=s.tp1; s.target2_index=s.target1_index; s.tp1=l.price; s.target1_index=i; }
      else if(l.price!=s.tp1 && (s.tp2<=0 || (l.price-s.tp2)*s.direction<0))
        { s.tp2=l.price; s.target2_index=i; }
     }
   s.target_distance=(s.tp1>0 ? MathAbs(s.tp1-entry) : 0);
   if(s.target1_index>=0)
     { s.target1_pool_id=s.levels[s.target1_index].id; s.target1_pool_tf=s.levels[s.target1_index].timeframe; }
   if(s.target2_index>=0)
     { s.target2_pool_id=s.levels[s.target2_index].id; s.target2_pool_tf=s.levels[s.target2_index].timeframe; }
   s.target_reason=(s.tp1>0 ? "Nearest unconsumed same-range ERL: "+s.levels[s.target1_index].name+" | "+
      EnumToString(s.target1_pool_tf)+" | "+s.target1_pool_id+"; conditional, not a forecast" :
      "TARGET UNAVAILABLE: no fresh same-range ERL or retained LTF coverage incomplete");
  }

uint ICTRangeEvidence(const SICTRangeSnapshot &s)
  {
   uint evidence=0;
   if(s.direction!=0 && s.direction==s.htf_bias) evidence|=ICT_E_HTF;
   if((s.scenario==IR_REVERSAL && s.sweep_at>0) ||
      (s.scenario==IR_CONTINUATION && s.sweep_at>0) ||
      (s.scenario==IR_BREAKOUT_CONTINUATION && s.structure_confirmed)) evidence|=ICT_E_SWEEP;
   if(s.structure_confirmed) evidence|=ICT_E_MSS;
   if(s.displacement && s.active_zone.displacement) evidence|=ICT_E_DISPLACEMENT;
   if(s.active_zone.id!="")
     {
      evidence|=(s.active_zone.type==IR_FVG ? ICT_E_FVG : ICT_E_OB);
      if(s.active_zone.confluence) evidence|=ICT_E_FVG|ICT_E_OB;
      if(s.active_zone.membership==IR_INTERNAL &&
         (s.direction>0 ? s.active_zone.midpoint<=s.range.midpoint : s.active_zone.midpoint>=s.range.midpoint)) evidence|=ICT_E_PD;
     }
   return evidence;
  }

// Pure state reducer. Each transition is appended once by the engine below.
class CICTRangeEngine
  {
private:
   bool m_unified_ob;
   int m_unified_ob_count;
   SICTStrongOrderBlock m_unified_zones[128];
   SICTStrongOBConfig m_unified_ob_config;
   SICTRangeSnapshot m_state;
   SICTDealingRange m_history[ICT_RANGE_HISTORY];
   SICTRangeEvent m_events[ICT_RANGE_EVENTS];
   SICTSweepSequence m_sweep_sequences[2];
   int m_history_count,m_event_count,m_version,m_sweep_age;
   datetime m_last;
   bool m_revised;
   MqlRates m_previous_h[],m_previous_m[],m_previous_l[],m_liquidity_history[];
   bool m_use_liquidity_history;
   string m_context_symbol;
   ENUM_TIMEFRAMES m_context_htf,m_context_mtf,m_context_ltf;
   bool m_unified_ob_pending;

   void ClearObservedHistory()
     {
      ZeroMemory(m_state); m_state.schema=ICT_RANGE_SCHEMA;
      m_history_count=0; m_event_count=0; m_version=0; m_sweep_age=0; m_last=0; m_revised=false;
      for(int i=0;i<2;i++) ZeroMemory(m_sweep_sequences[i]);
      ArrayResize(m_previous_h,0); ArrayResize(m_previous_m,0); ArrayResize(m_previous_l,0);
      ArrayResize(m_liquidity_history,0); m_use_liquidity_history=false;
     }
   void SelectContext(const string symbol,const SICTRangeConfig &c)
     {
      if(m_context_symbol!="" && (m_context_symbol!=symbol || m_context_htf!=c.htf ||
         m_context_mtf!=c.mtf || m_context_ltf!=c.ltf))
        {
         ClearObservedHistory();
         // A new adapter batch supplied immediately before Update belongs to
         // the new context. An older batch must not survive a context switch.
         if(!m_unified_ob_pending) { m_unified_ob=false; m_unified_ob_count=0; }
        }
      m_context_symbol=symbol; m_context_htf=c.htf; m_context_mtf=c.mtf; m_context_ltf=c.ltf;
      m_state.symbol=symbol; m_state.range.timeframe=c.htf; m_state.mtf=c.mtf; m_state.ltf=c.ltf;
      m_unified_ob_pending=false;
     }

   void Transition(const ENUM_IR_PHASE next,const string trigger,const string reason,
                     const MqlRates &bar,const datetime confirmed,const SICTRangeConfig &c)
     {
      if(m_state.phase==next && m_state.phase_at>0) return;
      SICTRangeEvent e; ZeroMemory(e); e.range_id=m_state.range.id;
      e.direction=m_state.direction;
      e.signal_id=m_state.range.id+"_"+IntegerToString(e.direction)+"_"+IntegerToString((long)m_state.reaction_at);
      e.from_phase=m_state.phase; e.to_phase=next; e.confirmed_at=confirmed;
      e.trigger=trigger; e.reason=reason; e.open=bar.open; e.high=bar.high;
      e.low=bar.low; e.close=bar.close; e.invalidation=m_state.invalidation;
      e.zone_low=m_state.active_zone.lower; e.zone_high=m_state.active_zone.upper; e.target=m_state.tp1;
      if(m_event_count==ICT_RANGE_EVENTS)
        { for(int i=1;i<m_event_count;i++) m_events[i-1]=m_events[i]; m_event_count--; }
      m_events[m_event_count++]=e;
      m_state.phase=next; m_state.phase_at=confirmed; m_state.reason=reason;
      if(c.log_events) PrintFormat("IRL/ERL %s %s at %s: %s",m_state.range.id,
                    ICTRangePhaseText(next),TimeToString(confirmed),reason);
     }

   // Keep pool lifecycles and past transitions intact. Only a newly observed
   // liquidity event can start a separate setup within the same dealing range.
   void RearmSetup(const MqlRates &bar,const datetime asof,const SICTRangeConfig &c)
     {
      Transition(IR_RANGE_IDENTIFIED,"NEW_LIQUIDITY_EVENT","New event starts a separate setup",bar,asof,c);
      m_state.scenario=IR_CONSOLIDATION; m_state.direction=0;
      m_state.source_pool_id=""; m_state.source_pool_tf=PERIOD_CURRENT;
      m_state.source_event=IR_EVENT_NONE; m_state.source_event_at=0;
      m_state.source_reason=""; m_state.signal_id="";
      m_state.sweep_at=0; m_state.structure_at=0; m_state.reaction_at=0;
      m_state.sweep_extreme=0; m_state.sweep_level=0; m_state.invalidation=0;
      m_state.structure_confirmed=false; m_state.displacement=false;
      m_state.entry=0; m_state.stop=0; m_state.tp1=0; m_state.tp2=0; m_state.target_distance=0;
      m_state.target1_index=-1; m_state.target2_index=-1;
      m_state.target1_pool_id=""; m_state.target2_pool_id="";
      m_state.target1_pool_tf=PERIOD_CURRENT; m_state.target2_pool_tf=PERIOD_CURRENT;
      m_state.target_reason=""; m_state.technical_ready=false; m_sweep_age=0;
      ZeroMemory(m_state.active_zone);
     }

   bool Revised(const MqlRates &old[],const MqlRates &fresh[])
     {
      int i=0,j=0;
      while(i<ArraySize(old) && j<ArraySize(fresh))
        {
         if(old[i].time<fresh[j].time) { i++; continue; }
         if(old[i].time>fresh[j].time) { j++; continue; }
         if(old[i].open!=fresh[j].open || old[i].high!=fresh[j].high ||
            old[i].low!=fresh[j].low || old[i].close!=fresh[j].close) return true;
         i++; j++;
        }
      return false;
     }

public:
   void SetUnifiedOrderBlocks(const SICTStrongOrderBlock &zones[],const int count,const SICTStrongOBConfig &config)
     {
      m_unified_ob=true; m_unified_ob_count=(int)MathMax(0,MathMin(128,count)); m_unified_ob_config=config;
       m_unified_ob_pending=true;
      for(int i=0;i<m_unified_ob_count;i++) m_unified_zones[i]=zones[i];
     }
   CICTRangeEngine() { Reset(); }
   void Reset()
     {
       m_unified_ob=false; m_unified_ob_count=0; m_unified_ob_pending=false;
       m_context_symbol=""; m_context_htf=PERIOD_CURRENT; m_context_mtf=PERIOD_CURRENT; m_context_ltf=PERIOD_CURRENT;
       ClearObservedHistory();
     }
   void Snapshot(SICTRangeSnapshot &s) { s=m_state; }
   int HistoryCount() { return m_history_count; }
   int EventCount() { return m_event_count; }
   bool Event(const int index,SICTRangeEvent &e)
     { if(index<0 || index>=m_event_count) return false; e=m_events[index]; return true; }
   bool History(const int index,SICTDealingRange &r)
     { if(index<0 || index>=m_history_count) return false; r=m_history[index]; return true; }
   void Reject(const string symbol,const ENUM_IR_REASON code,const string reason)
     {
      m_state.symbol=symbol; m_state.valid=false; m_state.technical_ready=false;
      m_state.proposed_action=0; m_state.score=0; m_state.reason_code=code; m_state.reason=reason;
     }

   // Prepared as-of inputs let tests and real-history replay use identical logic.
   bool Step(const string symbol,const SICTRangeConfig &c,const SICTDealingRange &candidate,
               const SMarketStructure &mtf,const SMarketStructure &ltf,
               const MqlRates &mid[],const int mn,const MqlRates &low[],const int ln,
               const SICTRangeLevel &period_levels[],const int period_count,const double tick,
               const double spread_price=0,const datetime high_available=0,const datetime low_available=0)
     {
       SelectContext(symbol,c);
      if(!ICTValidRangeConfig(c) || !MathIsValidNumber(tick) || tick<=0)
        { Reject(symbol,IR_CONFIG,"Invalid range settings/tick"); return false; }
      if(ln<16 || mn<40 || !SRMPValidDetectorRates(low,ln) || !SRMPValidDetectorRates(mid,mn))
        { Reject(symbol,IR_DATA,"Missing or malformed chronological closed data"); return false; }
      datetime asof=low[ln-1].time+PeriodSeconds(c.ltf);
      if(asof<=m_last) return m_state.valid;
      if(mid[mn-1].time+PeriodSeconds(c.mtf)>asof || !candidate.valid || candidate.confirmed_at>asof)
        { Reject(symbol,IR_NO_RANGE,"No confirmed HTF range at this LTF close"); return false; }
      if(high_available>candidate.confirmed_at || low_available>candidate.confirmed_at)
        { Reject(symbol,IR_DATA,"Boundary pivot confirmation follows its range confirmation"); return false; }
      MqlRates bar=low[ln-1];
      SICTRangeSnapshot previous=m_state;
      bool new_range=candidate.id!=m_state.range.id;
      if(new_range && m_state.range.valid &&
         MathMax(candidate.high_time,candidate.low_time)<=MathMax(m_state.range.high_time,m_state.range.low_time))
        { Reject(symbol,IR_DATA,"Range endpoints moved backward; reinitialize required"); return false; }
      if(!new_range && (candidate.high!=m_state.range.high || candidate.low!=m_state.range.low))
        { m_revised=true; Reject(symbol,IR_HISTORY_REVISED,"Confirmed range revised; reset required"); return false; }
      if(new_range)
        {
         if(m_state.range.valid)
           {
            // Retiring a completed range must not relabel a previously reached
            // target as an invalidated trade outcome.
            if(m_state.phase!=IR_TARGET_REACHED && m_state.phase!=IR_SETUP_INVALIDATED)
               Transition(IR_SETUP_INVALIDATED,"RANGE_REPLACED","New confirmed structural leg",bar,asof,c);
            SICTDealingRange retired=m_state.range; retired.retired_at=asof;
            if(m_history_count==ICT_RANGE_HISTORY)
              { for(int i=1;i<m_history_count;i++) m_history[i-1]=m_history[i]; m_history_count--; }
            m_history[m_history_count++]=retired;
           }
         ZeroMemory(m_state); m_state.range=candidate; m_state.range.version=++m_version;
          // Observed liquidity events remain immutable across range versions;
          // their recorded owner/category describes the range at observation.
          m_state.liquidity_event_count=previous.liquidity_event_count;
          for(int i=0;i<previous.liquidity_event_count;i++) m_state.liquidity_events[i]=previous.liquidity_events[i];
         m_sweep_age=0;
         m_state.phase=IR_RANGE_IDENTIFIED;
         Transition(IR_RANGE_IDENTIFIED,"CONFIRMED_PIVOT_PAIR","Confirmed HTF structural leg; bounded replay",bar,asof,c);
        }
      m_state.schema=ICT_RANGE_SCHEMA; m_state.valid=true; m_state.symbol=symbol;
      m_state.as_of=asof; m_state.mtf=c.mtf; m_state.ltf=c.ltf;
       m_state.source_reason=ICTRangeSourceExplanation(m_state);
       m_state.liquidity_display_start=low[(int)MathMax(0,ln-c.liquidity_history_bars)].time;
       for(int i=m_state.liquidity_event_count-1;i>=0;i--)
          if(m_state.liquidity_events[i].bar_time<m_state.liquidity_display_start)
            { for(int j=i+1;j<m_state.liquidity_event_count;j++) m_state.liquidity_events[j-1]=m_state.liquidity_events[j]; m_state.liquidity_event_count--; }
      m_state.last_close=bar.close;
      m_state.sweep_event_count=0;
      m_state.htf_bias=candidate.bias; m_state.level_count=0; m_state.zone_count=0;
      m_state.proposed_action=0; m_state.score=0; m_state.technical_ready=false;
      if(m_state.phase<IR_STRUCTURE_SHIFT) m_state.reason_code=IR_WAIT_SWEEP;
      double atr=ICTRangeATR(low,ln);
      double tolerance=MathMax(c.tolerance_ticks*tick,c.tolerance_atr*atr);
      double penetration=MathMax(c.penetration_ticks*tick,c.penetration_atr*atr);
      double equal_tolerance=ICTRangeEqualTolerance(tick,atr,spread_price,c);
      if(equal_tolerance<0)
        { Reject(symbol,IR_DATA,"Invalid tick, ATR or historical spread for liquidity tolerance"); return false; }
       ICTRangeAddLevel(m_state,"RANGE_BSL",candidate.high,1,
                        high_available>0 ? high_available : candidate.confirmed_at,tolerance,c.htf);
       ICTRangeAddLevel(m_state,"RANGE_SSL",candidate.low,-1,
                        low_available>0 ? low_available : candidate.confirmed_at,tolerance,c.htf);
      // Identity follows the source pivot, not the range's later opposite-end
      // confirmation. A surviving boundary must retain its consumed state.
      m_state.levels[0].id="BH_"+IntegerToString((long)candidate.high_time)+"_"+DoubleToString(candidate.high,8);
      m_state.levels[1].id="BL_"+IntegerToString((long)candidate.low_time)+"_"+DoubleToString(candidate.low,8);
      for(int i=0;i<period_count && i<ArraySize(period_levels);i++)
         ICTRangeAddLevel(m_state,period_levels[i].name,period_levels[i].price,period_levels[i].side,
                             period_levels[i].available_at,tolerance,period_levels[i].timeframe);
      if(ltf.recent_high>0) ICTRangeAddLevel(m_state,"MINOR_HIGH",ltf.recent_high,1,
                               ltf.recent_high_confirmed_time+PeriodSeconds(c.ltf),tolerance);
      if(ltf.recent_low>0) ICTRangeAddLevel(m_state,"MINOR_LOW",ltf.recent_low,-1,
                               ltf.recent_low_confirmed_time+PeriodSeconds(c.ltf),tolerance);
      if(ltf.prior_high>0 && MathAbs(ltf.recent_high-ltf.prior_high)<=equal_tolerance)
         ICTRangeAddLevel(m_state,"EQH",MathMax(ltf.recent_high,ltf.prior_high),1,
                             ltf.recent_high_confirmed_time+PeriodSeconds(c.ltf),tolerance);
      if(ltf.prior_low>0 && MathAbs(ltf.recent_low-ltf.prior_low)<=equal_tolerance)
         ICTRangeAddLevel(m_state,"EQL",MathMin(ltf.recent_low,ltf.prior_low),-1,
                             ltf.recent_low_confirmed_time+PeriodSeconds(c.ltf),tolerance);
       if(mtf.recent_high>0) ICTRangeAddLevel(m_state,"MTF_HIGH",mtf.recent_high,1,
          ICTBarClose(c.mtf,mtf.recent_high_confirmed_time),tolerance,c.mtf);
       if(mtf.recent_low>0) ICTRangeAddLevel(m_state,"MTF_LOW",mtf.recent_low,-1,
          ICTBarClose(c.mtf,mtf.recent_low_confirmed_time),tolerance,c.mtf);
      bool bull=ICTRangeDisplacement(low,ln-1,1,c),bear=ICTRangeDisplacement(low,ln-1,-1,c);
      int sweep_index=-1,break_index=-1,internal_sweep_index=-1;
      for(int i=0;i<m_state.level_count;i++)
        {
         SICTRangeLevel l=m_state.levels[i]; bool found=false;
         for(int j=0;j<previous.level_count;j++) if(previous.levels[j].id==l.id)
           {
             SICTRangeLevel retained=previous.levels[j];
             retained.range_id=l.range_id; retained.membership=l.membership;
             retained.name=l.name; retained.timeframe=l.timeframe;
             l=retained; found=true; break;
           }
          bool track_sequence=c.enable_sweep_sequence && i<2;
          bool seed_sequence=track_sequence && m_sweep_sequences[i].pool_id!=l.id;
          if(seed_sequence)
            {
             ICTSweepSequenceStart(m_sweep_sequences[i],l.id,l.side,l.price,l.available_at);
            }
         // Seed newly discovered pools only from already closed bars, preserving
         // consumption across range versions and avoiding fresh stale targets.
         if(!found || seed_sequence)
           {
            SICTRangeLevel seed=(!found ? l : m_state.levels[i]);
            if(found) seed.available_at=l.available_at;
            SICTSweepSequence sequence; ZeroMemory(sequence);
            if(track_sequence) sequence=m_sweep_sequences[i];
            bool covered=false;
            if(m_use_liquidity_history)
               covered=ICTRangeSeedLevel(seed,sequence,seed_sequence,m_liquidity_history,
                  ArraySize(m_liquidity_history),bar.time,c,tick,m_state,!found);
            else covered=ICTRangeSeedLevel(seed,sequence,seed_sequence,low,ln,
                  bar.time,c,tick,m_state,!found);
            if(!covered)
              {
               if(!found) { l.state=IR_LEVEL_INVALIDATED; l.event_at=asof; }
               if(track_sequence) sequence.valid=false;
              }
            else if(!found) l=seed;
            if(track_sequence) m_sweep_sequences[i]=sequence;
           }
          ICTRangeAdvanceLevelConfigured(bar,asof,penetration,c.approach_atr*atr,l.side>0 ? bull : bear,c,tick,atr,l);
          ICTRangeRecordLiquidityEvent(m_state,l);
          if(l.id==m_state.source_pool_id && l.last_event!=IR_EVENT_NONE && l.event_at==asof)
            {
             m_state.source_event=l.last_event; m_state.source_event_at=l.event_at;
             m_state.source_reason=ICTRangeSourceExplanation(m_state);
             if(l.last_event==IR_EVENT_FALSE_BREAKOUT && m_state.scenario==IR_BREAKOUT_CONTINUATION &&
                m_state.phase!=IR_SETUP_INVALIDATED && m_state.phase!=IR_TARGET_REACHED)
               {
                m_state.reason_code=IR_INVALIDATION; m_state.technical_ready=false;
                m_state.tp1=0; m_state.tp2=0; m_state.target_distance=0;
                m_state.target1_index=-1; m_state.target2_index=-1;
                m_state.target1_pool_id=""; m_state.target2_pool_id="";
                m_state.target1_pool_tf=PERIOD_CURRENT; m_state.target2_pool_tf=PERIOD_CURRENT;
                m_state.target_reason="TARGET UNAVAILABLE: source breakout failed; "+m_state.source_reason;
                Transition(IR_SETUP_INVALIDATED,"FALSE_BREAKOUT",m_state.target_reason,bar,asof,c);
               }
            }
          if(track_sequence)
            {
             ICTRangeAdvanceBoundarySequence(m_sweep_sequences[i],l,bar,asof,c,penetration,tick);
            for(int k=0;k<m_sweep_sequences[i].count && m_state.sweep_event_count<ICT_SWEEP_SNAPSHOT_MAX;k++)
               m_state.sweep_events[m_state.sweep_event_count++]=m_sweep_sequences[i].events[k];
           }
         m_state.levels[i]=l;
         if(c.allow_continuation && candidate.bias!=0 && l.membership==IR_INTERNAL &&
            l.range_id==m_state.range.id && l.side==-candidate.bias && l.state==IR_SWEPT &&
            l.last_event==IR_EVENT_LIQUIDITY_SWEEP && l.event_at==asof)
            internal_sweep_index=i;
         if(!ICTRangeExternal(l,m_state.range)) continue;
          if(l.state==IR_SWEPT && l.event_at==asof &&
             (l.last_event==IR_EVENT_LIQUIDITY_SWEEP || l.last_event==IR_EVENT_FALSE_BREAKOUT))
           { if(sweep_index>=0 && m_state.levels[sweep_index].side!=l.side) sweep_index=-2;
             else if(sweep_index!=-2) sweep_index=i; }
          if(l.last_event==IR_EVENT_BREAKOUT_CONFIRMED && l.event_at==asof) break_index=i;
         if(l.candidate && m_state.phase<=IR_SWEEP_CANDIDATE)
            Transition(IR_SWEEP_CANDIDATE,"OUTSIDE_CLOSE","Excursion candidate; no reversal confirmation",bar,asof,c);
         else if(l.state==IR_APPROACHING && m_state.phase==IR_RANGE_IDENTIFIED)
            Transition(IR_ERL_APPROACH,"NEAR_ERL","Price near external pool",bar,asof,c);
        }
      if(sweep_index==-2)
        { m_state.reason_code=IR_CONFLICT; m_state.reason="Both external sides swept on one candle"; m_last=asof; return true; }
      if(m_state.phase==IR_SETUP_INVALIDATED || m_state.phase==IR_TARGET_REACHED)
        {
         if(sweep_index<0 && break_index<0 && internal_sweep_index<0)
           { m_last=asof; return true; }
         RearmSetup(bar,asof,c);
        }
      if(m_state.sweep_at>0) m_sweep_age++;
      int maximum_setup_bars=c.max_zone_age*PeriodSeconds(c.mtf)/PeriodSeconds(c.ltf);
      if(m_sweep_age>maximum_setup_bars)
        {
         m_state.reason_code=IR_EXPIRED;
         Transition(IR_SETUP_INVALIDATED,"SWEEP_EXPIRED","Sweep setup exceeded equivalent MTF age in closed LTF bars",bar,asof,c);
         m_last=asof; return true;
        }
      if(sweep_index>=0 && m_state.phase<IR_STRUCTURE_SHIFT)
        {
         m_state.direction=-m_state.levels[sweep_index].side; m_state.scenario=IR_REVERSAL;
          m_state.source_pool_id=m_state.levels[sweep_index].id;
          m_state.source_pool_tf=m_state.levels[sweep_index].timeframe;
          m_state.source_event=m_state.levels[sweep_index].last_event; m_state.source_event_at=asof;
          m_state.source_reason=ICTRangeSourceExplanation(m_state);
         m_state.sweep_at=asof; m_state.sweep_level=m_state.levels[sweep_index].price;
         m_sweep_age=0;
          m_state.sweep_extreme=m_state.levels[sweep_index].event_wick;
         m_state.invalidation=m_state.sweep_extreme;
         Transition(IR_SWEEP_CANDIDATE,"PENETRATION","Closed excursion observed",bar,asof,c);
          Transition(IR_SWEEP_CONFIRMED,ICTRangeLevelEventText(m_state.source_event),
             "Closed external reclaim; "+ICTRangeSourceExplanation(m_state)+"; awaiting structure",bar,asof,c);
        }
      if(sweep_index<0 && break_index<0 && internal_sweep_index>=0 &&
         m_state.phase<IR_STRUCTURE_SHIFT && m_state.scenario==IR_CONSOLIDATION)
        {
         SICTRangeLevel source=m_state.levels[internal_sweep_index];
         m_state.direction=candidate.bias; m_state.scenario=IR_CONTINUATION;
         m_state.source_pool_id=source.id; m_state.source_pool_tf=source.timeframe;
         m_state.source_event=source.last_event; m_state.source_event_at=asof;
         m_state.source_reason=ICTRangeSourceExplanation(m_state);
         m_state.sweep_at=asof; m_state.sweep_level=source.price;
         m_state.sweep_extreme=source.event_wick; m_state.invalidation=source.event_wick;
         m_sweep_age=0;
         Transition(IR_SWEEP_CONFIRMED,"INTERNAL_LIQUIDITY_SWEEP",
            "Closed internal sweep and reclaim in HTF direction; awaiting later structure",bar,asof,c);
        }
      if(break_index>=0 && m_state.phase<IR_STRUCTURE_SHIFT && c.allow_continuation)
        {
         if(m_state.scenario==IR_REVERSAL)
           {
            m_state.scenario=IR_FAILED_SWEEP; m_state.reason_code=IR_INVALIDATION;
            Transition(IR_SETUP_INVALIDATED,"FAILED_SWEEP","Continuation invalidated the sweep thesis",bar,asof,c);
            m_last=asof; return true;
           }
         m_state.direction=m_state.levels[break_index].side; m_state.scenario=IR_BREAKOUT_CONTINUATION;
          m_state.source_pool_id=m_state.levels[break_index].id;
          m_state.source_pool_tf=m_state.levels[break_index].timeframe;
          m_state.source_event=IR_EVENT_BREAKOUT_CONFIRMED; m_state.source_event_at=asof;
          m_state.source_reason=ICTRangeSourceExplanation(m_state);
        }
      if((m_state.scenario==IR_REVERSAL || (m_state.scenario==IR_CONTINUATION && m_state.sweep_at>0)) &&
         (bar.close-m_state.invalidation)*m_state.direction<0)
        {
         m_state.scenario=IR_FAILED_SWEEP; m_state.reason_code=IR_INVALIDATION;
         Transition(IR_SETUP_INVALIDATED,"SWEEP_EXTREME_BROKEN","Closed beyond sweep invalidation",bar,asof,c);
         m_last=asof; return true;
        }
      datetime structure_close=mtf.bos_time+PeriodSeconds(c.mtf);
      datetime source_breakout=0;
      if(m_state.scenario==IR_BREAKOUT_CONTINUATION)
         for(int i=0;i<m_state.level_count;i++)
            if(m_state.levels[i].id==m_state.source_pool_id) source_breakout=m_state.levels[i].breakout_at;
      bool new_structure=mtf.bos_time>0 && structure_close>m_state.last_mtf_event && structure_close<=asof;
      if(new_structure)
        {
         m_state.last_mtf_event=structure_close;
         if(m_state.phase<IR_STRUCTURE_SHIFT && c.allow_continuation && m_state.scenario==IR_CONSOLIDATION &&
            mtf.bos_direction==candidate.bias && candidate.bias!=0 && structure_close>=candidate.confirmed_at)
           { m_state.direction=candidate.bias; m_state.scenario=IR_CONTINUATION; }
         bool matching=m_state.direction!=0 && mtf.bos_direction==m_state.direction &&
            candidate.bias==m_state.direction && structure_close>=candidate.confirmed_at &&
            (m_state.scenario!=IR_REVERSAL || (structure_close>m_state.sweep_at && (!c.require_mss || mtf.mss))) &&
            (m_state.scenario!=IR_CONTINUATION || m_state.sweep_at<=0 || structure_close>m_state.sweep_at) &&
            (m_state.scenario!=IR_BREAKOUT_CONTINUATION || (source_breakout>0 && structure_close>source_breakout));
         if(matching)
           {
            m_state.structure_at=structure_close; m_state.structure_confirmed=true;
            m_state.displacement=ICTRangeDisplacement(mid,mn-1,m_state.direction,c);
            if(!c.require_displacement || m_state.displacement)
               Transition(IR_STRUCTURE_SHIFT,"CONFIRMED_MTF_BREAK","Aligned closed structure and displacement",bar,asof,c);
           }
         else if(m_state.phase>=IR_STRUCTURE_SHIFT && mtf.bos_direction==-m_state.direction)
           {
            m_state.reason_code=IR_CONFLICT;
            Transition(IR_SETUP_INVALIDATED,"OPPOSITE_STRUCTURE","Opposite confirmed MTF break",bar,asof,c);
            m_last=asof; return true;
           }
        }
      if(candidate.bias==0 || (m_state.direction!=0 && candidate.bias!=m_state.direction))
        { m_state.reason_code=IR_CONFLICT; m_state.reason="Neutral/opposing HTF structure; no actionable rotation"; m_last=asof; return true; }
      ICTRangeDetectZones(mid,mn,mtf,c,tick,tolerance,m_state,!m_unified_ob);
      if(m_unified_ob && c.use_ob)
        {
         for(int i=m_unified_ob_count-1;i>=0 && m_state.zone_count<ICT_RANGE_ZONES;i--)
           {
            SICTStrongOrderBlock block=m_unified_zones[i];
            if(block.timeframe!=c.mtf || !block.hard_gates || block.confirmation_score<60 ||
               block.ob.confirmation_time>asof) continue;
            // Reconstruct lifecycle at THIS historical prefix. Current lifecycle
            // must never leak into an earlier range replay step.
            block.life=ICT_OB_CONFIRMED; block.ob.state=SRMP_OB_CONFIRMED;
            block.processed_at=block.ob.confirmation_time; block.ob.state_time=block.ob.confirmation_time;
            block.touch_count=0; block.age=0; block.mitigation_depth=0; block.in_contact=false; block.departed=true;
            for(int k=0;k<mn;k++) ICTAdvanceStrongOB(mid[k],ICTBarClose(c.mtf,mid[k].time),m_unified_ob_config,
                                                   tick*m_unified_ob_config.tolerance_ticks,block);
            if(!ICTOBActive(block)) continue;
            SICTRangeZone z; ZeroMemory(z); z.id=block.id; z.type=IR_OB; z.timeframe=c.mtf;
            z.direction=block.ob.direction; z.lower=block.ob.lower; z.upper=block.ob.upper;
            z.formed_at=block.ob.formation_time; z.confirmed_at=block.ob.confirmation_time;
            z.state=(block.touch_count>0 ? IR_TOUCHED : IR_FRESH);
            z.displacement=block.ob.displacement; z.structure_match=block.ob.break_confirmed;
            ICTRangeAddZone(m_state,z,tolerance);
           }
         ICTRangeUpdateZoneConfluence(m_state);
        }
      for(int i=0;i<m_state.zone_count;i++)
        {
         m_state.zones[i].structure_match=m_state.structure_confirmed && m_state.zones[i].direction==m_state.direction;
         bool pd_match=(m_state.zones[i].direction>0 ? m_state.zones[i].midpoint<=m_state.range.midpoint :
                                                      m_state.zones[i].midpoint>=m_state.range.midpoint);
         m_state.zones[i].quality=ICTRangeZoneQuality(m_state.zones[i],candidate.bias,m_state.zones[i].confluence,pd_match);
        }
      if(m_state.phase<IR_STRUCTURE_SHIFT)
        { m_state.reason_code=IR_WAIT_STRUCTURE; m_state.reason="Awaiting aligned post-event MTF structure/displacement"; m_last=asof; return true; }
      if(m_state.active_zone.id=="")
        {
         int best=-1;
         for(int i=0;i<m_state.zone_count;i++)
            if(ICTRangeZoneEligible(m_state.zones[i],m_state) &&
               (c.zone_mode!=0 || m_state.zones[i].type==IR_FVG) &&
               (c.zone_mode!=1 || m_state.zones[i].type==IR_OB) &&
               (!c.require_displacement || m_state.zones[i].displacement) &&
               (best<0 || m_state.zones[i].quality>m_state.zones[best].quality)) best=i;
         if(best<0) { m_state.reason_code=IR_NO_ZONE; m_state.reason="No eligible same-range internal PD array"; m_last=asof; return true; }
         m_state.active_zone=m_state.zones[best];
         m_state.entry=MathRound(m_state.active_zone.midpoint/tick)*tick;
         double invalid=((m_state.scenario==IR_REVERSAL ||
                         (m_state.scenario==IR_CONTINUATION && m_state.sweep_at>0)) ?
            (m_state.direction>0 ? MathMin(m_state.sweep_extreme,m_state.active_zone.lower) :
                                  MathMax(m_state.sweep_extreme,m_state.active_zone.upper)) :
            m_state.active_zone.invalidation);
         m_state.invalidation=invalid;
         m_state.stop=(m_state.direction>0 ? MathFloor((invalid-c.stop_buffer_ticks*tick)/tick)*tick :
                                            MathCeil((invalid+c.stop_buffer_ticks*tick)/tick)*tick);
        }
      SICTRangeZone zone=m_state.active_zone;
      int zone_age=0;
      for(int i=0;i<mn;i++) if(mid[i].time>=zone.confirmed_at) zone_age++;
      bool expired=zone_age>c.max_zone_age || zone.confirmed_at<mid[0].time;
      bool invalid=(bar.close-m_state.invalidation)*m_state.direction<0;
      // A full traversal/mitigation is not a fresh reaction opportunity.
      bool fully_filled=asof>zone.confirmed_at && (zone.direction>0 ? bar.low<=zone.lower : bar.high>=zone.upper);
      if(expired || invalid || fully_filled)
        {
         m_state.active_zone.state=(invalid ? IR_ZONE_INVALIDATED : IR_MITIGATED);
         m_state.active_zone.quality=0;
         m_state.reason_code=(expired ? IR_EXPIRED : IR_INVALIDATION);
         Transition(IR_SETUP_INVALIDATED,"ZONE_INVALID","Entry array expired, fully mitigated or invalidated",bar,asof,c);
         m_last=asof; return true;
        }
      bool touched=bar.low<=zone.upper && bar.high>=zone.lower && bar.time>=zone.confirmed_at && asof>m_state.structure_at;
      if(touched && m_state.phase==IR_STRUCTURE_SHIFT)
        {
         m_state.active_zone.state=IR_TOUCHED;
         m_state.active_zone.quality=ICTRangeZoneQuality(m_state.active_zone,candidate.bias,
                                                         m_state.active_zone.confluence,true);
         Transition(IR_RETRACEMENT,"IRL_TOUCH","Closed retracement into selected internal PD array",bar,asof,c);
        }
      bool reaction=m_state.phase==IR_RETRACEMENT &&
         (bar.close-bar.open)*m_state.direction>0 &&
         (m_state.direction>0 ? bar.close>zone.midpoint : bar.close<zone.midpoint);
      if(reaction)
        {
         m_state.reaction_at=asof;
         Transition(IR_REACTION,"DIRECTIONAL_REACTION","Closed directional rejection after IRL touch",bar,asof,c);
         ICTRangeSelectTargets(m_state,m_state.entry);
         // A nearer pool can be swept by this same candle and disappear from
         // the current selection. Inspect its state before the candle too;
         // do not silently replace it with a farther untouched target.
         double prior_target=0;
         if(previous.range.valid && previous.range.id==m_state.range.id)
           {
            previous.direction=m_state.direction;
            ICTRangeSelectTargets(previous,m_state.entry);
            prior_target=previous.tp1;
           }
         if((prior_target>0 && !ICTRangeReactionTargetSafe(m_state.direction,bar,prior_target)) ||
            (m_state.tp1>0 && !ICTRangeReactionTargetSafe(m_state.direction,bar,m_state.tp1)))
           {
            m_state.technical_ready=false; m_state.reason_code=IR_INVALIDATION;
            Transition(IR_SETUP_INVALIDATED,"TARGET_ON_REACTION_BAR",
               "Target touched during reaction candle; intrabar order is unknown",bar,asof,c);
            m_last=asof; return true;
           }
         if(m_state.tp1>0) Transition(IR_TARGETING,"VALID_ERL_TARGET",m_state.target_reason,bar,asof,c);
        }
      if(m_state.phase==IR_TARGETING)
        {
          // Array positions can change as new confirmed pools appear. Resolve
          // targets by source identity so an equal price cannot replace a pool.
          m_state.target1_index=-1; m_state.target2_index=-1;
          for(int i=0;i<m_state.level_count;i++)
            {
             if(m_state.levels[i].id==m_state.target1_pool_id) m_state.target1_index=i;
             if(m_state.levels[i].id==m_state.target2_pool_id) m_state.target2_index=i;
            }
         bool reached=asof>m_state.reaction_at && (m_state.direction>0 ? bar.high>=m_state.tp1 : bar.low<=m_state.tp1);
         if(reached)
           {
            for(int i=0;i<m_state.level_count;i++)
                if(m_state.levels[i].id==m_state.target1_pool_id && ICTRangeExternal(m_state.levels[i],m_state.range))
                  m_state.levels[i].state=IR_CONSUMED;
            Transition(IR_TARGET_REACHED,"TARGET_TOUCH","Confirmed later closed bar reached scenario target",bar,asof,c);
           }
         else
           {
            // Never rotate a consumed target silently to a farther target.
            bool target_valid=false;
             for(int i=0;i<m_state.level_count;i++) if(m_state.levels[i].id==m_state.target1_pool_id &&
               ICTRangeExternal(m_state.levels[i],m_state.range) && m_state.levels[i].state<=IR_APPROACHING) target_valid=true;
            m_state.technical_ready=target_valid;
            m_state.reason_code=(target_valid ? IR_OK : IR_NO_TARGET);
            m_state.reason=(target_valid ? "Confirmed rotation; proposed zone entry awaits risk/score gates" : "Scenario target consumed/unavailable");
           }
        }
      else if(m_state.phase==IR_REACTION)
        { m_state.reason_code=IR_NO_TARGET; m_state.reason=m_state.target_reason; }
      else if(m_state.phase!=IR_TARGET_REACHED)
        { m_state.reason_code=IR_WAIT_REACTION; m_state.reason="Awaiting closed IRL reaction and eligible ERL target"; }
      m_state.signal_id=m_state.range.id+"_"+IntegerToString(m_state.direction)+"_"+
                         IntegerToString((long)m_state.reaction_at);
      m_last=asof; return true;
     }

   bool Update(const string symbol,const SICTRangeConfig &c)
     {
       SelectContext(symbol,c);
      if(!c.enabled) { Reject(symbol,IR_DISABLED,"IRL/ERL disabled"); return false; }
      if(!ICTValidRangeConfig(c)) { Reject(symbol,IR_CONFIG,"Invalid IRL/ERL configuration"); return false; }
      if(m_revised) { Reject(symbol,IR_HISTORY_REVISED,"Closed history revised; reinitialize and audit replay"); return false; }
      MqlRates high[],mid[],low[];
      ArraySetAsSeries(high,false); ArraySetAsSeries(mid,false); ArraySetAsSeries(low,false);
      if(CopyRates(symbol,c.htf,1,c.lookback,high)!=c.lookback ||
         CopyRates(symbol,c.mtf,1,c.lookback,mid)!=c.lookback ||
         CopyRates(symbol,c.ltf,1,c.lookback,low)!=c.lookback ||
         !SRMPValidDetectorRates(high,c.lookback) || !SRMPValidDetectorRates(mid,c.lookback) ||
         !SRMPValidDetectorRates(low,c.lookback))
        { Reject(symbol,IR_DATA,"Incomplete closed HTF/MTF/LTF history"); return false; }
      if(Revised(m_previous_h,high) || Revised(m_previous_m,mid) || Revised(m_previous_l,low))
        { m_revised=true; Reject(symbol,IR_HISTORY_REVISED,"Broker revised observed closed candles; reset required"); return false; }
      if(m_last>0 && m_last<low[0].time)
        { Reject(symbol,IR_DATA,"Replay gap exceeds retained history; reinitialize required"); return false; }
      double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(point<=0) { Reject(symbol,IR_DATA,"Invalid symbol point for historical spread"); return false; }
      datetime now=TimeCurrent();
      datetime latest=low[c.lookback-1].time+PeriodSeconds(c.ltf);
      string history_error=ICTRangeHistoryError(latest,now,c.ltf,tick);
      if(history_error!="")
        { Reject(symbol,IR_DATA,history_error); return false; }
      if(latest==m_last && m_state.valid) return true;
      // The structural replay remains bounded by lookback. A separate, larger
      // closed LTF window is used only to reconstruct an older pool's life.
      // Partial history is allowed, but pools older than it stay invalid.
      ArrayResize(m_liquidity_history,0); ArraySetAsSeries(m_liquidity_history,false);
      int history_count=CopyRates(symbol,c.ltf,1,c.liquidity_seed_bars,m_liquidity_history);
      if(history_count<c.lookback || !SRMPValidDetectorRates(m_liquidity_history,history_count))
        { ArrayResize(m_liquidity_history,0); ArrayCopy(m_liquidity_history,low); }
      if(Revised(m_previous_l,m_liquidity_history))
        { m_revised=true; Reject(symbol,IR_HISTORY_REVISED,"Broker revised observed liquidity history; reset required"); return false; }
      m_use_liquidity_history=true;
      for(int n=30;n<=c.lookback;n++)
        {
         datetime asof=low[n-1].time+PeriodSeconds(c.ltf);
         if(asof<=m_last) continue;
         int hn=ICTRangeClosedCount(high,c.lookback,c.htf,asof);
         int mn=ICTRangeClosedCount(mid,c.lookback,c.mtf,asof);
         SMarketStructure hs,ms,ls;
         SICTDealingRange range;
         if(!SRMPAnalyzeStructureFromRates(high,hn,c.left,c.right,hs) ||
            !SRMPAnalyzeStructureFromRates(mid,mn,c.left,c.right,ms) ||
            !SRMPAnalyzeStructureFromRates(low,n,c.left,c.right,ls) ||
            !ICTRangeFromStructure(symbol,c.htf,hs,c.min_range_ticks*tick,asof,range))
           { if(n==c.lookback) Reject(symbol,IR_NO_RANGE,"Confirmed structural leg unavailable in retained history"); continue; }
         SICTRangeLevel periods[8]; int used=0;
         ENUM_TIMEFRAMES frames[3]={PERIOD_D1,PERIOD_W1,PERIOD_MN1};
         string names[3]={"PD","PW","PM"};
         bool periods_ok=true;
         for(int j=0;j<3;j++)
           {
            SLiquidityLevelEvidence e;
            if(!SRMPPriorPeriodEvidenceAt(symbol,frames[j],low[n-1],e)) { periods_ok=false; break; }
            for(int side=-1;side<=1;side+=2)
              {
               ZeroMemory(periods[used]); periods[used].name=names[j]+(side>0 ? "H" : "L");
                periods[used].timeframe=frames[j];
               periods[used].price=(side>0 ? e.high : e.low); periods[used].side=side;
               periods[used].available_at=e.available_from; used++;
              }
           }
         if(!periods_ok) { if(n==c.lookback) Reject(symbol,IR_DATA,"Prior D/W/M liquidity history unavailable"); continue; }
         // The existing project's session definition is the broker's D1 session;
         // it aliases PDH/PDL and is not duplicated as a second liquidity pool.
         double historical_spread=(double)low[n-1].spread*point;
         datetime high_available=ICTBarClose(c.htf,hs.recent_high_confirmed_time);
         datetime low_available=ICTBarClose(c.htf,hs.recent_low_confirmed_time);
         if(!Step(symbol,c,range,ms,ls,mid,mn,low,n,periods,used,tick,historical_spread,
                  high_available,low_available) && n==c.lookback)
           { m_use_liquidity_history=false; return false; }
        }
      m_use_liquidity_history=false;
      ArrayCopy(m_previous_h,high); ArrayCopy(m_previous_m,mid);
      // CopyRates may return a shorter partial history on a later request.
      // Trim the destination so stale trailing bars cannot corrupt revision checks.
      ArrayResize(m_previous_l,ArraySize(m_liquidity_history));
      ArrayCopy(m_previous_l,m_liquidity_history);
      return m_state.valid && m_state.as_of==latest;
     }

   bool ExportHistory(const string filename)
     {
      ResetLastError();
      int file=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
      if(file==INVALID_HANDLE) { Print("IRL/ERL history export failed ",GetLastError()); return false; }
      FileWrite(file,"kind","range_id","version/phase","confirmed_at","reason","open/high","high/low","low/mid","close/retired","invalidation","direction","signal_id","zone_low","zone_high","target");
      for(int i=0;i<m_history_count;i++) FileWrite(file,"range",m_history[i].id,m_history[i].version,
         (long)m_history[i].confirmed_at,"retired",m_history[i].high,m_history[i].low,
         m_history[i].midpoint,(long)m_history[i].retired_at,0,m_history[i].direction,"",0,0,0);
      if(m_state.range.valid) FileWrite(file,"range",m_state.range.id,m_state.range.version,
         (long)m_state.range.confirmed_at,"active",m_state.range.high,m_state.range.low,m_state.range.midpoint,0,0,m_state.range.direction,"",0,0,0);
      for(int i=0;i<m_event_count;i++) FileWrite(file,"event",m_events[i].range_id,
         ICTRangePhaseText(m_events[i].to_phase),(long)m_events[i].confirmed_at,
         ICTRangeCSV(m_events[i].trigger+": "+m_events[i].reason),m_events[i].open,m_events[i].high,
         m_events[i].low,m_events[i].close,m_events[i].invalidation,m_events[i].direction,
         m_events[i].signal_id,m_events[i].zone_low,m_events[i].zone_high,m_events[i].target);
      FileFlush(file); int error=GetLastError(); FileClose(file);
      return error==0;
     }
  };
#endif
