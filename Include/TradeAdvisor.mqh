#ifndef SRMP_TRADE_ADVISOR_MQH
#define SRMP_TRADE_ADVISOR_MQH

#include "MarketStructure.mqh"
#include "LiquidityDetector.mqh"
#include "FVGDetector.mqh"
#include "RiskCalculator.mqh"
#include "ProtectionPersistence.mqh"
#include "AdviceBridge.mqh"
#include "ICTConfluenceEngine.mqh"

struct STradeAdvice
  {
   ENUM_SRMP_ADVICE_STATUS status;
   int      direction;
   datetime signal_bar;
   double   entry;
   double   stop_loss;
   double   take_profit;
   double   invalidation;
   double   atr;
   double   spread_points;
   double   equilibrium;
   double   zone_low;
   double   zone_high;
   SRiskResult risk;
   string   context;
   string   setup_type;
   string   entry_conditions;
   string   reasons;
   string   warnings;
  };

bool SRMPAnalyzeAdvice(const string symbol,
                       const ENUM_TIMEFRAMES context_tf,
                       const ENUM_TIMEFRAMES structure_tf,
                       const ENUM_TIMEFRAMES setup_tf,
                       const ENUM_TIMEFRAMES trigger_tf,
                       const double reference_capital,
                       const double risk_percent,
                       const double max_risk_percent,
                       const double minimum_rr,
                       const double max_spread_points,
                       const double commission_per_lot,
                       const double cost_buffer_per_lot,
                       const double slippage_points,
                       const int max_quote_age_seconds,
                       STradeAdvice &advice,
                       const bool tester_simulated_protection=false,
                       const bool require_latest_structure_bos=true)
  {
   ZeroMemory(advice);
   advice.status=SRMP_NO_TRADE;
   advice.setup_type="PDH/PDL sweep + FVG + BOS";
   advice.entry_conditions="Closed-bar sweep, aligned BOS, unmitigated FVG, price in gap";
   advice.reasons="Data unavailable";
   if(risk_percent<=0.0 || risk_percent>3.0 || max_risk_percent<=0.0 ||
      max_risk_percent>3.0 || minimum_rr<2.0 || max_spread_points<=0.0)
     { advice.reasons="Invalid advisory risk limits"; return false; }
   if(TerminalInfoInteger(TERMINAL_CONNECTED)==0)
     { advice.reasons="Terminal disconnected"; return false; }
   // Simulation is explicitly opt-in and can never bypass live protection.
   bool simulated=(tester_simulated_protection && MQLInfoInteger(MQL_TESTER)!=0);
   if(!simulated && (!GlobalVariableCheck(SRMPGlobalKey("STATE")) ||
      !GlobalVariableCheck(SRMPGlobalKey("HB")) ||
      !GlobalVariableCheck(SRMPGlobalKey("HEALTH")) ||
      !GlobalVariableCheck(SRMPGlobalKey("AUTO")) ||
      TimeLocal()-(datetime)GlobalVariableGet(SRMPGlobalKey("HB"))>3 ||
      (int)GlobalVariableGet(SRMPGlobalKey("STATE"))!=SRMP_NORMAL ||
      GlobalVariableGet(SRMPGlobalKey("AUTO"))<0.5 ||
      (int)GlobalVariableGet(SRMPGlobalKey("HEALTH"))!=0))
     { advice.reasons="Protection offline, unhealthy or locked"; return true; }
   if(reference_capital<=0.0)
     { advice.reasons="Protection reference unavailable"; return false; }

   SMarketStructure context,structure;
   if(!SRMPAnalyzeStructure(symbol,context_tf,120,2,context) ||
      !SRMPAnalyzeStructure(symbol,structure_tf,120,2,structure))
     { advice.reasons="Insufficient closed bars or swing structure"; return false; }
   advice.context=StringFormat("H4 bias=%d, H1 bias=%d, H1 BOS=%d MSS=%d",
                               context.bias,structure.bias,
                               structure.bos_direction,(int)structure.mss);
   if(context.bias==0 || structure.bias!=context.bias)
     { advice.reasons="Multi-timeframe bias not aligned"; return true; }
   advice.direction=context.bias;
   if(require_latest_structure_bos && structure.bos_direction!=advice.direction)
     { advice.status=SRMP_WAIT; advice.reasons="Awaiting closed H1 BOS in bias direction"; return true; }

   int atr_handle=iATR(symbol,structure_tf,14);
   double atr_value[];
   bool atr_ready=(atr_handle!=INVALID_HANDLE &&
                   CopyBuffer(atr_handle,0,1,1,atr_value)==1);
   if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(!atr_ready || atr_value[0]<=0.0)
     { advice.reasons="Closed-bar ATR unavailable"; return false; }
   advice.atr=atr_value[0];

   SFairValueGap gap;
   if(!SRMPFindFVG(symbol,setup_tf,80,advice.atr*0.05,gap))
     { advice.status=SRMP_WAIT; advice.reasons="No confirmed M15 FVG"; return true; }
   if(gap.direction!=advice.direction || gap.mitigated)
     { advice.status=SRMP_WAIT; advice.reasons="FVG direction/mitigation not valid"; return true; }
   advice.zone_low=gap.lower;
   advice.zone_high=gap.upper;
   advice.equilibrium=(structure.recent_high+structure.recent_low)/2.0;
   double gap_mid=(gap.lower+gap.upper)/2.0;
   if((advice.direction==1 && gap_mid>advice.equilibrium) ||
      (advice.direction==-1 && gap_mid<advice.equilibrium))
     { advice.status=SRMP_WAIT; advice.reasons="FVG outside discount/premium zone"; return true; }

   SLiquidityState liquidity;
   if(!SRMPAnalyzeLiquidity(symbol,trigger_tf,structure,advice.atr*0.1,liquidity))
     { advice.reasons="Previous day or trigger candles unavailable"; return false; }
   advice.context+=StringFormat(", equal highs=%d, equal lows=%d",
                                (int)liquidity.equal_highs,(int)liquidity.equal_lows);
   if((advice.direction==1 && !liquidity.bullish_sweep) ||
      (advice.direction==-1 && !liquidity.bearish_sweep))
     { advice.status=SRMP_WAIT; advice.reasons="Awaiting closed PDH/PDL liquidity sweep"; return true; }

   MqlRates trigger[];
   ArraySetAsSeries(trigger,false);
   if(CopyRates(symbol,trigger_tf,1,2,trigger)!=2)
     { advice.reasons="Closed trigger candles unavailable"; return false; }
   advice.signal_bar=trigger[1].time;
   bool confirmed=(advice.direction==1 ? trigger[1].close>trigger[0].high :
                   trigger[1].close<trigger[0].low);
   if(!confirmed)
     { advice.status=SRMP_WAIT; advice.reasons="M5 close has not confirmed trigger"; return true; }

   MqlTick quote;
   if(!SymbolInfoTick(symbol,quote) || quote.ask<=0.0 || quote.bid<=0.0)
     { advice.reasons="Current quote unavailable"; return false; }
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   if(point<=0.0 || tick<=0.0)
     { advice.reasons="Invalid symbol tick specification"; return false; }
   advice.spread_points=(quote.ask-quote.bid)/point;
   if(advice.spread_points>max_spread_points)
     { advice.status=SRMP_WAIT; advice.reasons="Spread above configured limit"; return true; }
   advice.entry=(advice.direction==1 ? quote.ask : quote.bid);
   if(advice.entry<gap.lower || advice.entry>gap.upper)
     { advice.status=SRMP_WAIT; advice.reasons="Current price outside FVG entry zone"; return true; }

   if(advice.direction==1)
     {
      advice.stop_loss=NormalizeDouble(MathFloor((MathMin(liquidity.sweep_extreme,gap.lower)-tick)/tick)*tick,digits);
      advice.take_profit=NormalizeDouble(MathFloor(MathMax(structure.recent_high,
                                      liquidity.previous_day_high)/tick)*tick,digits);
     }
   else
     {
      advice.stop_loss=NormalizeDouble(MathCeil((MathMax(liquidity.sweep_extreme,gap.upper)+tick)/tick)*tick,digits);
      advice.take_profit=NormalizeDouble(MathCeil(MathMin(structure.recent_low,
                                      liquidity.previous_day_low)/tick)*tick,digits);
     }
   advice.invalidation=advice.stop_loss;
   ENUM_RM_DIRECTION risk_direction=(advice.direction==1 ? RM_BUY : RM_SELL);
   if(!CalculateRisk(symbol,risk_direction,advice.entry,advice.stop_loss,
                     advice.take_profit,reference_capital,risk_percent,
                     max_risk_percent,minimum_rr,commission_per_lot,
                     cost_buffer_per_lot,slippage_points,max_quote_age_seconds,
                     advice.risk))
     {
      advice.status=SRMP_NO_TRADE;
      advice.reasons="Risk gate: "+advice.risk.reason;
      return true;
     }
   advice.status=SRMP_TRADE_READY;
   advice.reasons="Aligned closed-bar structure, sweep, FVG, trigger and risk gates";
   advice.warnings="Advisory only; RR is not win probability";
   return true;
  }

// ICT context is informational until it agrees with a fully risk-gated
// Phase 3 plan. It cannot upgrade a blocked plan to a trade recommendation.
bool SRMPAnalyzeAdviceWithICT(const string symbol,
                       const ENUM_TIMEFRAMES context_tf,
                       const ENUM_TIMEFRAMES structure_tf,
                       const ENUM_TIMEFRAMES setup_tf,
                       const ENUM_TIMEFRAMES trigger_tf,
                       const double reference_capital,
                       const double risk_percent,
                       const double max_risk_percent,
                       const double minimum_rr,
                       const double max_spread_points,
                       const double commission_per_lot,
                       const double cost_buffer_per_lot,
                       const double slippage_points,
                       const int max_quote_age_seconds,
                       const SICTSettings &settings,
                       STradeAdvice &advice,SICTSnapshot &ict)
  {
   bool analyzed=SRMPAnalyzeAdvice(symbol,context_tf,structure_tf,
                       setup_tf,trigger_tf,reference_capital,risk_percent,
                       max_risk_percent,minimum_rr,max_spread_points,
                       commission_per_lot,cost_buffer_per_lot,
                       slippage_points,max_quote_age_seconds,advice);
   SRMPAnalyzeICT(symbol,settings,ict);
   if(advice.status==SRMP_TRADE_READY && ict.ob_available &&
      ict.ob.state==SRMP_OB_CONFIRMED &&
      ict.ob.direction==advice.direction &&
      advice.entry>=ict.ob.lower && advice.entry<=ict.ob.upper &&
      ict.recommendation==SRMP_ICT_WAIT_RETRACE)
      ict.recommendation=(advice.direction>0 ? SRMP_ICT_BULLISH_SETUP :
                                               SRMP_ICT_BEARISH_SETUP);
   return analyzed;
  }

#endif
