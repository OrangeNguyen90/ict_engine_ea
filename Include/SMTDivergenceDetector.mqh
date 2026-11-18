#ifndef SRMP_SMT_DIVERGENCE_DETECTOR_MQH
#define SRMP_SMT_DIVERGENCE_DETECTOR_MQH

#include "MarketStructure.mqh"
#include "SMTSignalValidator.mqh"
#include "ICTBarSnapshot.mqh"

struct SSMTDivergence
  {
   ENUM_SRMP_SMT_STATE state;
   string comparison;
   int direction;
   double correlation;
   int correlation_pairs;
   datetime primary_pivot_time;
   datetime primary_prior_time;
   datetime comparison_pivot_time;
   datetime pivot_confirmation_time;
   datetime confirmation_time;
   double primary_prior;
   double primary_recent;
   // Extended metadata used by the unified chronological replay; legacy API stays intact.
   ENUM_TIMEFRAMES timeframe;
   int relation;
   bool comparator_extreme;
   datetime comparison_prior_time;
   double comparison_prior,comparison_recent;
   string event_id;
  };

bool SRMPAlignedCorrelationFromRates(const MqlRates &a[],const int an,const MqlRates &b[],const int bn,
                                     const int window,const int skip,double &value,int &pairs)
  {
   value=0; pairs=0;
   if(window<2 || skip<0 || an<2 || bn<2 || an>ArraySize(a) || bn>ArraySize(b)) return false;
   double sx=0,sy=0,sxx=0,syy=0,sxy=0;
   int i=an-1,j=bn-1,ignored=0;
   while(i>0 && j>0 && pairs<window)
     {
      if(a[i].time>b[j].time) { i--; continue; }
      if(a[i].time<b[j].time) { j--; continue; }
      if(a[i-1].time==b[j-1].time && a[i].close>0 && a[i-1].close>0 && b[j].close>0 && b[j-1].close>0)
        {
         if(ignored<skip) ignored++;
         else
           {
            double x=MathLog(a[i].close/a[i-1].close),y=MathLog(b[j].close/b[j-1].close);
            sx+=x; sy+=y; sxx+=x*x; syy+=y*y; sxy+=x*y; pairs++;
           }
        }
      i--; j--;
     }
   double vx=pairs*sxx-sx*sx,vy=pairs*syy-sy*sy;
   if(pairs<window || vx<=0 || vy<=0) return false;
   value=(pairs*sxy-sx*sy)/MathSqrt(vx*vy);
   return MathIsValidNumber(value) && MathAbs(value)<=1.000001;
  }

// Match confirmed comparator pivots in the same order, within actual primary
// bar indices. Missing bar timestamps are not filled with manufactured OHLC.
bool SRMPFindSMTPairFromRates(const string primary,const string comparison,const ENUM_TIMEFRAMES tf,
                              const MqlRates &a[],const int an,const MqlRates &b[],const int bn,
                              const int left,const int right,const int gap,const int relation,
                              const double primary_tolerance,const double comparison_tolerance,
                              const int direction,SSMTDivergence &s)
  {
   ZeroMemory(s); s.comparison=comparison; s.state=SRMP_SMT_INSUFFICIENT;
   if(primary=="" || comparison=="" || primary==comparison || an<30 || bn<30 ||
      !SRMPValidDetectorRates(a,an) || !SRMPValidDetectorRates(b,bn) ||
      a[an-1].time!=b[bn-1].time || (relation!=1 && relation!=-1) ||
      (direction!=1 && direction!=-1) || left<1 || right<1 || gap<0 ||
      !MathIsValidNumber(primary_tolerance) || primary_tolerance<0 ||
      !MathIsValidNumber(comparison_tolerance) || comparison_tolerance<0) return false;
   int recent=-1,prior=-1;
   bool high=direction<0;
   for(int i=an-right-1;i>=left;i--)
      if(SRMPConfirmedSwingAt(a,an,i,left,right,high))
        { if(recent<0) recent=i; else { prior=i; break; } }
   if(prior<0) { s.state=SRMP_SMT_UNCONFIRMED; return false; }
   int matched_recent=-1,matched_prior=-1,best_recent=2147483647,best_prior=2147483647;
   bool other_high=(relation>0 ? high : !high);
   for(int j=left;j<bn-right;j++)
     {
      if(!SRMPConfirmedSwingAt(b,bn,j,left,right,other_high)) continue;
      int primary_index=ICTRateIndex(a,an,b[j].time);
      if(primary_index<0) continue;
      int distance=(int)MathAbs(primary_index-recent);
      if(distance<=gap && distance<best_recent) { matched_recent=j; best_recent=distance; }
     }
   if(matched_recent<0) return false;
   for(int j=left;j<matched_recent;j++)
     {
      if(!SRMPConfirmedSwingAt(b,bn,j,left,right,other_high)) continue;
      int primary_index=ICTRateIndex(a,an,b[j].time);
      if(primary_index<0) continue;
      int distance=(int)MathAbs(primary_index-prior);
      if(distance<=gap && distance<best_prior) { matched_prior=j; best_prior=distance; }
     }
   if(matched_prior<0) return false;
   // Require exact observed bars throughout the paired interval, not identical
   // pivot timestamps. This conservatively rejects mismatched sessions.
   int start=(int)MathMax(0,MathMin(prior,recent)-gap);
   for(int k=start;k<an;k++)
     {
      if(ICTRateIndex(b,bn,a[k].time)<0) return false;
     }
   double p1=(high ? a[prior].high : a[prior].low),p2=(high ? a[recent].high : a[recent].low);
   double o1=(other_high ? b[matched_prior].high : b[matched_prior].low);
   double o2=(other_high ? b[matched_recent].high : b[matched_recent].low);
   bool primary_break=(p2-p1)*(-direction)>primary_tolerance;
   bool comparison_break=(o2-o1)*relation*(-direction)>comparison_tolerance;
   if(primary_break==comparison_break) { s.state=SRMP_SMT_UNCONFIRMED; return false; }
   s.direction=direction; s.timeframe=tf; s.relation=relation;
   s.primary_prior_time=a[prior].time; s.primary_pivot_time=a[recent].time;
   s.primary_prior=p1; s.primary_recent=p2; s.comparison_prior_time=b[matched_prior].time;
   s.comparison_pivot_time=b[matched_recent].time; s.comparison_prior=o1; s.comparison_recent=o2;
   s.comparator_extreme=comparison_break;
   s.pivot_confirmation_time=(datetime)MathMax(ICTBarClose(tf,a[recent+right].time),ICTBarClose(tf,b[matched_recent+right].time));
   s.confirmation_time=ICTBarClose(tf,a[an-1].time);
   s.event_id=primary+"|"+comparison+"|"+IntegerToString((int)tf)+"|"+IntegerToString(direction)+"|"+
      IntegerToString(relation)+"|"+IntegerToString((long)a[prior].time)+"|"+IntegerToString((long)a[recent].time)+"|"+
      IntegerToString((long)b[matched_prior].time)+"|"+IntegerToString((long)b[matched_recent].time);
   s.state=(direction>0 ? SRMP_SMT_BULLISH : SRMP_SMT_BEARISH);
   return s.pivot_confirmation_time>0 && s.pivot_confirmation_time<=s.confirmation_time;
  }

datetime SRMPSMTPivotConfirmation(const string symbol,
                                   const ENUM_TIMEFRAMES timeframe,
                                   const datetime pivot,const int right)
  {
   int shift=iBarShift(symbol,timeframe,pivot,true);
   if(shift<=right || right<1) return 0;
   return iTime(symbol,timeframe,shift-right)+(datetime)PeriodSeconds(timeframe);
  }

bool SRMPFindSMT(const string primary,const string comparison,
                 const ENUM_TIMEFRAMES timeframe,const int lookback,
                 const int left,const int right,
                 const ENUM_SMT_CORRELATION correlation_mode,
                 const int correlation_window,const int min_pairs,
                 const double min_abs_correlation,const int max_gap_bars,
                 SSMTDivergence &signal)
  {
   ZeroMemory(signal);
   signal.state=SRMP_SMT_NOT_CONFIGURED;
   signal.comparison=comparison;
   if(comparison=="") return false;
   if(!SRMPValidateComparisonSymbol(primary,comparison))
     { signal.state=SRMP_SMT_INVALID_SYMBOL; return false; }
   if(lookback<30 || left<1 || right<1 ||
      max_gap_bars<0 || correlation_window<min_pairs || min_pairs<60)
     { signal.state=SRMP_SMT_INSUFFICIENT; return false; }
   datetime asof=iTime(primary,timeframe,1);
   if(asof<=0) { signal.state=SRMP_SMT_INSUFFICIENT; return false; }
   if(iTime(comparison,timeframe,1)!=asof)
     { signal.state=SRMP_SMT_INSUFFICIENT; return false; }
   SSymbolCorrelation corr;
   if(!SRMPCalculateCorrelation(primary,comparison,timeframe,
                                correlation_window,min_pairs,
                                min_abs_correlation,asof,corr))
     { signal.state=SRMP_SMT_INSUFFICIENT; return false; }
   signal.correlation=corr.coefficient;
   signal.correlation_pairs=corr.pairs;
   int regime=(correlation_mode==SMT_AUTO ?
               (corr.state==SMT_CORR_POSITIVE ? 1 :
                (corr.state==SMT_CORR_NEGATIVE ? -1 : 0)) :
               (int)correlation_mode);
   // Manual polarity is an expectation, never permission to bypass measured
   // correlation quality or to use a regime contradicted by current data.
   if(regime==0 || corr.state==SMT_CORR_WEAK ||
      corr.coefficient*regime<min_abs_correlation)
     { signal.state=SRMP_SMT_WEAK; return false; }
   SMarketStructure main_structure,other_structure;
   if(!SRMPAnalyzeStructureAsymmetric(primary,timeframe,lookback,left,right,
                                      main_structure) ||
      !SRMPAnalyzeStructureAsymmetric(comparison,timeframe,lookback,left,right,
                                      other_structure))
     { signal.state=SRMP_SMT_INSUFFICIENT; return false; }
   int period=PeriodSeconds(timeframe);
   if(period<=0) { signal.state=SRMP_SMT_INSUFFICIENT; return false; }
   bool bull_main=main_structure.recent_low<main_structure.prior_low;
   bool bear_main=main_structure.recent_high>main_structure.prior_high;
   bool bull_other=(regime>0 ? other_structure.recent_low>=other_structure.prior_low :
                              other_structure.recent_high<=other_structure.prior_high);
   bool bear_other=(regime>0 ? other_structure.recent_high<=other_structure.prior_high :
                              other_structure.recent_low>=other_structure.prior_low);
   datetime mt=0,ot=0,mp=0,op=0;
   int direction=0;
   if(bull_main && bull_other)
     {
      direction=1; mt=main_structure.recent_low_time;
      ot=(regime>0 ? other_structure.recent_low_time :
                     other_structure.recent_high_time);
      mp=main_structure.prior_low_time;
      op=(regime>0 ? other_structure.prior_low_time :
                     other_structure.prior_high_time);
      signal.primary_prior=main_structure.prior_low;
      signal.primary_recent=main_structure.recent_low;
     }
   else if(bear_main && bear_other)
     {
      direction=-1; mt=main_structure.recent_high_time;
      ot=(regime>0 ? other_structure.recent_high_time :
                     other_structure.recent_low_time);
      mp=main_structure.prior_high_time;
      op=(regime>0 ? other_structure.prior_high_time :
                     other_structure.prior_low_time);
      signal.primary_prior=main_structure.prior_high;
      signal.primary_recent=main_structure.recent_high;
     }
   else
     {
      bool other_low_break=(regime>0 ?
             other_structure.recent_low<other_structure.prior_low :
             other_structure.recent_high>other_structure.prior_high);
      bool other_high_break=(regime>0 ?
             other_structure.recent_high>other_structure.prior_high :
             other_structure.recent_low<other_structure.prior_low);
      signal.state=((other_low_break && !bull_main) ||
                    (other_high_break && !bear_main) ?
                    SRMP_SMT_COMP_ONLY : SRMP_SMT_UNCONFIRMED);
      return false;
     }
   if(mt<=0 || ot<=0 || mp<=0 || op<=0 ||
      MathAbs((double)(mt-ot))>max_gap_bars*period ||
      MathAbs((double)(mp-op))>max_gap_bars*period)
     { signal.state=SRMP_SMT_INSUFFICIENT; return false; }
   datetime mc=SRMPSMTPivotConfirmation(primary,timeframe,mt,right);
   datetime oc=SRMPSMTPivotConfirmation(comparison,timeframe,ot,right);
   if(mc<=0 || oc<=0)
     { signal.state=SRMP_SMT_UNCONFIRMED; return false; }
   signal.direction=direction;
   signal.primary_pivot_time=mt;
   signal.primary_prior_time=mp;
   signal.comparison_pivot_time=ot;
   signal.pivot_confirmation_time=MathMax(mc,oc);
   // Correlation is computed at 'asof', so the combined SMT signal is first
   // confirmed now, never backdated to the earlier pivot confirmation.
   signal.confirmation_time=asof+(datetime)period;
   signal.state=(direction>0 ? SRMP_SMT_BULLISH : SRMP_SMT_BEARISH);
   return true;
  }

#endif
