#ifndef SRMP_SMT_CHART_RENDERER_MQH
#define SRMP_SMT_CHART_RENDERER_MQH

#include "DashboardComponents.mqh"
#include "SMTDivergenceDetector.mqh"

void SRMPClearSMTObjects(const string prefix)
  {
   ObjectDelete(0,prefix+"line");
   ObjectDelete(0,prefix+"label");
  }

// Display only confirmed primary-symbol pivot divergences available by now.
bool SRMPSMTDisplayValid(const SSMTDivergence &s,const datetime now)
  {
   if(now<=0 || s.comparison=="" || s.correlation_pairs<60 ||
      !MathIsValidNumber(s.correlation) || MathAbs(s.correlation)>1.000001 ||
      s.primary_prior_time<=0 || s.primary_pivot_time<=s.primary_prior_time ||
      s.pivot_confirmation_time<=s.primary_pivot_time ||
      s.confirmation_time<s.pivot_confirmation_time || s.confirmation_time>now ||
      !MathIsValidNumber(s.primary_prior) || !MathIsValidNumber(s.primary_recent) ||
      s.primary_prior<=0.0 || s.primary_recent<=0.0) return false;
   return (s.state==SRMP_SMT_BULLISH && s.direction==1 && s.primary_recent<s.primary_prior) ||
          (s.state==SRMP_SMT_BEARISH && s.direction==-1 && s.primary_recent>s.primary_prior);
  }

// Only the primary symbol's two pivot prices are placed on its price axis.
void SRMPRenderSMT(const string prefix,const SSMTDivergence &signal,
                    const ENUM_TIMEFRAMES timeframe)
  {
   if(!SRMPSMTDisplayValid(signal,TimeTradeServer()))
     { SRMPClearSMTObjects(prefix); return; }
   int prior_shift=iBarShift(_Symbol,timeframe,signal.primary_prior_time,true);
   int recent_shift=iBarShift(_Symbol,timeframe,signal.primary_pivot_time,true);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(prior_shift<=0 || recent_shift<=0 || tick<=0)
     { SRMPClearSMTObjects(prefix); return; }
   double prior=(signal.direction>0 ? iLow(_Symbol,timeframe,prior_shift) : iHigh(_Symbol,timeframe,prior_shift));
   double recent=(signal.direction>0 ? iLow(_Symbol,timeframe,recent_shift) : iHigh(_Symbol,timeframe,recent_shift));
   if(prior<=0 || recent<=0 || MathAbs(prior-signal.primary_prior)>tick*0.5 ||
      MathAbs(recent-signal.primary_recent)>tick*0.5)
     { SRMPClearSMTObjects(prefix); return; }
   string name=prefix+"line";
   if(ObjectFind(0,name)<0 &&
      !ObjectCreate(0,name,OBJ_TREND,0,signal.primary_prior_time,
                    signal.primary_prior,signal.primary_pivot_time,
                    signal.primary_recent)) return;
   ObjectMove(0,name,0,signal.primary_prior_time,signal.primary_prior);
   ObjectMove(0,name,1,signal.primary_pivot_time,signal.primary_recent);
   color ink=(signal.direction>0 ? C'30,137,83' : C'190,60,66');
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   bool second=(StringFind(prefix,"smt2_")>=0 || StringFind(prefix,"sm2_")>=0);
   ObjectSetInteger(0,name,OBJPROP_STYLE,second ? STYLE_DASH : STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   double label_price=signal.primary_recent+(signal.direction>0 ? -1 : 1)*tick*(second ? 30 : 12);
   RMContextMarker(prefix+"label",signal.primary_pivot_time,label_price,
                   StringFormat("SMT%d %s %s %s rho %.2f confirmed %s",
                                second ? 2 : 1,signal.direction>0 ? "BULL" : "BEAR",
                                signal.comparison,EnumToString(timeframe),
                                signal.correlation,
                                TimeToString(signal.confirmation_time,
                                             TIME_DATE|TIME_MINUTES)),ink);
  }

#endif
