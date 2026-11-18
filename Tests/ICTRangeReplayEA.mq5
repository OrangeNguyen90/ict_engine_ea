#property strict
#property description "Tester-only IRL/ERL chronological probe and paper ledger. Never sends orders."
#include "../Include/ICTRangeEngine.mqh"
#include "../Include/ICTRangeInputs.mqh"
#include "../Include/RiskCalculator.mqh"
#include "../Include/ICTSessionManager.mqh"
input int Replay_Broker_UTC_Offset_Minutes=9999; // 9999 = session attribution unavailable.

CICTRangeEngine g_engine;
SICTRangeConfig g_cfg;
SICTRangeSnapshot g_pending;
SRiskResult g_risk;
bool g_has_pending=false,g_active=false;
string g_last_signal="";
datetime g_last_bar=0;
double g_balance=10000,g_peak=10000,g_drawdown=0,g_open=0,g_net=0,g_sum_rr=0;
int g_bars=0,g_missing=0,g_signals=0,g_invalidated=0,g_fills=0,g_wins=0,g_losses=0,g_expired=0;
int g_buy=0,g_sell=0,g_account_orders=0;
int g_tp_hits=0,g_sl_hits=0,g_session_index=0;
// Snapshot counts are per processed LTF bar, not distinct rejected trades.
int g_reason_observations[16];
int g_observed_internal_sweeps=0,g_observed_external_sweeps=0,g_observed_breakouts=0;
int g_duplicate_observations=0,g_reject_busy=0,g_reject_geometry=0,g_reject_risk=0,g_reject_score=0,g_accepted=0;
int g_session_closed[5]; double g_session_net[5];
double g_frozen_risk=0;

void PaperTick()
  {
   MqlTick quote; if(!SymbolInfoTick(_Symbol,quote) || quote.ask<quote.bid || quote.bid<=0) return;
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(g_has_pending && !g_active)
     {
      bool wrong_side=(g_pending.direction>0 ? quote.bid<=g_pending.stop || quote.bid>=g_pending.tp1 :
                                             quote.ask>=g_pending.stop || quote.ask<=g_pending.tp1);
      if(wrong_side || TimeCurrent()-g_pending.reaction_at>Range_Maximum_Zone_Age*PeriodSeconds(g_cfg.mtf))
        { g_expired++; g_has_pending=false; return; }
      bool fill=(g_pending.direction>0 ? quote.ask<=g_pending.entry : quote.bid>=g_pending.entry);
      if(fill)
        {
         g_open=(g_pending.direction>0 ? quote.ask : quote.bid);
         // Recheck money/margin/net RR at modeled fill; a limit proposal is not
         // assumed filled when the signal first appears.
         if(!CalculateRisk(_Symbol,g_pending.direction>0 ? RM_BUY : RM_SELL,g_open,g_pending.stop,
                             g_pending.tp1,g_balance,1,2,2,0,10,2,60,g_risk) || g_risk.estimated_margin>g_balance)
           { g_has_pending=false; g_expired++; return; }
         g_active=true; g_has_pending=false; g_fills++; g_frozen_risk=g_risk.risk_money;
         g_session_index=0;
         if(Replay_Broker_UTC_Offset_Minutes!=9999)
           {
            bool kill_zone=false;
            string session=ICTNewYorkSession(TimeCurrent()-Replay_Broker_UTC_Offset_Minutes*60,kill_zone);
            g_session_index=(session=="London kill zone" ? 1 : (session=="New York AM kill zone" ? 2 :
                              (session=="New York PM kill zone" ? 3 : 4)));
           }
         PrintFormat("ICTRangeReplay PAPER_FILL signal=%s time=%s direction=%d entry=%.8f SL=%.8f TP=%.8f volume=%.4f",
            g_pending.signal_id,TimeToString(TimeCurrent()),g_pending.direction,g_open,g_pending.stop,g_pending.tp1,g_risk.volume);
        }
     }
   if(!g_active) return;
   double current=(g_pending.direction>0 ? quote.bid : quote.ask),floating=0;
   ENUM_ORDER_TYPE side=(g_pending.direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(side,_Symbol,g_risk.volume,g_open,current,floating)) return;
   double equity=g_balance+floating-g_risk.estimated_costs;
   g_peak=MathMax(g_peak,equity);
   if(g_peak>0) g_drawdown=MathMax(g_drawdown,100*(g_peak-equity)/g_peak);
   bool stop=(current-g_pending.stop)*g_pending.direction<=0;
   bool target=(current-g_pending.tp1)*g_pending.direction>=0;
   if(!stop && !target) return;
   // Two points adverse modeled exit slippage and the calculator's cost reserve.
   double exit=current-g_pending.direction*2*point,pnl=0;
   if(!OrderCalcProfit(side,_Symbol,g_risk.volume,g_open,exit,pnl)) return;
   pnl-=g_risk.estimated_costs;
   g_balance+=pnl; g_net+=pnl;
   if(g_frozen_risk>0) g_sum_rr+=pnl/g_frozen_risk;
   if(pnl>0) g_wins++; else g_losses++;
   if(stop) g_sl_hits++; else g_tp_hits++;
   g_session_closed[g_session_index]++; g_session_net[g_session_index]+=pnl;
   PrintFormat("ICTRangeReplay PAPER_EXIT signal=%s time=%s reason=%s net=%.2f realized_R=%.3f",
      g_pending.signal_id,TimeToString(TimeCurrent()),stop ? "SL" : "TP",pnl,
      g_frozen_risk>0 ? pnl/g_frozen_risk : 0);
   g_active=false;
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || Range_Auto_Trading) return INIT_PARAMETERS_INCORRECT;
   if(Replay_Broker_UTC_Offset_Minutes!=9999 &&
      (Replay_Broker_UTC_Offset_Minutes<-840 || Replay_Broker_UTC_Offset_Minutes>840)) return INIT_PARAMETERS_INCORRECT;
   ICTConfigureRangeInputs(g_cfg); g_cfg.enabled=true;
   if(!ICTValidRangeConfig(g_cfg)) return INIT_PARAMETERS_INCORRECT;
   Print("IRL/ERL replay: real broker history under configured Tester modeling; virtual ledger only. No execution acceptance.");
   return INIT_SUCCEEDED;
  }
void OnTick()
  {
   if(OrdersTotal()>0 || PositionsTotal()>0) g_account_orders++;
   PaperTick();
   datetime bar=iTime(_Symbol,g_cfg.ltf,1);
   if(bar<=0 || bar==g_last_bar) return;
   g_last_bar=bar; g_bars++;
   bool ok=g_engine.Update(_Symbol,g_cfg); SICTRangeSnapshot s; g_engine.Snapshot(s);
   int reason=(int)s.reason_code;
   if(reason>=0 && reason<ArraySize(g_reason_observations)) g_reason_observations[reason]++;
   if(!ok) { g_missing++; return; }
   for(int i=0;i<s.liquidity_event_count;i++)
     {
      SICTRangeLiquidityEvent e=s.liquidity_events[i];
      if(e.confirmed_at!=s.as_of) continue;
      if(e.type==IR_EVENT_LIQUIDITY_SWEEP || e.type==IR_EVENT_FALSE_BREAKOUT)
        {
         if(e.membership==IR_INTERNAL) g_observed_internal_sweeps++;
         else if(e.membership==IR_BOUNDARY || e.membership==IR_OUTSIDE) g_observed_external_sweeps++;
        }
      else if(e.type==IR_EVENT_BREAKOUT_CONFIRMED) g_observed_breakouts++;
     }
   if(s.phase==IR_SETUP_INVALIDATED && g_has_pending && s.range.id==g_pending.range.id)
     { g_invalidated++; g_has_pending=false; }
   if(g_has_pending && s.range.id!=g_pending.range.id) { g_invalidated++; g_has_pending=false; }
   if(!s.technical_ready) return;
   if(s.signal_id==g_last_signal) { g_duplicate_observations++; return; }
   g_last_signal=s.signal_id; g_signals++; if(s.direction>0) g_buy++; else g_sell++;
   if(g_has_pending || g_active) { g_reject_busy++; return; }
   if(!ICTRangePlanGeometry(s,2)) { g_reject_geometry++; return; }
   SRiskResult preview;
   if(!CalculateRisk(_Symbol,s.direction>0 ? RM_BUY : RM_SELL,s.entry,s.stop,s.tp1,
                       g_balance,1,2,2,0,10,2,60,preview) || preview.estimated_margin>g_balance)
     { g_reject_risk++; return; }
   SICTConfluenceConfig scoring; ICTDefaultConfluenceConfig(scoring);
   if(ICTRangeQualityConfluence(ICTRangeEvidence(s),s.active_zone.quality,scoring)<scoring.minimum_score)
     { g_reject_score++; return; }
   g_pending=s; g_has_pending=true; g_accepted++;
  }
double OnTester()
  {
   int closed=g_wins+g_losses;
   PrintFormat("ICTRangeReplay RESULT symbol=%s HTF=%s MTF=%s LTF=%s bars=%d missing=%d signals=%d buy=%d sell=%d invalidated_pending=%d fills=%d closed=%d wins=%d losses=%d expired=%d real_order_observations=%d",
      _Symbol,EnumToString(g_cfg.htf),EnumToString(g_cfg.mtf),EnumToString(g_cfg.ltf),
      g_bars,g_missing,g_signals,g_buy,g_sell,g_invalidated,g_fills,closed,g_wins,g_losses,g_expired,g_account_orders);
   PrintFormat("ICTRangeReplay DIAGNOSTIC internal_sweep_events=%d external_sweep_events=%d breakout_events=%d duplicate_bar_observations=%d candidates=%d blocked_busy=%d blocked_geometry=%d blocked_risk=%d blocked_score=%d paper_accepted=%d",
      g_observed_internal_sweeps,g_observed_external_sweeps,g_observed_breakouts,g_duplicate_observations,
      g_signals,g_reject_busy,g_reject_geometry,g_reject_risk,g_reject_score,g_accepted);
   for(int i=0;i<ArraySize(g_reason_observations);i++)
      if(g_reason_observations[i]>0)
         PrintFormat("ICTRangeReplay REASON_SNAPSHOTS code=%d bars=%d",i,g_reason_observations[i]);
   if(closed>0)
     {
      PrintFormat("ICTRangeReplay PAPER_ONLY net=%.2f expectancy_after_estimated_costs=%.2f mean_realized_R=%.3f modeled_max_drawdown_pct=%.3f TP_hits=%d SL_hits=%d TP_rate=%.4f pending_invalidation_per_signal=%.4f open_virtual_position=%d",
         g_net,g_net/closed,g_sum_rr/closed,g_drawdown,g_tp_hits,g_sl_hits,(double)g_tp_hits/closed,
         g_signals>0 ? (double)g_invalidated/g_signals : 0,(int)g_active);
      string labels[5]={"Unknown UTC","London KZ","NY AM KZ","NY PM KZ","Outside kill zone"};
      for(int i=0;i<5;i++) if(g_session_closed[i]>0)
         PrintFormat("ICTRangeReplay PAPER_SESSION %s closed=%d net=%.2f expectancy=%.2f",
                     labels[i],g_session_closed[i],g_session_net[i],g_session_net[i]/g_session_closed[i]);
     }
   else Print("ICTRangeReplay PAPER_ONLY outcome metrics unavailable: no closed virtual trades");
   // Open virtual positions are disclosed, not silently marked to realized P/L.
   return g_account_orders==0 ? g_net : -DBL_MAX;
  }
void OnDeinit(const int reason)
  {
   if(g_cfg.export_history) g_engine.ExportHistory("IRL_ERL_replay_"+IntegerToString(ChartID())+"_"+IntegerToString((long)TimeLocal())+".csv");
  }
