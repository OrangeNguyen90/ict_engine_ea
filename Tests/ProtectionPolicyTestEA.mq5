#property copyright "MT5 Smart Risk Manager Pro"
#property version "2.00"
#property description "Strategy Tester-only threshold tests. Never sends orders."

#include "../Include/PositionMonitor.mqh"

int g_failures=0;

void AssertCase(const string name,const bool condition)
  {
   Print("POLICY_TEST ",name,condition ? " PASS" : " FAIL");
   if(!condition) g_failures++;
  }

int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER)==0)
     {
      Print("ProtectionPolicyTestEA only runs in Strategy Tester");
      return INIT_FAILED;
     }
   AssertCase("TC01 100 loss warns at 1%",
              SRMPWarningLevel(SRMPLossPercent(-100.0,10000.0),3.0)==1);
   AssertCase("TC02 250 loss gives critical warning",
              SRMPWarningLevel(SRMPLossPercent(-250.0,10000.0),3.0)==3);
   AssertCase("TC03 300 loss triggers emergency",
              SRMPWarningLevel(SRMPLossPercent(-300.0,10000.0),3.0)==4);
   AssertCase("Positive P/L has no loss",SRMPLossPercent(500.0,10000.0)==0.0);
   AssertCase("Below threshold does not trigger",
              SRMPWarningLevel(SRMPLossPercent(-299.99,10000.0),3.0)<4);
   PrintFormat("POLICY_TEST SUMMARY failures=%d",g_failures);
   return g_failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
  }

void OnTick() {}

double OnTester()
  { return (double)g_failures; }
