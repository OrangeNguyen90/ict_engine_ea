#ifndef SRMP_MARKET_STRUCTURE_MQH
#define SRMP_MARKET_STRUCTURE_MQH

// Validate only the requested chronological prefix; future suffix is not observed.
bool SRMPValidDetectorBar(const MqlRates &bar)
  {
   return bar.time>0 && MathIsValidNumber(bar.open) && MathIsValidNumber(bar.high) &&
          MathIsValidNumber(bar.low) && MathIsValidNumber(bar.close) &&
          bar.high>=bar.low && bar.open>=bar.low && bar.open<=bar.high &&
          bar.close>=bar.low && bar.close<=bar.high;
  }

bool SRMPValidDetectorRates(const MqlRates &rates[],const int count)
  {
   if(count<1 || count>ArraySize(rates) || ArrayGetAsSeries(rates)) return false;
   for(int i=0;i<count;i++)
      if(!SRMPValidDetectorBar(rates[i]) || (i>0 && rates[i].time<=rates[i-1].time)) return false;
   return true;
  }
struct SMarketStructure
  {
   int      bias;          // +1 HH/HL, -1 LH/LL, 0 unconfirmed
   int      bos_direction; // Break on latest closed candle only
   bool     mss;
   double   recent_high;
   double   prior_high;
   double   recent_low;
   double   prior_low;
   datetime recent_high_time;
   datetime prior_high_time;
   datetime recent_low_time;
   datetime prior_low_time;
   // Confirmation timestamps identify the final right-hand CLOSED bar (open time).
   datetime recent_high_confirmed_time;
   datetime prior_high_confirmed_time;
   datetime recent_low_confirmed_time;
   datetime prior_low_confirmed_time;
   datetime bos_time;
   double   bos_level;
   datetime latest_closed_bar;
  };

bool SRMPConfirmedSwingAt(const MqlRates &rates[],const int count,const int index,
                          const int left,const int right,const bool high)
  {
   if(count>ArraySize(rates) || left<1 || right<1 || index<left || index+right>=count) return false;
   for(int k=1;k<=left;k++)
      if(high ? rates[index].high<=rates[index-k].high : rates[index].low>=rates[index-k].low) return false;
   for(int k=1;k<=right;k++)
      if(high ? rates[index].high<=rates[index+k].high : rates[index].low>=rates[index+k].low) return false;
   return true;
  }

bool SRMPAnalyzeStructureFromRates(const MqlRates &rates[],const int count,
                                    const int left,const int right,SMarketStructure &structure)
  {
   ZeroMemory(structure);
   if(count<30 || !SRMPValidDetectorRates(rates,count) ||
      left<1 || right<1 || count<left+right+10) return false;
   structure.latest_closed_bar=rates[count-1].time;
   int highs=0,lows=0;
   for(int i=left;i<count-right;i++)
     {
      bool is_high=SRMPConfirmedSwingAt(rates,count,i,left,right,true);
      bool is_low=SRMPConfirmedSwingAt(rates,count,i,left,right,false);
      if(is_high)
        {
         structure.prior_high=structure.recent_high;
         structure.prior_high_time=structure.recent_high_time;
         structure.prior_high_confirmed_time=structure.recent_high_confirmed_time;
         structure.recent_high_confirmed_time=rates[i+right].time;
         structure.recent_high=rates[i].high;
         structure.recent_high_time=rates[i].time;
         highs++;
        }
      if(is_low)
        {
         structure.prior_low=structure.recent_low;
         structure.prior_low_time=structure.recent_low_time;
         structure.prior_low_confirmed_time=structure.recent_low_confirmed_time;
         structure.recent_low_confirmed_time=rates[i+right].time;
         structure.recent_low=rates[i].low;
         structure.recent_low_time=rates[i].time;
         lows++;
        }
     }
   if(highs<2 || lows<2 || structure.recent_high<=structure.recent_low)
      return false;
   if(structure.recent_high>structure.prior_high &&
      structure.recent_low>structure.prior_low) structure.bias=1;
   else if(structure.recent_high<structure.prior_high &&
           structure.recent_low<structure.prior_low) structure.bias=-1;
   double close_now=rates[count-1].close;
   double close_before=rates[count-2].close;
   if(close_now>structure.recent_high && close_before<=structure.recent_high)
     { structure.bos_direction=1; structure.bos_time=rates[count-1].time;
       structure.bos_level=structure.recent_high; }
   else if(close_now<structure.recent_low && close_before>=structure.recent_low)
     { structure.bos_direction=-1; structure.bos_time=rates[count-1].time;
       structure.bos_level=structure.recent_low; }
   structure.mss=(structure.bias!=0 && structure.bos_direction!=0 &&
                  structure.bos_direction!=structure.bias);
   return true;
  }

bool SRMPAnalyzeStructureAsymmetric(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                    const int lookback,const int left,const int right,
                                    SMarketStructure &structure)
  {
   ZeroMemory(structure);
   if(lookback<30 || left<1 || right<1 || lookback<left+right+10) return false;
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int count=CopyRates(symbol,timeframe,1,lookback,rates);
   if(count<lookback) return false;
   return SRMPAnalyzeStructureFromRates(rates,count,left,right,structure);
  }
bool SRMPAnalyzeStructure(const string symbol,const ENUM_TIMEFRAMES timeframe,
                          const int lookback,const int swing_strength,
                          SMarketStructure &structure)
  {
   return SRMPAnalyzeStructureAsymmetric(symbol,timeframe,lookback,
                                         swing_strength,swing_strength,structure);
  }

#endif


