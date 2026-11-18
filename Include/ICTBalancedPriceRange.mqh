#ifndef ICT_BALANCED_PRICE_RANGE_MQH
#define ICT_BALANCED_PRICE_RANGE_MQH
#include "FVGDetector.mqh"
#include "ICTBarSnapshot.mqh"

enum ENUM_ICT_BPR_STATE { ICT_BPR_NONE=0, ICT_BPR_CONFIRMED=1, ICT_BPR_INVALIDATED=2 };
struct SICTBalancedPriceRange
  {
   string id;
   ENUM_TIMEFRAMES timeframe;
   ENUM_ICT_BPR_STATE state;
   int direction;
   double lower,upper,invalidation;
   datetime first_fvg_time,second_fvg_time,confirmed_at,invalidated_at;
  };

// A BPR is the non-empty overlap of two opposite, closed-bar FVGs. Direction
// is the newer FVG's direction, an explicit project convention, not a forecast.
bool ICTFindBPRFromRates(const string symbol,const ENUM_TIMEFRAMES timeframe,
                         const MqlRates &rates[],const int count,const double minimum_gap,
                         const double minimum_overlap,SICTBalancedPriceRange &out)
  {
   ZeroMemory(out);
   int seconds=PeriodSeconds(timeframe);
   if(symbol=="" || seconds<=0 || count<4 || count>ArraySize(rates) ||
      !SRMPValidDetectorRates(rates,count) || !MathIsValidNumber(minimum_gap) ||
      !MathIsValidNumber(minimum_overlap) || minimum_gap<=0 || minimum_overlap<=0) return false;
   for(int i=count-1;i>=3;i--)
     {
      SFairValueGap recent;
      if(!SRMPFVGAtRates(rates,i+1,i,minimum_gap,recent)) continue;
      for(int j=i-1;j>=2;j--)
        {
         SFairValueGap older;
         if(!SRMPFVGAtRates(rates,j+1,j,minimum_gap,older) || older.direction==recent.direction) continue;
         double low=MathMax(older.lower,recent.lower),high=MathMin(older.upper,recent.upper);
         if(high-low<minimum_overlap) continue;
         out.id=symbol+"_"+IntegerToString((int)timeframe)+"_"+
                IntegerToString((long)older.formed_time)+"_"+IntegerToString((long)recent.formed_time);
         out.timeframe=timeframe; out.direction=recent.direction; out.lower=low; out.upper=high;
         out.first_fvg_time=older.formed_time; out.second_fvg_time=recent.formed_time;
         out.confirmed_at=ICTBarClose(timeframe,recent.formed_time);
         out.invalidation=(out.direction>0 ? low : high); out.state=ICT_BPR_CONFIRMED;
         for(int k=i+1;k<count;k++)
            if((out.direction>0 && rates[k].close<low) || (out.direction<0 && rates[k].close>high))
              { out.invalidated_at=ICTBarClose(timeframe,rates[k].time); out.state=ICT_BPR_INVALIDATED; break; }
         return true;
        }
     }
   return false;
  }
#endif
