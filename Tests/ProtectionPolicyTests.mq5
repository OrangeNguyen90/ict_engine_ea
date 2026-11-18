#property copyright "MT5 Smart Risk Manager Pro"
#property version "2.00"
#property script_show_inputs
#property description "Read-only threshold checks; no trade requests."

#include "../Include/PositionMonitor.mqh"

void Check(const string name,const bool passed,int &failures)
  {
   Print(name,passed ? " PASS" : " FAIL");
   if(!passed) failures++;
  }

void OnStart()
  {
   int failures=0;
   Check("TC01 100/10000 warning only",
         SRMPWarningLevel(SRMPLossPercent(-100.0,10000.0),3.0)==1,failures);
   Check("TC02 250/10000 critical warning",
         SRMPWarningLevel(SRMPLossPercent(-250.0,10000.0),3.0)==3,failures);
   Check("TC03 300/10000 emergency",
         SRMPWarningLevel(SRMPLossPercent(-300.0,10000.0),3.0)==4,failures);
   Check("Positive P/L has zero loss",
         SRMPLossPercent(500.0,10000.0)==0.0,failures);
   PrintFormat("ProtectionPolicyTests: %d failure(s)",failures);
  }
