#ifndef ICT_REJECTION_BREAKER_DETECTOR_MQH
#define ICT_REJECTION_BREAKER_DETECTOR_MQH

#include "OrderBlockDetector.mqh"

enum ENUM_ICT_CHART_BLOCK_STATE
  {
   ICT_CHART_BLOCK_ACTIVE=0,
   ICT_CHART_BLOCK_RETESTED=1,
   ICT_CHART_BLOCK_INVALIDATED=2
  };

struct SICTChartBlockSignal
  {
   int direction;
   datetime formed_at;
   datetime confirmed_at;
   datetime sweep_at;
   double lower;
   double upper;
   double mean;
   bool swept;
   bool displacement;
   bool mss;
   ENUM_ICT_CHART_BLOCK_STATE state;
  };

string ICTChartBlockStateText(const ENUM_ICT_CHART_BLOCK_STATE state)
  {
   if(state==ICT_CHART_BLOCK_RETESTED) return "RETESTED";
   if(state==ICT_CHART_BLOCK_INVALIDATED) return "INVALIDATED";
   return "ACTIVE";
  }

double ICTChartAverageRange(const MqlRates &rates[],const int first,const int last)
  {
   if(first<0 || last<first) return 0.0;
   double total=0.0;
   for(int i=first;i<=last;i++) total+=rates[i].high-rates[i].low;
   return total/(last-first+1);
  }

bool ICTChartDisplacement(const MqlRates &rates[],const int index,const int direction,
                          const double min_body_ratio,const double min_range_average)
  {
   if(index<10 || index>=ArraySize(rates)) return false;
   double range=rates[index].high-rates[index].low;
   double body=MathAbs(rates[index].close-rates[index].open);
   double average=ICTChartAverageRange(rates,index-10,index-1);
   return range>0.0 && average>0.0 &&
      (direction>0 ? rates[index].close>rates[index].open : rates[index].close<rates[index].open) &&
      body/range>=min_body_ratio && range/average>=min_range_average;
  }

void ICTChartUpdateBlockState(const MqlRates &rates[],const int count,const int from,
                              SICTChartBlockSignal &signal)
  {
   signal.state=ICT_CHART_BLOCK_ACTIVE;
   for(int i=from;i<count;i++)
     {
      bool invalid=(signal.direction>0 ? rates[i].close<signal.lower : rates[i].close>signal.upper);
      if(invalid) { signal.state=ICT_CHART_BLOCK_INVALIDATED; return; }
      if(rates[i].low<=signal.upper && rates[i].high>=signal.lower)
         signal.state=ICT_CHART_BLOCK_RETESTED;
     }
  }

// Rejection is confirmed only after a closed displacement candle breaks a
// previously established local swing level. Pivot confirmation uses closed bars.
bool ICTFindRejectionBlockFromRates(const MqlRates &rates[],const int count,
                                    const double min_wick_range_ratio,
                                    const double min_body_ratio,const double min_range_average,
                                    const int confirm_bars,const int timeframe_seconds,
                                    SICTChartBlockSignal &signal)
  {
   ZeroMemory(signal);
   if(count<40 || min_wick_range_ratio<=0.0 || min_wick_range_ratio>=1.0 ||
      min_body_ratio<=0.0 || min_body_ratio>1.0 || min_range_average<=0.0 ||
      confirm_bars<1 || confirm_bars>10 || timeframe_seconds<=0 ||
      !SRMPValidDetectorRates(rates,count)) return false;
   for(int i=count-3;i>=12;i--)
     {
      double range=rates[i].high-rates[i].low;
      if(range<=0.0) continue;
      bool swing_low=true,swing_high=true;
      for(int k=1;k<=2;k++)
        {
         if(rates[i].low>rates[i-k].low || rates[i].low>rates[i+k].low) swing_low=false;
         if(rates[i].high<rates[i-k].high || rates[i].high<rates[i+k].high) swing_high=false;
        }
      double body_high=MathMax(rates[i].open,rates[i].close);
      double body_low=MathMin(rates[i].open,rates[i].close);
      double prior_high=rates[i-10].high,prior_low=rates[i-10].low;
      for(int k=i-9;k<i;k++)
        { prior_high=MathMax(prior_high,rates[k].high); prior_low=MathMin(prior_low,rates[k].low); }
      int pivot_confirmation=i+2;
      for(int j=pivot_confirmation+1;j<=MathMin(count-1,pivot_confirmation+confirm_bars);j++)
        {
         if(swing_low && (body_low-rates[i].low)/range>=min_wick_range_ratio &&
            ICTChartDisplacement(rates,j,1,min_body_ratio,min_range_average) && rates[j].close>prior_high)
           {
            signal.direction=1; signal.formed_at=rates[i].time;
            signal.confirmed_at=rates[j].time+timeframe_seconds;
            signal.lower=rates[i].low; signal.upper=body_low; signal.mean=(signal.lower+signal.upper)*0.5;
            signal.swept=rates[i].low<prior_low; signal.sweep_at=(signal.swept ? rates[i].time : 0);
            signal.displacement=true; signal.mss=true;
            ICTChartUpdateBlockState(rates,count,j+1,signal);
            return true;
           }
         double upper_wick=rates[i].high-body_high;
         if(swing_high && upper_wick/range>=min_wick_range_ratio &&
            ICTChartDisplacement(rates,j,-1,min_body_ratio,min_range_average) && rates[j].close<prior_low)
           {
            signal.direction=-1; signal.formed_at=rates[i].time;
            signal.confirmed_at=rates[j].time+timeframe_seconds;
            signal.lower=body_high; signal.upper=rates[i].high; signal.mean=(signal.lower+signal.upper)*0.5;
            signal.swept=rates[i].high>prior_high; signal.sweep_at=(signal.swept ? rates[i].time : 0);
            signal.displacement=true; signal.mss=true;
            ICTChartUpdateBlockState(rates,count,j+1,signal);
            return true;
           }
        }
     }
   return false;
  }

// An invalidated opposite OB is not sufficient: the later sequence must also
// include a liquidity sweep and a directional displacement/MSS.
bool ICTFindBreakerBlockFromRates(const MqlRates &rates[],const int count,
                                  const ENUM_SRMP_OB_BOUNDS bounds,
                                  const double ob_displacement_factor,
                                  const double min_body_ratio,const double min_range_average,
                                  const int confirm_bars,const int timeframe_seconds,
                                  SICTChartBlockSignal &signal)
  {
   ZeroMemory(signal);
   if(count<40 || timeframe_seconds<=0 || confirm_bars<1 || confirm_bars>10 ||
      !SRMPValidDetectorRates(rates,count)) return false;
   for(int direction=1;direction>=-1;direction-=2)
     {
      SOrderBlock original;
      if(!SRMPFindOrderBlockFromRates(rates,count,bounds,ob_displacement_factor,6,
                                      original,-direction,false,1000) ||
         original.state!=SRMP_OB_CONFIRMED) continue;
      int source=-1;
      for(int i=0;i<count;i++) if(rates[i].time==original.confirmation_time) { source=i; break; }
      if(source<0) continue;
      int failed=-1;
      for(int i=source+1;i<count;i++)
        {
         bool broke=(direction>0 ? rates[i].close>original.upper : rates[i].close<original.lower);
         if(broke) { failed=i; break; }
        }
      if(failed<0) continue;
      for(int j=failed+1;j<count;j++)
        {
         if(!ICTChartDisplacement(rates,j,direction,min_body_ratio,min_range_average)) continue;
         double prior_high=rates[j-10].high,prior_low=rates[j-10].low;
         for(int k=j-9;k<j;k++)
           { prior_high=MathMax(prior_high,rates[k].high); prior_low=MathMin(prior_low,rates[k].low); }
         bool mss=(direction>0 ? rates[j].close>prior_high : rates[j].close<prior_low);
         if(!mss) continue;
         bool swept=false; datetime sweep_time=0;
         for(int k=failed+1;k<=j;k++)
           {
            if(k<10) continue;
            double pool=(direction>0 ? rates[k-10].low : rates[k-10].high);
            for(int n=k-9;n<k;n++) pool=(direction>0 ? MathMin(pool,rates[n].low) : MathMax(pool,rates[n].high));
            if(direction>0 ? rates[k].low<pool : rates[k].high>pool)
              { swept=true; sweep_time=rates[k].time; break; }
           }
         if(!swept) continue;
         signal.direction=direction; signal.formed_at=original.formation_time;
         signal.confirmed_at=rates[j].time+timeframe_seconds; signal.sweep_at=sweep_time;
         signal.lower=original.lower; signal.upper=original.upper;
         signal.mean=(signal.lower+signal.upper)*0.5; signal.swept=true;
         signal.displacement=true; signal.mss=true;
         ICTChartUpdateBlockState(rates,count,j+1,signal);
         return true;
        }
     }
   return false;
  }

#endif