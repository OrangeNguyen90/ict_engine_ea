#property copyright "MT5 Smart Risk Manager Pro"
#property version "3.00"
#property description "Closed-bar ICT/SMC advisory only. Never sends orders."

#include "../Include/TradeAdvisor.mqh"
#include "../Include/OrderBlockRenderer.mqh"
#include "../Include/SMTChartRenderer.mqh"

input ENUM_TIMEFRAMES Context_Timeframe=PERIOD_H4;
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H1;
input ENUM_TIMEFRAMES Setup_Timeframe=PERIOD_M15;
input ENUM_TIMEFRAMES Trigger_Timeframe=PERIOD_M5;
input double Risk_Per_Trade=1.0;
input double Max_Risk_Per_Trade=2.0;
input double Minimum_Risk_Reward=2.0;
input double Max_Spread_Points=50.0;
input double Commission_Round_Turn_Per_Lot=0.0;
input double Unspecified_Cost_Buffer_Per_Lot=10.0;
input double Estimated_Slippage_Points=2.0;
input int Max_Quote_Age_Seconds=60;
input bool Show_Order_Block=true;
input bool Show_Inactive_Order_Block=true;
input ENUM_TIMEFRAMES Order_Block_Timeframe=PERIOD_M15;
input bool Show_SMT=true;
input string SMT_Comparison_1="";
input string SMT_Comparison_2="";
input ENUM_TIMEFRAMES SMT_Timeframe=PERIOD_H1;
input ENUM_SMT_CORRELATION SMT_Correlation_1=SMT_AUTO;
input ENUM_SMT_CORRELATION SMT_Correlation_2=SMT_AUTO;

string g_ob_prefix="SRMP_standalone_ob_";
string g_smt1_prefix="SRMP_standalone_smt1_";
string g_smt2_prefix="SRMP_standalone_smt2_";
int g_smt1_state=-1,g_smt2_state=-1;

datetime g_last_bar=0;
int g_last_status=-1;
string g_last_reason="";

string AdviceStatus(const ENUM_SRMP_ADVICE_STATUS status)
  {
   if(status==SRMP_TRADE_READY) return "TRADE READY (ADVISORY ONLY)";
   if(status==SRMP_WAIT) return "WAIT";
   return "NO TRADE";
  }

int OnInit()
  {
   if(Risk_Per_Trade<=0.0 || Max_Risk_Per_Trade<=0.0 ||
      Risk_Per_Trade>Max_Risk_Per_Trade || Minimum_Risk_Reward<2.0 ||
      Max_Spread_Points<=0.0 || Max_Quote_Age_Seconds<=0 ||
      Commission_Round_Turn_Per_Lot<0.0 ||
      Unspecified_Cost_Buffer_Per_Lot<0.0 || Estimated_Slippage_Points<0.0 ||
      (Show_SMT && (StringLen(SMT_Comparison_1)>24 ||
                    StringLen(SMT_Comparison_2)>24 ||
                    (SMT_Comparison_1!="" && SMT_Comparison_1==SMT_Comparison_2))))
      return INIT_PARAMETERS_INCORRECT;
   EventSetTimer(5);
   Print("TradingAdvisoryEA started. Signals use closed bars; no order execution.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   SRMPClearOBObjects(g_ob_prefix);
   SRMPClearSMTObjects(g_smt1_prefix);
   SRMPClearSMTObjects(g_smt2_prefix);
   ChartRedraw();
  }

void OnTimer()
  {
   if(Show_Order_Block || Show_SMT)
     {
      SICTSettings settings;
      SRMPDefaultICTSettings(settings);
      settings.ob_timeframe=Order_Block_Timeframe;
      settings.enable_ob=Show_Order_Block;
      settings.enable_smt=Show_SMT;
      settings.comparison1=SMT_Comparison_1;
      settings.comparison2=SMT_Comparison_2;
      settings.smt_timeframe=SMT_Timeframe;
      settings.correlation1=SMT_Correlation_1;
      settings.correlation2=SMT_Correlation_2;
      SICTSnapshot snapshot;
      bool valid=SRMPAnalyzeICT(_Symbol,settings,snapshot);
      if(valid && snapshot.ob_available)
        {
         datetime edge=iTime(_Symbol,_Period,0)+(datetime)PeriodSeconds(_Period);
         SRMPRenderOrderBlock(g_ob_prefix,snapshot.ob,edge,Show_Inactive_Order_Block);
        }
      else SRMPClearOBObjects(g_ob_prefix);
      if(valid && snapshot.smt1_available)
         SRMPRenderSMT(g_smt1_prefix,snapshot.smt1,SMT_Timeframe);
      else SRMPClearSMTObjects(g_smt1_prefix);
      if(valid && snapshot.smt2_available)
         SRMPRenderSMT(g_smt2_prefix,snapshot.smt2,SMT_Timeframe);
      else SRMPClearSMTObjects(g_smt2_prefix);
      if(valid && Show_SMT)
        {
         if(SMT_Comparison_1!="" && (int)snapshot.smt1.state!=g_smt1_state)
            PrintFormat("SMT %s / %s: %s (rho %.3f, pairs %d)",_Symbol,
                        SMT_Comparison_1,SRMPSMTStateText(snapshot.smt1.state),
                        snapshot.smt1.correlation,snapshot.smt1.correlation_pairs);
         if(SMT_Comparison_2!="" && (int)snapshot.smt2.state!=g_smt2_state)
            PrintFormat("SMT %s / %s: %s (rho %.3f, pairs %d)",_Symbol,
                        SMT_Comparison_2,SRMPSMTStateText(snapshot.smt2.state),
                        snapshot.smt2.correlation,snapshot.smt2.correlation_pairs);
         g_smt1_state=(int)snapshot.smt1.state;
         g_smt2_state=(int)snapshot.smt2.state;
        }
      if(!valid) Print("Invalid ICT settings: check SMT comparison symbols and timeframes.");
      ChartRedraw();
     }
   else
     {
      SRMPClearOBObjects(g_ob_prefix);
      SRMPClearSMTObjects(g_smt1_prefix);
      SRMPClearSMTObjects(g_smt2_prefix);
     }
   datetime bar=iTime(_Symbol,Trigger_Timeframe,1);
   if(bar<=0) return;
   double reference=(GlobalVariableCheck(SRMPGlobalKey("REF")) ?
                     GlobalVariableGet(SRMPGlobalKey("REF")) : 0.0);
   STradeAdvice advice;
   bool data_ready=SRMPAnalyzeAdvice(_Symbol,Context_Timeframe,
                        Structure_Timeframe,Setup_Timeframe,Trigger_Timeframe,
                        reference,Risk_Per_Trade,Max_Risk_Per_Trade,
                        Minimum_Risk_Reward,Max_Spread_Points,
                        Commission_Round_Turn_Per_Lot,Unspecified_Cost_Buffer_Per_Lot,
                        Estimated_Slippage_Points,Max_Quote_Age_Seconds,advice);
   if(bar!=g_last_bar || (int)advice.status!=g_last_status ||
      advice.reasons!=g_last_reason)
     {
      PrintFormat("ADVISORY %s %s bar=%s direction=%d context=%s reason=%s data=%d",
                  _Symbol,AdviceStatus(advice.status),TimeToString(bar),
                  advice.direction,advice.context,advice.reasons,(int)data_ready);
      if(advice.status==SRMP_TRADE_READY)
         PrintFormat("ADVISORY PLAN %s zone=[%.*f,%.*f] entry=%.*f SL=%.*f TP=%.*f lot=%.8f risk=%.2f reward=%.2f RR=%.2f invalidation=%.*f",
                     _Symbol,_Digits,advice.zone_low,_Digits,advice.zone_high,
                     _Digits,advice.entry,_Digits,advice.stop_loss,
                     _Digits,advice.take_profit,advice.risk.volume,
                     advice.risk.risk_money,advice.risk.reward_money,
                     advice.risk.rr,_Digits,advice.invalidation);
     }
   g_last_bar=bar;
   g_last_status=(int)advice.status;
   g_last_reason=advice.reasons;
  }

void OnTick() {} // Never places orders.
