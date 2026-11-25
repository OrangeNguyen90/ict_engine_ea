#ifndef SMART_RISK_CALCULATOR_MQH
#define SMART_RISK_CALCULATOR_MQH

#include "RiskTypes.mqh"
#include "SymbolSpecification.mqh"

// This is a preview calculator. It never sends an order or modifies a position.
bool CalculateRisk(const string symbol,const ENUM_RM_DIRECTION direction,
                   const double entry,const double stop_loss,const double take_profit,
                   const double reference_capital,const double risk_percent,
                   const double max_risk_percent,const double minimum_rr,
                   const double commission_round_turn_per_lot,const double cost_buffer_per_lot,
                   const double slippage_points,const int max_quote_age_seconds,
                   SRiskResult &result)
  {
   ZeroMemory(result);
   result.reason="Calculation unavailable";
   SSymbolSpecification spec;
   string spec_reason;
   if(!LoadSymbolSpecification(symbol,spec,spec_reason))
     { result.reason=spec_reason; return false; }
   if(!MathIsValidNumber(reference_capital) || !MathIsValidNumber(risk_percent) ||
      !MathIsValidNumber(max_risk_percent) || !MathIsValidNumber(minimum_rr) ||
      !MathIsValidNumber(commission_round_turn_per_lot) ||
      !MathIsValidNumber(cost_buffer_per_lot) || !MathIsValidNumber(slippage_points) ||
      reference_capital<=0.0 || risk_percent<=0.0 || max_risk_percent<=0.0 ||
      risk_percent>max_risk_percent || max_risk_percent>3.0 || minimum_rr<2.0 ||
      commission_round_turn_per_lot<0.0 || cost_buffer_per_lot<0.0 ||
      slippage_points<0.0 || max_quote_age_seconds<=0)
     { result.reason="Invalid risk inputs"; return false; }
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(stop_loss) ||
      !MathIsValidNumber(take_profit) || entry<=0.0 || stop_loss<=0.0 || take_profit<=0.0)
     { result.reason="Invalid price"; return false; }
   if((direction==RM_BUY && !(stop_loss<entry && take_profit>entry)) ||
      (direction==RM_SELL && !(stop_loss>entry && take_profit<entry)))
     { result.reason="SL/TP on wrong side of entry"; return false; }

   result.point=spec.point;
   result.tick_size=spec.tick_size;
   if(MathAbs(entry/result.tick_size-MathRound(entry/result.tick_size))>1e-5 ||
      MathAbs(stop_loss/result.tick_size-MathRound(stop_loss/result.tick_size))>1e-5 ||
      MathAbs(take_profit/result.tick_size-MathRound(take_profit/result.tick_size))>1e-5)
     { result.reason="Price is off the symbol tick grid"; return false; }
   result.stop_distance=MathAbs(entry-stop_loss);
   result.target_distance=MathAbs(take_profit-entry);
   double min_distance=(double)MathMax(spec.stops_level,spec.freeze_level)*result.point;
   if(result.stop_distance+result.point*0.0001<min_distance ||
      result.target_distance+result.point*0.0001<min_distance)
     { result.reason="SL/TP inside broker stop/freeze distance"; return false; }

   MqlTick quote;
   if(TerminalInfoInteger(TERMINAL_CONNECTED)==0)
     { result.reason="Terminal disconnected"; return false; }
   if(!SymbolInfoTick(symbol,quote) || quote.ask<=0.0 || quote.bid<=0.0 || quote.ask<quote.bid)
     { result.reason="Valid bid/ask unavailable"; return false; }
   datetime server_now=TimeTradeServer();
   if(quote.time<=0 || (server_now>0 &&
      (quote.time>server_now+2 || server_now-quote.time>max_quote_age_seconds)))
     { result.reason="Market quote is stale"; return false; }
   result.spread_points=(quote.ask-quote.bid)/result.point;
   ENUM_ORDER_TYPE order_type=(direction==RM_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double adverse_stop=stop_loss+(direction==RM_BUY ? -1.0 : 1.0)*slippage_points*result.point;
   double gross_loss=0.0,gross_reward=0.0;
   if(adverse_stop<=0.0 ||
      !OrderCalcProfit(order_type,symbol,spec.volume_min,entry,adverse_stop,gross_loss) ||
      !OrderCalcProfit(order_type,symbol,spec.volume_min,entry,take_profit,gross_reward) ||
      !MathIsValidNumber(gross_loss) || !MathIsValidNumber(gross_reward))
     { result.reason="OrderCalcProfit failed"; return false; }
   double estimated_cost_per_lot=commission_round_turn_per_lot+cost_buffer_per_lot;
   double loss_per_lot=-gross_loss/spec.volume_min+estimated_cost_per_lot;
   double reward_per_lot=gross_reward/spec.volume_min-estimated_cost_per_lot;
   if(loss_per_lot<=0.0 || reward_per_lot<=0.0)
     { result.reason="Nonpositive loss or reward estimate"; return false; }
   double budget=reference_capital*risk_percent/100.0;
   double raw_volume=budget/loss_per_lot;
   if(raw_volume+1e-10<spec.volume_min)
     { result.reason="Minimum lot exceeds risk budget"; return false; }
   double capped=MathMin(raw_volume,spec.volume_max);
   double steps=MathFloor((capped-spec.volume_min)/spec.volume_step+1e-9);
   double volume=NormalizeDouble(spec.volume_min+steps*spec.volume_step,8);
   while(volume>=spec.volume_min-1e-9 && volume*loss_per_lot>budget+1e-8)
      volume=NormalizeDouble(volume-spec.volume_step,8);
   if(volume<spec.volume_min-1e-9)
     { result.reason="No lot fits risk budget"; return false; }

   double margin=0.0;
   if(!OrderCalcMargin(order_type,symbol,volume,entry,margin) ||
      !MathIsValidNumber(margin) || margin<0.0)
     { result.reason="OrderCalcMargin failed"; return false; }
   result.estimated_margin=margin;
   if(margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)+1e-8)
     { result.reason="Insufficient free margin"; return false; }

   result.volume=volume;
   result.risk_money=volume*loss_per_lot;
   result.reward_money=volume*reward_per_lot;
   result.estimated_costs=volume*estimated_cost_per_lot;
   result.risk_percent=100.0*result.risk_money/reference_capital;
   result.rr=result.reward_money/result.risk_money;
   if(result.rr+1e-9<minimum_rr)
     { result.reason="RR below minimum"; return false; }
   result.valid=true;
   result.reason="SAFE preview (no order sent)";
   return true;
  }

#endif
