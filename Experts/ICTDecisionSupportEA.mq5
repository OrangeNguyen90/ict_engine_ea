#property copyright "MT5 Smart Risk Manager Pro"
#property version "1.03"
#property description "Closed-bar ICT decision support. Never places, modifies or closes trades."

#include "../Include/ICTDecisionEngine.mqh"
#include "../Include/ICTSessionManager.mqh"
#include "../Include/ICTAlertManager.mqh"
#include "../Include/ICTRangeInputs.mqh"
#include "../Include/ICTRangeBridge.mqh"
#include "../Include/ICTRangeRenderer.mqh"
#include "../Include/ICTPositionRiskRenderer.mqh"
#ifdef ICT_SMART_ENGINE
#include "../Include/ICTDecisionBridge.mqh"
#include "../Include/ICTSmartDashboard.mqh"
#include "../Include/SmartAutoPositionSLTP.mqh"
#include "../Include/ICTBalancedPriceRange.mqh"
#include "../Include/ICTTimeframeMapper.mqh"
#include "../Include/ICTUnifiedInputs.mqh"
#include "../Include/ICTUnifiedRenderer.mqh"
#include "../Include/ICTUnifiedBridge.mqh"
#include "../Include/ICTUnifiedDecisionAdapter.mqh"
#include "../Include/ICTSignalHistory.mqh"
#endif

input string Main_Symbol=""; // Empty uses chart symbol; mismatches are rejected.
input ENUM_TIMEFRAMES Higher_Timeframe=PERIOD_H4;
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H1;
input ENUM_TIMEFRAMES Setup_Timeframe=PERIOD_M15;
input ENUM_TIMEFRAMES Trigger_Timeframe=PERIOD_M5;
#ifdef ICT_SMART_ENGINE
input group "SMT 1 / 2: manual symbol overrides automatic"
#endif
input ENUM_TIMEFRAMES SMT_Timeframe=PERIOD_H1;
input string Comparison_Symbol_1=""; // Enter exact broker symbol; blank uses auto if enabled.
input string Comparison_Symbol_2="";
#ifdef ICT_SMART_ENGINE
input bool Auto_Suggest_SMT_Symbols=true; // Master auto switch; Market Watch candidates only.
input bool SMT_1_Auto=true; // Blank manual value + true = automatic; false = disabled.
input bool SMT_2_Auto=true;
input group "ICT analysis and dashboard"
#endif
input int Structure_Lookback=120;
input int Swing_Strength=2;
input int Maximum_Setup_Age_Bars=48;
input double Displacement_Body_ATR=1.0;
input double Displacement_Body_Fraction=0.60;
input double Minimum_FVG_ATR=0.05;
input double Maximum_Spread_Points=50.0;
input double Risk_Per_Trade=1.0;
input double Maximum_Risk_Per_Trade=2.0;
input double Minimum_RR=2.0;
input double Commission_Round_Turn_Per_Lot=0.0;
input double Unspecified_Cost_Buffer_Per_Lot=10.0;
input double Estimated_Slippage_Points=2.0;
input double Daily_Loss_Limit_Percent=0.0; // Disabled by default.
input int Maximum_Quote_Age_Seconds=60;
input bool Show_Chart_Levels=true;
input bool Show_Dashboard=true;
input ENUM_BASE_CORNER Dashboard_Corner=CORNER_LEFT_UPPER;
input int Dashboard_X=12;
input int Dashboard_Y=80; // Keep header below the one-click trading controls.
input int Dashboard_Width=380;
input int Dashboard_Height=420;
input int Dashboard_Font_Size=11;
input ENUM_TIMEFRAMES Chart_Zone_Timeframe=PERIOD_CURRENT; // CURRENT follows the chart; choose an analyzed timeframe to view its zones.
input int Chart_Label_Font_Size=10; // Chart annotations use 75% of this size; independent of the dashboard.
input bool Dashboard_Market_Group=true;
input bool Dashboard_ICT_Group=true;
input bool Dashboard_Plan_Group=true;
input bool Show_FVG=true;
input bool Show_Order_Blocks=true;
input bool Show_SMT=true;
#ifdef ICT_SMART_ENGINE
input bool Show_SMT_Comparison_Legend=true; // Selected comparison symbols and detector states.
input bool EnableBPRDetection=true;
input bool ShowBPRZones=true;
input double BPR_Minimum_Overlap_Ticks=1;
#endif
input bool Show_Premium_Discount=true;
input bool Show_Liquidity=true;
input bool Show_Structure=true;
input bool Show_Inactive_Order_Blocks=false;
input bool Show_Inactive_FVG=false; // Latest historical gap only; no inactive entry approval.
input bool Enable_Popup_Alerts=false;
input bool Enable_Push_Alerts=false;
input bool Enable_Sound_Alerts=false;
input bool Enable_Signal_Log=false;
input bool Alert_On_Startup=false;
input string Alert_Sound_File="alert.wav";
input int Alert_Cooldown_Seconds=60;
input int Weight_HTF=20;
input int Weight_Sweep=15;
input int Weight_MSS=15;
input int Weight_Displacement=5;
input int Weight_FVG=10;
input int Weight_OB=10;
input int Weight_Premium_Discount=10;
input int Weight_SMT=10;
input int Weight_Session=5;
input int Minimum_Priority_Score=65;
input int Strong_Priority_Score=80;
input ENUM_ICT_ZONE_MODE Entry_Zone_Mode=ICT_ZONE_FVG_OR_OB;
input int Minimum_Score_Lead=0;
input bool Mandatory_SMT=false;
input bool Mandatory_Session=false;
input int Tester_Broker_UTC_Offset_Minutes=9999; // Configure per replay period; 9999 disables Tester session evidence.

input group "Live position risk / reward (read-only)"
input bool Show_Position_Risk=true;
input bool Position_Risk_All_Symbols=false; // false: positions on this chart symbol, including manual trades.
input ENUM_ICT_POSITION_CAPITAL Position_Risk_Capital=ICT_POSITION_BALANCE;
input ENUM_BASE_CORNER Position_Risk_Corner=CORNER_RIGHT_UPPER;
input int Position_Risk_X=12;
input int Position_Risk_Y=80;
input int Position_Risk_Width=380;
input int Position_Risk_Height=420;

SICTDecisionConfig g_config;
SICTConfluenceConfig g_scoring;
CICTAlertManager g_alerts;
SICTDecision g_decision;
string g_prefix="SRMP_ICTD_";
string g_session="";
SICTRangeConfig g_range_config;
SICTRangeSnapshot g_range_snapshot;
CICTRangeEngine g_range_engine;
int g_last_range_reason=-1;
bool g_last_range_valid=false;
SICTPositionRiskSnapshot g_position_risk;
ulong g_position_risk_last_ms=0;
int g_position_risk_page=0,g_position_risk_x=-1,g_position_risk_y=-1;
bool g_position_risk_hidden=false;
#ifdef ICT_SMART_ENGINE
SICTTimeframes g_timeframes;
SICTUnifiedConfig g_unified_config;
SICTUnifiedSnapshot g_unified_snapshot;
CICTUnifiedAnalysis g_unified_engine;
CICTSignalHistory g_signal_history;
datetime g_smt_selection_bar=0;
datetime g_smt_last_attempt=0;

void ICTUpdateSMTComparisons()
  {
   datetime closed_bar=iTime(_Symbol,g_config.smt_tf,1);
   datetime now=TimeCurrent();
   if(closed_bar<=0) return;
   bool auto1=Auto_Suggest_SMT_Symbols && SMT_1_Auto && Comparison_Symbol_1=="";
   bool auto2=Auto_Suggest_SMT_Symbols && SMT_2_Auto && Comparison_Symbol_2=="";
   if(closed_bar==g_smt_selection_bar &&
      (!auto1 || g_config.comparison1!="") && (!auto2 || g_config.comparison2!="")) return;
   if(closed_bar==g_smt_selection_bar && now>=g_smt_last_attempt && now-g_smt_last_attempt<60) return;
   g_smt_selection_bar=closed_bar;
   g_smt_last_attempt=now;
   string first="",second="";
   double first_strength=-1.0,second_strength=-1.0;
   if(auto1 || auto2)
     {
      for(int i=0;i<SymbolsTotal(true);i++)
        {
         string candidate=SymbolName(i,true);
         if(candidate=="" || candidate==_Symbol || candidate==Comparison_Symbol_1 ||
            candidate==Comparison_Symbol_2 || StringLen(candidate)>24) continue;
         SSymbolCorrelation correlation;
         if(SRMPCalculateCorrelation(_Symbol,candidate,g_config.smt_tf,100,60,0.60,closed_bar,correlation) &&
            (correlation.state==SMT_CORR_POSITIVE || correlation.state==SMT_CORR_NEGATIVE))
            SRMPRankComparison(candidate,correlation.coefficient,first,first_strength,second,second_strength);
        }
     }
   string one,two;
   SRMPResolveSMTSlots(Comparison_Symbol_1,Comparison_Symbol_2,auto1,auto2,first,second,one,two);
   if(one!=g_config.comparison1 || two!=g_config.comparison2)
      PrintFormat("ICT SMT comparisons %s: 1=%s 2=%s (manual values take precedence)",_Symbol,one,two);
   g_config.comparison1=one;
   g_config.comparison2=two;
  }

void ICTDrawSMTLegend(const SICTSnapshot &context)
  {
   string prefix=g_prefix+"smtlegend_";
   if(!Show_SMT || !Show_SMT_Comparison_Legend)
     { ObjectsDeleteAll(0,prefix); return; }
   int chart_width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   if(chart_width<200) { ObjectsDeleteAll(0,prefix); return; }
   int width=(int)MathMin(340,chart_width-16);
   RMPanel(prefix+"bg",8,8,width,64);
   string a=(g_config.comparison1=="" ? "NO SYMBOL" : SRMPSMTStateText(context.smt1.state));
   string b=(g_config.comparison2=="" ? "NO SYMBOL" : SRMPSMTStateText(context.smt2.state));
   RMText(prefix+"head",_Symbol+" | SMT "+ICTSmartTimeframe(g_config.smt_tf),16,12,clrWhite,9);
   RMText(prefix+"one","SMT1: "+(g_config.comparison1=="" ? "--" : g_config.comparison1)+" | "+a,16,29,clrLightSkyBlue,9);
   RMText(prefix+"two","SMT2: "+(g_config.comparison2=="" ? "--" : g_config.comparison2)+" | "+b,16,46,clrLightSkyBlue,9);
  }

void ICTDrawBPR()
  {
   string prefix=g_prefix+"bpr_";
   if(!EnableBPRDetection || !ShowBPRZones)
     { ObjectsDeleteAll(0,prefix); return; }
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   int count=CopyRates(_Symbol,g_config.setup_tf,1,Structure_Lookback,rates);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   SICTBalancedPriceRange zone;
   if(count!=Structure_Lookback || tick<=0 || BPR_Minimum_Overlap_Ticks<=0 ||
      !ICTFindBPRFromRates(_Symbol,g_config.setup_tf,rates,count,tick,BPR_Minimum_Overlap_Ticks*tick,zone) ||
      zone.state!=ICT_BPR_CONFIRMED || zone.confirmed_at>TimeCurrent())
     { ObjectsDeleteAll(0,prefix); return; }
   datetime edge=TimeCurrent()+PeriodSeconds(g_config.setup_tf)*10;
   color ink=zone.direction>0 ? C'145,206,185' : C'222,169,187';
   RMContextZone(prefix+"zone",zone.confirmed_at,edge,zone.lower,zone.upper,ink);
   RMContextMarker(prefix+"label",zone.confirmed_at,zone.upper,
                   (zone.direction>0 ? "Bullish" : "Bearish")+" BPR | "+ICTSmartTimeframe(g_config.setup_tf),
                   zone.direction>0 ? clrDarkGreen : clrMaroon);
   ObjectSetString(0,prefix+"zone",OBJPROP_TOOLTIP,zone.id+" | overlap of opposite closed FVGs; context only");
  }
#endif

void ICTDrawPositionRisk()
  {
   if(!Show_Position_Risk) { ObjectsDeleteAll(0,g_prefix+"position_risk_"); return; }
   ICTRenderPositionRiskPanel(g_prefix+"position_risk_",g_position_risk,
      Position_Risk_Corner,Position_Risk_X,Position_Risk_Y,Position_Risk_Width,Position_Risk_Height,
      Dashboard_Font_Size,g_position_risk_page,g_position_risk_x,g_position_risk_y,g_position_risk_hidden);
  }

void ICTRefreshPositionRisk(const bool force=false)
  {
   if(!Show_Position_Risk) return;
   ulong now=GetTickCount64();
   if(!force && g_position_risk_last_ms>0 && now-g_position_risk_last_ms<1000) return;
   g_position_risk_last_ms=now;
   int previous=g_position_risk.totals.count;
   ICTReadPositionRiskSnapshot(Position_Risk_All_Symbols ? "" : _Symbol,Position_Risk_Capital,
      Commission_Round_Turn_Per_Lot+Unspecified_Cost_Buffer_Per_Lot,g_position_risk);
   if(g_position_risk.totals.count!=previous) g_position_risk_page=0;
   ICTDrawPositionRisk();
   ICTChartLayoutApply(g_prefix+"ui_",g_prefix+"position_risk_");
   ChartRedraw();
  }

void ICTDrawCurrentPanel()
  {
   if(!Show_Dashboard) return;
#ifdef ICT_SMART_ENGINE
   string decision=ICTDashboardSignalState(g_unified_snapshot.signal.state);
   string plan=(g_decision.entry>0 && g_decision.stop>0 && g_decision.target>0 ?
      "Giá vào đề xuất "+ICTPriceLabel(g_decision.entry)+" | SL "+ICTPriceLabel(g_decision.stop)+" | TP1 "+ICTPriceLabel(g_decision.target)+
      " | TP2 "+(g_decision.target2>0 ? ICTPriceLabel(g_decision.target2) : "--")+" | RR ròng "+DoubleToString(g_decision.risk.rr,2)+
      (g_decision.entry_confirmed ? " | RỦI RO ĐẠT" : " | CHƯA ĐƯỢC DUYỆT") : "Chưa có giá vào / SL / TP do kế hoạch chưa đầy đủ");
   ICTRenderUnifiedDashboard(g_prefix+"ui_",g_unified_snapshot,decision,plan,g_decision.reason,
      Dashboard_Corner,Dashboard_X,Dashboard_Y,Dashboard_Width,Dashboard_Height,Dashboard_Font_Size,
      g_ict_dashboard_page,g_ict_dashboard_x,g_ict_dashboard_y,g_ict_dashboard_hidden);
#else
   if(Enable_IRL_ERL)
      ICTRenderRangeDashboard(g_prefix+"ui_",g_range_snapshot,Dashboard_Corner,
         Dashboard_X,Dashboard_Y,Dashboard_Width,Dashboard_Height,Dashboard_Font_Size,
         Dashboard_Market_Group,Dashboard_ICT_Group,Dashboard_Plan_Group);
   else ICTRenderDashboard(g_prefix+"ui_",g_decision,g_session,Dashboard_Corner,
         Dashboard_X,Dashboard_Y,Dashboard_Width,Dashboard_Font_Size,
         Dashboard_Height,Dashboard_Market_Group,Dashboard_ICT_Group,Dashboard_Plan_Group);
#endif
  }

#ifdef ICT_SMART_ENGINE
void ICTRefreshUnified()
  {
   g_unified_engine.Update(_Symbol,g_unified_config); g_unified_engine.Snapshot(g_unified_snapshot);
   g_config.comparison1=g_unified_snapshot.comparison1; g_config.comparison2=g_unified_snapshot.comparison2;
   ICTAnalyzeUnifiedDecision(_Symbol,g_unified_snapshot,g_unified_config,g_config,g_scoring,Enable_IRL_ERL,
                            g_range_config,g_range_engine,g_decision,g_range_snapshot,g_unified_snapshot.signal);
   datetime oldest=iTime(_Symbol,g_timeframes.ltf,SignalHistoryClosedBars);
   if(oldest>0) g_signal_history.Prune(oldest,g_unified_snapshot.asof);
   if(g_unified_snapshot.valid && !g_signal_history.Observe(g_unified_snapshot.signal))
     {
      g_unified_snapshot.signal.confirmed=false; g_unified_snapshot.signal.state=ICT_SIGNAL_NO_TRADE;
      g_unified_snapshot.signal.risk_pass=false; g_unified_snapshot.signal.confirmation_time=0;
      g_unified_snapshot.signal.reason="NO_TRADE: confirmed signal journal unavailable";
      ICTUnifiedBlock(g_decision,ICT_NO_TRADE,g_unified_snapshot.signal.reason);
     }
   ICTApplyCommittedSignal(g_unified_snapshot.signal,g_decision);
   if(g_range_snapshot.schema==ICT_RANGE_SCHEMA)
     {
      g_range_snapshot.proposed_action=(int)g_decision.priority; g_range_snapshot.score=g_decision.score;
      g_range_snapshot.reason=g_decision.reason;
      if(!g_decision.entry_confirmed) g_range_snapshot.technical_ready=false;
     }
   ENUM_TIMEFRAMES display_tf=(Chart_Zone_Timeframe==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : Chart_Zone_Timeframe);
   ICTChartLayoutBegin(g_prefix,display_tf,ICTChartScaledFontSize(Chart_Label_Font_Size));
   if((oldest>0 && g_unified_snapshot.asof>0) || !ShowConfirmedSignals)
      g_signal_history.Render(g_prefix+"signals_",oldest,g_unified_snapshot.asof,ShowConfirmedSignals);
   if(!ICTPublishUnified(_Symbol,g_unified_snapshot)) Print("Unified analysis publication failed; consumers must reject stale snapshots");
   if(Enable_IRL_ERL && g_range_snapshot.schema==ICT_RANGE_SCHEMA)
     { if(!ICTPublishRange(_Symbol,g_range_snapshot)) Print("IRL/ERL publication failed"); }
   else GlobalVariableSet(SRMPAdviceKey(_Symbol,"IRTS"),0);
   SmartSLTPObserveDecision(g_decision); ICTPublishDecision(_Symbol,g_decision);
   bool ready=Show_Chart_Levels && g_decision.entry_confirmed && g_decision.risk.valid;
   datetime entry_edge=ICTVisualEdge(g_timeframes.ltf,g_unified_snapshot.asof,OB_ExtendBars);
   ENUM_TIMEFRAMES entry_tf=(Enable_IRL_ERL ? g_range_config.mtf : g_config.setup_tf);
   if(ready && ICTChartReserveZone(entry_tf,g_decision.zone_time,entry_edge,g_decision.zone_low,g_decision.zone_high))
     {
      RMContextZone(g_prefix+"ENTRY_ZONE",g_decision.zone_time,entry_edge,
                    g_decision.zone_low,g_decision.zone_high,C'180,205,230');
      ObjectSetString(0,g_prefix+"ENTRY_ZONE",OBJPROP_TOOLTIP,"Confirmed advisory entry zone | "+EnumToString(entry_tf));
     }
   else ObjectDelete(0,g_prefix+"ENTRY_ZONE");
   bool range_backdrop=Enable_IRL_ERL && Show_Liquidity && Range_Show_Range &&
                       g_range_snapshot.valid && g_range_snapshot.range.valid &&
                       g_range_snapshot.range.timeframe==display_tf;
   ICTRenderUnifiedOverlays(g_prefix+"unified_draw_",g_unified_snapshot,Show_SMT,Show_Order_Blocks,
      Show_FVG,EnableBPRDetection && ShowBPRZones,Show_Premium_Discount && !range_backdrop,
      Show_Structure,Show_Liquidity && !range_backdrop);
   if(Enable_IRL_ERL)
     {
      ICTRenderRange(g_prefix+"range_",g_range_snapshot,Show_Liquidity && Range_Show_Range,Show_Liquidity && Range_Show_IRL,Show_Liquidity && Range_Show_ERL,
                     false,Range_Show_Rotation,true); // Final targets belong exclusively to committed SignalResult.
      ICTRenderSweepSequence(g_prefix+"sweepseq_",g_range_snapshot,Sweep_Maximum_Events_To_Draw,
         Show_Liquidity && ShowSweep1,Show_Liquidity && ShowSweep2,Show_Liquidity && ShowSweep3Plus,EnableMultiSweepAnalysis,EnableSweepConnectionLine);
     }
   g_signal_history.RenderPlan(g_prefix+"signal_plan_",g_unified_snapshot.signal,ready);
   RMContextLine(g_prefix+"ENTRY",ready ? g_decision.entry : 0,clrDodgerBlue,"Advisory Entry; not an order");
   RMContextLine(g_prefix+"STOP",ready ? g_decision.stop : 0,clrTomato,"Advisory SL invalidation");
   RMContextLine(g_prefix+"TARGET",ready ? g_decision.target : 0,clrLimeGreen,"Advisory liquidity TP1");
   RMContextLine(g_prefix+"TARGET2",ready ? g_decision.target2 : 0,clrGreen,"Advisory liquidity TP2");
   ICTDrawCurrentPanel();
   ICTChartLayoutEnd(g_prefix+"ui_",g_prefix+"position_risk_");
   g_alerts.UpdateSignal(g_unified_snapshot.signal,Enable_Popup_Alerts,Enable_Push_Alerts,Enable_Sound_Alerts,
      Enable_Signal_Log,Alert_Sound_File,Alert_Cooldown_Seconds,Alert_On_Startup);
   ChartRedraw();
  }
#endif

void ICTRefresh()
  {
#ifdef ICT_SMART_ENGINE
   ICTRefreshUnified();
#else
   ENUM_TIMEFRAMES display_tf=(Chart_Zone_Timeframe==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : Chart_Zone_Timeframe);
   ICTChartLayoutBegin(g_prefix,display_tf,ICTChartScaledFontSize(Chart_Label_Font_Size));
#ifdef ICT_SMART_ENGINE
   // The existing range replay uses fixed seconds for candle closes. Monthly
   // candles have variable length, so do not admit an MN1 HTF until the replay
   // uses verified calendar/session boundaries rather than PeriodSeconds(MN1).
   if(g_timeframes.status!=ICT_MTF_FULL || g_timeframes.htf==PERIOD_MN1)
     {
      ZeroMemory(g_decision); ZeroMemory(g_range_snapshot);
      g_decision.symbol=_Symbol; g_decision.timeframe=g_timeframes.ltf;
      g_decision.state=ICT_NO_TRADE; g_decision.data_quality_ok=false;
      g_decision.reason=(g_timeframes.htf==PERIOD_MN1 ?
         "INSUFFICIENT_DATA: MN1 calendar-close replay is not yet supported" :
         "INSUFFICIENT_DATA: three-tier decision unavailable on this chart timeframe");
      g_decision.data_quality=g_decision.reason;
      GlobalVariableSet(SRMPAdviceKey(_Symbol,"IRTS"),0);
      SmartSLTPObserveDecision(g_decision);
      ICTPublishDecision(_Symbol,g_decision);
      ICTDrawCurrentPanel(); ChartRedraw(); return;
     }
   ICTUpdateSMTComparisons();
#endif
   if(Enable_IRL_ERL)
     {
      ICTAnalyzeRangeDecision(_Symbol,g_config,g_scoring,g_range_config,g_range_engine,g_decision,g_range_snapshot);
      if(g_last_range_reason!=(int)g_range_snapshot.reason_code || g_last_range_valid!=g_range_snapshot.valid)
        {
         PrintFormat("ICT range %s %s/%s/%s valid=%d: %s",_Symbol,
            EnumToString(g_range_config.htf),EnumToString(g_range_config.mtf),EnumToString(g_range_config.ltf),
            (int)g_range_snapshot.valid,g_range_snapshot.reason);
         g_last_range_reason=(int)g_range_snapshot.reason_code; g_last_range_valid=g_range_snapshot.valid;
        }
      if(!ICTPublishRange(_Symbol,g_range_snapshot)) Print("IRL/ERL publication failed; indicator must withhold stale data");
#ifdef ICT_SMART_ENGINE
      ICTRenderRange(g_prefix+"range_",g_range_snapshot,Range_Show_Range,Range_Show_IRL,
                      Range_Show_ERL,Range_Show_Targets,Range_Show_Rotation,true);
      ICTRenderSweepSequence(g_prefix+"sweepseq_",g_range_snapshot,Sweep_Maximum_Events_To_Draw,
                             ShowSweep1,ShowSweep2,ShowSweep3Plus,EnableMultiSweepAnalysis,EnableSweepConnectionLine);
#else
      ICTRenderRange(g_prefix+"range_",g_range_snapshot,Range_Show_Range,Range_Show_IRL,
                      Range_Show_ERL,Range_Show_Targets,Range_Show_Rotation);
#endif
     }
   else ICTAnalyzeDecision(_Symbol,g_config,g_scoring,g_decision);
#ifdef ICT_SMART_ENGINE
   SmartSLTPObserveDecision(g_decision);
   ICTPublishDecision(_Symbol,g_decision);
   g_decision.optional_data_notes=StringFormat("SMT 1=%s, SMT 2=%s; %s",
      g_config.comparison1=="" ? "unavailable" : g_config.comparison1,
      g_config.comparison2=="" ? "unavailable" : g_config.comparison2,
      g_decision.optional_data_notes);
#endif
   bool kill_zone=false;
   g_session=ICTNewYorkSession(ICTSessionUTC(g_scoring.tester_broker_utc_offset_minutes),kill_zone);
   ICTDrawCurrentPanel();
   SMarketContextSnapshot market;
   SRMPAnalyzeMarketContext(_Symbol,g_config.higher_tf,g_config.structure_tf,
                            g_config.setup_tf,g_config.trigger_tf,market);
   SICTSettings settings;
   SRMPDefaultICTSettings(settings);
   settings.enable_ob=Show_Order_Blocks;
   settings.enable_smt=Show_SMT;
   settings.ob_timeframe=g_config.setup_tf;
   settings.ob_lookback=Structure_Lookback;
   settings.expiry_bars=Maximum_Setup_Age_Bars;
   settings.smt_timeframe=g_config.smt_tf;
   settings.smt_lookback=Structure_Lookback;
   settings.pivot_left=Swing_Strength;
   settings.pivot_right=Swing_Strength;
   settings.comparison1=g_config.comparison1;
   settings.comparison2=g_config.comparison2;
   SICTSnapshot context;
   SRMPAnalyzeICT(_Symbol,settings,context);
#ifdef ICT_SMART_ENGINE
   ICTDrawSMTLegend(context);
   ICTDrawBPR();
#endif
#ifdef ICT_SMART_ENGINE
   bool show_context_layers=true; // Independent context; range zones remain separate.
#else
   bool show_context_layers=!Enable_IRL_ERL;
#endif
   datetime entry_edge=TimeCurrent()+PeriodSeconds(g_config.setup_tf)*10;
   if(Show_Chart_Levels && !Enable_IRL_ERL && g_decision.state!=ICT_INVALIDATED &&
      ICTChartReserveZone(g_config.setup_tf,g_decision.zone_time,entry_edge,g_decision.zone_low,g_decision.zone_high))
     {
      RMContextZone(g_prefix+"ENTRY_ZONE",g_decision.zone_time,entry_edge,g_decision.zone_low,g_decision.zone_high,C'180,205,230');
      ObjectSetString(0,g_prefix+"ENTRY_ZONE",OBJPROP_TOOLTIP,"Advisory entry zone | "+EnumToString(g_config.setup_tf));
     }
   else ObjectDelete(0,g_prefix+"ENTRY_ZONE");
   SRMPRenderChartAnalysis(g_prefix+"context_",market,context,g_config.structure_tf,
      g_config.smt_tf,g_config.setup_tf,entry_edge,
      Show_FVG && show_context_layers,Show_Order_Blocks && show_context_layers,Show_SMT,
      Show_Premium_Discount && show_context_layers,Show_Liquidity && show_context_layers,
      Show_Structure,Show_Inactive_Order_Blocks,Show_Inactive_FVG);
   bool ready=Show_Chart_Levels && !Enable_IRL_ERL && g_decision.state==ICT_ENTRY_READY &&
              g_decision.hard_filters_passed && g_decision.risk.valid;
   RMContextLine(g_prefix+"DOL",Show_Chart_Levels && !Enable_IRL_ERL ? g_decision.dol : 0,clrGold,"Decision DOL");
   RMContextLine(g_prefix+"ENTRY",ready ? g_decision.entry : 0,clrDodgerBlue,"Advisory entry");
   RMContextLine(g_prefix+"STOP",ready ? g_decision.stop : 0,clrTomato,"Advisory SL");
   RMContextLine(g_prefix+"TARGET",ready ? g_decision.target : 0,clrLimeGreen,"Advisory TP");
   RMContextLine(g_prefix+"TARGET2",ready ? g_decision.target2 : 0,clrGreen,"Advisory TP2");
   ICTChartLayoutEnd(g_prefix+"ui_",g_prefix+"position_risk_");
   g_alerts.Update(g_decision,Enable_Popup_Alerts,Enable_Push_Alerts,Enable_Sound_Alerts,
                   Enable_Signal_Log,Alert_Sound_File,Alert_Cooldown_Seconds,Alert_On_Startup);
   ChartRedraw();
#endif
  }
int OnInit()
  {
#ifdef ICT_SMART_ENGINE
   int sltp_init=SmartSLTPInit();
   if(sltp_init!=INIT_SUCCEEDED) return sltp_init;
#endif
   ICTConfigureRangeInputs(g_range_config);
#ifdef ICT_SMART_ENGINE
   if(!ICTConfigureUnifiedInputs((ENUM_TIMEFRAMES)_Period,Comparison_Symbol_1,Comparison_Symbol_2,
                                 g_unified_config,Auto_Suggest_SMT_Symbols,SMT_1_Auto,SMT_2_Auto))
     { Print("ICT: Invalid unified timeframe / SMT / Strong OB inputs"); return INIT_PARAMETERS_INCORRECT; }
   g_timeframes=g_unified_config.frames;
   if(g_timeframes.status==ICT_MTF_FULL)
     { g_range_config.ltf=g_timeframes.ltf; g_range_config.mtf=g_timeframes.mtf; g_range_config.htf=g_timeframes.htf; }
   bool validate_range=(g_timeframes.status==ICT_MTF_FULL);
#else
   bool validate_range=true;
#endif
   if(Range_Auto_Trading || (Enable_IRL_ERL && validate_range && !ICTValidRangeConfig(g_range_config)) ||
      Sweep_Maximum_Events_To_Draw<1 || Sweep_Maximum_Events_To_Draw>ICT_SWEEP_SNAPSHOT_MAX) return INIT_PARAMETERS_INCORRECT;
   if(Main_Symbol!="" && Main_Symbol!=_Symbol)
     { Print("ICT: Main_Symbol must equal chart symbol ",_Symbol,". Separate-symbol rendering is unsupported."); return INIT_PARAMETERS_INCORRECT; }
#ifdef ICT_SMART_ENGINE
   if(!MathIsValidNumber(BPR_Minimum_Overlap_Ticks) || BPR_Minimum_Overlap_Ticks<=0) return INIT_PARAMETERS_INCORRECT;
#endif
   ICTDefaultConfluenceConfig(g_scoring);
   g_scoring.strong_score=Strong_Priority_Score;
   g_scoring.entry_zone_mode=Entry_Zone_Mode;
   g_scoring.tester_broker_utc_offset_minutes=Tester_Broker_UTC_Offset_Minutes;
   g_prefix="SRMP_ICTD_"+IntegerToString(ChartID())+"_";
   g_scoring.htf=Weight_HTF; g_scoring.sweep=Weight_Sweep; g_scoring.mss=Weight_MSS;
   g_scoring.displacement=Weight_Displacement; g_scoring.fvg=Weight_FVG;
   g_scoring.ob=Weight_OB; g_scoring.premium_discount=Weight_Premium_Discount;
   g_scoring.smt=Weight_SMT; g_scoring.session=Weight_Session;
   g_scoring.minimum_score=Minimum_Priority_Score; g_scoring.minimum_lead=Minimum_Score_Lead;
   g_scoring.mandatory_smt=Mandatory_SMT; g_scoring.mandatory_session=Mandatory_Session;
#ifdef ICT_SMART_ENGINE
   g_scoring.mandatory_smt=Mandatory_SMT || SMTRequiredForConfirmation;
#endif
   if(!ICTValidConfluenceConfig(g_scoring))
     {
      PrintFormat("ICT: Invalid scoring inputs. Weights HTF/Sweep/MSS/Displacement/FVG/OB/PD/SMT/Session=%d/%d/%d/%d/%d/%d/%d/%d/%d (nonnegative, total 100 required); Minimum/Strong=%d/%d (1<=Minimum<=Strong<=100); Lead=%d (0..100); Zone=%d (0..2); Tester UTC offset=%d (9999 or -840..840).",
         Weight_HTF,Weight_Sweep,Weight_MSS,Weight_Displacement,Weight_FVG,Weight_OB,
         Weight_Premium_Discount,Weight_SMT,Weight_Session,Minimum_Priority_Score,
         Strong_Priority_Score,Minimum_Score_Lead,(int)Entry_Zone_Mode,Tester_Broker_UTC_Offset_Minutes);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(Dashboard_X<0 || Dashboard_Y<0 || Dashboard_Width<300 || Dashboard_Height<120 ||
      Dashboard_Font_Size<7 || Dashboard_Font_Size>18 || Chart_Label_Font_Size<8 || Chart_Label_Font_Size>16)
     {
      PrintFormat("ICT: Invalid dashboard inputs X=%d Y=%d Width=%d Height=%d Font=%d Chart font=%d; require X/Y>=0, Width>=300, Height>=120, Font=7..18, Chart font=8..16.",
         Dashboard_X,Dashboard_Y,Dashboard_Width,Dashboard_Height,Dashboard_Font_Size,Chart_Label_Font_Size);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(Show_Position_Risk && (Position_Risk_X<0 || Position_Risk_Y<0 ||
      Position_Risk_Width<300 || Position_Risk_Height<180 ||
      (Position_Risk_Capital!=ICT_POSITION_BALANCE && Position_Risk_Capital!=ICT_POSITION_EQUITY) ||
      !MathIsValidNumber(Commission_Round_Turn_Per_Lot) || Commission_Round_Turn_Per_Lot<0.0 ||
      !MathIsValidNumber(Unspecified_Cost_Buffer_Per_Lot) || Unspecified_Cost_Buffer_Per_Lot<0.0 ||
      !MathIsValidNumber(Commission_Round_Turn_Per_Lot+Unspecified_Cost_Buffer_Per_Lot)))
     { Print("ICT: Invalid live position risk panel/capital/cost inputs"); return INIT_PARAMETERS_INCORRECT; }
   if(Alert_Cooldown_Seconds<60)
     { PrintFormat("ICT: Alert_Cooldown_Seconds=%d; minimum is 60.",Alert_Cooldown_Seconds); return INIT_PARAMETERS_INCORRECT; }
#ifdef ICT_SMART_ENGINE
   if(g_scoring.mandatory_smt && g_unified_config.smt.slot1==SMT_SLOT_DISABLED && g_unified_config.smt.slot2==SMT_SLOT_DISABLED)
#else
   if(Mandatory_SMT && Comparison_Symbol_1=="" && Comparison_Symbol_2=="")
#endif
     { Print("ICT: Mandatory_SMT=true requires Comparison_Symbol_1 or Comparison_Symbol_2."); return INIT_PARAMETERS_INCORRECT; }
   g_config.higher_tf=Higher_Timeframe;
   g_config.structure_tf=Structure_Timeframe;
   g_config.setup_tf=Setup_Timeframe;
   g_config.trigger_tf=Trigger_Timeframe;
   g_config.smt_tf=SMT_Timeframe;
#ifdef ICT_SMART_ENGINE
   g_config.trigger_tf=g_timeframes.ltf;
   g_config.setup_tf=(g_timeframes.mtf!=PERIOD_CURRENT ? g_timeframes.mtf : g_timeframes.ltf);
   g_config.structure_tf=g_config.setup_tf;
   g_config.higher_tf=(g_timeframes.htf!=PERIOD_CURRENT ? g_timeframes.htf : g_config.setup_tf);
   g_config.smt_tf=(SMT_Timeframe_Mode==SMT_MANUAL ? SMT_ManualTimeframe : g_config.setup_tf);
#endif
   g_config.comparison1=Comparison_Symbol_1;
   g_config.comparison2=Comparison_Symbol_2;
   g_config.lookback=Structure_Lookback;
   g_config.swing_strength=Swing_Strength;
   g_config.max_setup_bars=Maximum_Setup_Age_Bars;
   g_config.displacement_body_atr=Displacement_Body_ATR;
   g_config.displacement_body_fraction=Displacement_Body_Fraction;
   g_config.min_gap_atr=Minimum_FVG_ATR;
   g_config.max_spread_points=Maximum_Spread_Points;
   g_config.risk_percent=Risk_Per_Trade;
   g_config.max_risk_percent=Maximum_Risk_Per_Trade;
   g_config.min_rr=Minimum_RR;
   g_config.commission_per_lot=Commission_Round_Turn_Per_Lot;
   g_config.cost_buffer_per_lot=Unspecified_Cost_Buffer_Per_Lot;
   g_config.slippage_points=Estimated_Slippage_Points;
   g_config.daily_loss_limit_percent=Daily_Loss_Limit_Percent;
   g_config.max_quote_age_seconds=Maximum_Quote_Age_Seconds;
   if(Structure_Lookback<40 || Swing_Strength<1 || Maximum_Setup_Age_Bars<1 ||
      Minimum_RR<2.0 || Maximum_Spread_Points<=0.0 ||
      Risk_Per_Trade<=0.0 || Risk_Per_Trade>Maximum_Risk_Per_Trade ||
      Maximum_Risk_Per_Trade>2.0 || Daily_Loss_Limit_Percent<0.0)
      return INIT_PARAMETERS_INCORRECT;
#ifdef ICT_SMART_ENGINE
   if(!g_signal_history.Init(_Symbol,g_timeframes,SignalHistoryClosedBars))
      Print("ICT: signal history unavailable; new confirmations withheld until journal is readable");
#endif
   if(!EventSetTimer(5)) return INIT_FAILED;
   // Remove annotation backgrounds left by versions that framed chart labels.
   ObjectsDeleteAll(0,g_prefix+"label_bg_");
   ICTRefreshPositionRisk(true);
   ICTRefresh();
   return INIT_SUCCEEDED;
  }

void OnTimer()
  {
   ICTRefreshPositionRisk();
   ICTRefresh();
#ifdef ICT_SMART_ENGINE
   SmartSLTPProcess(g_decision,Maximum_Risk_Per_Trade,Minimum_RR,
                    Commission_Round_Turn_Per_Lot+Unspecified_Cost_Buffer_Per_Lot,
                    Estimated_Slippage_Points);
#endif
  }
void OnTick() { ICTRefreshPositionRisk(); }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
#ifdef ICT_SMART_ENGINE
   SmartSLTPOnTrade(trans);
#endif
   // Account events include manual entries, partial closes and SL/TP changes.
   // This telemetry refresh never sends, modifies or closes an order.
   ICTRefreshPositionRisk(true);
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
#ifdef ICT_SMART_ENGINE
   bool changed=ICTPanelEvent(g_prefix+"ui_",id,sparam,g_ict_dashboard_page,g_ict_dashboard_x,g_ict_dashboard_y,g_ict_dashboard_hidden);
#else
   bool changed=(Enable_IRL_ERL ?
      ICTPanelEvent(g_prefix+"ui_",id,sparam,g_range_panel_page,g_range_panel_x,g_range_panel_y,g_range_panel_hidden) :
      ICTPanelEvent(g_prefix+"ui_",id,sparam,g_ict_dashboard_page,g_ict_dashboard_x,g_ict_dashboard_y,g_ict_dashboard_hidden));
#endif
   bool risk_changed=ICTPanelEvent(g_prefix+"position_risk_",id,sparam,
      g_position_risk_page,g_position_risk_x,g_position_risk_y,g_position_risk_hidden,1);
   if(id==CHARTEVENT_CHART_CHANGE || risk_changed) ICTDrawPositionRisk();
   if(id==CHARTEVENT_CHART_CHANGE || changed || risk_changed)
     { ICTDrawCurrentPanel(); ICTChartLayoutApply(g_prefix+"ui_",g_prefix+"position_risk_"); ChartRedraw(); }
  }
void OnDeinit(const int reason)
  {
   EventKillTimer();
#ifdef ICT_SMART_ENGINE
   SmartSLTPDeinit();
#endif
   if(Enable_IRL_ERL && Range_Export_History)
      g_range_engine.ExportHistory(g_prefix+IntegerToString((long)TimeLocal())+"_ranges.csv");
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"IRTS"),0);
#ifdef ICT_SMART_ENGINE
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"DTS"),0);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"UTS"),0);
#endif
   ObjectsDeleteAll(0,g_prefix);
   ChartRedraw();
  }
