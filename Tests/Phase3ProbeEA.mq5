#property copyright "MT5 Smart Risk Manager Pro"
#property version "3.10"
#property description "Strategy Tester-only, read-only Phase 3 probe. No order calls."

#include "../Include/TradeAdvisor.mqh"
#include "../Include/MarketContext.mqh"

input ENUM_TIMEFRAMES Context_Timeframe=PERIOD_H4;
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H1;
input ENUM_TIMEFRAMES Setup_Timeframe=PERIOD_M15;
input ENUM_TIMEFRAMES Trigger_Timeframe=PERIOD_M5;
input double Probe_Reference_Capital=10000.0;
input double Probe_Max_Spread_Points=50.0;

datetime g_last_bar=0;
int g_reason_counts[21];
int g_status_counts[3];
int g_bars=0,g_context_ready=0,g_revision=0,g_orders_seen=0;
bool g_a01=false,g_a02=false,g_a08=false;
datetime g_last_swing_time=0;
double g_last_swing_price=0.0;

void SetProbeProtection(const int state)
  {
   GlobalVariableSet(SRMPGlobalKey("REF"),Probe_Reference_Capital);
   GlobalVariableSet(SRMPGlobalKey("STATE"),(double)state);
   GlobalVariableSet(SRMPGlobalKey("HEALTH"),0.0);
   GlobalVariableSet(SRMPGlobalKey("AUTO"),1.0); // Tester-only simulated protection.
   GlobalVariableSet(SRMPGlobalKey("HB"),(double)TimeLocal());
  }

int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER)==0)
     { Print("Phase3ProbeEA refuses to run outside Strategy Tester"); return INIT_FAILED; }
   if(Probe_Reference_Capital<=0.0 || Probe_Max_Spread_Points<=0.0)
      return INIT_PARAMETERS_INCORRECT;
   ArrayInitialize(g_reason_counts,0);
   ArrayInitialize(g_status_counts,0);
   Print("PHASE3_PROBE started TESTER ONLY; no order execution functions");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   datetime bar=iTime(_Symbol,Trigger_Timeframe,1);
   if(bar<=0 || bar==g_last_bar) return;
   g_last_bar=bar;
   g_bars++;
   STradeAdvice advice;
   if(!g_a01)
     {
      GlobalVariableDel(SRMPGlobalKey("HB"));
      GlobalVariableDel(SRMPGlobalKey("STATE"));
      GlobalVariableDel(SRMPGlobalKey("HEALTH"));
      SRMPAnalyzeAdvice(_Symbol,Context_Timeframe,Structure_Timeframe,
                        Setup_Timeframe,Trigger_Timeframe,
                        Probe_Reference_Capital,1.0,2.0,2.0,
                        Probe_Max_Spread_Points,0.0,10.0,2.0,60,advice);
      g_a01=(advice.status==SRMP_NO_TRADE &&
             advice.reasons=="Protection offline, unhealthy or locked");
      Print("PHASE3_PROBE A01 absent protection ",g_a01 ? "PASS" : "NOT OBSERVED",
            " reason=",advice.reasons);
     }
   SetProbeProtection(SRMP_NORMAL);
   if(!g_a02)
     {
      SRMPAnalyzeAdvice(_Symbol,PERIOD_MN1,Structure_Timeframe,
                        Setup_Timeframe,Trigger_Timeframe,
                        Probe_Reference_Capital,1.0,2.0,2.0,
                        Probe_Max_Spread_Points,0.0,10.0,2.0,60,advice);
      g_a02=(advice.status==SRMP_NO_TRADE &&
             advice.reasons=="Insufficient closed bars or swing structure");
      Print("PHASE3_PROBE A02 insufficient MN1 history ",
            g_a02 ? "PASS" : "NOT OBSERVED"," reason=",advice.reasons);
     }
   if(!g_a08)
     {
      SetProbeProtection(SRMP_LOCKED);
      SRMPAnalyzeAdvice(_Symbol,Context_Timeframe,Structure_Timeframe,
                        Setup_Timeframe,Trigger_Timeframe,
                        Probe_Reference_Capital,1.0,2.0,2.0,
                        Probe_Max_Spread_Points,0.0,10.0,2.0,60,advice);
      g_a08=(advice.status==SRMP_NO_TRADE &&
             advice.reasons=="Protection offline, unhealthy or locked");
      Print("PHASE3_PROBE A08 locked protection ",
            g_a08 ? "PASS" : "NOT OBSERVED"," reason=",advice.reasons);
      SetProbeProtection(SRMP_NORMAL);
     }
   SMarketContextSnapshot market;
   SRMPAnalyzeMarketContext(_Symbol,Context_Timeframe,Structure_Timeframe,
                            Setup_Timeframe,Trigger_Timeframe,market);
   if(market.higher_ready && market.structure_ready && market.atr_ready)
      g_context_ready++;
   if(market.structure_ready)
     {
      if(g_last_swing_time==market.structure.recent_high_time &&
         g_last_swing_price!=market.structure.recent_high) g_revision++;
      g_last_swing_time=market.structure.recent_high_time;
      g_last_swing_price=market.structure.recent_high;
     }
   SRMPAnalyzeAdvice(_Symbol,Context_Timeframe,Structure_Timeframe,
                     Setup_Timeframe,Trigger_Timeframe,
                     Probe_Reference_Capital,1.0,2.0,2.0,
                     Probe_Max_Spread_Points,0.0,10.0,2.0,60,advice);
   int reason=SRMPAdviceReasonCode(advice.reasons);
   if(reason>=0 && reason<ArraySize(g_reason_counts)) g_reason_counts[reason]++;
   if((int)advice.status>=0 && (int)advice.status<3)
      g_status_counts[(int)advice.status]++;
   if(OrdersTotal()>0 || PositionsTotal()>0) g_orders_seen++;
  }

double OnTester()
  {
   PrintFormat("PHASE3_PROBE SUMMARY symbol=%s bars=%d context=%d NO_TRADE=%d WAIT=%d READY=%d revisions=%d exposure_observations=%d A01=%d A02=%d A08=%d",
               _Symbol,g_bars,g_context_ready,g_status_counts[0],
               g_status_counts[1],g_status_counts[2],g_revision,g_orders_seen,
               (int)g_a01,(int)g_a02,(int)g_a08);
   for(int i=0;i<ArraySize(g_reason_counts);i++)
      if(g_reason_counts[i]>0)
         PrintFormat("PHASE3_PROBE REASON code=%d count=%d text=%s",
                     i,g_reason_counts[i],SRMPAdviceReasonText(i));
   return (double)(g_a01 && g_a02 && g_a08 && g_orders_seen==0 ? 0 : 1);
  }

void OnDeinit(const int reason)
  {
   GlobalVariableDel(SRMPGlobalKey("REF"));
   GlobalVariableDel(SRMPGlobalKey("STATE"));
   GlobalVariableDel(SRMPGlobalKey("HEALTH"));
   GlobalVariableDel(SRMPGlobalKey("HB"));
  }
