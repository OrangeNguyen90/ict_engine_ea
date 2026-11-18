#ifndef ICT_UNIFIED_INPUTS_MQH
#define ICT_UNIFIED_INPUTS_MQH
#include "ICTUnifiedAnalysis.mqh"

input group "Unified LTF / MTF / HTF"
input bool AutoTimeframeMapping=true;
input ENUM_TIMEFRAMES LTFOverride=PERIOD_CURRENT; // CURRENT keeps chart / mapped tier independently.
input ENUM_TIMEFRAMES MTFOverride=PERIOD_CURRENT;
input ENUM_TIMEFRAMES HTFOverride=PERIOD_CURRENT;
input ENUM_ICT_MTF_MODE MTF_Mode=ICT_MTF_AUTO;
input ENUM_TIMEFRAMES MTF_Override=PERIOD_H1;
input ENUM_TIMEFRAMES HTF_Override=PERIOD_D1;
input int Context_Lookback_Bars=60;
input int SignalHistoryClosedBars=60;
input bool ShowConfirmedSignals=true;
input bool Context_ShowLTF=true;
input bool Context_ShowMTF=true;
input bool Context_ShowHTF=true;
input group "Dynamic SMT: detection and chart display are separate windows"
enum ENUM_ICT_SMT_SELECTION { SMT_SELECTION_AUTO=0, SMT_SELECTION_MANUAL=1, SMT_SELECTION_OFF=2 };
input ENUM_ICT_SMT_SELECTION SMTMode=SMT_SELECTION_AUTO;
input string SMTSymbol1="";
input string SMTSymbol2="";
input bool SMTRequiredForConfirmation=false; // Legacy Mandatory_SMT remains an additional veto.
input ENUM_SMT_CORRELATION SMT_Peer1_Relation=SMT_AUTO;
input ENUM_SMT_CORRELATION SMT_Peer2_Relation=SMT_AUTO;
input ENUM_ICT_SMT_MODE SMT_Timeframe_Mode=AUTO_ALL;
input ENUM_TIMEFRAMES SMT_ManualTimeframe=PERIOD_H1;
input ENUM_ICT_SMT_SLOT SMT_Comparator1_Mode=SMT_SLOT_AUTO;
input ENUM_ICT_SMT_SLOT SMT_Comparator2_Mode=SMT_SLOT_AUTO;
input string SMT_Comparator1_Symbol="";
input string SMT_Comparator2_Symbol="";
input string SMT_DefaultPairMap="EURUSD:GBPUSD,DXY;GBPUSD:EURUSD,DXY;XAUUSD:XAGUSD,DXY;XAGUSD:XAUUSD,DXY;ES:NQ,YM;NQ:ES,YM";
input ENUM_SMT_CORRELATION SMT_Relation_Mode=SMT_AUTO;
input int SMT_Display_Lookback_Bars=60;
input int SMT_Detection_Lookback_Bars=60;
input int SMT_MaxPivotTimeGapBars=3;
input int SMT_Pivot_Left=2;
input int SMT_Pivot_Right=2;
input int SMT_Correlation_Window=60;
input double SMT_MinAbsCorrelation=0.60;
input double SMT_PriceToleranceTicks=1;
input bool SMT_ShowLTF=true;
input bool SMT_ShowMTF=true;
input bool SMT_ShowHTF=true;
input bool SMT_ShowCurrentChart=true; // Used if an LTF override makes chart TF a fourth SMT source.
input group "ICT Strong Order Block: evidence at confirmation"
input bool EnableAutoOB=true;
input bool EnableStrongOBOnly=false;
input int OB_MinStrengthToDraw=60;
input int OB_MaxVisibleZones=12;
input int OB_LookbackBars=300;
input int OB_ExtendBars=60;
input int OB_MaxConsecutiveCandles=3;
input bool OB_UseMultiTimeframe=true;
input bool OB_AutoTimeframeMapping=true; // false limits analysis to chart LTF; no second mapping table.
input bool OB_ShowStrengthScore=true;
input bool OB_ShowMidline=true;
input bool OB_ShowOpenReference=true;
input bool OB_ShowMitigated=true;
input bool OB_ShowInvalidated=false;
input bool OB_ShowHigherTimeframeOB=true;
input bool OB_RequireFVG=false;
input double OB_FVG_MinSizeATR=0.10;
input double OB_DisplacementATRMultiplier=1.2;
input double Displacement_MinBodyRatio=0.60;
input int Displacement_LookaheadBars=3;
input double OB_MaxDisplacementOverlap=0.80;
input bool OB_InvalidateOnClose=true;
input double OB_PriceToleranceTicks=1;
input double OB_MitigationFraction=0.50;
input int OB_ExpiryBars=300;
input bool OB_AllowContinuation=true;
input int OB_Weight_Sweep=20;
input int OB_Weight_Displacement=20;
input int OB_Weight_Structure=15;
input int OB_Weight_FVG=15;
input int OB_Weight_HTF=15;
input int OB_Weight_PremiumDiscount=10;
input int OB_Weight_Freshness=5;
input int OB_StrongThreshold=80;
input int OB_ModerateThreshold=60;
input int OB_TouchPenalty=5;
input ENUM_SRMP_OB_BOUNDS OB_Bounds_Mode=SRMP_OB_HYBRID;
input bool OB_EnableAlerts=true; // Local diagnostic events; existing notification switches still apply.
input color OB_StrongBullColor=clrDarkGreen;
input color OB_StrongBearColor=clrMaroon;
input color OB_MediumBullColor=clrSeaGreen;
input color OB_MediumBearColor=clrDarkOrange;
input color OB_WeakColor=clrGray;
input group "ICT Rejection / Breaker chart signals"
input bool Show_Rejection_Blocks=true;
input bool Show_Breaker_Blocks=true;
input bool Show_Invalid_Block_Signals=false;
input int BlockSignal_LookbackBars=300;
input int BlockSignal_ConfirmBars=5;
input double RB_MinWickRangeRatio=0.50;
input double BlockSignal_MinBodyRatio=0.60;
input double BlockSignal_MinRangeAverage=1.20;
input double Breaker_OB_DisplacementFactor=1.20;
input color RB_BullColor=clrTurquoise;
input color RB_BearColor=clrDarkOrange;
input color Breaker_BullColor=clrMediumSeaGreen;
input color Breaker_BearColor=clrIndianRed;

bool ICTConfigureUnifiedInputs(const ENUM_TIMEFRAMES chart,const string legacy_one,const string legacy_two,
                               SICTUnifiedConfig &c,const bool legacy_auto=true,
                               const bool legacy_auto_one=true,const bool legacy_auto_two=true)
  {
   ZeroMemory(c);
   c.chart_tf=chart;
   bool automatic=AutoTimeframeMapping && MTF_Mode==ICT_MTF_AUTO;
   ENUM_TIMEFRAMES mtf=(MTFOverride!=PERIOD_CURRENT ? MTFOverride : automatic ? PERIOD_CURRENT : MTF_Override);
   ENUM_TIMEFRAMES htf=(HTFOverride!=PERIOD_CURRENT ? HTFOverride : automatic ? PERIOD_CURRENT : HTF_Override);
   if(!ICTResolveTimeframes(chart,automatic,LTFOverride,mtf,htf,c.frames)) return false;
   ICTDefaultDynamicSMTConfig(c.smt); ICTDefaultStrongOBConfig(c.ob);
   c.structure_lookback=Context_Lookback_Bars; c.ob_lookback=OB_LookbackBars;
   c.enable_ob=EnableAutoOB; c.enable_smt=SMTMode!=SMT_SELECTION_OFF;
   c.ob_multi=OB_UseMultiTimeframe && OB_AutoTimeframeMapping; c.ob_show_higher=OB_ShowHigherTimeframeOB;
   c.smt.mode=SMT_Timeframe_Mode; c.smt.manual_tf=SMT_ManualTimeframe;
   c.smt.slot1=SMT_Comparator1_Mode; c.smt.slot2=SMT_Comparator2_Mode;
   c.smt.manual1=(SMTSymbol1!="" ? SMTSymbol1 : SMT_Comparator1_Symbol!="" ? SMT_Comparator1_Symbol : legacy_one);
   c.smt.manual2=(SMTSymbol2!="" ? SMTSymbol2 : SMT_Comparator2_Symbol!="" ? SMT_Comparator2_Symbol : legacy_two);
   if(SMTMode==SMT_SELECTION_MANUAL) { c.smt.slot1=SMT_SLOT_MANUAL; c.smt.slot2=SMT_SLOT_MANUAL; }
   if(SMTMode==SMT_SELECTION_OFF) { c.smt.slot1=SMT_SLOT_DISABLED; c.smt.slot2=SMT_SLOT_DISABLED; }
   if(c.smt.slot1==SMT_SLOT_AUTO && c.smt.manual1=="" && (!legacy_auto || !legacy_auto_one)) c.smt.slot1=SMT_SLOT_DISABLED;
   if(c.smt.slot2==SMT_SLOT_AUTO && c.smt.manual2=="" && (!legacy_auto || !legacy_auto_two)) c.smt.slot2=SMT_SLOT_DISABLED;
   c.smt.pair_map=SMT_DefaultPairMap; c.smt.relation=SMT_Relation_Mode;
   c.smt.relation1=SMT_Peer1_Relation; c.smt.relation2=SMT_Peer2_Relation;
   c.smt.display_bars=SMT_Display_Lookback_Bars; c.smt.detection_bars=SMT_Detection_Lookback_Bars;
   c.smt.left=SMT_Pivot_Left; c.smt.right=SMT_Pivot_Right; c.smt.max_gap=SMT_MaxPivotTimeGapBars;
   c.smt.correlation_window=SMT_Correlation_Window; c.smt.correlation_threshold=SMT_MinAbsCorrelation;
   c.smt.tolerance_ticks=SMT_PriceToleranceTicks; c.smt.show_ltf=SMT_ShowLTF; c.smt.show_mtf=SMT_ShowMTF; c.smt.show_htf=SMT_ShowHTF;
   c.ob.max_group=OB_MaxConsecutiveCandles; c.ob.confirmation_bars=Displacement_LookaheadBars;
   c.ob.left=SMT_Pivot_Left; c.ob.right=SMT_Pivot_Right; c.ob.bounds=OB_Bounds_Mode;
   c.ob.displacement_atr=OB_DisplacementATRMultiplier; c.ob.body_ratio=Displacement_MinBodyRatio;
   c.ob.max_overlap=OB_MaxDisplacementOverlap; c.ob.fvg_atr=OB_FVG_MinSizeATR;
   c.ob.require_fvg=OB_RequireFVG; c.ob.invalidate_on_close=OB_InvalidateOnClose;
   c.ob.tolerance_ticks=OB_PriceToleranceTicks; c.ob.mitigation_fraction=OB_MitigationFraction;
   c.ob.expiry_bars=OB_ExpiryBars; c.ob.allow_continuation=OB_AllowContinuation;
   c.ob.weight_sweep=OB_Weight_Sweep; c.ob.weight_displacement=OB_Weight_Displacement;
   c.ob.weight_structure=OB_Weight_Structure; c.ob.weight_fvg=OB_Weight_FVG; c.ob.weight_bias=OB_Weight_HTF;
   c.ob.weight_pd=OB_Weight_PremiumDiscount; c.ob.weight_freshness=OB_Weight_Freshness;
   c.ob.strong_threshold=OB_StrongThreshold; c.ob.moderate_threshold=OB_ModerateThreshold; c.ob.touch_penalty=OB_TouchPenalty;
   if((c.smt.manual1!="" && c.smt.manual1==c.smt.manual2) || c.smt.manual1==_Symbol || c.smt.manual2==_Symbol ||
      OB_MinStrengthToDraw<0 || OB_MinStrengthToDraw>100 || OB_MaxVisibleZones<1 || OB_MaxVisibleZones>ICT_SMART_OB_MAX ||
      OB_ExtendBars<1 || OB_ExtendBars>1000 || SignalHistoryClosedBars<1 || SignalHistoryClosedBars>500 ||
      BlockSignal_LookbackBars<40 || BlockSignal_LookbackBars>1000 || BlockSignal_ConfirmBars<1 || BlockSignal_ConfirmBars>10 ||
      RB_MinWickRangeRatio<=0.0 || RB_MinWickRangeRatio>=1.0 || BlockSignal_MinBodyRatio<=0.0 || BlockSignal_MinBodyRatio>1.0 ||
      BlockSignal_MinRangeAverage<=0.0 || Breaker_OB_DisplacementFactor<=0.0) return false;
   return ICTValidUnifiedConfig(c);
  }
#endif
