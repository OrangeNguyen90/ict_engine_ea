#ifndef ICT_POSITION_RISK_MQH
#define ICT_POSITION_RISK_MQH

enum ENUM_ICT_POSITION_CAPITAL { ICT_POSITION_BALANCE=0, ICT_POSITION_EQUITY=1 };
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
   double locked_money,locked_percent,target_percent,rr;
  };

struct SICTPositionRiskTotals
  {
   int count,unknown_stops,unknown_targets,unknown_floating,invalid_positions;
   double volume,risk_money,target_money,floating,costs;
  };

struct SICTPositionRiskSnapshot
  {
   datetime observed_at;
   string symbol_filter,currency;
   int currency_digits,selection_errors;
   ENUM_ICT_POSITION_CAPITAL capital_mode;
   double balance,equity,capital,cost_per_lot;
   bool connected;
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

void ICTReadPositionRiskSnapshot(const string symbol_filter,const ENUM_ICT_POSITION_CAPITAL mode,
                                  const double cost_per_lot,SICTPositionRiskSnapshot &snapshot)
  {
   ZeroMemory(snapshot); ArrayResize(snapshot.positions,0);
   snapshot.observed_at=TimeCurrent(); snapshot.symbol_filter=symbol_filter;
   snapshot.currency=AccountInfoString(ACCOUNT_CURRENCY);
   snapshot.currency_digits=(int)MathMax(0,MathMin(8,AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS)));
   snapshot.capital_mode=mode; snapshot.balance=AccountInfoDouble(ACCOUNT_BALANCE);
   snapshot.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   snapshot.capital=(mode==ICT_POSITION_EQUITY ? snapshot.equity : snapshot.balance);
   snapshot.cost_per_lot=cost_per_lot;
   snapshot.connected=TerminalInfoInteger(TERMINAL_CONNECTED)!=0;
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
  }
#endif
