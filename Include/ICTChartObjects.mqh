#ifndef ICT_CHART_OBJECTS_MQH
#define ICT_CHART_OBJECTS_MQH

const string ICT_DECISION_OBJECT_PREFIX="SRMP_ICTD_";

int ICTDeleteDecisionChartObjects()
  {
   // Templates/profiles can restore names containing a previous ChartID.
   // One EA per chart owns this namespace; leave all other objects intact.
   int deleted=ObjectsDeleteAll(0,ICT_DECISION_OBJECT_PREFIX,-1,-1);
   ChartRedraw(0);
   return deleted;
  }

#endif
