#ifndef ICT_POSITION_RISK_MQH
#define ICT_POSITION_RISK_MQH

enum ENUM_ICT_POSITION_CAPITAL
  { ICT_POSITION_BALANCE=0, ICT_POSITION_EQUITY=1, ICT_POSITION_CONSERVATIVE=2 };
enum ENUM_ICT_POSITION_RISK_LIMIT
  { ICT_RISK_LIMIT_UNKNOWN=-1, ICT_RISK_LIMIT_NORMAL=0, ICT_RISK_LIMIT_WARNING=1, ICT_RISK_LIMIT_CLOSE=2 };

// Live account telemetry is deliberately separate from immutable ICT signals.
// Gross terminal valuations are in account currency, never pips * a fixed lot value.
struct SICTPositionRiskInput
  {
   ulong ticket;
   string symbol;
   int direction,digits;
   double volume,entry,stop,target,profit,swap;
   double gross_at_stop,gross_at_target;
   bool stop_valued,target_valued;
  };

struct SICTPositionRisk
  {
   SICTPositionRiskInput position;
   bool valid,capital_valid,stop_valid,target_valid,floating_valid,rr_valid;
   double costs,floating,floating_percent;
   double net_at_stop,net_at_target,risk_money,risk_percent;
   double locked_money,locked_percent,target_percent,rr,remaining_risk_money;
  };

struct SICTPositionRiskTotals
  {
   int count,unknown_stops,unknown_targets,unknown_floating,invalid_positions;
   double volume,risk_money,target_money,floating,costs,remaining_risk_money;
  };

struct SICTPositionRiskSnapshot
  {
   datetime observed_at;
   string symbol_filter,currency;
   int currency_digits,selection_errors;
   ENUM_ICT_POSITION_CAPITAL capital_mode;
   double balance,equity,capital,cost_per_lot;
   bool connected;
   int pending_count,unknown_pending;
   double pending_risk_money,margin,free_margin,margin_level,daily_net;
   bool daily_valid,margin_valid,protection_online,protection_armed,protection_healthy;
   bool daily_opened_valid;
   double daily_opened_risk_money;
   int protection_state;
   SICTPositionRiskTotals totals;
   SICTPositionRisk positions[];
  };

bool ICTPositionCapitalValid(const double capital)
  { return MathIsValidNumber(capital) && capital>0.0; }

double ICTPositionPercent(const double money,const double capital)
  {
   if(!MathIsValidNumber(money) || !ICTPositionCapitalValid(capital)) return 0.0;
   return money/capital*100.0;
  }

// Never size a new trade from a historic reference larger than today's funds.
double ICTConservativeRiskCapital(const double reference,const double balance,const double equity)
  {
   if(!ICTPositionCapitalValid(reference) || !ICTPositionCapitalValid(balance) ||
      !ICTPositionCapitalValid(equity)) return 0.0;
   return MathMin(reference,MathMin(balance,equity));
  }

// Policy only: callers must explicitly choose the loss/risk metric and scope.
// No trade request is made here. Unknown risk never authorizes a close.
// Strict boundaries implement "over 3%" / "over 5%", not rounded panel text.
ENUM_ICT_POSITION_RISK_LIMIT ICTEvaluatePositionRiskLimit(const bool known,const double risk_money,
                                                           const double capital,const double warning_percent=3.0,
                                                           const double close_percent=5.0)
  {
   if(!known || !MathIsValidNumber(risk_money) || risk_money<0.0 || !ICTPositionCapitalValid(capital) ||
      !MathIsValidNumber(warning_percent) || !MathIsValidNumber(close_percent) ||
      warning_percent<=0.0 || close_percent<=warning_percent || close_percent>100.0)
      return ICT_RISK_LIMIT_UNKNOWN;
   double percent=ICTPositionPercent(risk_money,capital);
   if(!MathIsValidNumber(percent)) return ICT_RISK_LIMIT_UNKNOWN;
   if(percent>close_percent) return ICT_RISK_LIMIT_CLOSE;
   if(percent>warning_percent) return ICT_RISK_LIMIT_WARNING;
   return ICT_RISK_LIMIT_NORMAL;
  }

bool ICTCalculatePositionRisk(const SICTPositionRiskInput &exposure,const double capital,
                               const double cost_per_lot,SICTPositionRisk &risk)
  {
   ZeroMemory(risk); risk.position=exposure;
   risk.capital_valid=ICTPositionCapitalValid(capital);
   if((exposure.direction!=1 && exposure.direction!=-1) || exposure.symbol=="" ||
      !MathIsValidNumber(exposure.volume) || exposure.volume<=0.0 ||
      !MathIsValidNumber(exposure.entry) || exposure.entry<=0.0 ||
      !MathIsValidNumber(cost_per_lot) || cost_per_lot<0.0) return false;
   risk.costs=exposure.volume*cost_per_lot;
   if(!MathIsValidNumber(risk.costs)) return false;
   risk.valid=true;
   if(MathIsValidNumber(exposure.profit) && MathIsValidNumber(exposure.swap))
     {
      risk.floating=exposure.profit+exposure.swap;
      risk.floating_valid=MathIsValidNumber(risk.floating);
      if(risk.floating_valid) risk.floating_percent=ICTPositionPercent(risk.floating,capital);
     }
   if(exposure.stop_valued && MathIsValidNumber(exposure.stop) && exposure.stop>0.0 &&
      MathIsValidNumber(exposure.gross_at_stop) && MathIsValidNumber(exposure.swap))
     {
      risk.net_at_stop=exposure.gross_at_stop+exposure.swap-risk.costs;
      risk.stop_valid=MathIsValidNumber(risk.net_at_stop);
      if(risk.stop_valid)
        {
         risk.risk_money=MathMax(0.0,-risk.net_at_stop);
         risk.locked_money=MathMax(0.0,risk.net_at_stop);
         risk.risk_percent=ICTPositionPercent(risk.risk_money,capital);
         risk.locked_percent=ICTPositionPercent(risk.locked_money,capital);
         if(risk.floating_valid)
            risk.remaining_risk_money=MathMax(0.0,risk.floating-risk.net_at_stop);
        }
     }
   if(exposure.target_valued && MathIsValidNumber(exposure.target) && exposure.target>0.0 &&
      MathIsValidNumber(exposure.gross_at_target) && MathIsValidNumber(exposure.swap))
     {
      risk.net_at_target=exposure.gross_at_target+exposure.swap-risk.costs;
      risk.target_valid=MathIsValidNumber(risk.net_at_target);
      if(risk.target_valid) risk.target_percent=ICTPositionPercent(risk.net_at_target,capital);
     }
   if(risk.stop_valid && risk.target_valid && risk.risk_money>0.0 && risk.net_at_target>0.0)
     {
      risk.rr=risk.net_at_target/risk.risk_money;
      risk.rr_valid=MathIsValidNumber(risk.rr);
     }
   return true;
  }

// Sum exposure, not net directional risk: a hedge or a profitable trailing SL
// must not cancel another position's loss. Missing stops never become 0% risk.
void ICTAccumulatePositionRisk(const SICTPositionRisk &risk,SICTPositionRiskTotals &totals)
  {
   totals.count++;
   if(!risk.valid)
     {
      totals.invalid_positions++; totals.unknown_stops++;
      totals.unknown_targets++; totals.unknown_floating++; return;
     }
   totals.volume+=risk.position.volume; totals.costs+=risk.costs;
   if(risk.stop_valid) totals.risk_money+=risk.risk_money; else totals.unknown_stops++;
   if(risk.target_valid) totals.target_money+=risk.net_at_target; else totals.unknown_targets++;
   if(risk.floating_valid) totals.floating+=risk.floating; else totals.unknown_floating++;
   if(risk.stop_valid && risk.floating_valid) totals.remaining_risk_money+=risk.remaining_risk_money;
  }

// Both measures matter: loss from entry and additional equity loss at the SL.
// No profit at one SL may subsidize the loss on a different position.
bool ICTPositionEntryBudgetAllowed(const SICTPositionRiskSnapshot &s,const double candidate_risk,
                                    const double reference,const double portfolio_limit,
                                    const double daily_limit,string &reason,const bool require_daily_risk=true)
  {
   reason="";
   double capital=ICTConservativeRiskCapital(reference,s.balance,s.equity);
   if(!ICTPositionCapitalValid(capital) || !MathIsValidNumber(candidate_risk) || candidate_risk<=0.0 ||
      !MathIsValidNumber(portfolio_limit) || portfolio_limit<0.0 || portfolio_limit>100.0 ||
      !MathIsValidNumber(daily_limit) || daily_limit<=0.0 || daily_limit>6.0 ||
      candidate_risk>capital*3.0/100.0+1e-8)
     { reason="Invalid account risk budget"; return false; }
   if(s.symbol_filter!="" || !s.connected || s.selection_errors>0 || s.totals.invalid_positions>0 ||
      s.totals.unknown_stops>0 || s.totals.unknown_floating>0 || s.unknown_pending>0)
     { reason="Account exposure or SL valuation unavailable"; return false; }
   if(!MathIsValidNumber(s.totals.risk_money) || s.totals.risk_money<0.0 ||
      !MathIsValidNumber(s.totals.remaining_risk_money) || s.totals.remaining_risk_money<0.0 ||
      !MathIsValidNumber(s.pending_risk_money) || s.pending_risk_money<0.0)
     { reason="Invalid account exposure totals"; return false; }
   double loss=s.totals.risk_money+s.pending_risk_money+candidate_risk;
   double remaining=s.totals.remaining_risk_money+s.pending_risk_money+candidate_risk;
   if(!MathIsValidNumber(loss) || !MathIsValidNumber(remaining))
     { reason="Account exposure overflow"; return false; }
   if(portfolio_limit>0.0 && MathMax(loss,remaining)>capital*portfolio_limit/100.0+1e-8)
     { reason="Portfolio SL risk budget exceeded (positions + pending + new trade)"; return false; }
   // This is today's deal P/L plus all current floating, not a midnight-equity drawdown.
   // Reserve existing giveback and the new SL before authorizing a fresh entry.
   if(daily_limit>0.0 && (!s.daily_valid || !MathIsValidNumber(s.daily_net) ||
      s.daily_net<=-capital*daily_limit/100.0 ||
      s.daily_net-remaining < -capital*daily_limit/100.0-1e-8))
     { reason="Daily loss budget exhausted or account history unavailable"; return false; }
   if(require_daily_risk && (!s.daily_opened_valid || !MathIsValidNumber(s.daily_opened_risk_money) ||
      s.daily_opened_risk_money<0.0 ||
      s.daily_opened_risk_money+s.pending_risk_money+candidate_risk>capital*daily_limit/100.0+1e-8))
     { reason="Daily opened-risk budget exhausted or original SL history unavailable"; return false; }
   return true;
  }

// Read-only terminal integration. Partial closes naturally use the remaining
// POSITION_VOLUME and netting positions use the current average entry.
bool ICTReadPositionRisk(const ulong ticket,const double capital,const double cost_per_lot,
                          SICTPositionRisk &risk)
  {
   ZeroMemory(risk);
   if(!PositionSelectByTicket(ticket)) return false;
   SICTPositionRiskInput exposure; ZeroMemory(exposure);
   exposure.ticket=ticket; exposure.symbol=PositionGetString(POSITION_SYMBOL);
   long kind=PositionGetInteger(POSITION_TYPE);
   exposure.direction=(kind==POSITION_TYPE_BUY ? 1 : kind==POSITION_TYPE_SELL ? -1 : 0);
   exposure.digits=(int)SymbolInfoInteger(exposure.symbol,SYMBOL_DIGITS);
   exposure.volume=PositionGetDouble(POSITION_VOLUME); exposure.entry=PositionGetDouble(POSITION_PRICE_OPEN);
   exposure.stop=PositionGetDouble(POSITION_SL); exposure.target=PositionGetDouble(POSITION_TP);
   exposure.profit=PositionGetDouble(POSITION_PROFIT); exposure.swap=PositionGetDouble(POSITION_SWAP);
   ENUM_ORDER_TYPE side=(exposure.direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(exposure.direction!=0 && exposure.volume>0.0 && exposure.entry>0.0)
     {
      if(exposure.stop>0.0) exposure.stop_valued=OrderCalcProfit(side,exposure.symbol,exposure.volume,exposure.entry,exposure.stop,exposure.gross_at_stop);
      if(exposure.target>0.0) exposure.target_valued=OrderCalcProfit(side,exposure.symbol,exposure.volume,exposure.entry,exposure.target,exposure.gross_at_target);
     }
   ICTCalculatePositionRisk(exposure,capital,cost_per_lot,risk);
   return true; // A selected position with an unavailable valuation is still reported.
  }

bool ICTReadAccountDayNet(double &net)
  {
   net=0.0;
   datetime now=TimeCurrent(); MqlDateTime day;
   if(now<=0 || !TimeToStruct(now,day)) return false;
   day.hour=0; day.min=0; day.sec=0;
   if(!HistorySelect(StructToTime(day),now)) return false;
   int deals=HistoryDealsTotal();
   for(int i=0;i<deals;i++)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0) return false;
      ENUM_DEAL_TYPE kind=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
      if(kind!=DEAL_TYPE_BUY && kind!=DEAL_TYPE_SELL) continue;
      double profit=0,swap=0,commission=0,fee=0;
      if(!HistoryDealGetDouble(ticket,DEAL_PROFIT,profit) || !HistoryDealGetDouble(ticket,DEAL_SWAP,swap) ||
         !HistoryDealGetDouble(ticket,DEAL_COMMISSION,commission) || !HistoryDealGetDouble(ticket,DEAL_FEE,fee) ||
         !MathIsValidNumber(profit) || !MathIsValidNumber(swap) || !MathIsValidNumber(commission) ||
         !MathIsValidNumber(fee)) return false;
      net+=profit+swap+commission+fee;
     }
   int positions=PositionsTotal();
   for(int i=0;i<positions;i++)
     {
      if(PositionGetTicket(i)==0) return false;
      double profit=0,swap=0;
      if(!PositionGetDouble(POSITION_PROFIT,profit) || !PositionGetDouble(POSITION_SWAP,swap) ||
         !MathIsValidNumber(profit) || !MathIsValidNumber(swap)) return false;
      net+=profit+swap;
     }
   return positions==PositionsTotal() && deals==HistoryDealsTotal() && MathIsValidNumber(net);
  }

// Reconstruct from broker history on every scan, including after an EA restart.
// Count entry fills once, even when already closed at TP. Exit deals never refund
// this budget. A reversal is conservatively charged on the entire INOUT volume.
bool ICTReadAccountDayOpenedRisk(const double costs,double &risk_money)
  {
   risk_money=0.0;
   if(!MathIsValidNumber(costs) || costs<0.0) return false;
   datetime now=TimeCurrent(); MqlDateTime day;
   if(now<=0 || !TimeToStruct(now,day)) return false;
   day.hour=0; day.min=0; day.sec=0;
   if(!HistorySelect(StructToTime(day),now)) return false;
   int count=HistoryDealsTotal();
   for(int i=0;i<count;i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0) return false;
      ENUM_DEAL_TYPE kind=(ENUM_DEAL_TYPE)HistoryDealGetInteger(deal,DEAL_TYPE);
      if(kind!=DEAL_TYPE_BUY && kind!=DEAL_TYPE_SELL) continue;
      ENUM_DEAL_ENTRY entry_kind=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry_kind!=DEAL_ENTRY_IN && entry_kind!=DEAL_ENTRY_INOUT) continue;
      ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
      double price=0,volume=0,stop=0,pnl=0;
      string symbol=HistoryDealGetString(deal,DEAL_SYMBOL);
      if(order==0 || symbol=="" || !HistoryDealGetDouble(deal,DEAL_PRICE,price) ||
         !HistoryDealGetDouble(deal,DEAL_VOLUME,volume) || !HistoryOrderGetDouble(order,ORDER_SL,stop) ||
         !MathIsValidNumber(price) || price<=0.0 || !MathIsValidNumber(volume) || volume<=0.0 ||
         !MathIsValidNumber(stop) || stop<=0.0 ||
         !OrderCalcProfit(kind==DEAL_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,symbol,volume,price,stop,pnl) ||
         !MathIsValidNumber(pnl)) return false;
      risk_money+=MathMax(0.0,-pnl)+costs*volume;
      if(!MathIsValidNumber(risk_money)) return false;
     }
   return count==HistoryDealsTotal();
  }

void ICTReadPositionRiskSnapshot(const string symbol_filter,const ENUM_ICT_POSITION_CAPITAL mode,
                                  const double cost_per_lot,SICTPositionRiskSnapshot &snapshot)
  {
   ZeroMemory(snapshot); ArrayResize(snapshot.positions,0);
   snapshot.observed_at=TimeCurrent(); snapshot.symbol_filter=symbol_filter;
   snapshot.currency=AccountInfoString(ACCOUNT_CURRENCY);
   snapshot.currency_digits=(int)MathMax(0,MathMin(8,AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS)));
   snapshot.capital_mode=mode; snapshot.balance=AccountInfoDouble(ACCOUNT_BALANCE);
   snapshot.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   snapshot.capital=(mode==ICT_POSITION_EQUITY ? snapshot.equity : mode==ICT_POSITION_CONSERVATIVE ?
      ICTConservativeRiskCapital(snapshot.balance,snapshot.balance,snapshot.equity) : snapshot.balance);
   snapshot.cost_per_lot=cost_per_lot;
   snapshot.connected=TerminalInfoInteger(TERMINAL_CONNECTED)!=0;
   snapshot.margin=AccountInfoDouble(ACCOUNT_MARGIN);
   snapshot.free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   snapshot.margin_level=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   snapshot.margin_valid=MathIsValidNumber(snapshot.margin) && snapshot.margin>=0.0 &&
      MathIsValidNumber(snapshot.free_margin) && MathIsValidNumber(snapshot.margin_level);
   int total=PositionsTotal();
   for(int i=0;i<total;i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) { snapshot.selection_errors++; continue; }
      if(symbol_filter!="" && PositionGetString(POSITION_SYMBOL)!=symbol_filter) continue;
      SICTPositionRisk risk;
      if(!ICTReadPositionRisk(ticket,snapshot.capital,cost_per_lot,risk))
        { snapshot.selection_errors++; continue; }
      int count=ArraySize(snapshot.positions);
      if(ArrayResize(snapshot.positions,count+1)!=count+1) { snapshot.selection_errors++; continue; }
      snapshot.positions[count]=risk;
      ICTAccumulatePositionRisk(risk,snapshot.totals);
     }
   if(total!=PositionsTotal()) snapshot.selection_errors++;
   int pending=OrdersTotal();
   for(int i=0;i<pending;i++)
     {
      if(OrderGetTicket(i)==0) { snapshot.selection_errors++; continue; }
      string symbol=OrderGetString(ORDER_SYMBOL);
      if(symbol_filter!="" && symbol!=symbol_filter) continue;
      snapshot.pending_count++;
      ENUM_ORDER_TYPE kind=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool buy=kind==ORDER_TYPE_BUY_LIMIT || kind==ORDER_TYPE_BUY_STOP || kind==ORDER_TYPE_BUY_STOP_LIMIT;
      bool sell=kind==ORDER_TYPE_SELL_LIMIT || kind==ORDER_TYPE_SELL_STOP || kind==ORDER_TYPE_SELL_STOP_LIMIT;
      double entry=OrderGetDouble(ORDER_PRICE_OPEN),stop=OrderGetDouble(ORDER_SL);
      if(kind==ORDER_TYPE_BUY_STOP_LIMIT || kind==ORDER_TYPE_SELL_STOP_LIMIT)
         entry=OrderGetDouble(ORDER_PRICE_STOPLIMIT);
      double volume=OrderGetDouble(ORDER_VOLUME_CURRENT),pnl=0.0;
      if((!buy && !sell) || !MathIsValidNumber(entry) || entry<=0.0 || !MathIsValidNumber(stop) || stop<=0.0 ||
         !MathIsValidNumber(volume) || volume<=0.0 || !MathIsValidNumber(cost_per_lot) || cost_per_lot<0.0 ||
         (buy && stop>=entry) || (sell && stop<=entry) ||
         !OrderCalcProfit(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,symbol,volume,entry,stop,pnl) ||
         !MathIsValidNumber(pnl) || pnl>0.0 || !MathIsValidNumber(pnl-volume*cost_per_lot))
        { snapshot.unknown_pending++; continue; }
      snapshot.pending_risk_money+=MathMax(0.0,-pnl+volume*cost_per_lot);
     }
   if(pending!=OrdersTotal()) snapshot.selection_errors++;
   snapshot.daily_valid=ICTReadAccountDayNet(snapshot.daily_net);
   snapshot.daily_opened_valid=ICTReadAccountDayOpenedRisk(cost_per_lot,snapshot.daily_opened_risk_money);
  }

bool ICTLiveEntryBudgetAllowed(const double reference,const double candidate_risk,const double costs,
                                const double portfolio_limit,const double daily_limit,string &reason,
                                const bool require_daily_risk=true)
  {
   SICTPositionRiskSnapshot snapshot;
   ICTReadPositionRiskSnapshot("",ICT_POSITION_CONSERVATIVE,costs,snapshot);
   return ICTPositionEntryBudgetAllowed(snapshot,candidate_risk,reference,portfolio_limit,daily_limit,reason,require_daily_risk);
  }
#endif
