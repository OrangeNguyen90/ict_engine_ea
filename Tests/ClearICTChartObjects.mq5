#property copyright "MT5 Smart Risk Manager Pro"
#property version "1.00"
#property description "Remove leftover ICT Decision/Smart EA drawings from the current chart."

#include "../Include/ICTChartObjects.mqh"

void OnStart()
  {
   int deleted=ICTDeleteDecisionChartObjects();
   PrintFormat("ICT cleanup: removed %d objects from chart %I64d. Remove the ICT EA first if drawings return.",
               deleted,ChartID());
  }
