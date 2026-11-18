#ifndef ICT_DECISION_BRIDGE_MQH
#define ICT_DECISION_BRIDGE_MQH

#include "AdviceBridge.mqh"
#include "ICTDecisionEngine.mqh"

// Chart/account scoped, commit timestamp last. A reader must reject stale DTS
// and independently validate protection before showing actionable readiness.
void ICTPublishDecision(const string symbol,const SICTDecision &d)
  {
   GlobalVariableSet(SRMPAdviceKey(symbol,"DTS"),0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DSTATE"),(double)d.state);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DSCORE"),(double)d.score);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DBUY"),(double)d.buy_score);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DSELL"),(double)d.sell_score);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DDIR"),(double)d.direction);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DDOL"),d.dol);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DSW"),(double)d.sweep_time);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DMSS"),(double)d.mss_time);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DFVG"),(double)d.fvg_time);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DE"),d.entry);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DSL"),d.stop);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DTP"),d.target);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DTP2"),d.target2);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DPRI"),(double)d.priority);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DREADY"),d.entry_confirmed ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DZL"),d.zone_low);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DZH"),d.zone_high);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DRR"),d.risk.rr);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DRM"),d.risk.risk_money);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DPORT"),d.portfolio_stop_risk);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DUNKN"),(double)d.portfolio_unknown_stops);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DCORR"),(double)d.correlated_positions);
   SRMPPublishAdviceSymbol(symbol,"DNAME",d.dol_name);
   SRMPPublishAdviceText(symbol,"DWHY",d.reason);
   SRMPPublishAdviceText(symbol,"DMISS",d.missing_conditions);
   SRMPPublishAdviceText(symbol,"DID",d.signal_id);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DCONF"),(double)d.confirmation_time);
   GlobalVariableSet(SRMPAdviceKey(symbol,"DTS"),(double)TimeLocal());
  }

#endif
