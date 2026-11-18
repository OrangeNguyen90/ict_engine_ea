#ifndef ICT_UNIFIED_DECISION_ADAPTER_MQH
#define ICT_UNIFIED_DECISION_ADAPTER_MQH
#include "ICTUnifiedAnalysis.mqh"
#include "ICTDecisionEngine.mqh"

uint ICTUnifiedEvidence(const SICTUnifiedSnapshot &s,const int direction)
  {
   uint evidence=0;
   if(!s.valid || (direction!=1 && direction!=-1)) return evidence;
   if(ICTUnifiedSMTAligned(s,direction)) evidence|=ICT_E_SMT;
   for(int i=0;i<s.ob_count;i++)
      if(s.zones[i].timeframe==s.frames.mtf && s.zones[i].ob.direction==direction &&
         ICTOBActive(s.zones[i]) && s.zones[i].hard_gates && s.zones[i].current_context_score>=60 &&
         s.zones[i].ob.confirmation_time<=s.asof && s.tiers[0].last_bar.low<=s.zones[i].ob.upper &&
         s.tiers[0].last_bar.high>=s.zones[i].ob.lower)
        { evidence|=ICT_E_OB; break; }
   return evidence;
  }
void ICTUnifiedBlock(SICTDecision &d,const ENUM_ICT_DECISION_STATE state,const string reason)
  {
   d.state=state; d.reason=reason; d.hard_filter_reason=reason;
   d.entry_confirmed=false; d.hard_filters_passed=false; d.strong_signal=false;
   d.priority=ICT_PRIORITY_WAIT; d.decision=ICT_PRIORITY_WAIT;
  }
void ICTApplyUnifiedContext(const SICTUnifiedSnapshot &s,SICTDecision &d)
  {
   int upper=(s.frames.htf!=PERIOD_CURRENT ? 2 : s.frames.mtf!=PERIOD_CURRENT ? 1 : 0);
   d.higher_bias=s.tiers[upper].structure.bias; d.directional_bias=d.higher_bias;
   d.structure_bias=s.tiers[s.frames.htf!=PERIOD_CURRENT ? 1 : 0].structure.bias;
   if(!s.valid)
     {
      d.data_quality_ok=false; d.data_quality=s.reason; d.data_quality_status=s.reason;
      ICTUnifiedBlock(d,ICT_NO_TRADE,s.reason); return;
     }
   if(s.frames.status!=ICT_MTF_FULL)
     { ICTUnifiedBlock(d,ICT_NO_TRADE,"DATA INSUFFICIENT: three independent tiers required for confirmation"); return; }
   if(d.higher_bias==0)
     { ICTUnifiedBlock(d,ICT_NO_TRADE,"Upper timeframe bias NEUTRAL"); return; }
   if(d.structure_bias==0 || d.structure_bias!=d.higher_bias || (d.direction!=0 && d.direction!=d.higher_bias))
     { ICTUnifiedBlock(d,ICT_NO_TRADE,"NO_TRADE: HTF bias / MTF setup / LTF execution direction conflict"); return; }
   if(d.entry_confirmed && (!d.risk.valid || d.risk.rr<2 || d.entry<=0 || d.stop<=0 || d.target<=0 ||
                           (d.entry-d.stop)*d.direction<=0 || (d.target-d.entry)*d.direction<=0))
     { ICTUnifiedBlock(d,ICT_RISK_BLOCKED,"Risk Manager veto: invalid plan or net RR below 1:2"); return; }
   d.optional_data_notes="Shared as-of LTF/MTF/HTF, Dynamic SMT and Strong OB; "+s.comparator_reason;
   for(int i=0;i<3;i++)
      if(s.tiers[i].bpr_ready && s.tiers[i].bpr.direction==d.direction && s.tiers[i].bpr.confirmed_at<=s.asof)
         d.confirmed_conditions+=", aligned BPR "+EnumToString(s.tiers[i].timeframe);
  }

// Describe peer evidence considered by ICTUnifiedSMTAligned. An unknown peer
// state is reported as unavailable. This never changes the existing SMT veto.
string ICTUnifiedSMTDiagnostic(const SICTUnifiedSnapshot &snapshot,const int direction)
  {
   if(!snapshot.valid) return "UNAVAILABLE: shared snapshot invalid";
   if(direction!=1 && direction!=-1) return "UNKNOWN: decision direction unavailable";
   if(snapshot.layer_count<=0) return "UNAVAILABLE: SMT analysis disabled or no timeframe";
   bool same=false,opposite=false,conflict=false,available=false,unavailable=false;
   for(int layer=0;layer<snapshot.layer_count;layer++)
      for(int comp=0;comp<2;comp++)
        {
         SICTSMTPeerSnapshot peer=snapshot.layers[layer].peers[comp];
         string configured=(comp==0 ? snapshot.comparison1 : snapshot.comparison2);
         if(peer.reason=="DISABLED" && peer.comparison=="" && configured=="") continue;
         if(peer.comparison=="" || peer.comparison!=configured || !peer.ready || !peer.relation_known ||
            peer.last_close!=snapshot.layers[layer].last_close || peer.last_close>snapshot.asof)
           { unavailable=true; continue; }
         available=true;
         if(peer.conflict) conflict=true;
         int bias=(peer.state==ICT_SMT_PEER_BULLISH ? 1 : peer.state==ICT_SMT_PEER_BEARISH ? -1 : 0);
         if(bias==direction) same=true;
         if(bias==-direction) opposite=true;
        }
   string partial=(unavailable ? " (some peer data unavailable)" : "");
   if(conflict || (same && opposite)) return "CONFLICT: opposing active divergences"+partial;
   if(same) return "ALIGNED: active divergence supports direction"+partial;
   if(opposite) return "OPPOSITE: active divergence opposes direction"+partial;
   if(available) return "NONE: no active divergence"+partial;
   return "UNAVAILABLE: no usable comparator data";
  }

// The final result is assembled once from the shared analysis and established
// broker-aware risk result. Chart, panel, journal and alerts consume this result.
void ICTBuildUnifiedSignal(const SICTUnifiedSnapshot &snapshot,const SICTDecision &d,
                           const SICTRangeSnapshot &range,const bool range_mode,
                           const bool required_smt,const double minimum_rr,SICTSignalResult &s)
  {
   ZeroMemory(s); s.symbol=snapshot.symbol; s.frames=snapshot.frames; s.asof=snapshot.asof;
   s.trigger_bar=snapshot.tiers[0].last_bar.time;
   s.direction=(d.direction!=0 ? d.direction : snapshot.tiers[2].structure.bias);
   s.score=d.score; s.entry=d.entry; s.stop=d.stop; s.tp1=d.target; s.tp2=d.target2; s.rr=d.risk.rr;
   s.source_price=d.sweep_level;
   s.liquidity_event=range_mode ? (range.scenario==IR_REVERSAL ? "LIQUIDITY_SWEEP" :
      range.scenario==IR_BREAKOUT_CONTINUATION ? "BREAKOUT_CONFIRMED / RETEST" : "MTF SETUP / LTF RETEST") : "LIQUIDITY_SWEEP / MSS";
   if(s.tp2<=0 || (s.tp2-s.tp1)*s.direction<=0) s.tp2=0;
   s.data_ready=snapshot.valid && d.data_quality_ok;
   s.htf_pass=s.direction!=0 && snapshot.tiers[2].structure.bias==s.direction;
   bool zone=d.zone_low>0 && d.zone_high>d.zone_low && d.zone_time>0 && d.zone_time<=s.asof;
   s.mtf_pass=s.direction!=0 && snapshot.tiers[1].structure.bias==s.direction && zone &&
      ICTMTFStructureReady(range_mode,s.direction,snapshot.tiers[1].structure.bos_direction,
                           range.direction,range.structure_confirmed,range.structure_at,s.asof);
   MqlRates bar=snapshot.tiers[0].last_bar;
   bool displaced=(s.direction>0 ? snapshot.tiers[0].displacement_up : snapshot.tiers[0].displacement_down);
   // The core already checks post-sweep MSS and displacement. Requiring a
   // second BOS and displacement on the retest candle discards valid causal
   // sequences. Keep a closed directional reaction and all existing risk gates.
   datetime legacy_zone_confirmed=ICTBarClose(s.frames.mtf,d.zone_time);
   datetime legacy_structure_confirmed=ICTBarClose(s.frames.mtf,d.mss_time);
   bool legacy_reaction=!range_mode && zone && ICTClosedZoneReaction(bar,s.asof,s.direction,
      d.zone_low,d.zone_high,legacy_zone_confirmed,legacy_structure_confirmed);
   bool prior_impulse=range.displacement && range.active_zone.displacement;
   bool latest_reaction=range_mode && zone && ICTClosedRangeReaction(bar,s.asof,s.direction,
      range.active_zone.confirmed_at,range.structure_at,range.reaction_at,
      range.technical_ready,prior_impulse || displaced);
   s.ltf_pass=snapshot.tiers[0].closed_at==s.asof && (latest_reaction || legacy_reaction);
   s.source_event_time=(range_mode ? range.source_event_at :
      d.sweep_time>0 ? ICTBarClose(s.frames.ltf,d.sweep_time) : 0);
   s.smt_required=required_smt; s.smt_pass=ICTUnifiedSMTAligned(snapshot,s.direction);
   s.smt_reason="SMT "+ICTUnifiedSMTDiagnostic(snapshot,s.direction)+
      (s.smt_required ? " | required" : " | optional, no veto");
   s.risk_pass=d.entry_confirmed && d.hard_filters_passed && d.risk.valid;
   if(range_mode)
     {
      s.source_pool_id=range.source_pool_id;
      if(range.source_event!=IR_EVENT_NONE) s.liquidity_event=ICTRangeLevelEventText(range.source_event);
      if(range.source_event_at>0) s.source_event_time=range.source_event_at;
      for(int i=0;i<range.level_count;i++)
         if(s.source_pool_id=="" && range.levels[i].side==-s.direction && range.levels[i].price==range.sweep_level)
           { s.source_pool_id=range.levels[i].id; break; }
      if(range.target1_index>=0 && range.target1_index<range.level_count) s.target_pool_id=range.levels[range.target1_index].id;
      if(range.target2_index>=0 && range.target2_index<range.level_count) s.target2_pool_id=range.levels[range.target2_index].id;
      if(s.target_pool_id=="") s.target_pool_id=range.target1_pool_id;
      if(s.target2_pool_id=="") s.target2_pool_id=range.target2_pool_id;
      for(int i=0;i<range.level_count;i++)
         if(range.levels[i].id==s.source_pool_id) { s.source_price=range.levels[i].price; break; }
     }
   else
     {
      if(d.sweep_time>0 && d.sweep_level>0) s.source_pool_id="SWEEP|"+IntegerToString((long)d.sweep_time)+"|"+DoubleToString(d.sweep_level,8);
      if(d.target>0 && d.dol_name!="") s.target_pool_id=d.dol_name+"|"+DoubleToString(d.target,8);
      if(d.target2>0 && d.target2_name!="") s.target2_pool_id=d.target2_name+"|"+DoubleToString(d.target2,8);
     }
   string side=s.direction>0 ? "bullish" : s.direction<0 ? "bearish" : "neutral";
   s.htf_reason="HTF "+EnumToString(s.frames.htf)+" "+(s.htf_pass ? side+" bias" : "bias missing/conflict");
   s.mtf_reason="MTF "+EnumToString(s.frames.mtf)+" "+(s.mtf_pass ? side+" structure + valid zone" : "setup missing/conflict");
   s.ltf_reason="LTF "+EnumToString(s.frames.ltf)+" "+(s.ltf_pass ? (latest_reaction ? "closed zone reaction after setup displacement" : "closed zone reaction after MSS and displacement") : "closed reaction / setup chronology missing");
   ICTEvaluateSignal(s,minimum_rr);
   if(!s.confirmed && d.reason!="") s.reason+=" | "+d.reason;
  }

// A committed result owns all published/drawn plan fields. A fresh risk veto
// may withhold present actionability, but may not change the historical signal.
void ICTApplyCommittedSignal(const SICTSignalResult &s,SICTDecision &d)
  {
   bool live=s.confirmed && d.entry_confirmed && d.risk.valid && d.hard_filters_passed &&
      d.direction==s.direction && d.entry==s.entry && d.stop==s.stop && d.target==s.tp1;
   string live_reason=d.reason;
   d.signal_id=s.id; d.symbol=s.symbol; d.timeframe=s.frames.ltf;
   d.as_of=s.asof; d.timestamp=s.asof; d.confirmation_time=s.confirmation_time;
   d.direction=s.direction; d.score=s.score; d.entry=s.entry; d.stop=s.stop;
   d.target=s.tp1; d.target2=s.tp2; d.stop_loss=s.stop; d.take_profit=s.tp1; d.take_profit2=s.tp2;
   d.reason=s.reason; d.entry_confirmed=live; d.hard_filters_passed=live;
   d.priority=live ? (s.direction>0 ? ICT_PRIORITY_BUY : ICT_PRIORITY_SELL) : ICT_PRIORITY_WAIT;
   d.decision=d.priority; d.strong_signal=live && d.strong_signal;
   if(live) d.state=ICT_ENTRY_READY;
   else if(s.confirmed)
     { d.state=ICT_RISK_BLOCKED; d.reason="RISK FILTER FAIL on live recheck; historical "+ICTSignalStateText(s.state)+" unchanged | "+live_reason; }
   else d.state=(s.state==ICT_SIGNAL_WATCH_BUY || s.state==ICT_SIGNAL_WATCH_SELL ? ICT_WATCH : ICT_NO_TRADE);
   if(!live) d.hard_filter_reason=d.reason;
  }

// Keep the established broker-aware risk calculation and protection gates.
// The adapter only supplies analysis evidence and may veto a candidate.
bool ICTAnalyzeUnifiedDecision(const string symbol,const SICTUnifiedSnapshot &snapshot,
                               const SICTUnifiedConfig &unified,const SICTDecisionConfig &config,
                               const SICTConfluenceConfig &scoring,const bool range_mode,
                               const SICTRangeConfig &range_config,CICTRangeEngine &range_engine,
                               SICTDecision &d,SICTRangeSnapshot &range,SICTSignalResult &signal)
  {
   ZeroMemory(d); d.symbol=symbol; d.timeframe=unified.frames.ltf; d.as_of=snapshot.asof;
   if(!snapshot.valid || unified.frames.status!=ICT_MTF_FULL)
     {
      ZeroMemory(range); d.data_quality_ok=snapshot.valid;
      ICTUnifiedBlock(d,snapshot.valid ? ICT_WAIT_CONFIRMATION : ICT_NO_TRADE,
         snapshot.valid ? "Reduced-tier context available; waiting for a supported execution/risk plan" : snapshot.reason);
      ICTApplyUnifiedContext(snapshot,d);
      ICTBuildUnifiedSignal(snapshot,d,range,range_mode,scoring.mandatory_smt,config.min_rr,signal);
      return snapshot.valid;
     }
   SICTDecisionConfig cfg=config; cfg.comparison1=""; cfg.comparison2="";
   uint buy=ICTUnifiedEvidence(snapshot,1),sell=ICTUnifiedEvidence(snapshot,-1);
   bool ok=false;
   if(range_mode)
     {
      range_engine.SetUnifiedOrderBlocks(snapshot.zones,snapshot.ob_count,unified.ob);
      ok=ICTAnalyzeRangeDecision(symbol,cfg,scoring,range_config,range_engine,d,range,buy,sell,true);
     }
   else ok=ICTAnalyzeDecision(symbol,cfg,scoring,d,buy,sell,true);
   ICTApplyUnifiedContext(snapshot,d);
   bool asof_matches=(range_mode ? d.as_of==snapshot.asof : ICTBarClose(cfg.trigger_tf,d.as_of)==snapshot.asof);
   if(!asof_matches && d.data_quality_ok)
     { d.data_quality_ok=false; ICTUnifiedBlock(d,ICT_NO_TRADE,"INSUFFICIENT_DATA: decision and shared snapshot timestamps differ"); }
   if(!range_mode && d.zone_low>0 && d.fvg_time<=0)
     {
      bool found=false;
      for(int i=0;i<snapshot.ob_count;i++)
         if(ICTOBActive(snapshot.zones[i]) && snapshot.zones[i].hard_gates && snapshot.zones[i].confirmation_score>=60 &&
            snapshot.zones[i].ob.direction==d.direction && snapshot.zones[i].ob.lower==d.zone_low && snapshot.zones[i].ob.upper==d.zone_high) found=true;
      if(!found) ICTUnifiedBlock(d,ICT_WAIT_CONFIRMATION,"WAIT: legacy OB entry is not an active shared OB with valid hard gates");
     }
   ICTBuildUnifiedSignal(snapshot,d,range,range_mode,scoring.mandatory_smt,cfg.min_rr,signal);
   d.as_of=snapshot.asof; d.timestamp=snapshot.asof;
   d.signal_id=signal.id; d.reason=signal.reason; d.confirmation_time=signal.confirmation_time;
   if(!signal.confirmed)
     {
      ENUM_ICT_DECISION_STATE state=(signal.state==ICT_SIGNAL_WATCH_BUY || signal.state==ICT_SIGNAL_WATCH_SELL ? ICT_WATCH : ICT_NO_TRADE);
      if(signal.ltf_pass && signal.htf_pass && signal.mtf_pass && !signal.risk_pass) state=ICT_RISK_BLOCKED;
      ICTUnifiedBlock(d,state,signal.reason);
     }
   if(range_mode)
     { range.proposed_action=(int)d.priority; range.score=d.score; range.reason=d.reason;
       if(!d.entry_confirmed) range.technical_ready=false; }
   return ok;
  }
#endif
