#property copyright "MT5 Smart Risk Manager Pro"
#property version "3.60"
#property description "Tester-only, no-order OB/SMT invariant probe"

#include "../Include/ICTConfluenceEngine.mqh"

input string InpSMTSymbol1="";
input string InpSMTSymbol2="";
input ENUM_TIMEFRAMES InpOBTimeframe=PERIOD_M15;
input ENUM_TIMEFRAMES InpSMTTimeframe=PERIOD_H1;

SICTSettings g_settings;
datetime g_last_bar=0;
int g_bars=0,g_ob_candidates=0,g_ob_confirmed=0,g_ob_mitigated=0;
int g_ob_invalidated=0,g_ob_expired=0,g_smt_bull=0,g_smt_bear=0;
int g_smt_missing=0,g_exposure=0,g_failures=0;
int g_smt1_bull=0,g_smt1_bear=0,g_smt2_bull=0,g_smt2_bear=0;
int g_smt1_negative=0,g_smt2_negative=0;

int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER)==0)
     { Print("OBSMTProbeEA refuses non-Tester execution"); return INIT_FAILED; }
   SRMPDefaultICTSettings(g_settings);
   g_settings.comparison1=InpSMTSymbol1;
   g_settings.comparison2=InpSMTSymbol2;
#ifdef OBSMT_FORCE_EMPTY
   g_settings.comparison1="";
   g_settings.comparison2="";
#endif
   g_settings.ob_timeframe=InpOBTimeframe;
   g_settings.smt_timeframe=InpSMTTimeframe;
   if(!SRMPValidICTSettings(g_settings)) return INIT_PARAMETERS_INCORRECT;
   PrintFormat("OBSMT_PROBE START primary=%s comparison1=%s comparison2=%s",
               _Symbol,g_settings.comparison1,g_settings.comparison2);
   return INIT_SUCCEEDED;
  }

void CheckSMT(const SSMTDivergence &signal,const int slot)
  {
   if(signal.state==SRMP_SMT_BULLISH || signal.state==SRMP_SMT_BEARISH)
     {
      if(signal.state==SRMP_SMT_BULLISH) g_smt_bull++;
      else g_smt_bear++;
      if(slot==1)
        {
         if(signal.state==SRMP_SMT_BULLISH) g_smt1_bull++;
         else g_smt1_bear++;
         if(signal.correlation<=-g_settings.correlation_threshold)
            g_smt1_negative++;
        }
      else
        {
         if(signal.state==SRMP_SMT_BULLISH) g_smt2_bull++;
         else g_smt2_bear++;
         if(signal.correlation<=-g_settings.correlation_threshold)
            g_smt2_negative++;
        }
      if(signal.correlation_pairs<60 ||
         signal.confirmation_time<signal.pivot_confirmation_time ||
         signal.primary_prior_time>=signal.primary_pivot_time ||
         signal.primary_prior<=0.0 || signal.primary_recent<=0.0)
        { g_failures++; Print("OBSMT_PROBE FAIL SMT invariant"); }
     }
   else if(signal.state==SRMP_SMT_INVALID_SYMBOL ||
           signal.state==SRMP_SMT_INSUFFICIENT) g_smt_missing++;
  }

void OnTick()
  {
   datetime bar=iTime(_Symbol,InpOBTimeframe,1);
   if(bar<=0 || bar==g_last_bar) return;
   g_last_bar=bar;
   g_bars++;
   SICTSnapshot ict;
   SRMPAnalyzeICT(_Symbol,g_settings,ict);
   if(ict.ob_available)
     {
      if(ict.ob.state==SRMP_OB_CANDIDATE) g_ob_candidates++;
      if(ict.ob.state==SRMP_OB_CONFIRMED) g_ob_confirmed++;
      if(ict.ob.state==SRMP_OB_MITIGATED) g_ob_mitigated++;
      if(ict.ob.state==SRMP_OB_INVALIDATED) g_ob_invalidated++;
      if(ict.ob.state==SRMP_OB_EXPIRED) g_ob_expired++;
      if(ict.ob.lower<=0.0 || ict.ob.upper<=ict.ob.lower ||
         ict.ob.score<0 || ict.ob.score>100 ||
         (ict.ob.state!=SRMP_OB_CANDIDATE &&
          ict.ob.confirmation_time<=ict.ob.formation_time) ||
         ict.ob.state_time<ict.ob.formation_time)
        { g_failures++; Print("OBSMT_PROBE FAIL OB invariant"); }
     }
   CheckSMT(ict.smt1,1);
   CheckSMT(ict.smt2,2);
   if(PositionsTotal()>0 || OrdersTotal()>0) g_exposure++;
  }

double OnTester()
  {
   PrintFormat("OBSMT_PROBE SUMMARY symbol=%s bars=%d candidate=%d confirmed=%d mitigated=%d invalidated=%d expired=%d smt_bull=%d smt_bear=%d smt_missing=%d exposure=%d failures=%d",
      _Symbol,g_bars,g_ob_candidates,g_ob_confirmed,g_ob_mitigated,
      g_ob_invalidated,g_ob_expired,g_smt_bull,g_smt_bear,g_smt_missing,
      g_exposure,g_failures);
   PrintFormat("OBSMT_PROBE SMT_SLOTS slot1=%s bull=%d bear=%d negative=%d slot2=%s bull=%d bear=%d negative=%d",
      g_settings.comparison1,g_smt1_bull,g_smt1_bear,g_smt1_negative,
      g_settings.comparison2,g_smt2_bull,g_smt2_bear,g_smt2_negative);
   return (double)(g_failures+g_exposure);
  }

void OnDeinit(const int reason) {}
