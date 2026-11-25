#property copyright "MT5 Smart Risk Manager Pro"
#property version   "1.01"
#property description "Phase 1 risk preview. Does not place or modify trades."
#property indicator_chart_window
#property indicator_plots 0

#include "../Include/RiskTypes.mqh"
#include "../Include/DashboardComponents.mqh"
#include "../Include/RiskBridge.mqh"
#include "../Include/ProtectionPersistence.mqh"
#include "../Include/AdviceBridge.mqh"
#include "../Include/OrderBlockRenderer.mqh"
#include "../Include/SMTChartRenderer.mqh"
#include "../Include/ICTConfluenceEngine.mqh"
#include "../Include/ChartAnalysisRenderer.mqh"
#include "../Include/ICTRangeBridge.mqh"
#include "../Include/ICTRangeRenderer.mqh"
#include "../Include/ICTUnifiedInputs.mqh"
#include "../Include/ICTUnifiedRenderer.mqh"
#include "../Include/ICTUnifiedBridge.mqh"

input string Instance_ID="A";                    // Unique per chart when using multiple copies
input double Risk_Per_Trade=0.25;               // Percent of reference capital
input double Max_Risk_Per_Trade=3.0;            // User ceiling; target may be lower
input double Minimum_RR=2.0;
input double Preferred_Risk_Reward=3.0;        // Default target when resetting a plan
input int Default_Stop_Points=200;
input double Commission_Round_Turn_Per_Lot=0.0; // Account currency; broker dependent
input double Unspecified_Cost_Buffer_Per_Lot=10.0; // Account currency; conservative default
input double Estimated_Slippage_Points=2.0;
input int Max_Quote_Age_Seconds=60;
input bool Use_Equity_As_Reference=false;       // Default: current balance
input int Dashboard_Right_Margin=12;
input int Dashboard_Top_Margin=12;
input bool Show_Advisory_Panel=false;
input bool Show_Market_Overlays=false;
input int Advisory_Left_Margin=12;
input bool Show_ICT_Group=true;
input bool Show_OB_Overlay=true;
input bool Show_SMT_Overlay=true;
input bool Show_Inactive_OB=false;
input bool Show_Service_ICT_Overlays=false;
input bool Compact_Dashboard=true;
input bool Show_FVG_Overlay=true;
input bool Show_Premium_Discount=true;
input bool Show_Liquidity_Overlay=true;
input bool Show_Structure_Overlay=true;
input ENUM_TIMEFRAMES Analysis_Higher_Timeframe=PERIOD_H4;
input ENUM_TIMEFRAMES Analysis_Structure_Timeframe=PERIOD_H1;
input ENUM_TIMEFRAMES Analysis_Setup_Timeframe=PERIOD_M15;
input ENUM_TIMEFRAMES Analysis_Trigger_Timeframe=PERIOD_M5;
input ENUM_TIMEFRAMES Analysis_OB_Timeframe=PERIOD_M15;
input ENUM_TIMEFRAMES Analysis_SMT_Timeframe=PERIOD_H1;
input string Comparison_Symbol_1="";
input string Comparison_Symbol_2="";
input group "Shared IRL/ERL service snapshot"
input bool Show_IRL_ERL=true;
input bool Show_Range_Layer=true;
input bool Show_IRL_Layer=true;
input bool Show_ERL_Layer=true;
input bool Show_Range_Targets=true;
input bool Show_Range_Rotation=true;
input bool Show_Range_Dashboard=true;
input int Range_Panel_X=12;
input int Range_Panel_Y=80;
input int Range_Panel_Width=520;
input int Range_Panel_Height=420;
input int Range_Panel_Font_Size=11;

string g_prefix;
SICTRangeSnapshot g_range_view;
SICTUnifiedConfig g_unified_config;
SICTUnifiedSnapshot g_unified_snapshot;
CICTUnifiedAnalysis g_unified_engine;
bool g_unified_from_ea=false;
datetime g_analysis_bar=0;
datetime g_analysis_refresh=0;
SICTSnapshot g_chart_ict;
bool g_chart_ict_ready=false;
bool g_dashboard_visible=true;
string g_bridge;
ENUM_RM_DIRECTION g_direction=RM_BUY;
bool g_initialized=false;
bool g_has_request=false;
bool g_show_ict_view=false;
double g_request_sequence=0.0;
double g_last_entry=0.0,g_last_sl=0.0,g_last_tp=0.0,g_last_capital=0.0;
ENUM_RM_DIRECTION g_last_direction=RM_BUY;
color g_white=C'230,236,242';
color g_muted=C'166,179,193';
color g_green=C'105,218,154';
color g_yellow=C'250,201,91';
color g_red=C'247,105,110';

string Key(const string suffix) { return g_prefix+suffix; }

double Price(const string suffix)
  { return ObjectGetDouble(0,Key(suffix),OBJPROP_PRICE); }

double TickPrice(const double price)
  {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0) return NormalizeDouble(price,_Digits);
   return NormalizeDouble(MathRound(price/tick)*tick,_Digits);
  }

void Row(const int index,const string value,const color ink)
  {
   int height=(int)MathMin(Compact_Dashboard ? 190.0 : 230.0,
                            (double)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS)-
                            Dashboard_Top_Margin-4.0);
   int column=0,line=0,spacing=0;
   if(Compact_Dashboard)
     {
      int shown[]={0,2,3,9,10,11,12,15,19,
                   23,25,26,27,28,29,30,31,32};
      int position=-1;
      for(int i=0;i<ArraySize(shown);i++)
         if(shown[i]==index) { position=i; break; }
      if(position<0)
        { ObjectDelete(0,Key("row_"+IntegerToString(index))); return; }
      column=(position<9 ? 0 : 1);
      line=(column==0 ? position : position-9);
      spacing=(int)MathMax(12.0,(double)(height-56)/8.0);
     }
   else
     {
      column=(index<17 ? 0 : 1);
      line=(column==0 ? index : index-17);
      spacing=(int)MathMax(10.0,(double)(height-48)/17.0);
     }
   RMText(Key("row_"+IntegerToString(index)),value,
          Dashboard_Right_Margin+(column==0 ? 285 : 44),
          Dashboard_Top_Margin+10+line*spacing,ink,index==0 ? 9 : 8);
  }

void ClearDashboardUI()
  {
   ObjectDelete(0,Key("panel"));
   ObjectDelete(0,Key("advice_panel"));
   for(int i=0;i<=32;i++) ObjectDelete(0,Key("row_"+IntegerToString(i)));
   for(int i=0;i<=19;i++) ObjectDelete(0,Key("advice_"+IntegerToString(i)));
   string buttons[]={"buy","sell","calc","reset","ict_toggle"};
   for(int i=0;i<ArraySize(buttons);i++) ObjectDelete(0,Key(buttons[i]));
  }

void AdviceRow(const int index,const string value,const color ink)
  {
   int height=(int)MathMin(380.0,(double)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS)-
                            Dashboard_Top_Margin-4.0);
   int spacing=(int)MathMax(9.0,(double)(height-28)/20.0);
   RMTextLeft(Key("advice_"+IntegerToString(index)),value,
              Advisory_Left_Margin+10,Dashboard_Top_Margin+16+index*spacing,ink);
  }

void ShowAdvice()
  {
   if(!Show_Advisory_Panel) return;
   AdviceRow(0,"TRADING ADVISORY  |  UNVALIDATED",g_white);
   double timestamp=(GlobalVariableCheck(SRMPAdviceKey(_Symbol,"TS")) ?
                     GlobalVariableGet(SRMPAdviceKey(_Symbol,"TS")) : 0.0);
   if(timestamp<=0.0 || TimeLocal()-(datetime)timestamp>10)
     {
      AdviceRow(1,"STATUS: NO TRADE",g_red);
      AdviceRow(2,"Service offline/stale; use RiskCalculationService",g_yellow);
      for(int i=3;i<=12;i++) AdviceRow(i,"",g_muted);
      return;
     }
   bool protection_ok=GlobalVariableCheck(SRMPGlobalKey("HB")) &&
      GlobalVariableCheck(SRMPGlobalKey("STATE")) &&
      GlobalVariableCheck(SRMPGlobalKey("HEALTH")) &&
      GlobalVariableCheck(SRMPGlobalKey("AUTO")) &&
      TimeLocal()-(datetime)GlobalVariableGet(SRMPGlobalKey("HB"))<=3 &&
      (int)GlobalVariableGet(SRMPGlobalKey("STATE"))==SRMP_NORMAL &&
      GlobalVariableGet(SRMPGlobalKey("AUTO"))>0.5 &&
      (int)GlobalVariableGet(SRMPGlobalKey("HEALTH"))==0;
   int status=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"STATUS"));
   if(!protection_ok) status=SRMP_NO_TRADE;
   string status_text=(status==SRMP_TRADE_READY ? "TRADE READY" :
                       (status==SRMP_WAIT ? "WAIT" : "NO TRADE"));
   AdviceRow(1,"STATUS: "+status_text+"  (advisory only)",
             status==SRMP_TRADE_READY ? g_green : g_yellow);
   AdviceRow(2,protection_ok ? SRMPAdviceReasonText((int)GlobalVariableGet(
             SRMPAdviceKey(_Symbol,"REASON"))) : "Protection offline or locked",g_muted);
   if(status!=SRMP_TRADE_READY)
     {
      for(int i=3;i<=11;i++) AdviceRow(i,"",g_muted);
      AdviceRow(12,"Closed bars only | no automatic order",g_muted);
      return;
     }
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   int direction=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"DIR"));
   AdviceRow(3,"Setup: PDH/PDL sweep + FVG + BOS",g_white);
   AdviceRow(4,"H4/H1 aligned: "+(direction>0 ? "BUY" : "SELL")+
             " | closed M5 "+TimeToString((datetime)GlobalVariableGet(
             SRMPAdviceKey(_Symbol,"BAR")),TIME_DATE|TIME_MINUTES),g_white);
   AdviceRow(5,"Entry zone: "+DoubleToString(GlobalVariableGet(
             SRMPAdviceKey(_Symbol,"ZL")),digits)+" - "+DoubleToString(
             GlobalVariableGet(SRMPAdviceKey(_Symbol,"ZU")),digits),g_white);
   double entry=GlobalVariableGet(SRMPAdviceKey(_Symbol,"E"));
   double stop=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SL"));
   double target=GlobalVariableGet(SRMPAdviceKey(_Symbol,"TP"));
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   AdviceRow(6,"Entry: "+DoubleToString(GlobalVariableGet(
             SRMPAdviceKey(_Symbol,"E")),digits),g_white);
   AdviceRow(7,"SL / TP: "+DoubleToString(GlobalVariableGet(
             SRMPAdviceKey(_Symbol,"SL")),digits)+" / "+DoubleToString(
             GlobalVariableGet(SRMPAdviceKey(_Symbol,"TP")),digits),g_white);
   AdviceRow(8,"SL / target: "+DoubleToString(MathAbs(entry-stop)/point,1)+
             " / "+DoubleToString(MathAbs(target-entry)/point,1)+" points",g_white);
   AdviceRow(9,"Lot "+DoubleToString(GlobalVariableGet(
             SRMPAdviceKey(_Symbol,"VOL")),4)+" | Risk "+DoubleToString(
             GlobalVariableGet(SRMPAdviceKey(_Symbol,"RP")),2)+"%",g_white);
   AdviceRow(10,"Risk "+DoubleToString(GlobalVariableGet(
             SRMPAdviceKey(_Symbol,"RM")),2)+" | Reward "+DoubleToString(
             GlobalVariableGet(SRMPAdviceKey(_Symbol,"RW")),2)+" | RR "+
             DoubleToString(GlobalVariableGet(SRMPAdviceKey(_Symbol,"RR")),2),g_white);
   AdviceRow(11,"Invalidation: "+DoubleToString(stop,digits)+" (SL)",g_yellow);
   AdviceRow(12,"Closed bars | experimental | no auto order",g_muted);
  }

void ShowDecision()
  {
   if(!Show_Advisory_Panel) return;
   double stamp=(GlobalVariableCheck(SRMPAdviceKey(_Symbol,"DTS")) ?
                 GlobalVariableGet(SRMPAdviceKey(_Symbol,"DTS")) : 0.0);
   if(stamp<=0.0 || stamp>(double)TimeLocal() || TimeLocal()-(datetime)stamp>10)
     {
      AdviceRow(18,"ICT DECISION: OFFLINE / STALE",g_yellow);
      AdviceRow(19,"Enable ICT decision in RiskCalculationService",g_muted);
      return;
     }
   int state=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"DSTATE"));
   bool protection_ok=GlobalVariableCheck(SRMPGlobalKey("HB")) &&
      GlobalVariableCheck(SRMPGlobalKey("STATE")) &&
      GlobalVariableCheck(SRMPGlobalKey("HEALTH")) &&
      GlobalVariableCheck(SRMPGlobalKey("AUTO")) &&
      GlobalVariableGet(SRMPGlobalKey("HB"))<=(double)TimeLocal() &&
      TimeLocal()-(datetime)GlobalVariableGet(SRMPGlobalKey("HB"))<=3 &&
      (int)GlobalVariableGet(SRMPGlobalKey("STATE"))==SRMP_NORMAL &&
      (int)GlobalVariableGet(SRMPGlobalKey("HEALTH"))==0 &&
      GlobalVariableGet(SRMPGlobalKey("AUTO"))>0.5;
   if(state==4 && !protection_ok) state=7;
   int direction=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"DDIR"));
   string state_text=(state==4 ? (direction>0 ? "BUY PRIORITY" : "SELL PRIORITY") : "NO TRADE");
   int buy_score=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"DBUY"));
   int sell_score=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"DSELL"));
   AdviceRow(18,"ICT DECISION: "+state_text+" | "+
             "BUY "+IntegerToString(buy_score)+" SELL "+IntegerToString(sell_score),
             state==4 ? (direction>0 ? g_green : g_red) : g_muted);
   AdviceRow(19,protection_ok ? SRMPReadAdviceText(_Symbol,"DWHY") :
             "Protection offline, disabled or locked",g_muted);
  }

void ClearMarketObjects()
  {
   string names[]={"ctx_h4hi","ctx_h4lo","ctx_h1hi","ctx_h1lo",
                   "ctx_pdh","ctx_pdl","ctx_eq","ctx_fvg",
                   "ctx_bos","ctx_sweep","ctx_entry","ctx_sl","ctx_tp"};
   for(int i=0;i<ArraySize(names);i++) ObjectDelete(0,Key(names[i]));
  }

void ShowMarketContext()
  {
   if(g_unified_snapshot.schema==ICT_UNIFIED_SCHEMA)
     {
      ClearMarketObjects();
      if(!Show_Advisory_Panel) return;
      for(int i=0;i<3;i++) AdviceRow(13+i,ICTUnifiedTF(g_unified_snapshot.tiers[i].timeframe)+" "+
         ICTUnifiedBias(g_unified_snapshot.tiers[i]),g_muted);
      AdviceRow(16,"MTF "+ICTUnifiedStructureText(g_unified_snapshot.mtf_state),g_white);
      AdviceRow(17,g_unified_snapshot.reason,g_muted); return;
     }
   if(Show_IRL_ERL) { ClearMarketObjects(); return; }
   if(!Show_Advisory_Panel) return;
   double timestamp=(GlobalVariableCheck(SRMPAdviceKey(_Symbol,"CTS")) ?
                     GlobalVariableGet(SRMPAdviceKey(_Symbol,"CTS")) : 0.0);
   if(timestamp<=0.0 || TimeLocal()-(datetime)timestamp>10)
     {
      AdviceRow(13,"Market context unavailable or stale",g_yellow);
      for(int i=14;i<=17;i++) AdviceRow(i,"",g_muted);
      ClearMarketObjects();
      return;
     }
   bool h4=GlobalVariableGet(SRMPAdviceKey(_Symbol,"H4OK"))>0.5;
   bool h1=GlobalVariableGet(SRMPAdviceKey(_Symbol,"H1OK"))>0.5;
   bool gap=GlobalVariableGet(SRMPAdviceKey(_Symbol,"FGOK"))>0.5;
   bool liquidity=GlobalVariableGet(SRMPAdviceKey(_Symbol,"LQOK"))>0.5;
   if(!h4 || !h1)
     {
      AdviceRow(13,"Swing history incomplete (closed bars)",g_yellow);
      for(int i=14;i<=17;i++) AdviceRow(i,"",g_muted);
      ClearMarketObjects();
      return;
     }
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double h4hi=GlobalVariableGet(SRMPAdviceKey(_Symbol,"H4HI"));
   double h4lo=GlobalVariableGet(SRMPAdviceKey(_Symbol,"H4LO"));
   double h1hi=GlobalVariableGet(SRMPAdviceKey(_Symbol,"H1HI"));
   double h1lo=GlobalVariableGet(SRMPAdviceKey(_Symbol,"H1LO"));
   double eq=GlobalVariableGet(SRMPAdviceKey(_Symbol,"EQ"));
   int bos=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"BOS"));
   bool mss=GlobalVariableGet(SRMPAdviceKey(_Symbol,"MSS"))>0.5;
   int h4bias=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"H4BI"));
   int h1bias=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"H1BI"));
   AdviceRow(13,"Swing H4 "+DoubleToString(h4hi,digits)+" / "+
             DoubleToString(h4lo,digits)+" bias "+IntegerToString(h4bias),g_white);
   AdviceRow(14,"Swing H1 "+DoubleToString(h1hi,digits)+" / "+
             DoubleToString(h1lo,digits)+" bias "+IntegerToString(h1bias),g_white);
   AdviceRow(15,"H1 BOS "+IntegerToString(bos)+" | MSS "+(mss ? "YES" : "NO")+
             " | EQ "+DoubleToString(eq,digits),g_white);
   double fglo=GlobalVariableGet(SRMPAdviceKey(_Symbol,"FGL"));
   double fghi=GlobalVariableGet(SRMPAdviceKey(_Symbol,"FGU"));
   bool mitigated=GlobalVariableGet(SRMPAdviceKey(_Symbol,"FGM"))>0.5;
   AdviceRow(16,gap ? "FVG "+DoubleToString(fglo,digits)+"-"+
             DoubleToString(fghi,digits)+(mitigated ? " mitigated" :
             (((fglo+fghi)/2.0<=eq) ? " discount" : " premium")) :
             "FVG unavailable",gap ? g_white : g_yellow);
   bool buy_sweep=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SWB"))>0.5;
   bool sell_sweep=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SWS"))>0.5;
   AdviceRow(17,liquidity ? "PDH "+DoubleToString(GlobalVariableGet(
             SRMPAdviceKey(_Symbol,"PDH")),digits)+" PDL "+DoubleToString(
             GlobalVariableGet(SRMPAdviceKey(_Symbol,"PDL")),digits)+
             (buy_sweep ? " BUY sweep" : (sell_sweep ? " SELL sweep" : "")) :
             "Liquidity unavailable",liquidity ? g_white : g_yellow);
   if(!Show_Market_Overlays)
     { ClearMarketObjects(); return; }
   RMContextLine(Key("ctx_h4hi"),h4hi,C'94,125,191',"Confirmed H4 swing high");
   RMContextLine(Key("ctx_h4lo"),h4lo,C'94,125,191',"Confirmed H4 swing low");
   RMContextLine(Key("ctx_h1hi"),h1hi,C'83,169,201',"Confirmed H1 swing high");
   RMContextLine(Key("ctx_h1lo"),h1lo,C'83,169,201',"Confirmed H1 swing low");
   RMContextLine(Key("ctx_eq"),eq,C'180,145,98',"H1 equilibrium 50 percent");
   RMContextLine(Key("ctx_pdh"),liquidity ? GlobalVariableGet(
                 SRMPAdviceKey(_Symbol,"PDH")) : 0.0,g_yellow,"Previous day high");
   RMContextLine(Key("ctx_pdl"),liquidity ? GlobalVariableGet(
                 SRMPAdviceKey(_Symbol,"PDL")) : 0.0,g_yellow,"Previous day low");
   datetime formed=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"FGT"));
   datetime now_bar=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"CTBAR"));
   RMContextZone(Key("ctx_fvg"),gap ? formed : 0,
                 now_bar+(datetime)PeriodSeconds((ENUM_TIMEFRAMES)(int)
                 GlobalVariableGet(SRMPAdviceKey(_Symbol,"TTF"))),
                 fglo,fghi,mitigated ? C'91,91,91' : C'49,105,83');
   datetime bos_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"BOST"));
   if(bos_time>0)
      RMContextMarker(Key("ctx_bos"),bos_time,
                      GlobalVariableGet(SRMPAdviceKey(_Symbol,"BOSP")),
                      mss ? "H1 MSS" : "H1 BOS",g_yellow);
   datetime sweep_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SWT"));
   if(sweep_time>0)
      RMContextMarker(Key("ctx_sweep"),
                      sweep_time,GlobalVariableGet(SRMPAdviceKey(_Symbol,"SWE")),
                      "PDH/PDL sweep",g_yellow);
   bool ready=GlobalVariableCheck(SRMPAdviceKey(_Symbol,"TS")) &&
      TimeLocal()-(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"TS"))<=10 &&
      (int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"STATUS"))==SRMP_TRADE_READY &&
      GlobalVariableCheck(SRMPGlobalKey("HB")) &&
      GlobalVariableCheck(SRMPGlobalKey("STATE")) &&
      GlobalVariableCheck(SRMPGlobalKey("HEALTH")) &&
      TimeLocal()-(datetime)GlobalVariableGet(SRMPGlobalKey("HB"))<=3 &&
      (int)GlobalVariableGet(SRMPGlobalKey("STATE"))==SRMP_NORMAL &&
      (int)GlobalVariableGet(SRMPGlobalKey("HEALTH"))==0;
   RMContextLine(Key("ctx_entry"),ready ? GlobalVariableGet(
                 SRMPAdviceKey(_Symbol,"E")) : 0.0,C'28,107,185',"Advisory entry, not an order");
   RMContextLine(Key("ctx_sl"),ready ? GlobalVariableGet(
                 SRMPAdviceKey(_Symbol,"SL")) : 0.0,g_red,"Advisory stop, not an order");
   RMContextLine(Key("ctx_tp"),ready ? GlobalVariableGet(
                 SRMPAdviceKey(_Symbol,"TP")) : 0.0,g_green,"Advisory target, not an order");
  }

void ClearICTObjects()
  {
   SRMPClearOBObjects(Key("ict_ob_"));
   SRMPClearSMTObjects(Key("ict_sm1_"));
   SRMPClearSMTObjects(Key("ict_sm2_"));
  }

string ICTRecommendationText(const int value)
  {
   if(value==SRMP_ICT_WAIT_CONFIRMATION) return "WAIT FOR CONFIRMATION";
   if(value==SRMP_ICT_WAIT_RETRACE) return "WAIT FOR RETRACE";
   if(value==SRMP_ICT_BULLISH_SETUP) return "BULLISH SETUP";
   if(value==SRMP_ICT_BEARISH_SETUP) return "BEARISH SETUP";
   if(value==SRMP_ICT_INVALIDATED) return "INVALIDATED";
   return "NO TRADE";
  }

void ShowICT()
  {
   if(!g_show_ict_view)
     { ClearICTObjects(); return; }
   if(g_unified_snapshot.schema==ICT_UNIFIED_SCHEMA)
     {
      ClearICTObjects();
      Row(26,g_unified_from_ea ? "ICT | SHARED EA SNAPSHOT" : "ICT | SHARED ANALYSIS LIBRARY",g_white);
      int nearest=ICTNearestActiveOB(g_unified_snapshot,SymbolInfoDouble(_Symbol,SYMBOL_BID));
      Row(27,nearest>=0 ? ICTUnifiedTF(g_unified_snapshot.zones[nearest].timeframe)+" "+
         ICTOBGradeText(g_unified_snapshot.zones[nearest].grade)+" OB "+
         IntegerToString(g_unified_snapshot.zones[nearest].confirmation_score)+"/100" : "No active validated OB",g_yellow);
      Row(28,"SMT1: "+(g_unified_snapshot.comparison1=="" ? "DISABLED / UNAVAILABLE" : g_unified_snapshot.comparison1),g_muted);
      Row(29,"SMT2: "+(g_unified_snapshot.comparison2=="" ? "DISABLED / UNAVAILABLE" : g_unified_snapshot.comparison2),g_muted);
      Row(30,"LTF "+ICTUnifiedTF(g_unified_snapshot.frames.ltf)+" MTF "+ICTUnifiedTF(g_unified_snapshot.frames.mtf)+" HTF "+ICTUnifiedTF(g_unified_snapshot.frames.htf),g_white);
      Row(31,ICTUnifiedStructureText(g_unified_snapshot.mtf_state),g_muted);
      Row(32,g_unified_snapshot.valid ? "Analysis only; see Decision/Risk" : "INSUFFICIENT_DATA",g_yellow); return;
     }
   double stamp=(GlobalVariableCheck(SRMPAdviceKey(_Symbol,"ICTTS")) ?
                 GlobalVariableGet(SRMPAdviceKey(_Symbol,"ICTTS")) : 0.0);
   if(stamp<=0.0 || TimeLocal()-(datetime)stamp>10)
     {
      Row(26,"ICT ANALYSIS  |  CHART DATA",g_white);
      Row(27,g_chart_ict_ready && g_chart_ict.ob_available ?
          StringFormat("OB %s %s score %d",
                       g_chart_ict.ob.direction>0 ? "BULL" : "BEAR",
                       SRMPOBStateText(g_chart_ict.ob.state),
                       g_chart_ict.ob.score) : "OB: no validated zone",g_yellow);
      Row(28,"SMT 1: "+(Comparison_Symbol_1=="" ? "not configured" :
          g_chart_ict.smt1_available ? SRMPSMTStateText(g_chart_ict.smt1.state) :
          "data unavailable"),g_muted);
      Row(29,"SMT 2: "+(Comparison_Symbol_2=="" ? "not configured" :
          g_chart_ict.smt2_available ? SRMPSMTStateText(g_chart_ict.smt2.state) :
          "data unavailable"),g_muted);
      Row(30,"Analysis uses closed candles",g_muted);
      Row(31,"Lot/advice service offline",g_yellow);
      Row(32,"NO TRADE recommendation",g_yellow);
      ClearICTObjects();
      return;
     }
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   bool ob=GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBOK"))>0.5;
   int ob_state=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBSTATE"));
   int ob_dir=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBDIR"));
   int score=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"ICTSCORE"));
   int recommendation=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"ICTREC"));
   Row(26,"ICT ANALYSIS  |  CLOSED BARS",g_white);
   Row(27,ob ? StringFormat("OB %s %s score %d/100",
         ob_dir>0 ? "BULL" : "BEAR",
         SRMPOBStateText((ENUM_SRMP_OB_STATE)ob_state),
         (int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBSCORE"))) :
         "OB: no confirmed displacement + break",ob ? g_white : g_yellow);
   Row(28,ob ? "OB zone "+DoubleToString(GlobalVariableGet(
         SRMPAdviceKey(_Symbol,"OBLO")),digits)+" - "+DoubleToString(
         GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBHI")),digits)+
         " mid "+DoubleToString(GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBMID")),digits) :
         "OB zone unavailable",ob ? g_white : g_muted);
   string symbol1=SRMPReadAdviceSymbol(_Symbol,"SM1S");
   string symbol2=SRMPReadAdviceSymbol(_Symbol,"SM2S");
   int state1=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1STATE"));
   int state2=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2STATE"));
   Row(29,"SMT 1 "+(symbol1=="" ? "(blank)" : symbol1)+" "+
       (symbol1=="" ? "NOT CONFIGURED" :
        SRMPSMTStateText((ENUM_SRMP_SMT_STATE)state1))+
       (symbol1=="" ? "" : " rho "+DoubleToString(GlobalVariableGet(
         SRMPAdviceKey(_Symbol,"SM1CORR")),2)),g_white);
   Row(30,"SMT 2 "+(symbol2=="" ? "(blank)" : symbol2)+" "+
       (symbol2=="" ? "NOT CONFIGURED" :
        SRMPSMTStateText((ENUM_SRMP_SMT_STATE)state2))+
       (symbol2=="" ? "" : " rho "+DoubleToString(GlobalVariableGet(
         SRMPAdviceKey(_Symbol,"SM2CORR")),2)),g_white);
   Row(31,"Confluence score "+IntegerToString(score)+"/100 (criteria only)",g_white);
   Row(32,"ICT: "+ICTRecommendationText(recommendation),
       (recommendation==SRMP_ICT_BULLISH_SETUP ||
        recommendation==SRMP_ICT_BEARISH_SETUP) ? g_green : g_yellow);
   if(!Show_Service_ICT_Overlays)
     { ClearICTObjects(); return; }
   if(Show_OB_Overlay && ob)
     {
      SOrderBlock block;
      ZeroMemory(block);
      block.direction=ob_dir;
      block.state=(ENUM_SRMP_OB_STATE)ob_state;
      block.lower=GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBLO"));
      block.upper=GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBHI"));
      block.midpoint=GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBMID"));
      block.score=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBSCORE"));
      block.formation_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBFORM"));
      block.confirmation_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"OBCONF"));
      datetime edge=iTime(_Symbol,_Period,0)+(datetime)PeriodSeconds(_Period);
      SRMPRenderOrderBlock(Key("ict_ob_"),block,edge,Show_Inactive_OB);
     }
   else SRMPClearOBObjects(Key("ict_ob_"));
   ENUM_TIMEFRAMES smt_tf=(ENUM_TIMEFRAMES)(int)GlobalVariableGet(
                            SRMPAdviceKey(_Symbol,"SMTTF"));
   if(Show_SMT_Overlay && symbol1!="" &&
      (state1==SRMP_SMT_BULLISH || state1==SRMP_SMT_BEARISH))
     {
      SSMTDivergence signal;
      ZeroMemory(signal);
      signal.comparison=symbol1;
      signal.state=(ENUM_SRMP_SMT_STATE)state1;
      signal.direction=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1DIR"));
      signal.correlation=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1CORR"));
      signal.correlation_pairs=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1PAIR"));
      signal.primary_prior_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1PRT"));
      signal.primary_pivot_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1PT"));
      signal.confirmation_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1CONF"));
      signal.pivot_confirmation_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1PVCONF"));
      signal.primary_prior=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1PREV"));
      signal.primary_recent=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1LAST"));
      SRMPRenderSMT(Key("ict_sm1_"),signal,smt_tf);
     }
   else SRMPClearSMTObjects(Key("ict_sm1_"));
   if(Show_SMT_Overlay && symbol2!="" &&
      (state2==SRMP_SMT_BULLISH || state2==SRMP_SMT_BEARISH))
     {
      SSMTDivergence signal;
      ZeroMemory(signal);
      signal.comparison=symbol2;
      signal.state=(ENUM_SRMP_SMT_STATE)state2;
      signal.direction=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2DIR"));
      signal.correlation=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2CORR"));
      signal.correlation_pairs=(int)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2PAIR"));
      signal.primary_prior_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2PRT"));
      signal.primary_pivot_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2PT"));
      signal.confirmation_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2CONF"));
      signal.pivot_confirmation_time=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2PVCONF"));
      signal.primary_prior=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2PREV"));
      signal.primary_recent=GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2LAST"));
      SRMPRenderSMT(Key("ict_sm2_"),signal,smt_tf);
     }
   else SRMPClearSMTObjects(Key("ict_sm2_"));
  }

void NewSetup(const ENUM_RM_DIRECTION direction)
  {
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote) || quote.ask<=0 || quote.bid<=0) return;
   g_direction=direction;
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(point<=0.0 || tick<=0.0) return;
   long stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freeze=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   int distance=(int)MathMax((double)Default_Stop_Points,
                             (double)MathMax(stops,freeze)+MathCeil(tick/point));
   distance=(int)MathMax((double)distance,1.0);
   double entry=(direction==RM_BUY ? quote.ask : quote.bid);
   double sign=(direction==RM_BUY ? 1.0 : -1.0);
   RMLine(Key("ENTRY"),TickPrice(entry),C'28,107,185');
   RMLine(Key("SL"),TickPrice(entry-sign*distance*point),g_red);
   RMLine(Key("TP"),TickPrice(entry+sign*distance*point*Preferred_Risk_Reward),g_green);
   g_initialized=true;
  }

void PublishRequest(const double entry,const double sl,const double tp,const double capital)
  {
   if(g_has_request && entry==g_last_entry && sl==g_last_sl && tp==g_last_tp &&
      capital==g_last_capital && g_direction==g_last_direction) return;
   g_request_sequence=(GlobalVariableCheck(g_bridge+"REQ") ?
                       GlobalVariableGet(g_bridge+"REQ")+1.0 : 1.0);
   GlobalVariableSet(g_bridge+"E",entry);
   GlobalVariableSet(g_bridge+"SL",sl);
   GlobalVariableSet(g_bridge+"TP",tp);
   GlobalVariableSet(g_bridge+"DIR",(double)g_direction);
   GlobalVariableSet(g_bridge+"CAP",capital);
   GlobalVariableSet(g_bridge+"RISK",Risk_Per_Trade);
   GlobalVariableSet(g_bridge+"MAXR",Max_Risk_Per_Trade);
   GlobalVariableSet(g_bridge+"MINRR",Minimum_RR);
   GlobalVariableSet(g_bridge+"COMM",Commission_Round_Turn_Per_Lot);
   GlobalVariableSet(g_bridge+"BUF",Unspecified_Cost_Buffer_Per_Lot);
   GlobalVariableSet(g_bridge+"SLIP",Estimated_Slippage_Points);
   GlobalVariableSet(g_bridge+"AGE",(double)Max_Quote_Age_Seconds);
   GlobalVariableSet(g_bridge+"REQ",g_request_sequence);
   g_last_entry=entry; g_last_sl=sl; g_last_tp=tp;
   g_last_capital=capital; g_last_direction=g_direction;
   g_has_request=true;
  }

bool ReadResponse(SRiskResult &result)
  {
   ZeroMemory(result);
   result.reason="RiskCalculationService offline or pending";
   if(!g_has_request || !GlobalVariableCheck(g_bridge+"RESP") ||
      GlobalVariableGet(g_bridge+"RESP")!=g_request_sequence ||
      !GlobalVariableCheck(g_bridge+"TS") ||
      TimeLocal()-(datetime)GlobalVariableGet(g_bridge+"TS")>3) return false;
   result.volume=GlobalVariableGet(g_bridge+"VOL");
   result.risk_money=GlobalVariableGet(g_bridge+"RM");
   result.reward_money=GlobalVariableGet(g_bridge+"RW");
   result.risk_percent=GlobalVariableGet(g_bridge+"RP");
   result.rr=GlobalVariableGet(g_bridge+"RR");
   result.estimated_costs=GlobalVariableGet(g_bridge+"COST");
   result.estimated_margin=GlobalVariableGet(g_bridge+"MARGIN");
   result.reason=RMReasonText((int)GlobalVariableGet(g_bridge+"REASON"));
   result.valid=(GlobalVariableGet(g_bridge+"VALID")>0.5);
   return result.valid;
  }

string DistanceText(const double distance,const double point,const double tick_size)
  {
   if(point<=0 || tick_size<=0) return "n/a";
   string s=DoubleToString(distance/point,1)+" points / "+
            DoubleToString(distance/tick_size,1)+" ticks";
   string base=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE);
   ENUM_SYMBOL_CALC_MODE mode=(ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_CALC_MODE);
   if((mode==SYMBOL_CALC_MODE_FOREX || mode==SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE) &&
      base!="XAU" && base!="XAG" && (_Digits==3 || _Digits==5))
      s=DoubleToString(distance/(point*10.0),1)+" pips / "+s;
   return s;
  }

void Refresh()
  {
   if(!g_dashboard_visible) return;
   if(!g_initialized)
     {
      Row(0,"SMART RISK MANAGER PRO",g_white);
      Row(1,"PHASE 1  |  PREVIEW ONLY",g_muted);
      Row(23,"PLAN: BLOCKED",g_red);
      Row(24,"Waiting for valid quote / symbol specification",g_yellow);
      ShowAdvice();
      ShowMarketContext();
      ShowICT();
      ShowDecision();
      ChartRedraw(0);
      return;
     }
   double entry=Price("ENTRY"),sl=Price("SL"),tp=Price("TP");
   double capital=AccountInfoDouble(Use_Equity_As_Reference ? ACCOUNT_EQUITY : ACCOUNT_BALANCE);
   SRiskResult result;
   PublishRequest(entry,sl,tp,capital);
   bool ready=ReadResponse(result);
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   string currency=AccountInfoString(ACCOUNT_CURRENCY);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   MqlTick quote;
   ZeroMemory(quote);
   double spread=0.0;
   if(SymbolInfoTick(_Symbol,quote) && point>0) spread=(quote.ask-quote.bid)/point;

   int all_positions=PositionsTotal();
   int symbol_positions=0;
   ulong first_ticket=0;
   for(int i=0;i<all_positions;i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      symbol_positions++;
      if(first_ticket==0) first_ticket=ticket;
     }

   Row(0,"SMART RISK MANAGER PRO",g_white);
   Row(1,"PHASE 1  |  PREVIEW ONLY",g_muted);
   Row(2,"Balance: "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2)+" "+currency,g_white);
   Row(3,"Equity: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2)+" "+currency,g_white);
   Row(4,"Free margin: "+DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2)+" "+currency,g_white);
   Row(5,"Floating P/L: "+DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT),2)+" "+currency,g_white);
   Row(6,"Preview capital: "+(Use_Equity_As_Reference ? "equity" : "balance")+
       " "+DoubleToString(capital,2),g_muted);
   Row(7,"Open positions (account): "+IntegerToString(all_positions),g_white);
   Row(8,"TRADE PLAN  |  DRAG LINES",g_muted);
   Row(9,_Symbol+"  "+(g_direction==RM_BUY ? "BUY" : "SELL"),g_white);
   Row(10,"Planned Entry: "+DoubleToString(entry,digits),g_white);
   Row(11,"Planned SL: "+DoubleToString(sl,digits),g_red);
   Row(12,"Planned TP: "+DoubleToString(tp,digits),g_green);
   Row(13,"SL distance: "+DistanceText(MathAbs(entry-sl),point,tick_size),g_white);
   Row(14,"TP distance: "+DistanceText(MathAbs(entry-tp),point,tick_size),g_white);
   Row(15,"Maximum lot: "+(result.volume>0 ? DoubleToString(result.volume,8) : "BLOCKED"),ready ? g_green : g_red);
   Row(16,"Estimated risk: "+DoubleToString(result.risk_money,2)+" "+currency,g_white);
   Row(17,"Net reward: "+DoubleToString(result.reward_money,2)+" "+currency,g_white);
   Row(18,"Risk / capital: "+DoubleToString(result.risk_percent,2)+"%",g_white);
   Row(19,"Net RR: "+(result.risk_money>0 ? "1:"+DoubleToString(result.rr,2) : "n/a"),ready ? g_green : g_yellow);
   Row(20,"Current spread: "+DoubleToString(spread,1)+" points",g_white);
   Row(21,"Cost estimate: "+DoubleToString(result.estimated_costs,2)+" "+currency,g_white);
   Row(22,"Margin estimate: "+DoubleToString(result.estimated_margin,2)+" "+currency,g_white);
   Row(23,ready ? "PLAN: VALID PREVIEW" : "PLAN: BLOCKED",ready ? g_green : g_red);
   Row(24,result.reason,ready ? g_muted : g_yellow);
   string protection="PROTECTION: EA OFFLINE";
   color protection_color=g_red;
   if(GlobalVariableCheck(SRMPGlobalKey("REF")) &&
      GlobalVariableCheck(SRMPGlobalKey("STATE")))
     {
      ENUM_SRMP_STATE saved=(ENUM_SRMP_STATE)(int)GlobalVariableGet(SRMPGlobalKey("STATE"));
      bool active=GlobalVariableCheck(SRMPGlobalKey("HB")) &&
                  TimeLocal()-(datetime)GlobalVariableGet(SRMPGlobalKey("HB"))<=3;
      if(active)
        {
         int health=(GlobalVariableCheck(SRMPGlobalKey("HEALTH")) ?
                     (int)GlobalVariableGet(SRMPGlobalKey("HEALTH")) : 1);
         double worst_pct=(GlobalVariableCheck(SRMPGlobalKey("WORST")) ?
                           GlobalVariableGet(SRMPGlobalKey("WORST")) : 0.0);
         if(health!=0)
           {
            protection=(health==1 ? "PROTECTION: RISK SCAN FAILED" :
                        (health==2 ? "PROTECTION: DISCONNECTED / TRADE DISABLED" :
                         "PROTECTION: RETRY LIMIT REACHED"));
            protection_color=g_red;
           }
         else
           {
            protection="PROTECTION: "+SRMPStateName(saved)+" | Ref "+
                       DoubleToString(GlobalVariableGet(SRMPGlobalKey("REF")),2)+
                       " | Max "+DoubleToString(worst_pct,2)+"%";
            protection_color=(saved==SRMP_NORMAL ? g_green : g_red);
            if(saved==SRMP_NORMAL && GlobalVariableCheck(SRMPGlobalKey("LEVEL")))
              {
               int level=(int)GlobalVariableGet(SRMPGlobalKey("LEVEL"));
               if(level>=1)
                 {
                  string label=(level>=3 ? "CRITICAL WARNING" :
                                (level>=2 ? "HIGH RISK" : "WARNING"));
                  protection="PROTECTION: "+label+" | Max "+
                             DoubleToString(worst_pct,2)+"%";
                  protection_color=(level>=3 ? g_red : g_yellow);
                 }
              }
           }
        }
      else protection="PROTECTION: EA OFFLINE | Saved "+SRMPStateName(saved);
     }
   Row(25,protection,protection_color);
   Row(26,"ACTUAL POSITION  |  CURRENT SYMBOL",g_muted);
   if(first_ticket>0 && PositionSelectByTicket(first_ticket))
     {
      bool buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double current=(buy ? quote.bid : quote.ask);
      Row(27,"Ticket "+IntegerToString(first_ticket)+(buy ? " BUY" : " SELL"),g_white);
      Row(28,"Actual Entry / Now: "+DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),digits)+
          " / "+DoubleToString(current,digits),g_white);
      Row(29,"Actual SL / TP: "+DoubleToString(PositionGetDouble(POSITION_SL),digits)+
          " / "+DoubleToString(PositionGetDouble(POSITION_TP),digits),g_white);
      Row(30,"Actual volume: "+DoubleToString(PositionGetDouble(POSITION_VOLUME),8),g_white);
      Row(31,"Floating P/L + swap: "+DoubleToString(PositionGetDouble(POSITION_PROFIT)+
          PositionGetDouble(POSITION_SWAP),2)+" "+currency,g_white);
      Row(32,"Current symbol positions: "+IntegerToString(symbol_positions)+" (first shown)",g_muted);
     }
   else
     {
      for(int row=27;row<=31;row++) Row(row,"",g_muted);
      Row(32,"No open position on this symbol",g_muted);
     }
   ShowAdvice();
   ShowMarketContext();
   ShowICT();
   ShowDecision();
   ChartRedraw(0);
  }

void RefreshChartAnalysis()
  {
   g_unified_from_ea=ICTReadUnified(_Symbol,g_unified_snapshot,15,g_unified_config.frames.ltf);
   if(!g_unified_from_ea)
     {
      string stamp=SRMPAdviceKey(_Symbol,"UTS");
      bool producer_recent=GlobalVariableCheck(stamp) && GlobalVariableGet(stamp)>0 &&
         TimeLocal()-(datetime)GlobalVariableGet(stamp)<=15;
      if(producer_recent)
        {
         ZeroMemory(g_unified_snapshot); g_unified_snapshot.schema=ICT_UNIFIED_SCHEMA;
         g_unified_snapshot.symbol=_Symbol; g_unified_snapshot.frames=g_unified_config.frames;
         g_unified_snapshot.reason="Shared publication incomplete/in progress; no independent replacement signal";
        }
      else { g_unified_engine.Update(_Symbol,g_unified_config); g_unified_engine.Snapshot(g_unified_snapshot); }
     }
   g_chart_ict_ready=g_unified_snapshot.valid;
   ZeroMemory(g_chart_ict);
   int nearest=ICTNearestActiveOB(g_unified_snapshot,SymbolInfoDouble(_Symbol,SYMBOL_BID));
   if(nearest>=0) { g_chart_ict.ob=g_unified_snapshot.zones[nearest].ob; g_chart_ict.ob_available=true; }
   string standalone="SRMP_ICTD_"+IntegerToString(ChartID())+"_ui_";
   bool ea_draws=g_unified_from_ea || ObjectFind(0,standalone+"eye")>=0 || ObjectFind(0,standalone+"panel")>=0;
   if(ea_draws) ObjectsDeleteAll(0,Key("unified_draw_"));
   else ICTRenderUnifiedOverlays(Key("unified_draw_"),g_unified_snapshot,Show_SMT_Overlay,Show_OB_Overlay,
      Show_FVG_Overlay,true,Show_Premium_Discount,Show_Structure_Overlay,Show_Liquidity_Overlay && !Show_IRL_ERL);
  }

void RefreshRangeView()
  {
   string unified_ui="SRMP_ICTD_"+IntegerToString(ChartID())+"_ui_";
   bool ea_panel=ObjectFind(0,unified_ui+"eye")>=0 || ObjectFind(0,unified_ui+"panel")>=0;
   if(Show_Range_Dashboard && !ea_panel)
     {
      string decision="ANALYSIS ONLY / NO TRADE",plan="Risk Manager approval required for any actionable plan",reason=g_unified_snapshot.reason;
      if(g_unified_from_ea && g_unified_snapshot.signal.symbol==_Symbol &&
         g_unified_snapshot.signal.asof==g_unified_snapshot.asof)
        {
         decision=ICTSignalStateText(g_unified_snapshot.signal.state);
         reason=g_unified_snapshot.signal.reason;
         plan="Shared confirmed-bar decision; no independent indicator signal";
        }
      ICTRenderUnifiedDashboard(Key("smart_ui_"),g_unified_snapshot,decision,plan,reason,CORNER_LEFT_UPPER,
         Range_Panel_X,Range_Panel_Y,Range_Panel_Width,Range_Panel_Height,Range_Panel_Font_Size,
         g_range_panel_page,g_range_panel_x,g_range_panel_y,g_range_panel_hidden);
     }
   else ObjectsDeleteAll(0,Key("smart_ui_"));
   if(!Show_IRL_ERL)
     { ObjectsDeleteAll(0,Key("range_")); return; }
   if(g_unified_from_ea)
     { ObjectsDeleteAll(0,Key("range_")); return; }
   if(!ICTReadRange(_Symbol,g_range_view))
     {
      ZeroMemory(g_range_view); g_range_view.symbol=_Symbol; g_range_view.schema=ICT_RANGE_SCHEMA;
      g_range_view.reason_code=IR_DATA;
      g_range_view.reason="IRL/ERL service offline, stale or incomplete; enable IRL/ERL in the EA on this chart";
     }
   ICTRenderRange(Key("range_"),g_range_view,Show_Range_Layer,Show_IRL_Layer,
                    Show_ERL_Layer,Show_Range_Targets,Show_Range_Rotation);
   ICTRenderSweepSequence(Key("range_sweeps_"),g_range_view,12,true,true,true,true,true);
   // The standalone EA owns its left panel, including its retained eye when
   // collapsed. Avoid a second panel underneath that would appear after Hide.
   string standalone_ui="SRMP_ICTD_"+IntegerToString(ChartID())+"_ui_";
   bool standalone_panel=ObjectFind(0,standalone_ui+"eye")>=0 || ObjectFind(0,standalone_ui+"panel")>=0;
   if(standalone_panel) ObjectsDeleteAll(0,Key("smart_ui_"));
  }

void ShowEyeButton()
  {
   ObjectDelete(0,Key("eye"));
   RMButton(Key("eye"),"👁",Dashboard_Right_Margin+6,
            Dashboard_Top_Margin+3,28,C'46,56,71');
   ObjectSetString(0,Key("eye"),OBJPROP_FONT,"Segoe UI Emoji");
   ObjectSetInteger(0,Key("eye"),OBJPROP_ZORDER,10);
   ObjectSetString(0,Key("eye"),OBJPROP_TOOLTIP,
                   g_dashboard_visible ? "Hide dashboard" : "Show dashboard");
  }

void LayoutDashboard()
  {
   if(!g_dashboard_visible)
     { ClearDashboardUI(); ShowEyeButton(); ChartRedraw(0); return; }
   int panel_height=(int)MathMin(Compact_Dashboard ? 190.0 : 230.0,
                                  (double)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS)-
                                  Dashboard_Top_Margin-4.0);
   RMPanel(Key("panel"),Dashboard_Right_Margin,Dashboard_Top_Margin,560,panel_height);
   if(Show_Advisory_Panel)
     {
      int advice_height=(int)MathMin(380.0,
                           (double)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS)-
                           Dashboard_Top_Margin-4.0);
      RMPanelLeft(Key("advice_panel"),Advisory_Left_Margin,
                  Dashboard_Top_Margin,380,advice_height);
     }
   RMButton(Key("buy"),"BUY",Dashboard_Right_Margin+333,
            Dashboard_Top_Margin+panel_height-27,100,C'34,98,68');
   RMButton(Key("sell"),"SELL",Dashboard_Right_Margin+227,
            Dashboard_Top_Margin+panel_height-27,100,C'125,48,54');
   RMButton(Key("calc"),"LOT",Dashboard_Right_Margin+121,
            Dashboard_Top_Margin+panel_height-27,100,C'48,77,113');
   RMButton(Key("reset"),"RESET",Dashboard_Right_Margin+15,
            Dashboard_Top_Margin+panel_height-27,100,C'64,72,84');
   RMButton(Key("ict_toggle"),"ICT / POS",Dashboard_Right_Margin+439,
            Dashboard_Top_Margin+panel_height-27,100,C'67,59,99');
   ShowEyeButton();
  }

int OnInit()
  {
   if(!ICTConfigureUnifiedInputs((ENUM_TIMEFRAMES)_Period,Comparison_Symbol_1,Comparison_Symbol_2,g_unified_config))
     { Print("Invalid unified MTF / SMT / Strong OB inputs"); return INIT_PARAMETERS_INCORRECT; }
   if(StringLen(Instance_ID)<1 || StringLen(Instance_ID)>12 ||
      Risk_Per_Trade<=0 || Max_Risk_Per_Trade<=0 || Minimum_RR<2.0 ||
      Preferred_Risk_Reward<Minimum_RR ||
      Default_Stop_Points<=0 || Max_Quote_Age_Seconds<=0 ||
      Commission_Round_Turn_Per_Lot<0 || Unspecified_Cost_Buffer_Per_Lot<0 ||
      Estimated_Slippage_Points<0 || Dashboard_Right_Margin<0 ||
      Dashboard_Top_Margin<0 || Advisory_Left_Margin<0 ||
      StringLen(Comparison_Symbol_1)>24 || StringLen(Comparison_Symbol_2)>24 ||
      (Comparison_Symbol_1!="" && Comparison_Symbol_1==Comparison_Symbol_2))
      return INIT_PARAMETERS_INCORRECT;
   if(Range_Panel_X<0 || Range_Panel_Y<0 || Range_Panel_Width<300 || Range_Panel_Height<120 ||
      Range_Panel_Font_Size<7 || Range_Panel_Font_Size>18)
      return INIT_PARAMETERS_INCORRECT;
   g_prefix="SRM_"+IntegerToString(ChartID())+"_"+Instance_ID+"_";
   g_show_ict_view=Show_ICT_Group;
   g_bridge=RMBridgePrefix(Instance_ID);
   LayoutDashboard();
   NewSetup(RM_BUY);
   EventSetTimer(1);
   RefreshChartAnalysis();
   RefreshRangeView();
   Refresh();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   SRMPClearChartAnalysis(Key("analysis_"));
   ObjectsDeleteAll(0,g_prefix);
   ChartRedraw(0);
  }

void OnTimer()
  {
   if(!g_initialized) NewSetup(g_direction);
   RefreshChartAnalysis();
   RefreshRangeView();
   Refresh();
  }

int OnCalculate(const int rates_total,const int prev_calculated,const int begin,const double &price[])
  { return rates_total; }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(ICTPanelEvent(Key("smart_ui_"),id,sparam,g_range_panel_page,
      g_range_panel_x,g_range_panel_y,g_range_panel_hidden))
     { RefreshRangeView(); ChartRedraw(); return; }
   if(id==CHARTEVENT_CHART_CHANGE)
     { LayoutDashboard(); g_analysis_bar=0; RefreshChartAnalysis(); RefreshRangeView(); Refresh(); return; }
   if(id==CHARTEVENT_OBJECT_DRAG &&
      (sparam==Key("ENTRY") || sparam==Key("SL") || sparam==Key("TP"))) Refresh();
   if(id!=CHARTEVENT_OBJECT_CLICK) return;
   if(sparam==Key("eye"))
     {
      g_dashboard_visible=!g_dashboard_visible;
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      LayoutDashboard();
      RefreshRangeView();
      Refresh();
      return;
     }
   if(sparam==Key("buy")) NewSetup(RM_BUY);
   else if(sparam==Key("ict_toggle")) g_show_ict_view=!g_show_ict_view;
   else if(sparam==Key("sell")) NewSetup(RM_SELL);
   else if(sparam==Key("reset")) NewSetup(g_direction);
   else if(sparam!=Key("calc")) return;
   ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
   Refresh();
  }
