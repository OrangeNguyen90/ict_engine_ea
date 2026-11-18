#ifndef SMART_RISK_TYPES_MQH
#define SMART_RISK_TYPES_MQH

enum ENUM_RM_DIRECTION
  {
   RM_BUY=0,
   RM_SELL=1
  };

struct SRiskResult
  {
   bool              valid;
   string            reason;
   double            volume;
   double            risk_money;
   double            reward_money;
   double            risk_percent;
   double            rr;
   double            stop_distance;
   double            target_distance;
   double            point;
   double            tick_size;
   double            spread_points;
   double            estimated_costs;
   double            estimated_margin;
  };

#endif
