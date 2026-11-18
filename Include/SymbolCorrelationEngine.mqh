#ifndef SRMP_SYMBOL_CORRELATION_ENGINE_MQH
#define SRMP_SYMBOL_CORRELATION_ENGINE_MQH

enum ENUM_SMT_CORRELATION { SMT_AUTO=0, SMT_POSITIVE=1, SMT_NEGATIVE=-1 };
enum ENUM_SMT_CORRELATION_STATE { SMT_CORR_INSUFFICIENT=0,
                                   SMT_CORR_POSITIVE=1, SMT_CORR_NEGATIVE=2,
                                   SMT_CORR_WEAK=3, SMT_CORR_INVALID=4 };

struct SSymbolCorrelation
  {
   ENUM_SMT_CORRELATION_STATE state;
   double coefficient;
   int pairs;
   datetime asof;
  };

// Keep the two strongest absolute correlations; lexical order breaks ties.
void SRMPRankComparison(const string symbol,const double correlation,
                        string &first,double &first_strength,
                        string &second,double &second_strength)
  {
   if(symbol=="" || !MathIsValidNumber(correlation)) return;
   double strength=MathAbs(correlation);
   if(symbol==first || symbol==second) return;
   if(first=="" || strength>first_strength ||
      (strength==first_strength && StringCompare(symbol,first)<0))
     { second=first; second_strength=first_strength; first=symbol; first_strength=strength; }
   else if(second=="" || strength>second_strength ||
           (strength==second_strength && StringCompare(symbol,second)<0))
     { second=symbol; second_strength=strength; }
  }

// Auto flags apply only to empty slots; manual symbols always take precedence.
void SRMPResolveSMTSlots(const string manual1,const string manual2,
                         const bool auto1,const bool auto2,
                         const string first,const string second,
                         string &one,string &two)
  {
   one=manual1; two=manual2;
   if(one=="" && auto1) one=(first!=two ? first : second);
   if(two=="" && auto2) two=(first!=one ? first : second);
   if(one!="" && two==one && manual2=="") two="";
  }

// Join by exact closed-bar timestamps. A return pair is used only if both
// symbols have two consecutive bars with identical timestamps.
bool SRMPCalculateCorrelation(const string primary,const string comparison,
                              const ENUM_TIMEFRAMES timeframe,const int window,
                              const int minimum_pairs,const double threshold,
                              const datetime asof,SSymbolCorrelation &result)
  {
   ZeroMemory(result);
   result.state=SMT_CORR_INSUFFICIENT;
   result.asof=asof;
   int period=PeriodSeconds(timeframe);
   if(window<minimum_pairs || minimum_pairs<60 || threshold<=0.0 ||
      threshold>1.0 || period<=0 || asof<=0)
     { result.state=SMT_CORR_INVALID; return false; }
   int bars=window*3+2;
   MqlRates first[],second[];
   ArraySetAsSeries(first,false);
   ArraySetAsSeries(second,false);
   int a=CopyRates(primary,timeframe,asof-(datetime)(bars*period*3),asof,first);
   int b=CopyRates(comparison,timeframe,asof-(datetime)(bars*period*3),asof,second);
   if(a<minimum_pairs+1 || b<minimum_pairs+1) return false;
   double x[],y[];
   ArrayResize(x,window);
   ArrayResize(y,window);
   int i=a-1,j=b-1,n=0;
   while(i>0 && j>0 && n<window)
     {
      if(first[i].time>second[j].time) { i--; continue; }
      if(first[i].time<second[j].time) { j--; continue; }
      if(first[i-1].time==second[j-1].time &&
         first[i].time-first[i-1].time==period &&
         first[i].close>0.0 && first[i-1].close>0.0 &&
         second[j].close>0.0 && second[j-1].close>0.0)
        {
         x[n]=MathLog(first[i].close/first[i-1].close);
         y[n]=MathLog(second[j].close/second[j-1].close);
         n++;
        }
      i--; j--;
     }
   result.pairs=n;
   if(n<minimum_pairs) return false;
   double sx=0.0,sy=0.0,sxx=0.0,syy=0.0,sxy=0.0;
   for(int k=0;k<n;k++)
     { sx+=x[k]; sy+=y[k]; sxx+=x[k]*x[k];
       syy+=y[k]*y[k]; sxy+=x[k]*y[k]; }
   double vx=n*sxx-sx*sx,vy=n*syy-sy*sy;
   if(vx<=0.0 || vy<=0.0)
     { result.state=SMT_CORR_INVALID; return false; }
   result.coefficient=(n*sxy-sx*sy)/MathSqrt(vx*vy);
   if(!MathIsValidNumber(result.coefficient))
     { result.state=SMT_CORR_INVALID; return false; }
   if(MathAbs(result.coefficient)<threshold) result.state=SMT_CORR_WEAK;
   else result.state=(result.coefficient>0.0 ? SMT_CORR_POSITIVE :
                                               SMT_CORR_NEGATIVE);
   return true;
  }

#endif
