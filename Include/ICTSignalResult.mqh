#ifndef ICT_SIGNAL_RESULT_MQH
#define ICT_SIGNAL_RESULT_MQH
#include "ICTTimeframeMapper.mqh"

enum ENUM_ICT_SIGNAL_STATE { ICT_SIGNAL_NO_TRADE=0, ICT_SIGNAL_WATCH_BUY=1,
   ICT_SIGNAL_WATCH_SELL=2, ICT_SIGNAL_BUY_CONFIRMED=3, ICT_SIGNAL_SELL_CONFIRMED=4 };
enum ENUM_ICT_SAME_BAR_ACTION { ICT_BAR_CONFLICT=0, ICT_BAR_KEEP_CONFIRMED=1,
   ICT_BAR_REFRESH_UNCONFIRMED=2, ICT_BAR_COMMIT_CONFIRMED=3 };
struct SICTSignalResult
  {
   string id,symbol,reason,htf_reason,mtf_reason,ltf_reason,smt_reason;
   string source_pool_id,target_pool_id,target2_pool_id,liquidity_event;
   SICTTimeframes frames;
   ENUM_ICT_SIGNAL_STATE state;
   datetime asof,trigger_bar,confirmation_time,source_event_time;
   int direction,score;
   bool data_ready,htf_pass,mtf_pass,ltf_pass,smt_required,smt_pass,risk_pass,confirmed;
   double entry,stop,tp1,tp2,rr,source_price;
  };
string ICTSignalStateText(const ENUM_ICT_SIGNAL_STATE state)
  {
   if(state==ICT_SIGNAL_BUY_CONFIRMED) return "BUY_CONFIRMED";
   if(state==ICT_SIGNAL_SELL_CONFIRMED) return "SELL_CONFIRMED";
   if(state==ICT_SIGNAL_WATCH_BUY) return "WATCH_BUY";
   if(state==ICT_SIGNAL_WATCH_SELL) return "WATCH_SELL";
   return "NO_TRADE";
  }

// A retest is observable only after both the setup zone and structure have
// closed.  A directional close away from the midpoint is confirmation, not a
// promise that an order was filled.  A complete traversal invalidates it.
bool ICTClosedZoneReaction(const MqlRates &bar,const datetime asof,const int direction,
                           const double lower,const double upper,
                           const datetime zone_confirmed,const datetime structure_confirmed)
  {
   if((direction!=1 && direction!=-1) || bar.time<=0 || asof<=bar.time ||
      zone_confirmed<=0 || structure_confirmed<=0 ||
      zone_confirmed>bar.time || structure_confirmed>bar.time ||
      !MathIsValidNumber(lower) || !MathIsValidNumber(upper) || lower<=0 || upper<=lower ||
      !MathIsValidNumber(bar.open) || !MathIsValidNumber(bar.high) ||
      !MathIsValidNumber(bar.low) || !MathIsValidNumber(bar.close) ||
      bar.low<=0 || bar.high<bar.low || bar.open<bar.low || bar.open>bar.high ||
      bar.close<bar.low || bar.close>bar.high) return false;
   double midpoint=(lower+upper)/2.0;
   if(bar.low>upper || bar.high<lower || (bar.close-bar.open)*direction<=0) return false;
   return direction>0 ? bar.low>lower && bar.close>midpoint :
                        bar.high<upper && bar.close<midpoint;
  }

// Range mode already records a prior zone touch. Its later reaction need not
// revisit the zone or repeat the displacement that confirmed the setup.
bool ICTClosedRangeReaction(const MqlRates &bar,const datetime asof,const int direction,
                            const datetime zone_confirmed,const datetime structure_confirmed,
                            const datetime reaction_confirmed,const bool setup_ready,
                            const bool displacement_confirmed)
  {
   return setup_ready && displacement_confirmed && (direction==1 || direction==-1) &&
      bar.time>0 && asof>bar.time && reaction_confirmed==asof &&
      zone_confirmed>0 && zone_confirmed<=bar.time &&
      structure_confirmed>0 && structure_confirmed<=bar.time &&
      MathIsValidNumber(bar.open) && MathIsValidNumber(bar.high) &&
      MathIsValidNumber(bar.low) && MathIsValidNumber(bar.close) &&
      bar.low>0 && bar.high>=bar.low && bar.open>=bar.low && bar.open<=bar.high &&
      bar.close>=bar.low && bar.close<=bar.high && (bar.close-bar.open)*direction>0;
  }

// A range setup retains the structure event observed after its source event.
// The current MTF candle need not be another BOS, but an opposing new break
// is never treated as support for the saved event.
bool ICTMTFStructureReady(const bool range_mode,const int direction,const int latest_break,
                          const int setup_direction,const bool setup_confirmed,
                          const datetime structure_confirmed,const datetime asof)
  {
   if(direction!=1 && direction!=-1) return false;
   if(!range_mode) return latest_break==direction;
   return setup_direction==direction && setup_confirmed && structure_confirmed>0 &&
      structure_confirmed<=asof && (latest_break==0 || latest_break==direction);
  }
bool ICTSignalPlanValid(const SICTSignalResult &s,const double minimum_rr)
  {
   if((s.direction!=1 && s.direction!=-1) || !MathIsValidNumber(minimum_rr) || minimum_rr<2 ||
      !MathIsValidNumber(s.entry) || !MathIsValidNumber(s.stop) || !MathIsValidNumber(s.tp1) ||
      !MathIsValidNumber(s.rr) || s.entry<=0 || s.stop<=0 || s.tp1<=0 ||
      (s.entry-s.stop)*s.direction<=0 || (s.tp1-s.entry)*s.direction<=0) return false;
   double gross=MathAbs(s.tp1-s.entry)/MathAbs(s.entry-s.stop);
   return s.rr+1e-9>=minimum_rr && gross+1e-9>=minimum_rr && s.rr<=gross+1e-9;
  }

// A candle's unconfirmed observation can change while data or the live risk
// gate recovers. Once confirmed, however, its journal record is immutable.
ENUM_ICT_SAME_BAR_ACTION ICTSignalSameBarAction(const SICTSignalResult &previous,
                                                const SICTSignalResult &current)
  {
   if(previous.symbol=="" || previous.symbol!=current.symbol || previous.asof<=0 ||
      previous.asof!=current.asof || previous.trigger_bar<=0 ||
      previous.trigger_bar!=current.trigger_bar || previous.asof<=previous.trigger_bar ||
      previous.frames.ltf!=current.frames.ltf || previous.frames.mtf!=current.frames.mtf ||
      previous.frames.htf!=current.frames.htf || previous.frames.mode!=current.frames.mode ||
      previous.frames.status!=current.frames.status) return ICT_BAR_CONFLICT;
   if(previous.confirmed) return ICT_BAR_KEEP_CONFIRMED;
   if(!current.confirmed)
      return current.state==ICT_SIGNAL_BUY_CONFIRMED || current.state==ICT_SIGNAL_SELL_CONFIRMED ?
         ICT_BAR_CONFLICT : ICT_BAR_REFRESH_UNCONFIRMED;
   if(current.id=="" || current.frames.status!=ICT_MTF_FULL ||
      !current.data_ready || !current.htf_pass || !current.mtf_pass || !current.ltf_pass ||
      !current.risk_pass || (current.smt_required && !current.smt_pass) ||
      current.confirmation_time!=current.asof || current.source_event_time>current.asof ||
      current.target_pool_id=="" || !ICTSignalPlanValid(current,2) ||
      current.state!=(current.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED))
      return ICT_BAR_CONFLICT;
   return ICT_BAR_COMMIT_CONFIRMED;
  }

// The persisted confirmation is historical evidence. Publish it as a live
// confirmed plan only while a fresh evaluation validates the identical plan.
void ICTSignalReconcileCommittedLive(const SICTSignalResult &committed,SICTSignalResult &current)
  {
   if(!current.confirmed) return; // Keep the current veto visible to consumers.
   bool same=current.id==committed.id && current.symbol==committed.symbol &&
      current.asof==committed.asof && current.trigger_bar==committed.trigger_bar &&
      current.direction==committed.direction && current.entry==committed.entry &&
      current.stop==committed.stop && current.tp1==committed.tp1 && current.tp2==committed.tp2 &&
      current.source_pool_id==committed.source_pool_id && current.target_pool_id==committed.target_pool_id &&
      current.target2_pool_id==committed.target2_pool_id && current.source_event_time==committed.source_event_time &&
      current.data_ready && current.htf_pass && current.mtf_pass && current.ltf_pass && current.risk_pass &&
      (!current.smt_required || current.smt_pass) && current.frames.status==ICT_MTF_FULL &&
      current.confirmation_time==current.asof && current.source_event_time<=current.asof &&
      current.target_pool_id!="" && ICTSignalPlanValid(current,2) &&
      current.state==(current.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED);
   // Keep the freshly evaluated score, RR and diagnostics in the live view;
   // the immutable journal retains the original observation separately.
   if(same) return;
   current.confirmed=false; current.state=ICT_SIGNAL_NO_TRADE; current.risk_pass=false;
   current.confirmation_time=0;
   current.reason="NO_TRADE: live plan differs from committed signal or failed recheck";
  }
// No score can override a missing tier/trigger, target, SMT veto or risk gate.
bool ICTEvaluateSignal(SICTSignalResult &s,const double minimum_rr)
  {
   s.confirmed=false; s.state=ICT_SIGNAL_NO_TRADE; s.confirmation_time=0;
   s.id=s.symbol+"|"+IntegerToString((int)s.frames.ltf)+"|"+IntegerToString((long)s.trigger_bar)+"|"+IntegerToString(s.direction);
   if(!s.data_ready || s.frames.status!=ICT_MTF_FULL)
     { s.reason="DATA INSUFFICIENT: three closed timeframe tiers required"; return false; }
   if((s.direction!=1 && s.direction!=-1) || !s.htf_pass || !s.mtf_pass)
     { s.reason="NO_TRADE: HTF bias / MTF setup conflict or missing"; return false; }
   if(!s.ltf_pass || s.trigger_bar<=0 || s.asof<=s.trigger_bar || s.source_event_time>s.asof)
     {
      s.state=(s.direction>0 ? ICT_SIGNAL_WATCH_BUY : ICT_SIGNAL_WATCH_SELL);
      s.reason="WATCH: waiting for a valid closed LTF trigger"; return false;
     }
   if(s.smt_required && !s.smt_pass)
     { s.reason="NO_TRADE: required SMT unavailable, conflicting or unaligned"; return false; }
   if(s.tp1<=0 || s.target_pool_id=="")
     { s.reason="TARGET UNAVAILABLE"; return false; }
   if(!s.risk_pass || !ICTSignalPlanValid(s,minimum_rr))
     { s.reason="RISK FILTER FAIL: invalid plan or net RR below configured minimum"; return false; }
   s.state=(s.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED);
   s.confirmed=true; s.confirmation_time=s.asof;
   s.reason=s.htf_reason+" / "+s.mtf_reason+" / "+s.ltf_reason;
   return true;
  }
bool ICTSignalInsideWindow(const SICTSignalResult &s,const datetime oldest_bar,const datetime latest_close)
  {
   return s.confirmed && s.trigger_bar>=oldest_bar && s.confirmation_time<=latest_close &&
      s.confirmation_time>s.trigger_bar;
  }
// Append-only within the retention window. A recalculation cannot overwrite a
// previously committed candle, even with another ID/direction or changed prices.
bool ICTMergeConfirmedSignal(const SICTSignalResult &s,SICTSignalResult &history[],const int maximum)
  {
   if(!s.confirmed || s.id=="" || maximum<1 || s.confirmation_time<=s.trigger_bar) return false;
   for(int i=0;i<ArraySize(history);i++)
      if(history[i].id==s.id || (history[i].symbol==s.symbol && history[i].frames.ltf==s.frames.ltf &&
                              history[i].trigger_bar==s.trigger_bar)) return false;
   int n=ArraySize(history);
   if(n>=maximum) return false; // Never silently replace in-window confirmations.
   ArrayResize(history,n+1); history[n]=s; return true;
  }
#endif
