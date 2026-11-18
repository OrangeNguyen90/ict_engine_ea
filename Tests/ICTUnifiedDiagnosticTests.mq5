#property strict
#property description "Read-only dashboard and SMT diagnostic fixtures; no trade requests."
#include "../Include/ICTUnifiedDecisionAdapter.mqh"
#include "../Include/ICTUnifiedRenderer.mqh"

int checks=0,failures=0;
void Check(const string name,const bool value)
  { checks++; if(!value) failures++; Print(name,value ? " PASS" : " FAIL"); }
#include "ICTUnifiedDiagnosticFixtures.mqh"

int OnInit()
  {
   RunUnifiedDiagnosticFixtures();
   PrintFormat("ICTUnifiedDiagnosticTests RESULT checks=%d failures=%d",checks,failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
  }
