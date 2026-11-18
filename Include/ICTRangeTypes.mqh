#ifndef ICT_RANGE_TYPES_MQH
#define ICT_RANGE_TYPES_MQH
#include "ICTSweepSequence.mqh"

#define ICT_RANGE_LEVELS 24
#define ICT_RANGE_ZONES 16
#define ICT_RANGE_HISTORY 64
#define ICT_RANGE_EVENTS 256
#define ICT_RANGE_LIQUIDITY_EVENTS 128
#define ICT_RANGE_SCHEMA 4

enum ENUM_IR_MEMBERSHIP { IR_OUTSIDE=0, IR_INTERNAL=1, IR_BOUNDARY=2, IR_CROSSING=3 };
enum ENUM_IR_LEVEL_STATE { IR_UNTOUCHED=0, IR_APPROACHING, IR_SWEPT, IR_BREAKOUT, IR_CONSUMED, IR_LEVEL_INVALIDATED };
// A pool's lifecycle is independent of its latest closed-bar observation.
enum ENUM_IR_LEVEL_EVENT { IR_EVENT_NONE=0, IR_EVENT_LIQUIDITY_SWEEP,
   IR_EVENT_BREAKOUT_CONFIRMED, IR_EVENT_FALSE_BREAKOUT, IR_EVENT_RETEST_CONFIRMED };
enum ENUM_IR_ZONE_TYPE { IR_FVG=0, IR_OB, IR_BREAKER };
enum ENUM_IR_ZONE_STATE { IR_FRESH=0, IR_TOUCHED, IR_MITIGATED, IR_ZONE_INVALIDATED };
enum ENUM_IR_PHASE { IR_RANGE_IDENTIFIED=0, IR_ERL_APPROACH, IR_SWEEP_CANDIDATE,
   IR_SWEEP_CONFIRMED, IR_STRUCTURE_SHIFT, IR_RETRACEMENT, IR_REACTION,
   IR_TARGETING, IR_TARGET_REACHED, IR_SETUP_INVALIDATED };
enum ENUM_IR_SCENARIO { IR_CONSOLIDATION=0, IR_REVERSAL, IR_CONTINUATION, IR_BREAKOUT_CONTINUATION, IR_FAILED_SWEEP };
enum ENUM_IR_REASON { IR_OK=0, IR_DATA, IR_CONFIG, IR_NO_RANGE, IR_CONFLICT,
   IR_WAIT_SWEEP, IR_WAIT_STRUCTURE, IR_NO_ZONE, IR_WAIT_REACTION, IR_NO_TARGET,
   IR_INVALIDATION, IR_EXPIRED, IR_HISTORY_REVISED, IR_RISK, IR_SCORE, IR_DISABLED };

struct SICTRangeConfig
  {
   bool enabled;
   ENUM_TIMEFRAMES htf,mtf,ltf;
   int lookback,left,right,max_zone_age,breakout_bars,zone_mode,liquidity_seed_bars;
   double min_range_ticks,tolerance_ticks,tolerance_atr,equal_ticks,equal_atr,equal_spread;
   double penetration_ticks,penetration_atr,approach_atr;
   double min_fvg_ticks,min_fvg_atr,displacement_atr,displacement_fraction,stop_buffer_ticks;
   bool require_mss,require_displacement,use_ob,allow_continuation;
   bool export_history,log_events;
   bool breakout_displacement_confirms,breakout_require_displacement;
   double breakout_buffer_ticks,breakout_buffer_atr,breakout_failure_ticks;
   double retest_tolerance_ticks,retest_tolerance_atr,retest_close_buffer_ticks;
   int retest_window_bars,liquidity_history_bars;
   bool enable_sweep_sequence;
   ENUM_ICT_SWEEP_MODE sweep_mode;
   int sweep_min_bars,sweep_validation_bars;
   double sweep_rejection_ticks,sweep_tolerance_ticks;
  };

void ICTDefaultRangeConfig(SICTRangeConfig &c)
  {
   ZeroMemory(c); c.enabled=true; c.htf=PERIOD_H4; c.mtf=PERIOD_M15; c.ltf=PERIOD_M5;
   c.lookback=240; c.liquidity_seed_bars=10000; c.left=2; c.right=2; c.max_zone_age=48; c.breakout_bars=2;
   c.zone_mode=2; // Same 0 FVG / 1 OB / 2 either values as ICTConfluenceScore.
   c.min_range_ticks=20; c.tolerance_ticks=2; c.tolerance_atr=0.02; c.equal_ticks=3;
   c.equal_atr=0.02; c.equal_spread=1.0;
   c.penetration_ticks=3; c.penetration_atr=0.05; c.approach_atr=0.25;
   c.min_fvg_ticks=2; c.min_fvg_atr=0.05; c.displacement_atr=1;
   c.displacement_fraction=0.6; c.stop_buffer_ticks=2;
   c.require_mss=true; c.require_displacement=true; c.use_ob=true;
   c.allow_continuation=true; c.export_history=true;
   // Preserve the existing displacement shortcut; users can require a full
   // close count and/or displacement explicitly, without changing risk gates.
   c.breakout_displacement_confirms=true; c.breakout_require_displacement=false;
   c.breakout_buffer_ticks=0; c.breakout_buffer_atr=0; c.breakout_failure_ticks=0;
   c.retest_tolerance_ticks=2; c.retest_tolerance_atr=0.02; c.retest_close_buffer_ticks=1;
   c.retest_window_bars=8; c.liquidity_history_bars=60;
   c.enable_sweep_sequence=true; c.sweep_min_bars=2; c.sweep_validation_bars=3;
   c.sweep_mode=SWEEP_1_ALLOWED; // Preserve existing consumers unless they opt in.
   c.sweep_rejection_ticks=3; c.sweep_tolerance_ticks=0;
  }

bool ICTValidRangeConfig(const SICTRangeConfig &c)
  {
   double values[22]={c.min_range_ticks,c.tolerance_ticks,c.tolerance_atr,c.equal_ticks,c.equal_atr,c.equal_spread,
      c.penetration_ticks,c.penetration_atr,c.approach_atr,c.min_fvg_ticks,c.min_fvg_atr,
       c.displacement_atr,c.displacement_fraction,c.stop_buffer_ticks,c.sweep_rejection_ticks,c.sweep_tolerance_ticks,
       c.breakout_buffer_ticks,c.breakout_buffer_atr,c.breakout_failure_ticks,
       c.retest_tolerance_ticks,c.retest_tolerance_atr,c.retest_close_buffer_ticks};
   for(int i=0;i<22;i++) if(!MathIsValidNumber(values[i]) || values[i]<0) return false;
   return PeriodSeconds(c.htf)>PeriodSeconds(c.mtf) && PeriodSeconds(c.mtf)>PeriodSeconds(c.ltf) &&
      PeriodSeconds(c.ltf)>0 && c.lookback>=80 && c.lookback<=1000 &&
      c.liquidity_seed_bars>=c.lookback && c.liquidity_seed_bars<=50000 && c.left>=1 && c.right>=1 &&
      c.left+c.right+30<c.lookback && c.max_zone_age>=1 && c.max_zone_age<=c.lookback &&
      c.breakout_bars>=2 && c.breakout_bars<=10 && c.zone_mode>=0 && c.zone_mode<=2 && c.min_range_ticks>0 &&
      c.min_fvg_ticks>0 && c.displacement_atr>0 && c.displacement_fraction>0 &&
      c.displacement_fraction<=1 && c.stop_buffer_ticks>=1 &&
      c.sweep_min_bars>=1 && c.sweep_validation_bars>=1 &&
       c.retest_window_bars>=1 && c.retest_window_bars<=1000 &&
       c.liquidity_history_bars>=1 && c.liquidity_history_bars<=1000 &&
      (int)c.sweep_mode>=0 && (int)c.sweep_mode<=2 &&
      (c.sweep_mode!=SWEEP_2_REQUIRED || c.enable_sweep_sequence);
  }

double ICTRangeEqualTolerance(const double tick,const double atr,const double spread_price,
                              const SICTRangeConfig &c)
  {
   if(!MathIsValidNumber(tick) || tick<=0 || !MathIsValidNumber(atr) || atr<0 ||
      !MathIsValidNumber(spread_price) || spread_price<0 ||
      !MathIsValidNumber(c.equal_ticks) || c.equal_ticks<0 ||
      !MathIsValidNumber(c.equal_atr) || c.equal_atr<0 ||
      !MathIsValidNumber(c.equal_spread) || c.equal_spread<0) return -1;
   return MathMax(c.equal_ticks*tick,MathMax(c.equal_atr*atr,c.equal_spread*spread_price));
  }

struct SICTDealingRange
  {
   string id;
   int version;
   double high,low,midpoint,width;
   int direction,bias;
   ENUM_TIMEFRAMES timeframe;
   datetime high_time,low_time,confirmed_at,retired_at;
   bool valid;
  };

struct SICTRangeLevel
  {
   string id,range_id,name;
   double price;
   int side; // +1 BSL / -1 SSL, not trade direction.
   ENUM_IR_MEMBERSHIP membership;
   ENUM_IR_LEVEL_STATE state;
   ENUM_TIMEFRAMES timeframe; // Source pool TF; events are observed on snapshot LTF.
   datetime available_at,event_at,last_bar;
   int outside_closes;
   bool candidate;
   ENUM_IR_LEVEL_EVENT last_event;
   datetime event_bar_time,event_wick_time;
   double event_wick,event_close;
   datetime candidate_wick_time,breakout_at;
   double candidate_wick;
   bool candidate_displacement,retest_pending,sweep_armed;
   int breakout_age,sweep_count,sweep_wait_bars;
  };

struct SICTRangeLiquidityEvent
  {
   string id,pool_id,range_id,pool_name;
   ENUM_IR_LEVEL_EVENT type;
   ENUM_IR_MEMBERSHIP membership;
   ENUM_TIMEFRAMES source_tf,event_tf;
   int side,sweep_number;
   datetime bar_time,wick_time,confirmed_at;
   double level,wick,close;
  };

struct SICTRangeZone
  {
   string id,range_id;
   ENUM_IR_ZONE_TYPE type;
   ENUM_IR_ZONE_STATE state;
   ENUM_IR_MEMBERSHIP membership;
   ENUM_TIMEFRAMES timeframe;
   int direction,quality;
   double upper,lower,midpoint,invalidation;
   datetime formed_at,confirmed_at;
   bool displacement,structure_match,confluence;
  };

bool ICTRangeExternal(const SICTRangeLevel &level,const SICTDealingRange &range)
  {
   return level.range_id==range.id && (level.membership==IR_OUTSIDE || level.membership==IR_BOUNDARY) &&
      (level.side>0 ? level.price>=range.high : level.price<=range.low);
  }

struct SICTRangeSnapshot
  {
   int schema;
   string symbol,signal_id,reason,target_reason,source_reason;
   string source_pool_id,target1_pool_id,target2_pool_id;
   ENUM_TIMEFRAMES source_pool_tf,target1_pool_tf,target2_pool_tf;
   ENUM_IR_LEVEL_EVENT source_event;
   datetime source_event_at,liquidity_display_start;
   ENUM_IR_REASON reason_code;
   SICTDealingRange range;
   ENUM_TIMEFRAMES mtf,ltf;
   datetime as_of,phase_at,sweep_at,structure_at,reaction_at,last_mtf_event;
   ENUM_IR_PHASE phase;
   ENUM_IR_SCENARIO scenario;
   int direction,htf_bias;
   bool valid,technical_ready,displacement,structure_confirmed;
   double sweep_extreme,sweep_level,invalidation,entry,stop,tp1,tp2,target_distance,last_close;
   int target1_index,target2_index;
   SICTRangeZone active_zone;
   int level_count,zone_count;
   SICTRangeLevel levels[ICT_RANGE_LEVELS];
   SICTRangeZone zones[ICT_RANGE_ZONES];
   int liquidity_event_count;
   SICTRangeLiquidityEvent liquidity_events[ICT_RANGE_LIQUIDITY_EVENTS];
   int sweep_event_count;
   SICTSweepRecord sweep_events[ICT_SWEEP_SNAPSHOT_MAX];
   // Filled only by the EA-side risk/decision integration, never by the indicator.
   int proposed_action,score;
   double risk_money,volume,rr;
  };

struct SICTRangeEvent
  {
   string range_id,signal_id,trigger,reason;
   int direction;
   ENUM_IR_PHASE from_phase,to_phase;
   datetime confirmed_at;
   double open,high,low,close,invalidation,zone_low,zone_high,target;
  };

bool ICTRangePlanGeometry(const SICTRangeSnapshot &s,const double minimum_rr)
  {
   if(!s.valid || !s.technical_ready || !s.range.valid ||
      s.active_zone.range_id!=s.range.id || (s.direction!=1 && s.direction!=-1) ||
      !MathIsValidNumber(s.entry) || !MathIsValidNumber(s.stop) || !MathIsValidNumber(s.tp1) ||
      !MathIsValidNumber(minimum_rr) || minimum_rr<2 || s.entry<=0 || s.stop<=0 || s.tp1<=0 ||
      (s.entry-s.stop)*s.direction<=0 || (s.tp1-s.entry)*s.direction<=0) return false;
   return MathAbs(s.tp1-s.entry)/MathAbs(s.entry-s.stop)+1e-9>=minimum_rr;
  }

// A paper plan is no longer actionable when the executable exit-side quote
// has already reached its first target, even if the current candle is open.
bool ICTRangeLiveTargetSafe(const int direction,const double bid,const double ask,const double target)
  {
   if((direction!=1 && direction!=-1) || !MathIsValidNumber(bid) || !MathIsValidNumber(ask) ||
      !MathIsValidNumber(target) || bid<=0 || ask<bid || target<=0) return false;
   return direction>0 ? bid<target : ask>target;
  }

// OHLC cannot establish whether the target was hit before or after the entry
// reaction in the same bar. Reject this ambiguous plan conservatively.
bool ICTRangeReactionTargetSafe(const int direction,const MqlRates &bar,const double target)
  {
   if((direction!=1 && direction!=-1) || !SRMPValidDetectorBar(bar) || bar.low<=0 ||
      !MathIsValidNumber(target) || target<=0) return false;
   return direction>0 ? bar.high<target : bar.low>target;
  }

string ICTRangePhaseText(const ENUM_IR_PHASE p)
  {
   string names[10]={"RANGE_IDENTIFIED","ERL_APPROACH","ERL_SWEEP_CANDIDATE",
      "ERL_SWEEP_CONFIRMED","STRUCTURE_SHIFT_CONFIRMED","IRL_RETRACEMENT",
      "IRL_REACTION_CONFIRMED","ERL_TARGETING","TARGET_REACHED","SETUP_INVALIDATED"};
   return (int)p>=0 && (int)p<10 ? names[(int)p] : "UNKNOWN";
  }
string ICTRangeLevelText(const ENUM_IR_LEVEL_STATE s)
  {
   string names[6]={"UNTOUCHED","APPROACHING","SWEPT","BREAKOUT","CONSUMED","INVALIDATED"};
   return (int)s>=0 && (int)s<6 ? names[(int)s] : "UNKNOWN";
  }
string ICTRangeLevelEventText(const ENUM_IR_LEVEL_EVENT event)
  {
   string names[5]={"NONE","LIQUIDITY_SWEEP","BREAKOUT_CONFIRMED","FALSE_BREAKOUT","RETEST_CONFIRMED"};
   return (int)event>=0 && (int)event<5 ? names[(int)event] : "N/A";
  }
string ICTRangeSourceExplanation(const SICTRangeSnapshot &s)
  {
   if(s.source_pool_id=="") return "No source liquidity pool; structure / internal price-objective setup only";
   return s.source_pool_id+" | "+EnumToString(s.source_pool_tf)+" | "+ICTRangeLevelEventText(s.source_event)+
      (s.source_event_at>0 ? " | "+TimeToString(s.source_event_at,TIME_DATE|TIME_MINUTES) : "");
  }
string ICTRangeZoneText(const ENUM_IR_ZONE_TYPE t)
  { return t==IR_FVG ? "FVG" : (t==IR_OB ? "OB" : "BREAKER"); }
string ICTRangeZoneStateText(const ENUM_IR_ZONE_STATE state)
  { return state==IR_FRESH ? "Fresh" : (state==IR_TOUCHED ? "Touched/partial" :
           (state==IR_MITIGATED ? "Fully mitigated/expired" : "Invalidated")); }
string ICTRangeLocation(const SICTDealingRange &r,const double price)
  {
   if(!r.valid) return "UNKNOWN";
   if(price>r.high || price<r.low) return "OUTSIDE";
   return price>r.midpoint ? "PREMIUM" : (price<r.midpoint ? "DISCOUNT" : "EQUILIBRIUM");
  }
#endif
