#ifndef SRMP_FVG_DETECTOR_MQH
#define SRMP_FVG_DETECTOR_MQH
#include "MarketStructure.mqh"

enum ENUM_SRMP_FVG_STATUS
  { SRMP_FVG_ACTIVE=0, SRMP_FVG_PARTIALLY_FILLED, SRMP_FVG_FULLY_FILLED, SRMP_FVG_INVALIDATED };

string SRMPFVGStatusText(const ENUM_SRMP_FVG_STATUS status)
  {
   switch(status)
     {
      case SRMP_FVG_ACTIVE: return "Active";
      case SRMP_FVG_PARTIALLY_FILLED: return "Partially filled";
      case SRMP_FVG_FULLY_FILLED: return "Fully filled";
      case SRMP_FVG_INVALIDATED: return "Invalidated";
     }
   return "Unknown";
  }
struct SFairValueGap
  {
   int direction;
   double lower;
   double upper;
   bool mitigated; // Legacy touch flag; also true on invalidation for conservative old callers.
   datetime formed_time;
   ENUM_SRMP_FVG_STATUS status;
   datetime first_touch_time;
   datetime fully_filled_time;
   datetime invalidated_time;
   bool inversion_evidence; // Close through far edge; evidence only, not a retest signal.
   int inversion_direction;
   datetime inversion_time;
  };

// All evidence timestamps identify the source CLOSED bar's opening time.
void SRMPUpdateFVGEvidence(const MqlRates &bar,SFairValueGap &gap)
  {
   if(!SRMPValidDetectorBar(bar) || bar.time<=gap.formed_time ||
      (gap.direction!=1 && gap.direction!=-1) || !MathIsValidNumber(gap.lower) ||
      !MathIsValidNumber(gap.upper) || gap.upper<=gap.lower) return;
   bool overlap=(bar.low<=gap.upper && bar.high>=gap.lower);
   if(overlap)
     {
      gap.mitigated=true;
      if(gap.first_touch_time==0) gap.first_touch_time=bar.time;
      if(gap.status==SRMP_FVG_ACTIVE) gap.status=SRMP_FVG_PARTIALLY_FILLED;
     }
   bool full=(gap.direction==1 ? bar.low<=gap.lower : bar.high>=gap.upper);
   if(full && gap.fully_filled_time==0) gap.fully_filled_time=bar.time;
   if(full && gap.status!=SRMP_FVG_INVALIDATED) gap.status=SRMP_FVG_FULLY_FILLED;
   bool invalid=(gap.direction==1 ? bar.close<gap.lower : bar.close>gap.upper);
   if(invalid)
     {
      gap.status=SRMP_FVG_INVALIDATED;
      gap.mitigated=true; // Gap-over must not appear tradable to legacy callers.
      if(gap.invalidated_time==0) gap.invalidated_time=bar.time;
      gap.inversion_evidence=true;
      gap.inversion_direction=-gap.direction;
      if(gap.inversion_time==0) gap.inversion_time=bar.time;
     }
  }

// One shared formation/lifecycle evaluator for finders and range enumeration.
bool SRMPFVGAtRates(const MqlRates &rates[],const int count,const int index,
                    const double min_gap,SFairValueGap &gap)
  {
   ZeroMemory(gap);
   if(index<2 || index>=count || count>ArraySize(rates) || min_gap<=0) return false;
   if(rates[index].low-rates[index-2].high>=min_gap)
     { gap.direction=1; gap.lower=rates[index-2].high; gap.upper=rates[index].low; }
   else if(rates[index-2].low-rates[index].high>=min_gap)
     { gap.direction=-1; gap.lower=rates[index].high; gap.upper=rates[index-2].low; }
   else return false;
   gap.formed_time=rates[index].time;
   for(int j=index+1;j<count;j++) SRMPUpdateFVGEvidence(rates[j],gap);
   return true;
  }

// Chronological closed bars only; count selects an as-of prefix (no future bars).
// desired_direction: 0 either (legacy), +1 bullish, -1 bearish; others rejected.
bool SRMPFindFVGFromRates(const MqlRates &rates[],const int count,
                          const double min_gap,SFairValueGap &gap,const int desired_direction=0)
  {
   ZeroMemory(gap);
   if(count<5 || !SRMPValidDetectorRates(rates,count) || !MathIsValidNumber(min_gap) ||
      min_gap<=0.0 || desired_direction<-1 || desired_direction>1) return false;
   bool found=false;
   for(int i=count-1;i>=2;i--)
     {
      SFairValueGap candidate;
      if(!SRMPFVGAtRates(rates,count,i,min_gap,candidate)) continue;
      if(desired_direction!=0 && candidate.direction!=desired_direction) continue;
      if(!found) { gap=candidate; found=true; }
      // Preserve legacy selection: newest untouched gap, otherwise newest gap.
      if(!candidate.mitigated) { gap=candidate; return true; }
     }
   return found;
  }

bool SRMPFindFVG(const string symbol,const ENUM_TIMEFRAMES timeframe,
                 const int lookback,const double min_gap,SFairValueGap &gap,const int desired_direction=0)
  {
   ZeroMemory(gap);
   if(lookback<5 || !MathIsValidNumber(min_gap) || min_gap<=0.0 ||
      desired_direction<-1 || desired_direction>1) return false;
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int count=CopyRates(symbol,timeframe,1,lookback,rates);
   if(count<lookback) return false;
   return SRMPFindFVGFromRates(rates,count,min_gap,gap,desired_direction);
  }
#endif

