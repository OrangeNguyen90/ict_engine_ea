#ifndef ICT_BAR_SNAPSHOT_MQH
#define ICT_BAR_SNAPSHOT_MQH
#include "MarketStructure.mqh"

// Server-clock calendar boundary. MN1 is not thirty fixed days.
datetime ICTBarClose(const ENUM_TIMEFRAMES tf,const datetime opened)
  {
   if(opened<=0 || tf==PERIOD_CURRENT || PeriodSeconds(tf)<=0) return 0;
   if(tf!=PERIOD_MN1) return opened+PeriodSeconds(tf);
   MqlDateTime d; if(!TimeToStruct(opened,d)) return 0;
   d.day=1; d.hour=0; d.min=0; d.sec=0;
   if(d.mon==12) { d.mon=1; d.year++; } else d.mon++;
   return StructToTime(d);
  }

int ICTClosedPrefix(const MqlRates &bars[],const int count,const ENUM_TIMEFRAMES tf,const datetime asof)
  {
   if(count<0 || count>ArraySize(bars) || tf==PERIOD_CURRENT) return 0;
   int n=0;
   while(n<count)
     {
      datetime closed=ICTBarClose(tf,bars[n].time);
      if(closed<=0 || closed>asof) break;
      n++;
     }
   return n;
  }

// Never forward-fill or include the containing, unfinished higher-TF candle.
bool ICTCopyClosedAsOf(const string symbol,const ENUM_TIMEFRAMES tf,const datetime asof,
                       const int needed,MqlRates &out[])
  {
   ArrayResize(out,0); ArraySetAsSeries(out,false);
   if(symbol=="" || tf==PERIOD_CURRENT || asof<=0 || needed<1 || needed>2000) return false;
   MqlRates raw[]; ArraySetAsSeries(raw,false);
   int copied=CopyRates(symbol,tf,asof-1,needed+2,raw);
   if(copied<needed || !SRMPValidDetectorRates(raw,copied)) return false;
   int count=ICTClosedPrefix(raw,copied,tf,asof);
   if(count<needed) return false;
   ArrayResize(out,needed);
   if(ArrayCopy(out,raw,0,count-needed,needed)!=needed) { ArrayResize(out,0); return false; }
   return true;
  }

double ICTPriorATR(const MqlRates &bars[],const int end,const int period=14)
  {
   if(end<period+1 || end>ArraySize(bars)) return 0;
   double sum=0;
   for(int i=end-period;i<end;i++)
      sum+=MathMax(bars[i].high-bars[i].low,MathMax(MathAbs(bars[i].high-bars[i-1].close),MathAbs(bars[i].low-bars[i-1].close)));
   return sum/period;
  }

int ICTRateIndex(const MqlRates &bars[],const int count,const datetime timestamp)
  {
   int low=0,high=count-1;
   while(low<=high)
     { int middle=(low+high)/2; if(bars[middle].time==timestamp) return middle;
       if(bars[middle].time<timestamp) low=middle+1; else high=middle-1; }
   return -1;
  }

uint ICTStableHash(const string value)
  {
   uint h=2166136261;
   for(int i=0;i<StringLen(value);i++) h=(h^(uint)StringGetCharacter(value,i))*16777619;
   return h;
  }
#endif
