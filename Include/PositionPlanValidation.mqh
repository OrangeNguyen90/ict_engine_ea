#ifndef SRMP_POSITION_PLAN_VALIDATION_MQH
#define SRMP_POSITION_PLAN_VALIDATION_MQH

// Source-independent checks only. This module never sends or modifies trades.
struct SPositionPlanValidation
  {
   int direction; // +1 buy, -1 sell
   datetime opened_at,now,plan_revision,plan_published,quote_time;
   int max_position_age,max_plan_age,max_quote_age,max_entry_deviation_points;
   double entry,planned_entry,sl,tp,existing_sl,existing_tp;
   double bid,ask,point,tick,stops_points,freeze_points;
  };

bool SRMPValidatePositionPlan(const SPositionPlanValidation &p,string &reason)
  {
   reason="Invalid plan or market data";
   double values[]={p.entry,p.planned_entry,p.sl,p.tp,p.existing_sl,p.existing_tp,
                    p.bid,p.ask,p.point,p.tick,p.stops_points,p.freeze_points};
   for(int i=0;i<ArraySize(values);i++) if(!MathIsValidNumber(values[i])) return false;
   if((p.direction!=1 && p.direction!=-1) || p.entry<=0 || p.planned_entry<=0 ||
      p.sl<=0 || p.tp<=0 || p.existing_sl<0 || p.existing_tp<0 ||
      p.bid<=0 || p.ask<p.bid || p.point<=0 || p.tick<=0 ||
      p.stops_points<0 || p.freeze_points<0 || p.max_position_age<1 ||
      p.max_plan_age<1 || p.max_quote_age<1 || p.max_entry_deviation_points<0) return false;
   if(p.existing_sl>0 || p.existing_tp>0)
     { reason="Existing SL or TP preserved"; return false; }
   if(p.opened_at<=0 || p.now<p.opened_at || p.now-p.opened_at>p.max_position_age)
     { reason="Position is not recent"; return false; }
   if(p.plan_revision<=0 || p.plan_revision>p.opened_at || p.plan_published<p.plan_revision ||
      p.plan_published>p.now || p.now-p.plan_published>p.max_plan_age)
     { reason="Plan is stale or changed after entry"; return false; }
   if(p.quote_time<=0 || p.quote_time>p.now || p.now-p.quote_time>p.max_quote_age)
     { reason="Quote is stale"; return false; }
   if(MathAbs(p.entry-p.planned_entry)>p.max_entry_deviation_points*p.point+1e-10*p.point)
     { reason="Entry differs from plan"; return false; }
   if(MathAbs(p.sl/p.tick-MathRound(p.sl/p.tick))>1e-5 ||
      MathAbs(p.tp/p.tick-MathRound(p.tp/p.tick))>1e-5 ||
      (p.direction==1 && !(p.sl<p.entry && p.tp>p.entry)) ||
      (p.direction==-1 && !(p.sl>p.entry && p.tp<p.entry)))
     { reason="Invalid SL/TP geometry or tick grid"; return false; }
   double market=(p.direction==1 ? p.bid : p.ask);
   double gap=MathMax(p.stops_points,p.freeze_points)*p.point+p.tick;
   if((p.direction==1 && (p.sl>=market-gap || p.tp<=market+gap)) ||
      (p.direction==-1 && (p.sl<=market+gap || p.tp>=market-gap)))
     { reason="SL/TP inside broker stop or freeze distance"; return false; }
   reason="Position and plan geometry valid";
   return true;
  }

// Gross P/L must be supplied for the actual position volume by OrderCalcProfit.
bool SRMPValidatePositionPlanRisk(const double gross_loss,const double gross_reward,
                                  const double estimated_cost,const double reference,
                                  const double max_risk_percent,const double min_rr,
                                  string &reason)
  {
   reason="Invalid risk inputs";
   if(!MathIsValidNumber(gross_loss) || !MathIsValidNumber(gross_reward) ||
      !MathIsValidNumber(estimated_cost) || !MathIsValidNumber(reference) ||
      !MathIsValidNumber(max_risk_percent) || !MathIsValidNumber(min_rr) ||
      gross_loss>=0 || gross_reward<=0 || estimated_cost<0 || reference<=0 ||
      max_risk_percent<=0 || max_risk_percent>3 || min_rr<2)
      return false;
   double loss=-gross_loss+estimated_cost,reward=gross_reward-estimated_cost;
   if(loss<=0 || reward<=0 || loss>reference*max_risk_percent/100.0+1e-8 || reward/loss+1e-9<min_rr)
     { reason="Position risk or net RR outside limits"; return false; }
   reason="Position risk and net RR valid";
   return true;
  }
#endif
