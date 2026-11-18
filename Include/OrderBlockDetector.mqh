#ifndef SRMP_ORDER_BLOCK_DETECTOR_MQH
#define SRMP_ORDER_BLOCK_DETECTOR_MQH
#include "MarketStructure.mqh"

enum ENUM_SRMP_OB_BOUNDS { SRMP_OB_FULL=0, SRMP_OB_BODY=1, SRMP_OB_HYBRID=2 };
enum ENUM_SRMP_OB_STATE { SRMP_OB_NONE=0, SRMP_OB_CANDIDATE=1,
                          SRMP_OB_CONFIRMED=2, SRMP_OB_MITIGATED=3,
                          SRMP_OB_INVALIDATED=4, SRMP_OB_EXPIRED=5 };
enum ENUM_SRMP_OB_MITIGATION { SRMP_OB_TOUCH=0, SRMP_OB_MIDPOINT=1,
                               SRMP_OB_FULL_FILL=2 };
enum ENUM_SRMP_OB_INVALIDATION { SRMP_OB_CLOSE=0, SRMP_OB_WICK=1 };

struct SOrderBlock
  {
   int direction;
   ENUM_SRMP_OB_STATE state;
   datetime formation_time;
   datetime confirmation_time;
   datetime state_time;
   double upper;
   double lower;
   double midpoint;
   bool displacement;
   bool break_confirmed;
   bool liquidity_sweep;
   bool fvg;
   bool pd_match;
   bool session_match;
   int score;
  };

string SRMPOBStateText(const ENUM_SRMP_OB_STATE state)
  {
   if(state==SRMP_OB_CANDIDATE) return "CANDIDATE";
   if(state==SRMP_OB_CONFIRMED) return "CONFIRMED";
   if(state==SRMP_OB_MITIGATED) return "MITIGATED";
   if(state==SRMP_OB_INVALIDATED) return "INVALIDATED";
   if(state==SRMP_OB_EXPIRED) return "EXPIRED";
   return "NONE";
  }

// Shared chronological lifecycle, also callable by deterministic prefix tests.
void SRMPValidateOrderBlockFromRates(const MqlRates &rates[],const int count,
                                    const ENUM_SRMP_OB_MITIGATION mitigation,
                                    const ENUM_SRMP_OB_INVALIDATION invalidation,
                                    const int expiry_bars,SOrderBlock &block)
  {
   if(block.state!=SRMP_OB_CONFIRMED || expiry_bars<1) return;
   if(count>0 && !SRMPValidDetectorRates(rates,count))
     { block.state=SRMP_OB_NONE; return; }
   int age=0;
   for(int i=0;i<count;i++)
     {
      MqlRates bar=rates[i];
      if(bar.time<=block.confirmation_time) continue;
      age++;
      bool invalid=(block.direction>0 ?
         (invalidation==SRMP_OB_WICK ? bar.low<block.lower : bar.close<block.lower) :
         (invalidation==SRMP_OB_WICK ? bar.high>block.upper : bar.close>block.upper));
      if(invalid) { block.state=SRMP_OB_INVALIDATED; block.state_time=bar.time; return; }
      bool touched=bar.low<=block.upper && bar.high>=block.lower;
      bool filled=(mitigation==SRMP_OB_TOUCH ? touched :
         (block.direction>0 ? bar.low<=(mitigation==SRMP_OB_MIDPOINT ? block.midpoint : block.lower) :
                             bar.high>=(mitigation==SRMP_OB_MIDPOINT ? block.midpoint : block.upper)));
      if(filled && block.state==SRMP_OB_CONFIRMED)
        { block.state=SRMP_OB_MITIGATED; block.state_time=bar.time; }
      if(age>=expiry_bars) { block.state=SRMP_OB_EXPIRED; block.state_time=bar.time; return; }
     }
  }

// Only completed candles are copied. A candidate is promoted after a closed
// displacement candle breaks a high/low that preceded the candidate.
bool SRMPFindOrderBlockFromRates(const MqlRates &rates[],const int count,
                         const ENUM_SRMP_OB_BOUNDS bounds,
                         const double min_displacement_factor,
                         const int max_confirmation_bars,
                         SOrderBlock &block,const int desired_direction=0,
                         const bool active_only=false,const int expiry_bars=48)
  {
   ZeroMemory(block);
   if(count<40 || min_displacement_factor<=0.0 ||
      max_confirmation_bars<1 || max_confirmation_bars>6 ||
      desired_direction<-1 || desired_direction>1 || expiry_bars<1) return false;
   if(!SRMPValidDetectorRates(rates,count)) return false;
   bool has_candidate=false;
   // The newest copied bar is closed too; it can already be a candidate.
   for(int i=count-1;i>=15;i--)
     {
      int direction=0;
      if(rates[i].close<rates[i].open) direction=1;
      else if(rates[i].close>rates[i].open) direction=-1;
      if(direction==0) continue;
      if(desired_direction!=0 && direction!=desired_direction) continue;
      double prior_high=rates[i-1].high,prior_low=rates[i-1].low;
      double avg_range=0.0;
      for(int k=i-10;k<i;k++)
        {
         prior_high=MathMax(prior_high,rates[k].high);
         prior_low=MathMin(prior_low,rates[k].low);
         avg_range+=rates[k].high-rates[k].low;
        }
      avg_range/=10.0;
      if(avg_range<=0.0) continue;
      if(!has_candidate && i>=count-1-max_confirmation_bars)
        {
         block.direction=direction;
         block.state=SRMP_OB_CANDIDATE;
         block.formation_time=rates[i].time;
         block.state_time=rates[i].time;
         double body_upper=MathMax(rates[i].open,rates[i].close);
         double body_lower=MathMin(rates[i].open,rates[i].close);
         block.upper=(bounds==SRMP_OB_BODY ? body_upper : rates[i].high);
         block.lower=(bounds==SRMP_OB_BODY ? body_lower : rates[i].low);
         if(bounds==SRMP_OB_HYBRID)
           {
            block.upper=(direction>0 ? body_upper : rates[i].high);
            block.lower=(direction>0 ? rates[i].low : body_lower);
           }
         block.midpoint=(block.upper+block.lower)/2.0;
         block.liquidity_sweep=(direction>0 ? rates[i].low<prior_low :
                                             rates[i].high>prior_high);
         has_candidate=true;
        }
      for(int j=i+1;j<=MathMin(count-1,i+max_confirmation_bars);j++)
        {
         double body=MathAbs(rates[j].close-rates[j].open);
         bool directional=(direction>0 ? rates[j].close>rates[j].open :
                                        rates[j].close<rates[j].open);
         bool displacement=directional &&
                           body>=avg_range*min_displacement_factor;
         bool broken=(direction>0 ? rates[j].close>prior_high :
                                      rates[j].close<prior_low);
         if(!displacement || !broken) continue;
         block.direction=direction;
         block.formation_time=rates[i].time;
         block.confirmation_time=rates[j].time;
         block.state_time=rates[j].time;
         block.state=SRMP_OB_CONFIRMED;
         double body_upper=MathMax(rates[i].open,rates[i].close);
         double body_lower=MathMin(rates[i].open,rates[i].close);
         block.upper=(bounds==SRMP_OB_BODY ? body_upper : rates[i].high);
         block.lower=(bounds==SRMP_OB_BODY ? body_lower : rates[i].low);
         if(bounds==SRMP_OB_HYBRID)
           {
            block.upper=(direction>0 ? body_upper : rates[i].high);
            block.lower=(direction>0 ? rates[i].low : body_lower);
           }
         block.midpoint=(block.upper+block.lower)/2.0;
         block.displacement=true;
         block.break_confirmed=true;
         block.liquidity_sweep=(direction>0 ? rates[i].low<prior_low :
                                             rates[i].high>prior_high);
         for(int f=i+2;f<=j;f++)
           {
            if(direction>0 && rates[f].low>rates[f-2].high)
               block.fvg=true;
            if(direction<0 && rates[f].high<rates[f-2].low)
               block.fvg=true;
           }
         double equilibrium=(prior_high+prior_low)/2.0;
         block.pd_match=(direction>0 ? block.midpoint<=equilibrium :
                                       block.midpoint>=equilibrium);
         MqlDateTime tm;
         TimeToStruct(block.formation_time,tm);
         block.session_match=(tm.hour>=7 && tm.hour<21); // Broker server time.
         if(active_only)
           {
            SRMPValidateOrderBlockFromRates(rates,count,SRMP_OB_TOUCH,SRMP_OB_CLOSE,expiry_bars,block);
            if(block.state!=SRMP_OB_CONFIRMED) break;
           }
         return true;
        }
     }
   if(active_only) { ZeroMemory(block); return false; }
   return has_candidate;
  }

bool SRMPFindOrderBlock(const string symbol,const ENUM_TIMEFRAMES timeframe,
                         const int lookback,const ENUM_SRMP_OB_BOUNDS bounds,
                         const double min_displacement_factor,const int max_confirmation_bars,
                         SOrderBlock &block,const int desired_direction=0,
                         const bool active_only=false,const int expiry_bars=48)
  {
   ZeroMemory(block);
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   if(lookback<40 || CopyRates(symbol,timeframe,1,lookback,rates)!=lookback) return false;
   return SRMPFindOrderBlockFromRates(rates,lookback,bounds,min_displacement_factor,
                  max_confirmation_bars,block,desired_direction,active_only,expiry_bars);
  }
#endif
