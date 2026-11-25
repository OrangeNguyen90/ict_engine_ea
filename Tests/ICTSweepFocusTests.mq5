#property strict
#property description "Native sweep annotations, closed-H1 priority, causal MSS and ML/DL temporal gates. No trade requests."
#include "../Include/ICTSweepFocus.mqh"
int checks=0,failures=0;
void Check(const string name,const bool value)
  { checks++; if(!value) failures++; Print(name,value ? " PASS" : " FAIL"); }
#include "ICTSweepFocusFixtures.mqh"
int OnInit()
  {
   RunICTSweepFocusFixtures();
   PrintFormat("ICTSweepFocusTests RESULT checks=%d failures=%d",checks,failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
  }
void OnTick() {}
