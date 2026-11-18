#ifndef SRMP_POSITION_MONITOR_MQH
#define SRMP_POSITION_MONITOR_MQH

struct SPositionRisk
  {
   ulong  ticket;
   double net_floating;
   double loss_money;
   double loss_percent;
   bool   history_costs_available;
  };

double SRMPLossPercent(const double net_floating,const double reference_capital)
  {
   if(reference_capital<=0.0) return 0.0;
   return 100.0*MathMax(0.0,-net_floating)/reference_capital;
  }

int SRMPWarningLevel(const double loss_percent,const double emergency_threshold)
  {
   if(loss_percent>=emergency_threshold) return 4;
   if(loss_percent>=2.5) return 3;
   if(loss_percent>=2.0) return 2;
   if(loss_percent>=1.0) return 1;
   return 0;
  }

// Includes current position profit/swap, incurred deal commission/fees when
// history is available, and a conservative reserve for future exit costs.
bool SRMPPositionRisk(const ulong ticket,const double reference_capital,
                      const double exit_cost_per_lot,
                      const double missing_history_cost_per_lot,
                      SPositionRisk &risk)
  {
   ZeroMemory(risk);
   if(reference_capital<=0.0 || !PositionSelectByTicket(ticket)) return false;
   risk.ticket=ticket;
   double volume=PositionGetDouble(POSITION_VOLUME);
   double net=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   ulong position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   risk.history_costs_available=HistorySelectByPosition(position_id);
   if(risk.history_costs_available && HistoryDealsTotal()==0)
      risk.history_costs_available=false;
   if(risk.history_costs_available)
     {
      int deals=HistoryDealsTotal();
      for(int i=0;i<deals;i++)
        {
         ulong deal=HistoryDealGetTicket(i);
         if(deal==0) continue;
         net+=HistoryDealGetDouble(deal,DEAL_COMMISSION);
         net+=HistoryDealGetDouble(deal,DEAL_FEE);
        }
     }
   else
      net-=missing_history_cost_per_lot*volume;
   net-=exit_cost_per_lot*volume;
   risk.net_floating=net;
   risk.loss_money=MathMax(0.0,-net);
   risk.loss_percent=SRMPLossPercent(net,reference_capital);
   return MathIsValidNumber(risk.loss_percent);
  }

bool SRMPWorstPosition(const double reference_capital,
                       const double exit_cost_per_lot,
                       const double missing_history_cost_per_lot,
                       SPositionRisk &worst,int &position_count,
                       int &missing_history_count)
  {
   ZeroMemory(worst);
   position_count=PositionsTotal();
   missing_history_count=0;
   for(int i=0;i<position_count;i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      SPositionRisk current;
      if(!SRMPPositionRisk(ticket,reference_capital,exit_cost_per_lot,
                           missing_history_cost_per_lot,current))
        {
         if(!PositionSelectByTicket(ticket)) continue; // Closed during the scan.
         return false;
        }
      if(!current.history_costs_available) missing_history_count++;
      if(current.loss_percent>worst.loss_percent)
         worst=current;
     }
   return true;
  }

#endif
