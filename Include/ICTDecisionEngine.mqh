#ifndef SRMP_ICT_DECISION_ENGINE_MQH
#define SRMP_ICT_DECISION_ENGINE_MQH

#include "MarketStructure.mqh"
#include "LiquidityDetector.mqh"
#include "FVGDetector.mqh"
#include "RiskCalculator.mqh"
#include "ICTPositionRisk.mqh"
#include "ProtectionPersistence.mqh"
#include "SMTDivergenceDetector.mqh"
#include "ICTConfluenceScore.mqh"
#include "OrderBlockValidator.mqh"
#include "ICTSessionManager.mqh"
#include "ICTRangeEngine.mqh"
#ifdef ICT_SMART_ENGINE
#include "ICTTimeframeMapper.mqh"
#endif

// Project-defined, conservative interpretation of ICT terminology.
// All detected bars are closed. A state is a fresh observation, not a forecast.
enum ENUM_ICT_DECISION_STATE
  {
   ICT_NO_TRADE=0, ICT_WATCH=1, ICT_FORMING=2,
   ICT_WAIT_CONFIRMATION=3, ICT_ENTRY_READY=4,
   ICT_INVALIDATED=5, ICT_TRADE_ACTIVE=6, ICT_RISK_BLOCKED=7
  };

struct SICTDecisionConfig
  {
   ENUM_TIMEFRAMES higher_tf;
   ENUM_TIMEFRAMES structure_tf;
   ENUM_TIMEFRAMES setup_tf;
   ENUM_TIMEFRAMES trigger_tf;
   ENUM_TIMEFRAMES smt_tf;
   string comparison1;
   string comparison2;
   int lookback;
   int swing_strength;
   int max_setup_bars;
   double displacement_body_atr;
   double displacement_body_fraction;
   double min_gap_atr;
   double max_spread_points;
   double risk_percent;
   double max_risk_percent;
   double min_rr;
   double commission_per_lot;
   double cost_buffer_per_lot;
   double slippage_points;
   double daily_loss_limit_percent; // Required: >0 and <=6%, per user's account policy.
   bool daily_risk_budget_enabled;
   double portfolio_risk_limit_percent; // 0 disables the aggregate new-entry gate.
   int max_quote_age_seconds;
  };

struct SICTEntryZone { double low; double high; };

struct SICTDecision
  {
   ENUM_ICT_DECISION_STATE state;
   int direction;
   int score;
   int monthly_bias;
   int weekly_bias;
   int daily_bias;
   int higher_bias;
   int structure_bias;
   datetime as_of;
   datetime sweep_time;
   datetime mss_time;
   datetime fvg_time;
   double dol;
   string dol_name;
   double sweep_level;
   double entry;
   double stop;
   double target;
   double zone_low;
   double zone_high;
   double consequent_encroachment;
   double daily_net;
   double portfolio_stop_risk;
   int portfolio_unknown_stops;
   int correlated_positions;
   SRiskResult risk;
   string reason;
   int buy_score;
   int sell_score;
   ENUM_ICT_PRIORITY priority;
   uint buy_confirmed;
   uint sell_confirmed;
   uint buy_missing;
   uint sell_missing;
   uint required;
   uint confirmed;
   uint missing;
   bool hard_filters_passed;
   bool data_quality_ok;
   string data_quality;
   string invalidation;
   string hard_filter_reason;
   string signal_id;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime timestamp;
   int directional_bias;
   ENUM_ICT_PRIORITY decision;
   string setup_type;
   string required_conditions;
   string confirmed_conditions;
   string missing_conditions;
   string invalidation_reason;
   SICTEntryZone entry_zone;
   double stop_loss;
   double take_profit;
   double take_profit2;
   double risk_reward;
   string data_quality_status;
   bool strong_signal;
   datetime zone_time;
   double target2;
   string target2_name;
   string optional_data_notes;
   double dealing_low;
   double dealing_high;
   double equilibrium;
   string price_location;
   bool entry_confirmed;
   datetime confirmation_time;
  };

string ICTStateText(const ENUM_ICT_DECISION_STATE state)
  {
   switch(state)
     {
      case ICT_WATCH: return "WATCH";
      case ICT_FORMING: return "SETUP FORMING";
      case ICT_WAIT_CONFIRMATION: return "WAIT FOR CONFIRMATION";
      case ICT_ENTRY_READY: return "ENTRY READY";
      case ICT_INVALIDATED: return "ENTRY INVALIDATED";
      case ICT_TRADE_ACTIVE: return "TRADE ACTIVE";
      case ICT_RISK_BLOCKED: return "RISK BLOCKED";
      default: return "NO TRADE";
     }
  }

bool ICTBarsValid(const string symbol,const ENUM_TIMEFRAMES tf,const int count)
  {
   if(count<3) return false;
   MqlRates bars[];
   ArraySetAsSeries(bars,false);
   if(CopyRates(symbol,tf,1,count,bars)!=count) return false;
   for(int i=0;i<count;i++)
     {
      if(!SRMPValidDetectorBar(bars[i]) || bars[i].time+PeriodSeconds(tf)>TimeTradeServer() || bars[i].low<=0.0 ||
         bars[i].high<bars[i].low || bars[i].open<bars[i].low ||
         bars[i].open>bars[i].high || bars[i].close<bars[i].low ||
         bars[i].close>bars[i].high) return false;
      if(i>0 && bars[i].time<=bars[i-1].time) return false;
     }
   return true;
  }

bool ICTProtectionReady(double &reference)
  {
   reference=0.0;
   if(!GlobalVariableCheck(SRMPGlobalKey("HB")) ||
      !GlobalVariableCheck(SRMPGlobalKey("STATE")) ||
      !GlobalVariableCheck(SRMPGlobalKey("HEALTH")) ||
      !GlobalVariableCheck(SRMPGlobalKey("AUTO")) ||
      !GlobalVariableCheck(SRMPGlobalKey("REF"))) return false;
   if((datetime)GlobalVariableGet(SRMPGlobalKey("HB"))>TimeLocal() ||
      TimeLocal()-(datetime)GlobalVariableGet(SRMPGlobalKey("HB"))>3 ||
      (int)GlobalVariableGet(SRMPGlobalKey("STATE"))!=SRMP_NORMAL ||
      GlobalVariableGet(SRMPGlobalKey("AUTO"))<0.5 ||
      (int)GlobalVariableGet(SRMPGlobalKey("HEALTH"))!=0) return false;
   reference=GlobalVariableGet(SRMPGlobalKey("REF"));
   return reference>0.0;
  }

void ICTConsiderTarget(const int direction,const double price,const double level,
                       const string name,double &best,string &best_name)
  {
   if(level<=0.0) return;
   if(direction>0 && level<=price) return;
   if(direction<0 && level>=price) return;
   if(best==0.0 || MathAbs(level-price)<MathAbs(best-price))
     { best=level; best_name=name; }
  }

bool ICTDrawOnLiquidity(const string symbol,const int direction,const double price,
                        const SMarketStructure &structure,double &target,string &name,
                        double &target2,string &name2)
  {
   target=0.0; name=""; target2=0.0; name2="";
   MqlRates day[],week[],month[];
   if(CopyRates(symbol,PERIOD_D1,1,1,day)!=1 ||
      CopyRates(symbol,PERIOD_W1,1,1,week)!=1 ||
      CopyRates(symbol,PERIOD_MN1,1,1,month)!=1) return false;
   ICTRankTarget(direction,price,direction>0 ? day[0].high : day[0].low,
                     direction>0 ? "PDH" : "PDL",target,name,target2,name2);
   ICTRankTarget(direction,price,direction>0 ? week[0].high : week[0].low,
                     direction>0 ? "PWH" : "PWL",target,name,target2,name2);
   ICTRankTarget(direction,price,direction>0 ? month[0].high : month[0].low,
                     direction>0 ? "PMH" : "PML",target,name,target2,name2);
   ICTRankTarget(direction,price,direction>0 ? structure.recent_high : structure.recent_low,
                     direction>0 ? "Swing high" : "Swing low",target,name,target2,name2);
   return target>0.0;
  }

bool ICTDisplacementAt(const string symbol,const ENUM_TIMEFRAMES tf,
                       const datetime fvg_bar,const int direction,
                       const double min_body_atr,const double min_fraction,
                       const int candle_offset=1)
  {
   int shift=iBarShift(symbol,tf,fvg_bar,true);
   if(shift<1) return false;
   MqlRates middle[];
   if(CopyRates(symbol,tf,shift+candle_offset,1,middle)!=1) return false;
   int handle=iATR(symbol,tf,14);
   double atr[];
   bool ready=(handle!=INVALID_HANDLE &&
               CopyBuffer(handle,0,shift+candle_offset,1,atr)==1 && atr[0]>0.0);
   if(handle!=INVALID_HANDLE) IndicatorRelease(handle);
   if(!ready) return false;
   double body=middle[0].close-middle[0].open;
   double range=middle[0].high-middle[0].low;
   return (range>0.0 && body*direction>0.0 &&
           MathAbs(body)>=atr[0]*min_body_atr &&
           MathAbs(body)/range>=min_fraction);
  }

bool ICTMatchingPosition(const string symbol,const int direction,
                         const double zone_low,const double zone_high,
                         const double stop,const double tick)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=symbol) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if((direction>0 && type==POSITION_TYPE_BUY) ||
         (direction<0 && type==POSITION_TYPE_SELL))
        {
         double opened=PositionGetDouble(POSITION_PRICE_OPEN);
         double position_sl=PositionGetDouble(POSITION_SL);
         if(opened>=zone_low && opened<=zone_high && position_sl>0.0 &&
            MathAbs(position_sl-stop)<=tick*2.0) return true;
        }
     }
   return false;
  }

bool ICTDailyLossAllowed(const double reference,const double limit_percent,
                         double &net)
  {
   net=0.0;
   if(!MathIsValidNumber(limit_percent) || limit_percent<=0.0 || limit_percent>6.0) return false;
   if(!ICTPositionCapitalValid(reference) || !ICTReadAccountDayNet(net)) return false;
   return net>-(reference*limit_percent/100.0);
  }

void ICTAssessPortfolio(const string symbol,const SICTDecisionConfig &cfg,
                        const int direction,SICTDecision &d)
  {
   SSymbolCorrelation first,second;
   datetime asof=iTime(symbol,cfg.smt_tf,1);
   bool first_ready=(cfg.comparison1!="" &&
      SRMPCalculateCorrelation(symbol,cfg.comparison1,cfg.smt_tf,100,60,
                               0.60,asof,first));
   bool second_ready=(cfg.comparison2!="" &&
      SRMPCalculateCorrelation(symbol,cfg.comparison2,cfg.smt_tf,100,60,
                               0.60,asof,second));
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      if(PositionGetTicket(i)==0) continue;
      string held=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);
      int held_direction=(type==POSITION_TYPE_BUY ? 1 : -1);
      double stop=PositionGetDouble(POSITION_SL);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double opened=PositionGetDouble(POSITION_PRICE_OPEN);
      double pnl=0.0;
      if(stop<=0.0 || volume<=0.0 ||
         !OrderCalcProfit(type==POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                          held,volume,opened,stop,pnl))
         d.portfolio_unknown_stops++;
      else if(pnl<0.0) d.portfolio_stop_risk-=pnl;
      if(held==symbol && held_direction==direction)
         d.correlated_positions++;
      else if(first_ready && held==cfg.comparison1 &&
              first.state!=SMT_CORR_WEAK &&
              held_direction*(first.coefficient>0.0 ? 1 : -1)==direction)
         d.correlated_positions++;
      else if(second_ready && held==cfg.comparison2 &&
              second.state!=SMT_CORR_WEAK &&
              held_direction*(second.coefficient>0.0 ? 1 : -1)==direction)
         d.correlated_positions++;
     }
  }

// Directional candidates use the shared FVG lifecycle and OB validator.
// The legacy shared finders select one side; these searches never allow an
// opposite-side candidate to conceal this direction's active zone.
bool ICTFindZoneFVG(const string symbol,const ENUM_TIMEFRAMES tf,const int lookback,
                    const double min_gap,const int direction,SFairValueGap &gap)
  {
   return SRMPFindFVG(symbol,tf,lookback,min_gap,gap,direction) && !gap.mitigated;
  }

bool ICTFindZoneOB(const string symbol,const ENUM_TIMEFRAMES tf,const int lookback,
                   const int expiry,const int direction,SOrderBlock &block)
  {
   return SRMPFindOrderBlock(symbol,tf,lookback,SRMP_OB_HYBRID,1.2,3,block,
                             direction,true,expiry);
  }
bool ICTAnalyzeDecisionCore(const string symbol,const SICTDecisionConfig &cfg,
                        const SICTConfluenceConfig &scoring,SICTDecision &d)
  {
   ZeroMemory(d);
   d.state=ICT_NO_TRADE;
   d.reason="Insufficient confirmed evidence";
   d.as_of=iTime(symbol,cfg.trigger_tf,1);
   if(cfg.lookback<40 || cfg.swing_strength<1 || cfg.max_setup_bars<1 ||
      cfg.displacement_body_atr<=0.0 || cfg.displacement_body_fraction<=0.0 ||
      cfg.displacement_body_fraction>1.0 || cfg.min_gap_atr<=0.0 ||
      cfg.min_rr<2.0 || cfg.max_spread_points<=0.0 ||
      cfg.max_quote_age_seconds<1 || !MathIsValidNumber(cfg.daily_loss_limit_percent) ||
      cfg.daily_loss_limit_percent<=0.0 || cfg.daily_loss_limit_percent>6.0 ||
      !MathIsValidNumber(cfg.portfolio_risk_limit_percent) || cfg.portfolio_risk_limit_percent<0.0 ||
      cfg.portfolio_risk_limit_percent>100.0 ||
      cfg.risk_percent<=0.0 ||
      cfg.risk_percent>cfg.max_risk_percent || cfg.max_risk_percent>3.0)
     { d.reason="Invalid configuration"; return false; }
   if(d.as_of<=0 || !ICTBarsValid(symbol,cfg.trigger_tf,12) ||
      !ICTBarsValid(symbol,cfg.setup_tf,cfg.lookback) ||
      !ICTBarsValid(symbol,cfg.higher_tf,cfg.lookback) ||
      !ICTBarsValid(symbol,cfg.structure_tf,cfg.lookback) ||
      !ICTBarsValid(symbol,PERIOD_D1,120))
     { d.reason="Missing, duplicate or invalid closed candles"; return false; }
   SMarketStructure higher,structure;
   SMarketStructure monthly,weekly,daily;
   if(SRMPAnalyzeStructure(symbol,PERIOD_MN1,40,cfg.swing_strength,monthly))
      d.monthly_bias=monthly.bias;
   if(SRMPAnalyzeStructure(symbol,PERIOD_W1,80,cfg.swing_strength,weekly))
      d.weekly_bias=weekly.bias;
   if(!SRMPAnalyzeStructure(symbol,PERIOD_D1,120,cfg.swing_strength,daily))
     { d.reason="Required D1 structure unavailable"; return false; }
   d.daily_bias=daily.bias;
   if(!SRMPAnalyzeStructure(symbol,cfg.higher_tf,cfg.lookback,cfg.swing_strength,higher) ||
      !SRMPAnalyzeStructure(symbol,cfg.structure_tf,cfg.lookback,cfg.swing_strength,structure))
     { d.reason="Higher-timeframe structure unavailable"; return false; }
   d.higher_bias=higher.bias;
   d.structure_bias=structure.bias;
   d.dealing_low=structure.recent_low; d.dealing_high=structure.recent_high;
   d.equilibrium=(d.dealing_low+d.dealing_high)/2.0;
   if(ICTContextConflict(d.daily_bias,higher.bias,structure.bias,structure.bos_direction,structure.mss))
     { d.reason="Severe D1/HTF/LTF structure conflict"; return true; }
   if(higher.bias==0)
     { d.state=ICT_WATCH; d.reason="HTF bias is neutral"; return true; }
   d.direction=higher.bias;
   d.score+=(structure.bias==higher.bias ? 10 : 5);
   ICTAssessPortfolio(symbol,cfg,d.direction,d);
   MqlTick quote;
   if(!SymbolInfoTick(symbol,quote) || !ICTQuoteValidAt(quote,TimeTradeServer(),cfg.max_quote_age_seconds))
     { d.state=ICT_RISK_BLOCKED; d.reason="Quote unavailable, inverted, future or stale"; return false; }
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(point<=0.0 || tick<=0.0)
     { d.reason="Invalid symbol specification"; return false; }
   double current_price=(d.direction>0 ? quote.ask : quote.bid);
   d.price_location=(current_price<d.equilibrium ? "DISCOUNT" :
                     (current_price>d.equilibrium ? "PREMIUM" : "EQUILIBRIUM"));
   if(!ICTDrawOnLiquidity(symbol,d.direction,current_price,structure,d.dol,d.dol_name,d.target2,d.target2_name))
     { d.state=ICT_WATCH; d.reason="No eligible DOL target"; return true; }
   d.score+=10;
   SLiquidityState liquidity;
   if(!SRMPAnalyzeLiquidity(symbol,cfg.trigger_tf,structure,0.0,liquidity))
     { d.reason="Liquidity history unavailable"; return false; }
   if(!ICTFindDirectionalSweep(symbol,cfg.trigger_tf,cfg.max_setup_bars,d.direction,liquidity))
     { d.reason="Incomplete sweep history"; return false; }
   if(liquidity.recent_sweep_direction!=d.direction ||
      liquidity.recent_sweep_time<=0)
     { d.state=ICT_WATCH; d.reason="Awaiting aligned confirmed liquidity sweep"; return true; }
   d.sweep_time=liquidity.recent_sweep_time;
   d.sweep_level=liquidity.recent_sweep_level;
   d.score+=15;
   int age=iBarShift(symbol,cfg.trigger_tf,d.sweep_time,true);
   if(age<1 || age>cfg.max_setup_bars)
     { d.state=ICT_INVALIDATED; d.reason="Sweep expired"; return true; }
   datetime sweep_confirmed=d.sweep_time+(datetime)PeriodSeconds(cfg.trigger_tf);
   datetime mss_confirmed=structure.bos_time+(datetime)PeriodSeconds(cfg.structure_tf);
   if(structure.bos_direction!=d.direction ||
      mss_confirmed<sweep_confirmed ||
      !structure.mss)
     { d.state=ICT_FORMING; d.reason="Awaiting post-sweep MSS"; return true; }
   d.mss_time=structure.bos_time;
   d.score+=15;
   int atr_handle=iATR(symbol,cfg.setup_tf,14);
   double atr[];
   bool atr_ok=(atr_handle!=INVALID_HANDLE &&
                CopyBuffer(atr_handle,0,1,1,atr)==1 && atr[0]>0.0);
   if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(!atr_ok) { d.reason="ATR unavailable"; return false; }
   SFairValueGap gap;
   SOrderBlock block;
   bool fvg_ready=ICTFindZoneFVG(symbol,cfg.setup_tf,cfg.lookback,
                                  atr[0]*cfg.min_gap_atr,d.direction,gap) &&
                  !gap.mitigated &&
                  gap.formed_time+(datetime)PeriodSeconds(cfg.setup_tf)>=mss_confirmed;
   bool ob_ready=ICTFindZoneOB(symbol,cfg.setup_tf,cfg.lookback,cfg.max_setup_bars,
                               d.direction,block) &&
                 block.confirmation_time+(datetime)PeriodSeconds(cfg.setup_tf)>=mss_confirmed;
   bool use_fvg=(scoring.entry_zone_mode!=ICT_ZONE_OB_ONLY && fvg_ready);
   bool use_ob=(!use_fvg && scoring.entry_zone_mode!=ICT_ZONE_FVG_ONLY && ob_ready);
   if(!use_fvg && !use_ob)
     { d.state=ICT_WAIT_CONFIRMATION;
       d.reason=(scoring.entry_zone_mode==ICT_ZONE_OB_ONLY ?
                 "Awaiting post-MSS active Order Block" :
                 "Awaiting post-MSS active FVG or Order Block");
       return true; }
   datetime zone_time=(use_fvg ? gap.formed_time : block.confirmation_time);
   int zone_age=iBarShift(symbol,cfg.setup_tf,zone_time,true);
   if(zone_age<1 || zone_age>cfg.max_setup_bars)
     { d.state=ICT_INVALIDATED; d.reason="Entry zone expired"; return true; }
   d.fvg_time=(use_fvg ? gap.formed_time : 0);
   d.zone_time=zone_time;
   d.zone_low=(use_fvg ? gap.lower : block.lower);
   d.zone_high=(use_fvg ? gap.upper : block.upper);
   d.consequent_encroachment=(d.zone_low+d.zone_high)/2.0;
   if(use_fvg && !ICTDisplacementAt(symbol,cfg.setup_tf,gap.formed_time,d.direction,
                                     cfg.displacement_body_atr,cfg.displacement_body_fraction))
     { d.state=ICT_WAIT_CONFIRMATION; d.reason="Displacement not confirmed"; return true; }
   if(use_ob && !ICTDisplacementAt(symbol,cfg.setup_tf,block.confirmation_time,d.direction,
                                    cfg.displacement_body_atr,cfg.displacement_body_fraction,0))
     { d.state=ICT_WAIT_CONFIRMATION; d.reason="OB displacement not confirmed"; return true; }
   double equilibrium=(structure.recent_high+structure.recent_low)/2.0;
   double midpoint=d.consequent_encroachment;
   if((d.direction>0 && midpoint>equilibrium) ||
      (d.direction<0 && midpoint<equilibrium))
     { d.state=ICT_WAIT_CONFIRMATION; d.reason="FVG outside discount/premium"; return true; }
   d.score+=10;
   d.entry=current_price;
   if(d.entry<d.zone_low || d.entry>d.zone_high)
     { d.state=ICT_WAIT_CONFIRMATION;
       d.reason=(use_fvg ? "Awaiting FVG retest" : "Awaiting Order Block retest"); return true; }
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   d.stop=(d.direction>0 ?
           NormalizeDouble(MathFloor((MathMin(liquidity.recent_sweep_extreme,d.zone_low)-tick)/tick)*tick,digits) :
           NormalizeDouble(MathCeil((MathMax(liquidity.recent_sweep_extreme,d.zone_high)+tick)/tick)*tick,digits));
   d.target=d.dol;
   if(d.direction>0 ? (d.stop>=d.entry || d.target<=d.entry) :
                      (d.stop<=d.entry || d.target>=d.entry))
     { d.state=ICT_INVALIDATED; d.reason="Entry/stop/target geometry invalid"; return true; }
   if(ICTMatchingPosition(symbol,d.direction,d.zone_low,d.zone_high,d.stop,tick))
     { d.state=ICT_TRADE_ACTIVE; d.reason="Matching account position is active"; return true; }
   double reference=0.0;
   if(TerminalInfoInteger(TERMINAL_CONNECTED)==0 || !ICTProtectionReady(reference))
     { d.state=ICT_RISK_BLOCKED; d.reason="Protection offline, unhealthy or locked"; return true; }
   if((quote.ask-quote.bid)/point>cfg.max_spread_points)
     { d.state=ICT_RISK_BLOCKED; d.reason="Spread exceeds limit"; return true; }
   reference=ICTConservativeRiskCapital(reference,AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY));
   if(!ICTDailyLossAllowed(reference,cfg.daily_loss_limit_percent,d.daily_net))
     { d.state=ICT_RISK_BLOCKED;
       d.reason="Daily loss limit or account history unavailable"; return true; }
   ENUM_RM_DIRECTION side=(d.direction>0 ? RM_BUY : RM_SELL);
   if(!CalculateRisk(symbol,side,d.entry,d.stop,d.target,reference,
                     cfg.risk_percent,cfg.max_risk_percent,cfg.min_rr,
                     cfg.commission_per_lot,cfg.cost_buffer_per_lot,
                     cfg.slippage_points,cfg.max_quote_age_seconds,d.risk))
     { d.state=ICT_RISK_BLOCKED; d.reason="Risk gate: "+d.risk.reason; return true; }
   if(!ICTLiveEntryBudgetAllowed(reference,d.risk.risk_money,cfg.commission_per_lot+cfg.cost_buffer_per_lot,
      cfg.portfolio_risk_limit_percent,cfg.daily_loss_limit_percent,d.reason,cfg.daily_risk_budget_enabled))
     { d.state=ICT_RISK_BLOCKED; d.risk.valid=false; return true; }
   d.score+=5;
   d.state=ICT_ENTRY_READY;
   d.reason="Confirmed sweep, MSS, displacement, entry-zone retest, DOL and risk gates";
   return true;
  }

// Independent evidence is descriptive. Chronology, retest, geometry and risk
// remain hard prerequisites in ICTAnalyzeDecisionCore and cannot be bought
// with a high score. No order execution occurs in either function.
// Directional equivalent of the shared sweep search: an opposite-side sweep
// must not hide this side's most recent qualifying observation.
bool ICTFindDirectionalSweep(const string symbol,const ENUM_TIMEFRAMES tf,
                             const int lookback,const int direction,SLiquidityState &state)
  {
   // SRMPAnalyzeLiquidity may already contain the latest sweep of the other
   // side. Clear the directional observation fields before searching so an
   // opposite-side result cannot masquerade as evidence for this direction.
   state.recent_sweep_time=0;
   state.recent_sweep_direction=0;
   state.recent_sweep_level=0.0;
   state.recent_sweep_extreme=0.0;
   state.recent_sweep_daily=false;
   MqlRates bars[];
   ArraySetAsSeries(bars,false);
   int count=CopyRates(symbol,tf,1,lookback+10,bars);
   if(count<lookback+10 || !SRMPValidDetectorRates(bars,count)) return false;
   for(int i=count-1;i>=10;i--)
     {
      double high=0,low=0;
      bool daily=SRMPPriorDayLevelsAt(symbol,bars[i].time,high,low);
      bool up=daily && bars[i].low<low && bars[i].close>low;
      bool down=daily && bars[i].high>high && bars[i].close<high;
      if(up && down) continue;
      if(!up && !down)
        {
         high=bars[i-1].high; low=bars[i-1].low;
         for(int j=i-10;j<i;j++)
           { high=MathMax(high,bars[j].high); low=MathMin(low,bars[j].low); }
         up=bars[i].low<low && bars[i].close>low;
         down=bars[i].high>high && bars[i].close<high;
         daily=false;
        }
      if(up==down || (direction>0 ? !up : !down)) continue;
      state.recent_sweep_time=bars[i].time;
      state.recent_sweep_direction=direction;
      state.recent_sweep_level=(direction>0 ? low : high);
      state.recent_sweep_extreme=(direction>0 ? bars[i].low : bars[i].high);
      state.recent_sweep_daily=daily;
      break;
     }
   return true; // Complete history, including a valid absence of a sweep.
  }

uint ICTCollectEvidence(const string symbol,const SICTDecisionConfig &cfg,
                        const SICTConfluenceConfig &scoring,const int direction,bool &quality)
  {
   uint evidence=0;
   quality=true;
   SMarketStructure higher,structure,daily;
   ZeroMemory(higher); ZeroMemory(structure);
   bool h=SRMPAnalyzeStructure(symbol,cfg.higher_tf,cfg.lookback,cfg.swing_strength,higher);
   bool s=SRMPAnalyzeStructure(symbol,cfg.structure_tf,cfg.lookback,cfg.swing_strength,structure);
   bool daily_ok=SRMPAnalyzeStructure(symbol,PERIOD_D1,120,cfg.swing_strength,daily);
   if(!h || !s || !daily_ok) quality=false;
   if(h && daily_ok && higher.bias==direction &&
      (daily.bias==0 || daily.bias==direction)) evidence|=ICT_E_HTF;
   SLiquidityState liquidity;
   bool l=SRMPAnalyzeLiquidity(symbol,cfg.trigger_tf,structure,0.0,liquidity);
   if(!l) quality=false;
   else
     {
      if(!ICTFindDirectionalSweep(symbol,cfg.trigger_tf,cfg.max_setup_bars,direction,liquidity))
         quality=false;
      int age=iBarShift(symbol,cfg.trigger_tf,liquidity.recent_sweep_time,true);
      if(liquidity.recent_sweep_direction==direction && age>=1 && age<=cfg.max_setup_bars)
         evidence|=ICT_E_SWEEP;
     }
   if(s && (evidence&ICT_E_SWEEP)!=0 && structure.mss && structure.bos_direction==direction &&
      structure.bos_time+PeriodSeconds(cfg.structure_tf)>=
      liquidity.recent_sweep_time+PeriodSeconds(cfg.trigger_tf)) evidence|=ICT_E_MSS;
   int handle=iATR(symbol,cfg.setup_tf,14);
   double atr[];
   bool a=handle!=INVALID_HANDLE && CopyBuffer(handle,0,1,1,atr)==1 && atr[0]>0;
   if(handle!=INVALID_HANDLE) IndicatorRelease(handle);
   if(!a) quality=false;
   SFairValueGap gap;
   if(a && ICTFindZoneFVG(symbol,cfg.setup_tf,cfg.lookback,atr[0]*cfg.min_gap_atr,direction,gap))
     {
      int age=iBarShift(symbol,cfg.setup_tf,gap.formed_time,true);
      if(age>=1 && age<=cfg.max_setup_bars)
        {
         evidence|=ICT_E_FVG;
         if(ICTDisplacementAt(symbol,cfg.setup_tf,gap.formed_time,direction,
                              cfg.displacement_body_atr,cfg.displacement_body_fraction))
            evidence|=ICT_E_DISPLACEMENT;
         double mid=(gap.lower+gap.upper)/2.0;
         double eq=(structure.recent_high+structure.recent_low)/2.0;
         if(s && (direction>0 ? mid<=eq : mid>=eq)) evidence|=ICT_E_PD;
        }
     }
   SOrderBlock block;
   if(ICTFindZoneOB(symbol,cfg.setup_tf,cfg.lookback,cfg.max_setup_bars,direction,block))
     {
      evidence|=ICT_E_OB;
      if(ICTDisplacementAt(symbol,cfg.setup_tf,block.confirmation_time,direction,
                            cfg.displacement_body_atr,cfg.displacement_body_fraction,0))
         evidence|=ICT_E_DISPLACEMENT;
      double eq=(structure.recent_high+structure.recent_low)/2.0;
      if(s && (direction>0 ? block.midpoint<=eq : block.midpoint>=eq)) evidence|=ICT_E_PD;
     }
   for(int i=0;i<2;i++)
     {
      string comparison=(i==0 ? cfg.comparison1 : cfg.comparison2);
      if(comparison=="") continue;
      SSMTDivergence smt;
      if(SRMPFindSMT(symbol,comparison,cfg.smt_tf,cfg.lookback,cfg.swing_strength,
                     cfg.swing_strength,SMT_AUTO,100,60,0.60,3,smt))
        {
         int age=iBarShift(symbol,cfg.smt_tf,smt.confirmation_time,false);
         if(smt.confirmation_time>0 && smt.confirmation_time<=TimeTradeServer() &&
            smt.direction==direction && age>=0 && age<=cfg.max_setup_bars)
            evidence|=ICT_E_SMT;
        }
      // SMT is optional unless configured as mandatory. Its unavailable state
      // is represented by the missing evidence bit rather than corrupting the
      // underlying price-data quality.
     }
   bool session=false;
   ICTNewYorkSession(ICTSessionUTC(scoring.tester_broker_utc_offset_minutes),session);
   if(session) evidence|=ICT_E_SESSION;
   return evidence;
  }

bool ICTAnalyzeDecision(const string symbol,const SICTDecisionConfig &cfg,
                        const SICTConfluenceConfig &scoring,SICTDecision &d,
                        const uint unified_buy=0,const uint unified_sell=0,const bool external_analysis=false)
  {
   if(!ICTValidConfluenceConfig(scoring))
     {
      ZeroMemory(d); d.reason="Invalid confluence configuration";
      d.data_quality=d.reason; d.hard_filter_reason=d.reason; return false;
     }
   bool ok=ICTAnalyzeDecisionCore(symbol,cfg,scoring,d);
   d.required=ICTRequiredEvidence(scoring);
   bool buy_quality=false,sell_quality=false;
   // A failed gate must not erase otherwise observable evidence on either side.
   // Only unsafe detector parameters prevent collection, never a risk outcome.
   if(cfg.lookback>=40 && cfg.swing_strength>=1 && cfg.max_setup_bars>=1 &&
      cfg.min_gap_atr>0 && cfg.displacement_body_atr>0 && cfg.displacement_body_fraction>0)
     {
      d.buy_confirmed=ICTCollectEvidence(symbol,cfg,scoring,1,buy_quality);
      d.sell_confirmed=ICTCollectEvidence(symbol,cfg,scoring,-1,sell_quality);
     }
   if(external_analysis)
     {
      d.buy_confirmed=(d.buy_confirmed & ~(ICT_E_SMT|ICT_E_OB)) | (unified_buy & (ICT_E_SMT|ICT_E_OB));
      d.sell_confirmed=(d.sell_confirmed & ~(ICT_E_SMT|ICT_E_OB)) | (unified_sell & (ICT_E_SMT|ICT_E_OB));
     }
   d.buy_score=ICTWeightedScore(d.buy_confirmed,scoring);
   d.sell_score=ICTWeightedScore(d.sell_confirmed,scoring);
   d.buy_missing=d.required & ~d.buy_confirmed;
   d.sell_missing=d.required & ~d.sell_confirmed;
   MqlTick quote;
   if(!SymbolInfoTick(symbol,quote) || !ICTQuoteValidAt(quote,TimeTradeServer(),cfg.max_quote_age_seconds))
     {
      ok=false; d.state=ICT_RISK_BLOCKED;
      d.reason="Quote unavailable, inverted, future or stale";
     }
   d.data_quality_ok=ok && buy_quality && sell_quality;
   d.data_quality=(d.data_quality_ok ? "Closed-bar inputs available; session uses explicit UTC conversion in Tester" :
                    "Missing or invalid inputs; see reason and evidence masks");
   d.confirmed=(d.direction>0 ? d.buy_confirmed : (d.direction<0 ? d.sell_confirmed : 0));
   d.missing=d.required & ~d.confirmed;
   d.score=(d.direction>0 ? d.buy_score : (d.direction<0 ? d.sell_score : 0));
   if(d.state==ICT_INVALIDATED) d.invalidation=d.reason;
   if(d.state==ICT_ENTRY_READY &&
      ((scoring.mandatory_smt && (d.confirmed&ICT_E_SMT)==0) ||
       (scoring.mandatory_session && (d.confirmed&ICT_E_SESSION)==0)))
     { d.state=ICT_WAIT_CONFIRMATION; d.reason="Mandatory SMT/session evidence missing"; }
   d.hard_filters_passed=(ok && d.state==ICT_ENTRY_READY);
   d.priority=ICTPlanPriority(d.buy_score,d.sell_score,d.hard_filters_passed,
                              d.data_quality_ok,d.direction,d.confirmed,scoring);
   if(d.state==ICT_ENTRY_READY && d.priority==ICT_PRIORITY_WAIT)
     { d.state=ICT_WAIT_CONFIRMATION;
       d.reason="Missing required evidence, score threshold or directional conflict"; }
   d.hard_filters_passed=(ok && d.state==ICT_ENTRY_READY &&
                           d.priority!=ICT_PRIORITY_WAIT);
   if(!d.hard_filters_passed) d.hard_filter_reason=d.reason;
   d.symbol=symbol;
   d.timeframe=cfg.trigger_tf;
   d.timestamp=d.as_of;
   d.directional_bias=d.higher_bias;
   d.decision=d.priority;
   d.setup_type=(d.fvg_time>0 ? "Sweep + MSS + displacement + FVG retest" :
                 (d.zone_low>0.0 ? "Sweep + MSS + displacement + Order Block retest" :
                  "No confirmed execution setup"));
   d.required_conditions=ICTEvidenceText(d.required);
   d.confirmed_conditions=ICTEvidenceText(d.confirmed);
   d.missing_conditions=ICTEvidenceText(d.missing);
   d.invalidation_reason=d.invalidation;
   d.entry_zone.low=d.zone_low;
   d.entry_zone.high=d.zone_high;
   d.stop_loss=d.stop;
   d.take_profit=d.target;
   d.take_profit2=d.target2;
   d.entry_confirmed=d.hard_filters_passed && d.risk.valid;
   d.confirmation_time=(d.entry_confirmed ? d.as_of+(datetime)PeriodSeconds(cfg.trigger_tf) : 0);
   if((d.buy_confirmed&ICT_E_SMT)==0 && (d.sell_confirmed&ICT_E_SMT)==0)
      d.optional_data_notes="SMT absent/unavailable/unaligned; no SMT points awarded";
   d.risk_reward=d.risk.rr;
   d.data_quality_status=d.data_quality;
   d.strong_signal=(d.priority!=ICT_PRIORITY_WAIT &&
                    (d.priority==ICT_PRIORITY_BUY ? d.buy_score : d.sell_score)>=scoring.strong_score);
   d.signal_id=symbol+"_"+IntegerToString((int)cfg.trigger_tf)+"_"+
               IntegerToString((long)d.as_of)+"_"+IntegerToString((int)d.priority);
   return ok;
  }

bool ICTAnalyzeDecision(const string symbol,const SICTDecisionConfig &cfg,SICTDecision &d)
  {
   SICTConfluenceConfig scoring;
   ICTDefaultConfluenceConfig(scoring);
   return ICTAnalyzeDecision(symbol,cfg,scoring,d);
  }

// Range mode has its own chronological setup model but reuses the established
// broker-aware calculator, portfolio view, protection reference and limits.
bool ICTAnalyzeRangeDecision(const string symbol,const SICTDecisionConfig &cfg,
                              const SICTConfluenceConfig &scoring,const SICTRangeConfig &range_config,
                              CICTRangeEngine &engine,SICTDecision &d,SICTRangeSnapshot &s,
                              const uint unified_buy=0,const uint unified_sell=0,const bool external_analysis=false)
  {
   ZeroMemory(d);
   ZeroMemory(s);
   if(!ICTValidConfluenceConfig(scoring))
     {
      d.symbol=symbol; d.timeframe=range_config.ltf;
      d.state=ICT_NO_TRADE;
      d.reason="Invalid confluence configuration";
      d.data_quality_ok=false; d.data_quality=d.reason;
      d.data_quality_status=d.reason; d.hard_filter_reason=d.reason;
      return false;
     }
   if(!ICTValidRangeConfig(range_config))
     {
      d.symbol=symbol; d.timeframe=range_config.ltf;
      d.state=ICT_NO_TRADE;
      d.reason="Invalid range configuration";
      d.data_quality_ok=false; d.data_quality=d.reason;
      d.data_quality_status=d.reason; d.hard_filter_reason=d.reason;
      return false;
     }
   SICTRangeConfig settings=range_config; settings.zone_mode=(int)scoring.entry_zone_mode;
   bool analyzed=engine.Update(symbol,settings); engine.Snapshot(s);
   d.symbol=symbol; d.timeframe=settings.ltf; d.as_of=s.as_of; d.timestamp=s.as_of;
   d.signal_id=s.signal_id; d.directional_bias=s.htf_bias; d.higher_bias=s.htf_bias;
   d.direction=s.direction; d.dealing_high=s.range.high; d.dealing_low=s.range.low;
   d.equilibrium=s.range.midpoint; d.data_quality_ok=analyzed && s.valid;
   d.data_quality=(d.data_quality_ok ? "Closed chronological HTF/MTF/LTF range snapshot" : s.reason);
   d.data_quality_status=d.data_quality;
   d.reason=s.reason; d.hard_filter_reason=s.reason;
   d.setup_type=(s.scenario==IR_REVERSAL ? "ERL sweep -> MSS -> IRL reaction -> ERL" :
                (s.scenario==IR_BREAKOUT_CONTINUATION ? "Breakout -> IRL continuation -> ERL" :
                 (s.scenario==IR_CONTINUATION && s.sweep_at>0 ? "Internal sweep -> BOS -> IRL reaction -> ERL" : "IRL continuation -> ERL")));
   d.state=(s.phase==IR_SETUP_INVALIDATED ? ICT_INVALIDATED :
            (s.phase>=IR_STRUCTURE_SHIFT && s.phase<IR_TARGET_REACHED ? ICT_WAIT_CONFIRMATION : ICT_FORMING));
   if(s.phase==IR_SETUP_INVALIDATED) { d.invalidation=s.reason; d.invalidation_reason=s.reason; }
   if(s.phase==IR_TARGET_REACHED) d.state=ICT_NO_TRADE;
   d.sweep_time=s.sweep_at; d.sweep_level=s.sweep_level; d.mss_time=s.structure_at;
   d.zone_time=s.active_zone.confirmed_at; d.zone_low=s.active_zone.lower; d.zone_high=s.active_zone.upper;
   d.fvg_time=(s.active_zone.type==IR_FVG ? s.active_zone.formed_at : 0);
   d.entry=s.entry; d.stop=s.stop; d.target=s.tp1; d.target2=s.tp2; d.dol=s.tp1;
   d.dol_name=(s.target1_index>=0 && s.target1_index<s.level_count ? s.levels[s.target1_index].name : "");
   d.target2_name=(s.target2_index>=0 && s.target2_index<s.level_count ? s.levels[s.target2_index].name : "");
   d.entry_zone.low=s.active_zone.lower; d.entry_zone.high=s.active_zone.upper;
   d.stop_loss=s.stop; d.take_profit=s.tp1; d.take_profit2=s.tp2;
   d.consequent_encroachment=s.active_zone.midpoint;
   d.price_location=ICTRangeLocation(s.range,s.entry>0 ? s.entry : s.range.midpoint);
   uint evidence=ICTRangeEvidence(s);
   if(external_analysis) evidence=(evidence & ~(ICT_E_SMT|ICT_E_OB)) |
      ((s.direction>0 ? unified_buy : unified_sell) & (ICT_E_SMT|ICT_E_OB));
   for(int i=0;i<2 && !external_analysis;i++)
     {
      string comparison=(i==0 ? cfg.comparison1 : cfg.comparison2);
      if(comparison=="") continue;
      SSMTDivergence smt;
      if(SRMPFindSMT(symbol,comparison,cfg.smt_tf,cfg.lookback,cfg.swing_strength,cfg.swing_strength,
                      SMT_AUTO,100,60,0.60,3,smt) && smt.direction==s.direction &&
         smt.confirmation_time<=s.as_of && smt.confirmation_time>0) evidence|=ICT_E_SMT;
     }
   bool session=false; ICTNewYorkSession(ICTSessionUTC(scoring.tester_broker_utc_offset_minutes),session);
   if(session) evidence|=ICT_E_SESSION;
   if((evidence&ICT_E_SMT)==0) d.optional_data_notes="Optional SMT absent/unavailable/unaligned; no SMT points";
   d.required=ICT_E_HTF|ICT_E_MSS|ICT_E_PD;
   if(s.scenario==IR_REVERSAL || s.scenario==IR_BREAKOUT_CONTINUATION ||
      (s.scenario==IR_CONTINUATION && s.sweep_at>0)) d.required|=ICT_E_SWEEP;
   if(settings.require_displacement) d.required|=ICT_E_DISPLACEMENT;
   if(scoring.mandatory_smt) d.required|=ICT_E_SMT;
   if(scoring.mandatory_session) d.required|=ICT_E_SESSION;
   d.confirmed=evidence; d.missing=d.required & ~evidence;
   if(s.direction>0) d.buy_confirmed=evidence;
   if(s.direction<0) d.sell_confirmed=evidence;
   d.buy_missing=d.required & ~d.buy_confirmed; d.sell_missing=d.required & ~d.sell_confirmed;
   d.required_conditions=ICTEvidenceText(d.required)+", closed IRL reaction, unconsumed same-range ERL";
   d.confirmed_conditions=ICTEvidenceText(evidence); d.missing_conditions=ICTEvidenceText(d.missing);
   StringReplace(d.required_conditions,"Sweep","Liquidity event"); StringReplace(d.confirmed_conditions,"Sweep","Liquidity event");
   StringReplace(d.required_conditions,"MSS","MSS/BOS"); StringReplace(d.confirmed_conditions,"MSS","MSS/BOS");
#ifdef ICT_SMART_ENGINE
   // An MTF observation newer than this LTF close is not evidence for this
   // decision. Missing, neutral or opposing context must fail closed.
   if(analyzed && s.valid && !external_analysis)
     {
      SMarketStructure mtf_context; ZeroMemory(mtf_context);
      bool mtf_ready=SRMPAnalyzeStructure(symbol,settings.mtf,settings.lookback,
                                          settings.left,mtf_context) &&
                     mtf_context.latest_closed_bar>0 &&
                     mtf_context.latest_closed_bar+PeriodSeconds(settings.mtf)<=s.as_of;
      ENUM_ICT_TIER_ALIGNMENT alignment=ICTTierAlignment(mtf_ready,s.htf_bias,mtf_context.bias,s.direction);
      if(alignment==ICT_TIER_INSUFFICIENT)
        {
         d.state=ICT_NO_TRADE; d.data_quality_ok=false;
         d.reason="INSUFFICIENT_DATA: no MTF structure closed by the LTF snapshot";
         d.data_quality=d.reason; d.hard_filter_reason=d.reason;
         s.reason=d.reason; s.reason_code=IR_DATA; return analyzed;
        }
      d.structure_bias=mtf_context.bias;
      if(alignment==ICT_TIER_NEUTRAL)
        {
         d.state=ICT_NO_TRADE; d.reason="HTF bias neutral";
         d.hard_filter_reason=d.reason; s.reason=d.reason; s.reason_code=IR_CONFLICT; return analyzed;
        }
      if(alignment==ICT_TIER_CONFLICT)
        {
         d.state=ICT_WAIT_CONFIRMATION;
         d.reason="WAIT: MTF structure neutral/counter-trend or LTF setup conflicts with HTF";
         d.hard_filter_reason=d.reason; s.reason=d.reason; s.reason_code=IR_CONFLICT; return analyzed;
        }
     }
#endif
   if(!analyzed || !s.valid || !s.technical_ready || !ICTValidConfluenceConfig(scoring)) return analyzed;
   // Count only confirmed records owned by the current, still usable boundary pool.
   int confirmed_sweeps=0;
   for(int level=0;level<s.level_count;level++)
     {
      if(s.source_pool_id=="" || s.levels[level].id!=s.source_pool_id ||
         s.levels[level].membership!=IR_BOUNDARY || s.levels[level].side!=-s.direction ||
         s.levels[level].state==IR_CONSUMED || s.levels[level].state==IR_BREAKOUT ||
         s.levels[level].state==IR_LEVEL_INVALIDATED) continue;
      for(int event=0;event<s.sweep_event_count;event++)
         if(s.sweep_events[event].pool_id==s.levels[level].id &&
            s.sweep_events[event].status==ICT_SWEEP_CONFIRMED &&
            s.sweep_events[event].confirmed_at>=s.range.confirmed_at &&
            s.sweep_events[event].confirmed_at<=s.as_of)
            confirmed_sweeps++;
     }
   if(settings.sweep_mode==SWEEP_2_REQUIRED && confirmed_sweeps<2)
     {
      d.state=ICT_WAIT_CONFIRMATION; d.reason="Waiting for two confirmed sweeps of the same active pool";
      d.hard_filter_reason=d.reason; d.missing_conditions+=", second confirmed sweep";
      s.reason=d.reason; s.reason_code=IR_WAIT_SWEEP; return true;
     }
   MqlTick quote;
   string block="";
   double reference=0,point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(!ICTRangePlanGeometry(s,cfg.min_rr))
      block="Range plan geometry or gross RR below minimum; costs can only reduce RR further";
   else if(!SymbolInfoTick(symbol,quote) || !ICTQuoteValidAt(quote,TimeTradeServer(),cfg.max_quote_age_seconds))
      block="Missing/stale/inverted market quote";
   else if(s.direction==0 || d.missing!=0 || s.active_zone.range_id!=s.range.id)
      block="Required range evidence missing or wrong owner";
   else if(((s.direction>0 ? quote.bid : quote.ask)-s.stop)*s.direction<=0)
      block="Live quote crossed scenario stop after the closed reaction";
   else if(!ICTRangeLiveTargetSafe(s.direction,quote.bid,quote.ask,s.tp1))
      block="Live exit quote already reached or crossed the scenario target";
   else if(point<=0 || (quote.ask-quote.bid)/point>cfg.max_spread_points)
      block="Spread or symbol point invalid";
   else if(cfg.min_rr<2 || cfg.risk_percent<=0 || cfg.risk_percent>cfg.max_risk_percent || cfg.max_risk_percent>3)
      block="Invalid risk configuration: RR >=2 and maximum risk <=3% required";
   else if(TerminalInfoInteger(TERMINAL_CONNECTED)==0 || !ICTProtectionReady(reference))
      block="Protection offline, unhealthy, disabled or locked";
   else if(!ICTDailyLossAllowed(ICTConservativeRiskCapital(reference,AccountInfoDouble(ACCOUNT_BALANCE),
      AccountInfoDouble(ACCOUNT_EQUITY)),cfg.daily_loss_limit_percent,d.daily_net))
      block="Daily loss gate or deal history unavailable";
   else if(!CalculateRisk(symbol,s.direction>0 ? RM_BUY : RM_SELL,s.entry,s.stop,s.tp1,
                           ICTConservativeRiskCapital(reference,AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY)),
                           cfg.risk_percent,cfg.max_risk_percent,cfg.min_rr,cfg.commission_per_lot,
                           cfg.cost_buffer_per_lot,cfg.slippage_points,cfg.max_quote_age_seconds,d.risk))
      block="Risk gate: "+d.risk.reason;
   else if(!ICTLiveEntryBudgetAllowed(reference,d.risk.risk_money,cfg.commission_per_lot+cfg.cost_buffer_per_lot,
      cfg.portfolio_risk_limit_percent,cfg.daily_loss_limit_percent,block,cfg.daily_risk_budget_enabled)) d.risk.valid=false;
   if(block!="")
     {
      d.state=ICT_RISK_BLOCKED; d.reason=block; d.hard_filter_reason=block;
      s.reason_code=IR_RISK; s.reason=block; return true;
     }
   ICTAssessPortfolio(symbol,cfg,s.direction,d);
   // Hard gates passed before numerical score approval. These are confluence
   // points, never a probability; IRL's own quality is shown separately.
   int score=ICTRangeQualityConfluence(evidence,s.active_zone.quality,scoring);
   if(settings.sweep_mode==SWEEP_2_PREFERRED && confirmed_sweeps>=2 && s.structure_confirmed)
     {
      score=(int)MathMin(100,score+5);
      d.confirmed_conditions+=", double sweep with confirmed structure (+5)";
     }
   d.score=score; d.buy_score=(s.direction>0 ? score : 0); d.sell_score=(s.direction<0 ? score : 0);
   d.priority=ICTScorePriority(d.buy_score,d.sell_score,true,scoring);
   d.decision=d.priority; d.risk_reward=d.risk.rr;
   d.hard_filters_passed=true;
   d.entry_confirmed=d.priority!=ICT_PRIORITY_WAIT;
   d.state=(d.entry_confirmed ? ICT_ENTRY_READY : ICT_WAIT_CONFIRMATION);
   d.confirmation_time=(d.entry_confirmed ? s.reaction_at : 0);
   d.strong_signal=d.entry_confirmed && score>=scoring.strong_score;
   d.reason=(d.entry_confirmed ? "Confirmed IRL/ERL advisory plan; proposed zone entry is not a fill or order" : "Confluence below configured threshold");
   d.hard_filter_reason="";
   s.proposed_action=(int)d.priority; s.score=score; s.risk_money=d.risk.risk_money;
   s.rr=d.risk.rr; s.volume=d.risk.volume; s.reason=d.reason;
   s.reason_code=(d.entry_confirmed ? IR_OK : IR_SCORE);
   return true;
  }
#endif
