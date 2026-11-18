// Tester-only regression harness; inherits the production tick/timer handlers.
#define OnInit ICTAutoTraderInit
#include "../Experts/ICTAutoTraderEA.mq5"
#undef OnInit

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
   int result=ICTAutoTraderInit();
   if(result!=INIT_SUCCEEDED) return result;
   double reference=0;
   bool ok=SimulatedProtection() && ProtectionReady(reference) &&
           reference==AccountInfoDouble(ACCOUNT_BALANCE) && reference>0;
   bool existed=FileIsExist(g_state_file,SRMPFileScope());
   ok=RecordSignal(TimeCurrent()) && g_last_signal==TimeCurrent() && ok;
   ok=LoadSignal() && g_last_signal==0 && ok;
   ok=(FileIsExist(g_state_file,SRMPFileScope())==existed) && ok;
   string names[]={"HB","STATE","HEALTH","AUTO","REF"};
   for(int i=0;i<ArraySize(names);i++)
      ok=!GlobalVariableCheck(SRMPGlobalKey(names[i])) && ok;
   STradeAdvice a;
   SRMPAnalyzeAdvice(_Symbol,Context_Timeframe,Structure_Timeframe,Setup_Timeframe,Trigger_Timeframe,
                    reference,Risk_Percent,Max_Risk_Percent,Minimum_RR,Max_Spread_Points,
                    Commission_Per_Lot,Cost_Buffer_Per_Lot,Stop_Slippage_Points,Max_Quote_Age_Seconds,a);
   ok=(a.reasons=="Protection offline, unhealthy or locked") && ok;
   SRMPAnalyzeAdvice(_Symbol,Context_Timeframe,Structure_Timeframe,Setup_Timeframe,Trigger_Timeframe,
                    reference,Risk_Percent,Max_Risk_Percent,Minimum_RR,Max_Spread_Points,
                    Commission_Per_Lot,Cost_Buffer_Per_Lot,Stop_Slippage_Points,Max_Quote_Age_Seconds,a,true);
   ok=(a.reasons!="Protection offline, unhealthy or locked" && a.reasons!="Terminal disconnected") && ok;
   Print("ICT AUTO TESTER REGRESSION: ",ok ? "PASS" : "FAIL", "; analysis=",a.reasons);
   return ok ? INIT_SUCCEEDED : INIT_FAILED;
  }
