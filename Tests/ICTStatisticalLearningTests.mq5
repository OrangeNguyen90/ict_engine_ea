#property strict
#property description "Closed-candle statistics, native first-touch labels and separate ML/DNN learning fixtures. No trade requests."
#include "../Include/ICTStatisticalLearning.mqh"
int checks=0,failures=0;
void Check(const string name,const bool value)
  { checks++; if(!value) failures++; Print(name,value ? " PASS" : " FAIL"); }
#include "ICTStatisticalLearningFixtures.mqh"
int OnInit()
  {
   RunICTStatisticalLearningFixtures();
   PrintFormat("ICTStatisticalLearningTests RESULT checks=%d failures=%d",checks,failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
  }
void OnTick() {}
