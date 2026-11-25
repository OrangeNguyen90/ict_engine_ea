#property copyright "MT5 Smart Risk Manager Pro"
#property version "1.00"
#property description "Risk calculation and advisory service. Never sends orders."

#include "../Include/RiskCalculator.mqh"
#include "../Include/RiskBridge.mqh"
#include "../Include/TradeAdvisor.mqh"
#include "../Include/AdviceBridge.mqh"
#include "../Include/ICTDecisionBridge.mqh"
#include "../Include/MarketContext.mqh"
#include "../Include/ICTDecisionEngine.mqh"
#include "../Include/ICTSessionManager.mqh"
#include "../Include/ICTRangeInputs.mqh"
#include "../Include/ICTRangeBridge.mqh"

input string Instance_ID="A"; // Must match the indicator on this chart
input bool Enable_Trading_Advice=true;
input ENUM_TIMEFRAMES Context_Timeframe=PERIOD_H4;
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H1;
input ENUM_TIMEFRAMES Setup_Timeframe=PERIOD_M15;
input ENUM_TIMEFRAMES Trigger_Timeframe=PERIOD_M5;
input double Max_Advice_Spread_Points=50.0;
input bool InpEnableOB=true;
input ENUM_TIMEFRAMES InpOBTimeframe=PERIOD_M15;
input int InpOBLookbackBars=120;
input ENUM_SRMP_OB_BOUNDS InpOBBounds=SRMP_OB_HYBRID;
input double InpOBDisplacementFactor=1.2;
input int InpOBConfirmationBars=3;
input ENUM_SRMP_OB_MITIGATION InpOBMitigation=SRMP_OB_TOUCH;
input ENUM_SRMP_OB_INVALIDATION InpOBInvalidation=SRMP_OB_CLOSE;
input int InpOBExpiryBars=40;
input int InpOBScoreSweep=20;
input int InpOBScoreBOS=25;
input int InpOBScoreFVG=20;
input int InpOBScoreDisplacement=15;
input int InpOBScoreSession=10;
input int InpOBScorePD=10;
input bool InpEnableSMT=true;
input string InpSMTSymbol1="";
input string InpSMTSymbol2="";
input ENUM_TIMEFRAMES InpSMTTimeframe=PERIOD_H1;
input int InpSMTLookbackBars=50;
input int InpSMTPivotLeft=3;
input int InpSMTPivotRight=3;
input ENUM_SMT_CORRELATION InpSMTCorrelation1=SMT_AUTO;
input ENUM_SMT_CORRELATION InpSMTCorrelation2=SMT_AUTO;
input int InpSMTCorrelationWindow=100;
input double InpSMTMinAbsCorrelation=0.60;
input int InpSMTMaxTimeGapBars=3;
input bool Enable_ICT_Decision=true;
input int Decision_Max_Setup_Age_Bars=48;
input double Decision_Displacement_Body_ATR=1.0;
input double Decision_Displacement_Body_Fraction=0.60;
input double Decision_Minimum_FVG_ATR=0.05;
input double Decision_Daily_Loss_Limit_Percent=6.0;
input bool Decision_Daily_Risk_Budget_Enable=true;
input double Decision_Portfolio_Risk_Limit_Percent=3.0;
input int Decision_Minimum_Score=65;
input int Decision_Strong_Score=80;
input ENUM_ICT_ZONE_MODE Decision_Entry_Zone_Mode=ICT_ZONE_FVG_OR_OB;
input int Decision_Tester_Broker_UTC_Offset_Minutes=9999;
input bool Decision_Require_SMT=false;
input bool Decision_Require_Session=false;
input int Decision_Weight_HTF=20;
input int Decision_Weight_Sweep=15;
input int Decision_Weight_Structure=15;
input int Decision_Weight_FVG=10;
input int Decision_Weight_OB=10;
input int Decision_Weight_PD=10;
input int Decision_Weight_SMT=10;
input int Decision_Weight_Displacement=5;
input int Decision_Weight_Session=5;

string g_bridge;
SICTRangeConfig g_range_config;
CICTRangeEngine g_range_engine;
datetime g_last_advice_bar=0;
datetime g_last_advice_refresh=0;
int g_last_advice_status=-1;
SICTSettings g_ict_settings;
datetime g_logged_ob_time=0;
int g_logged_ob_state=-1;
double g_logged_ob_lower=0.0,g_logged_ob_upper=0.0;
datetime g_logged_smt1=0,g_logged_smt2=0;

void LogICTTransitions(const SICTSnapshot &ict)
  {
   if(ict.ob_available &&
      (ict.ob.formation_time!=g_logged_ob_time ||
       (int)ict.ob.state!=g_logged_ob_state ||
       ict.ob.lower!=g_logged_ob_lower || ict.ob.upper!=g_logged_ob_upper))
     {
      PrintFormat("ICT OB event symbol=%s formation=%s confirmation=%s state_time=%s direction=%d state=%s zone=[%.*f,%.*f] score=%d",
         _Symbol,TimeToString(ict.ob.formation_time),
         TimeToString(ict.ob.confirmation_time),
         TimeToString(ict.ob.state_time),ict.ob.direction,
         SRMPOBStateText(ict.ob.state),_Digits,ict.ob.lower,
         _Digits,ict.ob.upper,ict.ob.score);
      if(ict.ob.formation_time==g_logged_ob_time &&
         (ict.ob.lower!=g_logged_ob_lower || ict.ob.upper!=g_logged_ob_upper))
         Print("ICT OB historical candle prices revised by broker: ",_Symbol);
      g_logged_ob_time=ict.ob.formation_time;
      g_logged_ob_state=(int)ict.ob.state;
      g_logged_ob_lower=ict.ob.lower;
      g_logged_ob_upper=ict.ob.upper;
     }
   if(ict.smt1_available && ict.smt1.primary_pivot_time!=g_logged_smt1)
     {
      PrintFormat("ICT SMT1 event symbol=%s comparison=%s pivot=%s confirmation=%s direction=%d rho=%.3f pairs=%d",
         _Symbol,ict.smt1.comparison,TimeToString(ict.smt1.primary_pivot_time),
         TimeToString(ict.smt1.confirmation_time),ict.smt1.direction,
         ict.smt1.correlation,ict.smt1.correlation_pairs);
      g_logged_smt1=ict.smt1.primary_pivot_time;
     }
   if(ict.smt2_available && ict.smt2.primary_pivot_time!=g_logged_smt2)
     {
      PrintFormat("ICT SMT2 event symbol=%s comparison=%s pivot=%s confirmation=%s direction=%d rho=%.3f pairs=%d",
         _Symbol,ict.smt2.comparison,TimeToString(ict.smt2.primary_pivot_time),
         TimeToString(ict.smt2.confirmation_time),ict.smt2.direction,
         ict.smt2.correlation,ict.smt2.correlation_pairs);
      g_logged_smt2=ict.smt2.primary_pivot_time;
     }
  }

void ConfigureICT()
  {
   SRMPDefaultICTSettings(g_ict_settings);
   g_ict_settings.enable_ob=InpEnableOB;
   g_ict_settings.ob_timeframe=InpOBTimeframe;
   g_ict_settings.ob_lookback=InpOBLookbackBars;
   g_ict_settings.ob_bounds=InpOBBounds;
   g_ict_settings.displacement_factor=InpOBDisplacementFactor;
   g_ict_settings.confirmation_bars=InpOBConfirmationBars;
   g_ict_settings.mitigation=InpOBMitigation;
   g_ict_settings.invalidation=InpOBInvalidation;
   g_ict_settings.expiry_bars=InpOBExpiryBars;
   g_ict_settings.weights.sweep=InpOBScoreSweep;
   g_ict_settings.weights.break_structure=InpOBScoreBOS;
   g_ict_settings.weights.fvg=InpOBScoreFVG;
   g_ict_settings.weights.displacement=InpOBScoreDisplacement;
   g_ict_settings.weights.session=InpOBScoreSession;
   g_ict_settings.weights.premium_discount=InpOBScorePD;
   g_ict_settings.enable_smt=InpEnableSMT;
   g_ict_settings.comparison1=InpSMTSymbol1;
   g_ict_settings.comparison2=InpSMTSymbol2;
   g_ict_settings.smt_timeframe=InpSMTTimeframe;
   g_ict_settings.smt_lookback=InpSMTLookbackBars;
   g_ict_settings.pivot_left=InpSMTPivotLeft;
   g_ict_settings.pivot_right=InpSMTPivotRight;
   g_ict_settings.correlation1=InpSMTCorrelation1;
   g_ict_settings.correlation2=InpSMTCorrelation2;
   g_ict_settings.correlation_window=InpSMTCorrelationWindow;
   g_ict_settings.correlation_threshold=InpSMTMinAbsCorrelation;
   g_ict_settings.max_gap_bars=InpSMTMaxTimeGapBars;
  }

void PublishICT(SICTSnapshot &ict)
  {
   if(ict.smt1_available &&
      SRMPReadAdviceSymbol(_Symbol,"SM1S")==g_ict_settings.comparison1 &&
      GlobalVariableGet(SRMPAdviceKey(_Symbol,"SMTTF"))==
         (double)g_ict_settings.smt_timeframe &&
      GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1PT"))==
         (double)ict.smt1.primary_pivot_time &&
      GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1CPT"))==
         (double)ict.smt1.comparison_pivot_time)
     {
      if(GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1LAST"))!=
         ict.smt1.primary_recent)
         Print("ICT SMT1 primary pivot price revised by broker: ",_Symbol);
      datetime prior=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM1CONF"));
      if(prior>0) ict.smt1.confirmation_time=prior;
     }
   if(ict.smt2_available &&
      SRMPReadAdviceSymbol(_Symbol,"SM2S")==g_ict_settings.comparison2 &&
      GlobalVariableGet(SRMPAdviceKey(_Symbol,"SMTTF"))==
         (double)g_ict_settings.smt_timeframe &&
      GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2PT"))==
         (double)ict.smt2.primary_pivot_time &&
      GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2CPT"))==
         (double)ict.smt2.comparison_pivot_time)
     {
      if(GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2LAST"))!=
         ict.smt2.primary_recent)
         Print("ICT SMT2 primary pivot price revised by broker: ",_Symbol);
      datetime prior=(datetime)GlobalVariableGet(SRMPAdviceKey(_Symbol,"SM2CONF"));
      if(prior>0) ict.smt2.confirmation_time=prior;
     }
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"ICTTS"),0.0);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBOK"),ict.ob_available ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBDIR"),(double)ict.ob.direction);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBSTATE"),(double)ict.ob.state);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBLO"),ict.ob.lower);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBHI"),ict.ob.upper);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBMID"),ict.ob.midpoint);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBSCORE"),(double)ict.ob.score);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBFORM"),(double)ict.ob.formation_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBCONF"),(double)ict.ob.confirmation_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBSTIME"),(double)ict.ob.state_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1STATE"),(double)ict.smt1.state);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1DIR"),(double)ict.smt1.direction);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1CORR"),ict.smt1.correlation);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1PAIR"),(double)ict.smt1.correlation_pairs);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1PT"),(double)ict.smt1.primary_pivot_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1CPT"),(double)ict.smt1.comparison_pivot_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1PRT"),(double)ict.smt1.primary_prior_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1CONF"),(double)ict.smt1.confirmation_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1PVCONF"),(double)ict.smt1.pivot_confirmation_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1PREV"),ict.smt1.primary_prior);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM1LAST"),ict.smt1.primary_recent);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2STATE"),(double)ict.smt2.state);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2DIR"),(double)ict.smt2.direction);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2CORR"),ict.smt2.correlation);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2PAIR"),(double)ict.smt2.correlation_pairs);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2PT"),(double)ict.smt2.primary_pivot_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2CPT"),(double)ict.smt2.comparison_pivot_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2PRT"),(double)ict.smt2.primary_prior_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2CONF"),(double)ict.smt2.confirmation_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2PVCONF"),(double)ict.smt2.pivot_confirmation_time);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2PREV"),ict.smt2.primary_prior);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SM2LAST"),ict.smt2.primary_recent);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"ICTSCORE"),(double)ict.score);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"ICTREC"),(double)ict.recommendation);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"ICTBAR"),(double)ict.analyzed_bar);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"OBTF"),(double)g_ict_settings.ob_timeframe);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SMTTF"),(double)g_ict_settings.smt_timeframe);
   SRMPPublishAdviceSymbol(_Symbol,"SM1S",g_ict_settings.comparison1);
   SRMPPublishAdviceSymbol(_Symbol,"SM2S",g_ict_settings.comparison2);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"ICTTS"),(double)TimeLocal());
  }

void AnalyzeAndPublishDecision(const SICTSnapshot &ict)
  {
   if(!Enable_ICT_Decision)
     { GlobalVariableSet(SRMPAdviceKey(_Symbol,"DTS"),0.0); return; }
   SICTDecisionConfig cfg;
   cfg.higher_tf=Context_Timeframe;
   cfg.structure_tf=Structure_Timeframe;
   cfg.setup_tf=Setup_Timeframe;
   cfg.trigger_tf=Trigger_Timeframe;
   cfg.smt_tf=InpSMTTimeframe;
   cfg.comparison1=InpSMTSymbol1;
   cfg.comparison2=InpSMTSymbol2;
   cfg.lookback=120;
   cfg.swing_strength=2;
   cfg.max_setup_bars=Decision_Max_Setup_Age_Bars;
   cfg.displacement_body_atr=Decision_Displacement_Body_ATR;
   cfg.displacement_body_fraction=Decision_Displacement_Body_Fraction;
   cfg.min_gap_atr=Decision_Minimum_FVG_ATR;
   cfg.max_spread_points=Max_Advice_Spread_Points;
   cfg.risk_percent=Read("RISK");
   cfg.max_risk_percent=Read("MAXR");
   cfg.min_rr=Read("MINRR");
   cfg.commission_per_lot=Read("COMM");
   cfg.cost_buffer_per_lot=Read("BUF");
   cfg.slippage_points=Read("SLIP");
   cfg.daily_loss_limit_percent=Decision_Daily_Loss_Limit_Percent;
   cfg.daily_risk_budget_enabled=Decision_Daily_Risk_Budget_Enable;
   cfg.portfolio_risk_limit_percent=Decision_Portfolio_Risk_Limit_Percent;
   cfg.max_quote_age_seconds=(int)Read("AGE");
   SICTDecision decision;
   SICTConfluenceConfig scoring;
   ConfigureDecisionScoring(scoring);
   if(Enable_IRL_ERL)
     {
      SICTRangeSnapshot snapshot;
      ICTAnalyzeRangeDecision(_Symbol,cfg,scoring,g_range_config,g_range_engine,decision,snapshot);
      if(!ICTPublishRange(_Symbol,snapshot)) Print("IRL/ERL snapshot publication failed");
     }
   else ICTAnalyzeDecision(_Symbol,cfg,scoring,decision);
   ICTPublishDecision(_Symbol,decision);
  }

void ConfigureDecisionScoring(SICTConfluenceConfig &scoring)
  {
   ICTDefaultConfluenceConfig(scoring);
   scoring.minimum_score=Decision_Minimum_Score;
   scoring.strong_score=Decision_Strong_Score;
   scoring.entry_zone_mode=Decision_Entry_Zone_Mode;
   scoring.tester_broker_utc_offset_minutes=Decision_Tester_Broker_UTC_Offset_Minutes;
   scoring.mandatory_smt=Decision_Require_SMT;
   scoring.mandatory_session=Decision_Require_Session;
   scoring.htf=Decision_Weight_HTF;
   scoring.sweep=Decision_Weight_Sweep;
   scoring.mss=Decision_Weight_Structure;
   scoring.fvg=Decision_Weight_FVG;
   scoring.ob=Decision_Weight_OB;
   scoring.premium_discount=Decision_Weight_PD;
   scoring.smt=Decision_Weight_SMT;
   scoring.displacement=Decision_Weight_Displacement;
   scoring.session=Decision_Weight_Session;
  }

double Read(const string key) { return GlobalVariableGet(g_bridge+key); }
void Write(const string key,const double value) { GlobalVariableSet(g_bridge+key,value); }

int OnInit()
  {
   ICTConfigureRangeInputs(g_range_config);
   if(Range_Auto_Trading || (Enable_IRL_ERL && !ICTValidRangeConfig(g_range_config))) return INIT_PARAMETERS_INCORRECT;
   if(StringLen(Instance_ID)<1 || StringLen(Instance_ID)>12 ||
      Max_Advice_Spread_Points<=0.0 || Decision_Max_Setup_Age_Bars<1 ||
      Decision_Displacement_Body_ATR<=0.0 ||
      Decision_Displacement_Body_Fraction<=0.0 ||
      Decision_Displacement_Body_Fraction>1.0 ||
      Decision_Minimum_FVG_ATR<=0.0 ||
      !MathIsValidNumber(Decision_Daily_Loss_Limit_Percent) || Decision_Daily_Loss_Limit_Percent<=0.0 ||
      Decision_Daily_Loss_Limit_Percent>6.0 || !MathIsValidNumber(Decision_Portfolio_Risk_Limit_Percent) ||
      Decision_Portfolio_Risk_Limit_Percent<0.0 || Decision_Portfolio_Risk_Limit_Percent>100.0)
      return INIT_PARAMETERS_INCORRECT;
   ConfigureICT();
   SICTConfluenceConfig scoring;
   ConfigureDecisionScoring(scoring);
   if(!ICTValidConfluenceConfig(scoring)) return INIT_PARAMETERS_INCORRECT;
   if(!SRMPValidICTSettings(g_ict_settings)) return INIT_PARAMETERS_INCORRECT;
   g_bridge=RMBridgePrefix(Instance_ID);
   EventSetTimer(1);
   Print("RiskCalculationService started for chart ",ChartID()," instance ",Instance_ID,
         ". Calculation only; no order execution.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(Enable_IRL_ERL && Range_Export_History)
      g_range_engine.ExportHistory("IRL_ERL_"+IntegerToString(ChartID())+"_"+IntegerToString((long)TimeLocal())+"_ranges.csv");
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"IRTS"),0);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"TS"),0.0);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"CTS"),0.0);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"ICTTS"),0.0);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"DTS"),0.0);
   Print("RiskCalculationService stopped; reason=",reason);
  }

void OnTimer()
  {
   if(!GlobalVariableCheck(g_bridge+"REQ")) return;
   double sequence=Read("REQ");
   double entry=Read("E"),sl=Read("SL"),tp=Read("TP");
   ENUM_RM_DIRECTION direction=(Read("DIR")<0.5 ? RM_BUY : RM_SELL);
   SRiskResult result;
   bool valid=CalculateRisk(_Symbol,direction,entry,sl,tp,Read("CAP"),
                            Read("RISK"),Read("MAXR"),Read("MINRR"),
                            Read("COMM"),Read("BUF"),Read("SLIP"),
                            (int)Read("AGE"),result);
   Write("RESP",-1.0);
   Write("VALID",valid ? 1.0 : 0.0);
   Write("REASON",RMReasonCode(result.reason));
   Write("VOL",result.volume);
   Write("RM",result.risk_money);
   Write("RW",result.reward_money);
   Write("RP",result.risk_percent);
   Write("RR",result.rr);
   Write("COST",result.estimated_costs);
   Write("MARGIN",result.estimated_margin);
   Write("TS",(double)TimeLocal());
   Write("RESP",sequence);

   if(!Enable_Trading_Advice)
     {
      if(Enable_IRL_ERL && Enable_ICT_Decision && TimeLocal()-g_last_advice_refresh>=5)
        { g_last_advice_refresh=TimeLocal(); SICTSnapshot unused; ZeroMemory(unused); AnalyzeAndPublishDecision(unused); }
      return;
     }
   datetime bar=iTime(_Symbol,Trigger_Timeframe,1);
   if(bar<=0 || TimeLocal()-g_last_advice_refresh<5) return;
   g_last_advice_refresh=TimeLocal();
   SMarketContextSnapshot market;
   SRMPAnalyzeMarketContext(_Symbol,Context_Timeframe,Structure_Timeframe,
                            Setup_Timeframe,Trigger_Timeframe,market);
   SRMPPublishMarketContext(_Symbol,Context_Timeframe,Structure_Timeframe,
                            Setup_Timeframe,Trigger_Timeframe,market);
   double protection_reference=(GlobalVariableCheck(SRMPGlobalKey("REF")) ?
                                GlobalVariableGet(SRMPGlobalKey("REF")) : 0.0);
   STradeAdvice advice;
   SICTSnapshot ict;
   bool analyzed=SRMPAnalyzeAdviceWithICT(_Symbol,Context_Timeframe,
                      Structure_Timeframe,Setup_Timeframe,Trigger_Timeframe,
                      protection_reference,Read("RISK"),Read("MAXR"),Read("MINRR"),
                      Max_Advice_Spread_Points,Read("COMM"),Read("BUF"),
                      Read("SLIP"),(int)Read("AGE"),g_ict_settings,advice,ict);
   PublishICT(ict);
   LogICTTransitions(ict);
   AnalyzeAndPublishDecision(ict);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"TS"),0.0);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"STATUS"),(double)advice.status);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"DIR"),(double)advice.direction);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"REASON"),(double)SRMPAdviceReasonCode(advice.reasons));
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"E"),advice.entry);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"SL"),advice.stop_loss);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"TP"),advice.take_profit);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"ZL"),advice.zone_low);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"ZU"),advice.zone_high);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"VOL"),advice.risk.volume);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"RM"),advice.risk.risk_money);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"RW"),advice.risk.reward_money);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"RP"),advice.risk.risk_percent);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"RR"),advice.risk.rr);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"BAR"),(double)bar);
   GlobalVariableSet(SRMPAdviceKey(_Symbol,"TS"),(double)TimeLocal());
   if(bar!=g_last_advice_bar || (int)advice.status!=g_last_advice_status)
      PrintFormat("Advisory %s status=%d analyzed=%d reason=%s",
                  _Symbol,(int)advice.status,(int)analyzed,advice.reasons);
   g_last_advice_bar=bar;
   g_last_advice_status=(int)advice.status;
  }

void OnTick() {} // Calculations also refresh on the timer when ticks are absent.
