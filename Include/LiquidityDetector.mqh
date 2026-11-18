#ifndef SRMP_LIQUIDITY_DETECTOR_MQH
#define SRMP_LIQUIDITY_DETECTOR_MQH

#include "MarketStructure.mqh"

// Evidence is evaluated on a closed trigger bar against an already completed period.
// Timestamps are source bar opening times, not wall-clock detection times.
struct SLiquidityLevelEvidence
  {
   bool valid;
   double high;
   double low;
   datetime period_start;
   datetime available_from;
   bool high_touched;
   bool low_touched;
   bool high_swept; // Strict excursion followed by close back below high.
   bool low_swept;
   datetime high_touch_time;
   datetime low_touch_time;
   datetime high_sweep_time;
   datetime low_sweep_time;
  };

struct SLiquidityState
  {
   double previous_day_high;
   double previous_day_low;
   bool   equal_highs;
   bool   equal_lows;
   bool   bullish_sweep;
   bool   bearish_sweep;
   double sweep_extreme;
   datetime sweep_time;
   datetime recent_sweep_time;
   double recent_sweep_extreme;
   double recent_sweep_level;
   int recent_sweep_direction; // +1 low/SSL, -1 high/BSL
   bool recent_sweep_daily;
   SLiquidityLevelEvidence previous_week;
   SLiquidityLevelEvidence previous_session; // Session = broker D1 candle, explicitly. (No UTC conversion.)
  };

// Pure helper: period must have ended at available_from, before this trigger bar.
// A range intersection counts as touch; gaps entirely beyond a level do not.
bool SRMPEvaluateLiquidityLevels(const MqlRates &bar,const double high,const double low,
                                 const datetime period_start,const datetime available_from,
                                 SLiquidityLevelEvidence &evidence)
  {
   ZeroMemory(evidence);
   if(!SRMPValidDetectorBar(bar) || !MathIsValidNumber(high) || !MathIsValidNumber(low) ||
      low<=0.0 || high<=low || period_start<=0 || available_from<=period_start || bar.time<available_from) return false;
   evidence.valid=true;
   evidence.high=high;
   evidence.low=low;
   evidence.period_start=period_start;
   evidence.available_from=available_from;
   evidence.high_touched=(bar.low<=high && bar.high>=high);
   evidence.low_touched=(bar.low<=low && bar.high>=low);
   evidence.high_swept=(bar.high>high && bar.close<high);
   evidence.low_swept=(bar.low<low && bar.close>low);
   if(evidence.high_touched) evidence.high_touch_time=bar.time;
   if(evidence.low_touched) evidence.low_touch_time=bar.time;
   if(evidence.high_swept) evidence.high_sweep_time=bar.time;
   if(evidence.low_swept) evidence.low_sweep_time=bar.time;
   return true;
  }

// Period bars are chronological; use only the previous period, never the current
// period OHLC (which may contain data later than the requested historical time).
bool SRMPPriorPeriodEvidenceFromRates(const MqlRates &periods[],const int count,
                                      const MqlRates &bar,SLiquidityLevelEvidence &evidence)
  {
   ZeroMemory(evidence);
   if(count<2 || !SRMPValidDetectorRates(periods,count) || !SRMPValidDetectorBar(bar)) return false;
   for(int i=count-1;i>=1;i--)
      if(periods[i].time<=bar.time)
         return SRMPEvaluateLiquidityLevels(bar,periods[i-1].high,periods[i-1].low,
                                            periods[i-1].time,periods[i].time,evidence);
   return false;
  }

bool SRMPPriorPeriodEvidenceAt(const string symbol,const ENUM_TIMEFRAMES period,
                               const MqlRates &bar,SLiquidityLevelEvidence &evidence)
  {
   ZeroMemory(evidence);
   int shift=iBarShift(symbol,period,bar.time,false);
   if(shift<0) return false;
   MqlRates periods[];
   ArraySetAsSeries(periods,false);
   if(CopyRates(symbol,period,shift,2,periods)!=2) return false;
   return SRMPPriorPeriodEvidenceFromRates(periods,2,bar,evidence);
  }

// Broker-day session: boundaries follow the broker's D1 series, including DST.
bool SRMPPriorBrokerSessionEvidenceAt(const string symbol,const MqlRates &bar,
                                      SLiquidityLevelEvidence &evidence)
  {
   return SRMPPriorPeriodEvidenceAt(symbol,PERIOD_D1,bar,evidence);
  }
bool SRMPPriorDayLevelsAt(const string symbol,const datetime bar_time,
                          double &high,double &low)
  {
   int current_day=iBarShift(symbol,PERIOD_D1,bar_time,false);
   if(current_day<0 || iTime(symbol,PERIOD_D1,current_day)>bar_time)
      return false;
   MqlRates day[];
   if(CopyRates(symbol,PERIOD_D1,current_day+1,1,day)!=1) return false;
   high=day[0].high;
   low=day[0].low;
   return high>low && low>0.0;
  }

void SRMPFindRecentSweep(const string symbol,const ENUM_TIMEFRAMES timeframe,
                         const int lookback,SLiquidityState &state)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars,false);
   int count=CopyRates(symbol,timeframe,1,lookback+10,bars);
   if(count<11) return;
   for(int i=count-1;i>=10;i--)
     {
      double high=0.0,low=0.0;
      bool daily=SRMPPriorDayLevelsAt(symbol,bars[i].time,high,low);
      bool swept_low=daily && bars[i].low<low && bars[i].close>low;
      bool swept_high=daily && bars[i].high>high && bars[i].close<high;
      if(swept_low && swept_high) continue;
      if(!swept_low && !swept_high)
        {
         high=bars[i-1].high;
         low=bars[i-1].low;
         for(int j=i-10;j<i;j++)
           {
            high=MathMax(high,bars[j].high);
            low=MathMin(low,bars[j].low);
           }
         swept_low=(bars[i].low<low && bars[i].close>low);
         swept_high=(bars[i].high>high && bars[i].close<high);
         daily=false;
        }
      if(swept_low==swept_high) continue;
      state.recent_sweep_time=bars[i].time;
      state.recent_sweep_direction=swept_low ? 1 : -1;
      state.recent_sweep_level=swept_low ? low : high;
      state.recent_sweep_extreme=swept_low ? bars[i].low : bars[i].high;
      state.recent_sweep_daily=daily;
      return;
     }
  }

bool SRMPAnalyzeLiquidity(const string symbol,const ENUM_TIMEFRAMES trigger_timeframe,
                          const SMarketStructure &structure,
                          const double equal_tolerance,
                          SLiquidityState &state)
  {
   ZeroMemory(state);
   MqlRates day[],trigger[];
   ArraySetAsSeries(day,false);
   ArraySetAsSeries(trigger,false);
   if(CopyRates(symbol,PERIOD_D1,1,1,day)!=1 ||
      CopyRates(symbol,trigger_timeframe,1,2,trigger)!=2) return false;
   state.previous_day_high=day[0].high;
   state.previous_day_low=day[0].low;
   state.equal_highs=(structure.recent_high>0.0 && structure.prior_high>0.0 &&
                      MathAbs(structure.recent_high-structure.prior_high)<=equal_tolerance);
   state.equal_lows=(structure.recent_low>0.0 && structure.prior_low>0.0 &&
                     MathAbs(structure.recent_low-structure.prior_low)<=equal_tolerance);
   MqlRates latest=trigger[1]; // Last fully closed trigger candle.
   double latest_high=0.0,latest_low=0.0;
   if(!SRMPPriorDayLevelsAt(symbol,latest.time,latest_high,latest_low)) return false;
   SRMPPriorPeriodEvidenceAt(symbol,PERIOD_W1,latest,state.previous_week);
   SRMPPriorBrokerSessionEvidenceAt(symbol,latest,state.previous_session);
   state.bullish_sweep=(latest.low<latest_low && latest.close>latest_low);
   state.bearish_sweep=(latest.high>latest_high && latest.close<latest_high);
   if(state.bullish_sweep) state.sweep_extreme=latest.low;
   if(state.bearish_sweep) state.sweep_extreme=latest.high;
   if(state.bullish_sweep || state.bearish_sweep) state.sweep_time=latest.time;
   return true;
  }

#endif


