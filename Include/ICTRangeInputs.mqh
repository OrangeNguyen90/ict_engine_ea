#ifndef ICT_RANGE_INPUTS_MQH
#define ICT_RANGE_INPUTS_MQH
#include "ICTRangeTypes.mqh"
input group "ICT Internal / External Range Liquidity"
input bool Enable_IRL_ERL=true;
input ENUM_TIMEFRAMES Range_HTF=PERIOD_H4;
input ENUM_TIMEFRAMES Range_MTF=PERIOD_M15;
input ENUM_TIMEFRAMES Range_LTF=PERIOD_M5;
input int Range_Lookback=240; // Closed bars per timeframe; bounded replay.
input int Range_Liquidity_Seed_Bars=10000; // Maximum closed LTF bars used to seed older liquidity pools.
input int Range_Swing_Left=2;
input int Range_Swing_Right=2;
input double Range_Minimum_Width_Ticks=20;
input double Range_Tolerance_Ticks=2;
input double Range_Tolerance_ATR=0.02;
input double Range_Equal_Threshold_Ticks=3;
input double Range_Equal_Threshold_ATR=0.02;
input double Range_Equal_Spread_Multiplier=1.0;
input double Range_Sweep_Penetration_Ticks=3;
input double Range_Sweep_Penetration_ATR=0.05;
input double Range_Approach_ATR=0.25;
input int Range_Breakout_Confirmation_Bars=2;
input bool Range_Breakout_Displacement_Confirms=true; // Existing single-displacement shortcut.
input bool Range_Breakout_Require_Displacement=false; // Require displacement in the outside-close sequence.
input double Range_Breakout_Buffer_Ticks=0; // Additional floor; never less than sweep penetration.
input double Range_Breakout_Buffer_ATR=0;
input double Range_Breakout_Failure_Buffer_Ticks=0; // Close back inside the pool by this distance.
input int Range_Retest_Window_Bars=8; // Closed LTF bars after confirmed breakout.
input double Range_Retest_Tolerance_Ticks=2;
input double Range_Retest_Tolerance_ATR=0.02;
input double Range_Retest_Close_Buffer_Ticks=1; // Directional close holding beyond the broken level.
input int Range_Liquidity_Event_History_Bars=60; // Display window; bounded event records, not trade signals.
input double Range_FVG_Minimum_Ticks=2;
input double Range_FVG_Minimum_ATR=0.05;
input int Range_Maximum_Zone_Age=48; // MTF bars.
input double Range_Displacement_ATR=1.0; // Body vs prior rolling mean true range.
input double Range_Displacement_Body_Fraction=0.60;
input double Range_Stop_Buffer_Ticks=2;
input bool Range_Require_MSS=true; // Reversal; continuation requires aligned BOS.
input bool Range_Require_Displacement=true;
input bool Range_Use_OB_Confluence=true;
input bool Range_Allow_Continuation=true;
input bool Range_Export_History=true;
input bool Range_Log_Events=false;
input bool Range_Show_Range=true;
input bool Range_Show_IRL=true;
input bool Range_Show_ERL=true;
input bool Range_Show_Targets=true;
input bool Range_Show_Rotation=true;
input bool Range_Auto_Trading=false; // Unsupported; true is rejected. Advisory only.
input group "Liquidity sweep sequence"
input bool EnableLiquiditySweepDetection=true;
input bool EnableMultiSweepAnalysis=true;
#ifdef ICT_SMART_ENGINE
input ENUM_ICT_SWEEP_MODE SweepMode=SWEEP_2_PREFERRED;
#endif
input bool ShowSweep1=true;
input bool ShowSweep2=true;
input bool ShowSweep3Plus=true;
input bool EnableSweepConnectionLine=true;
input int Sweep_Minimum_Bars_Between=2;
input int Sweep_Validation_Window_Bars=3;
input double Sweep_Rejection_Distance_Ticks=3;
input double Sweep_Price_Tolerance_Ticks=0;
input int Sweep_Maximum_Events_To_Draw=12;

void ICTConfigureRangeInputs(SICTRangeConfig &c)
  {
   ICTDefaultRangeConfig(c); c.enabled=Enable_IRL_ERL;
   c.htf=Range_HTF; c.mtf=Range_MTF; c.ltf=Range_LTF;
   c.lookback=Range_Lookback; c.liquidity_seed_bars=Range_Liquidity_Seed_Bars;
   c.left=Range_Swing_Left; c.right=Range_Swing_Right;
   c.min_range_ticks=Range_Minimum_Width_Ticks; c.tolerance_ticks=Range_Tolerance_Ticks;
   c.tolerance_atr=Range_Tolerance_ATR; c.equal_ticks=Range_Equal_Threshold_Ticks;
   c.equal_atr=Range_Equal_Threshold_ATR; c.equal_spread=Range_Equal_Spread_Multiplier;
   c.penetration_ticks=Range_Sweep_Penetration_Ticks; c.penetration_atr=Range_Sweep_Penetration_ATR;
   c.approach_atr=Range_Approach_ATR; c.breakout_bars=Range_Breakout_Confirmation_Bars;
   c.breakout_displacement_confirms=Range_Breakout_Displacement_Confirms;
   c.breakout_require_displacement=Range_Breakout_Require_Displacement;
   c.breakout_buffer_ticks=Range_Breakout_Buffer_Ticks; c.breakout_buffer_atr=Range_Breakout_Buffer_ATR;
   c.breakout_failure_ticks=Range_Breakout_Failure_Buffer_Ticks;
   c.retest_window_bars=Range_Retest_Window_Bars; c.retest_tolerance_ticks=Range_Retest_Tolerance_Ticks;
   c.retest_tolerance_atr=Range_Retest_Tolerance_ATR; c.retest_close_buffer_ticks=Range_Retest_Close_Buffer_Ticks;
   c.liquidity_history_bars=Range_Liquidity_Event_History_Bars;
   c.min_fvg_ticks=Range_FVG_Minimum_Ticks; c.min_fvg_atr=Range_FVG_Minimum_ATR;
   c.max_zone_age=Range_Maximum_Zone_Age; c.displacement_atr=Range_Displacement_ATR;
   c.displacement_fraction=Range_Displacement_Body_Fraction; c.stop_buffer_ticks=Range_Stop_Buffer_Ticks;
   c.require_mss=Range_Require_MSS; c.require_displacement=Range_Require_Displacement;
   c.use_ob=Range_Use_OB_Confluence; c.allow_continuation=Range_Allow_Continuation;
   c.export_history=Range_Export_History; c.log_events=Range_Log_Events;
   c.enable_sweep_sequence=EnableLiquiditySweepDetection;
#ifdef ICT_SMART_ENGINE
   c.sweep_mode=SweepMode;
#endif
   c.sweep_min_bars=Sweep_Minimum_Bars_Between;
   c.sweep_validation_bars=Sweep_Validation_Window_Bars;
   c.sweep_rejection_ticks=Sweep_Rejection_Distance_Ticks;
   c.sweep_tolerance_ticks=Sweep_Price_Tolerance_Ticks;
  }
#endif
