#property strict
#property description "Tester-safe deterministic ICT confluence fixtures; no trade requests."
#include "../Include/ICTConfluenceScore.mqh"
#include "../Include/ICTDecisionBridge.mqh"
#include "../Include/ICTSmartDashboard.mqh"
#include "../Include/PositionPlanValidation.mqh"
#include "../Include/SmartAutoPositionSLTP.mqh"

int failures=0;
int assertions=0;
void Check(const bool condition,const string name)
  {
   assertions++;
   if(!condition) { failures++; Print("FAIL: ",name); }
  }

// No market history, account state, or trading permissions required.
// Run as a script; the final journal line is the machine-readable result.
int OnInit()
  {
   SICTConfluenceConfig c;
   ICTDefaultConfluenceConfig(c);
   Check(ICTValidConfluenceConfig(c),"default config");
   Check(c.tester_broker_utc_offset_minutes==9999,"unknown replay offset is explicit");
   Check(!c.mandatory_smt && !c.mandatory_session,"legacy optional defaults");
   Check(c.minimum_score==65 && c.minimum_lead==0 && c.strong_score==80,"priority defaults");
   int weights[9]={20,15,15,5,10,10,10,10,5};
   for(uint mask=0;mask<512;mask++)
     {
      int expected=0;
      for(int bit=0;bit<9;bit++) if((mask&(1<<bit))!=0) expected+=weights[bit];
      Check(ICTWeightedScore(mask,c)==expected,"all evidence combinations");
     }
   Check(ICTWeightedScore(511,c)==100,"full score");
   Check(ICTWeightedScore(0,c)==0,"empty score");
   Check(ICTWeightedScore(ICT_E_SESSION,c)==5,"session shared by both sides");
   Check(ICTWeightedScore(ICT_E_HTF|ICT_E_SWEEP,c)==35,"buy independent evidence");
   Check(ICTWeightedScore(ICT_E_MSS|ICT_E_OB,c)==25,"sell independent evidence");
   Check(ICTScorePriority(70,60,true,c)==ICT_PRIORITY_BUY,"buy threshold and lead inclusive");
   Check(ICTScorePriority(60,70,true,c)==ICT_PRIORITY_SELL,"sell threshold and lead inclusive");
   Check(ICTScorePriority(64,0,true,c)==ICT_PRIORITY_WAIT,"below minimum");
   Check(ICTScorePriority(65,0,true,c)==ICT_PRIORITY_BUY,"65 moderate boundary");
   Check(ICTScorePriority(0,65,true,c)==ICT_PRIORITY_SELL,"sell 65 boundary");
   Check(ICTScorePriority(80,71,true,c)==ICT_PRIORITY_WAIT,"insufficient lead");
   Check(ICTScorePriority(100,100,true,c)==ICT_PRIORITY_WAIT,"tie");
   Check(ICTScorePriority(100,0,false,c)==ICT_PRIORITY_WAIT,"bad data preserves WAIT");
   Check((ICTRequiredEvidence(c)&(ICT_E_SMT|ICT_E_SESSION))==0,"optional requirements");
   c.mandatory_smt=true; c.mandatory_session=true;
   Check((ICTRequiredEvidence(c)&(ICT_E_SMT|ICT_E_SESSION))==(ICT_E_SMT|ICT_E_SESSION),"mandatory requirements");
   c.htf=15; c.smt=15;
   Check(ICTValidConfluenceConfig(c) && ICTWeightedScore(ICT_E_HTF|ICT_E_SMT,c)==30,"custom weights");
   c.htf=-1;
   Check(!ICTValidConfluenceConfig(c),"negative weight rejected");
   ICTDefaultConfluenceConfig(c); c.htf=21;
   Check(!ICTValidConfluenceConfig(c),"invalid total rejected");
   ICTDefaultConfluenceConfig(c); c.minimum_lead=0;
   Check(ICTValidConfluenceConfig(c),"zero lead accepted with dual-side veto");
   c.tester_broker_utc_offset_minutes=900;
   Check(!ICTValidConfluenceConfig(c),"invalid replay offset rejected");
   c.tester_broker_utc_offset_minutes=420;
   Check(ICTValidConfluenceConfig(c),"explicit replay offset accepted");
   uint ready=ICTRequiredEvidence(c)|ICT_E_FVG;
   Check(ICTPlanPriority(80,0,true,true,1,ready,c)==ICT_PRIORITY_BUY,"BUY valid plan");
   Check(ICTPlanPriority(0,80,true,true,-1,ready,c)==ICT_PRIORITY_SELL,"SELL valid plan");
   Check(ICTPlanPriority(100,0,true,false,1,ready,c)==ICT_PRIORITY_WAIT,"missing data veto");
   Check(ICTPlanPriority(100,0,false,true,1,ready,c)==ICT_PRIORITY_WAIT,"risk/SL/RR/spread gate veto");
   Check(ICTPlanPriority(0,100,true,true,1,ready,c)==ICT_PRIORITY_WAIT,"opposite plan veto");
   Check(ICTPlanPriority(100,0,true,true,1,ready & ~ICT_E_MSS,c)==ICT_PRIORITY_WAIT,"missing MSS veto");
   Check(ICTPlanPriority(100,0,true,true,1,ready & ~ICT_E_FVG,c)==ICT_PRIORITY_WAIT,"no active zone veto");
   c.mandatory_smt=true;
   Check(ICTPlanPriority(100,0,true,true,1,ready,c)==ICT_PRIORITY_WAIT,"mandatory missing SMT veto");
   c.mandatory_smt=false; c.entry_zone_mode=ICT_ZONE_OB_ONLY;
   Check(ICTPlanPriority(80,0,true,true,1,ready,c)==ICT_PRIORITY_WAIT,"OB-only cannot use FVG");
   Check(ICTPlanPriority(80,0,true,true,1,(ready & ~ICT_E_FVG)|ICT_E_OB,c)==ICT_PRIORITY_BUY,"OB-only ready");
   Check(ICTContextConflict(-1,1,1,0,false),"daily conflict veto");
   Check(ICTContextConflict(1,1,-1,0,false),"HTF LTF conflict veto");
   Check(!ICTContextConflict(1,1,-1,1,true),"aligned MSS resolves LTF reversal");
   double tp1=0,tp2=0; string n1="",n2="";
   ICTRankTarget(1,100,130,"far",tp1,n1,tp2,n2);
   ICTRankTarget(1,100,110,"near",tp1,n1,tp2,n2);
   ICTRankTarget(1,100,120,"middle",tp1,n1,tp2,n2);
   ICTRankTarget(1,100,110,"duplicate",tp1,n1,tp2,n2);
   ICTRankTarget(1,100,90,"wrong side",tp1,n1,tp2,n2);
   Check(tp1==110 && tp2==120 && n1=="near" && n2=="middle","rank distinct buy targets");
   tp1=0; tp2=0;
   ICTRankTarget(-1,100,70,"far",tp1,n1,tp2,n2);
   ICTRankTarget(-1,100,90,"near",tp1,n1,tp2,n2);
   Check(tp1==90 && tp2==70,"rank sell targets");
   MqlTick q;
   ZeroMemory(q); q.bid=100; q.ask=101; q.time=1000; q.time_msc=1000999;
   Check(ICTQuoteValidAt(q,1000,5),"same second milliseconds valid");
   Check(ICTQuoteValidAt(q,1005,5),"age boundary valid");
   Check(!ICTQuoteValidAt(q,1006,5),"stale rejected");
   Check(!ICTQuoteValidAt(q,999,5),"future rejected");
   q.ask=99;
   Check(!ICTQuoteValidAt(q,1000,5),"inverted quote rejected");
   q.ask=101; q.time_msc=1001000;
   Check(!ICTQuoteValidAt(q,1000,5),"future millisecond timestamp rejected");
   q.time_msc=0;
   Check(ICTQuoteValidAt(q,1000,5),"legacy missing milliseconds accepted");
   q.time=0;
   Check(!ICTQuoteValidAt(q,1000,5),"missing timestamp rejected");
   SICTDecision display; ZeroMemory(display);
   Check(ICTSmartEvidence(display,ICT_E_FVG,false)=="DATA UNAVAILABLE","dashboard hides missing data");
   display.data_quality_ok=true; display.buy_confirmed=ICT_E_FVG; display.sell_confirmed=ICT_E_FVG;
   Check(ICTSmartEvidence(display,ICT_E_FVG,false)=="BUY / SELL CONFIRMED","dashboard distinguishes both sides");
   display.direction=-1; display.confirmed=ICT_E_SWEEP;
   Check(ICTSmartEvidence(display,ICT_E_SWEEP,true)=="SELL CONFIRMED","range evidence shows its own direction");
   Check(ICTSmartEvidence(display,ICT_E_FVG,true)=="NOT CONFIRMED","range absent evidence is not invented");
   Check(ICTSmartSMTSlotText("GBPUSD",false,true)=="AUTO: GBPUSD","dashboard shows auto-selected SMT");
   Check(ICTSmartSMTSlotText("",false,true)=="AUTO: WAIT DATA","dashboard shows missing auto candidate");
   Check(ICTSmartSMTSlotText("DXY",true,true)=="MANUAL: DXY","dashboard shows manual override");
   Check(ICTSmartSMTSlotText("",false,false)=="OFF","dashboard shows disabled SMT");
   Check(ICTSmartTimeframe(PERIOD_H1)=="H1" && ICTSmartTimeframe(PERIOD_M5)=="M5",
         "chart and analysis timeframes use compact labels");
   Check(ICTSmartPanelHeight(16,true,true,true,true)==283,"dashboard height fits all visible rows");
   Check(ICTSmartPanelHeight(16,true,false,true,true)==187,"hidden ICT rows do not occupy space");
   Check(ICTSmartPanelHeight(16,false,false,false,false)==123,"empty groups omit unused plan and reason rows");
   SSMTDivergence smt; ZeroMemory(smt);
   smt.state=SRMP_SMT_BULLISH; smt.direction=1; smt.comparison="GBPUSD";
   smt.correlation=0.8; smt.correlation_pairs=80;
   smt.primary_prior_time=1000; smt.primary_pivot_time=2000;
   smt.pivot_confirmation_time=2200; smt.confirmation_time=2300;
   smt.primary_prior=1.20; smt.primary_recent=1.19;
   Check(SRMPSMTDisplayValid(smt,2300),"confirmed bullish low divergence can display");
   Check(!SRMPSMTDisplayValid(smt,2299),"SMT cannot appear before confirmation");
   smt.primary_recent=1.21;
   Check(!SRMPSMTDisplayValid(smt,2300),"bullish SMT must connect descending lows");
   smt.state=SRMP_SMT_BEARISH; smt.direction=-1;
   Check(SRMPSMTDisplayValid(smt,2300),"confirmed bearish high divergence can display");
   smt.state=SRMP_SMT_UNCONFIRMED;
   Check(!SRMPSMTDisplayValid(smt,2300),"unconfirmed SMT cannot display");
   string smt_one,smt_two;
   SRMPResolveSMTSlots("","",true,true,"GBPUSD","DXY",smt_one,smt_two);
   Check(smt_one=="GBPUSD" && smt_two=="DXY","two SMT automatic slots use distinct candidates");
   SRMPResolveSMTSlots("EURGBP","",false,true,"GBPUSD","DXY",smt_one,smt_two);
   Check(smt_one=="EURGBP" && smt_two=="GBPUSD","manual SMT overrides first slot");
   SRMPResolveSMTSlots("","",false,true,"GBPUSD","DXY",smt_one,smt_two);
   Check(smt_one=="" && smt_two=="GBPUSD","SMT slots may be disabled independently");
   SRMPResolveSMTSlots("","",true,true,"GBPUSD","",smt_one,smt_two);
   Check(smt_one=="GBPUSD" && smt_two=="","missing second candidate stays empty");
   SPositionPlanValidation plan; ZeroMemory(plan);
   plan.direction=1; plan.opened_at=1000; plan.now=1005; plan.plan_revision=999;
   plan.plan_published=1000; plan.quote_time=1005;
   plan.max_position_age=120; plan.max_plan_age=10; plan.max_quote_age=10; plan.max_entry_deviation_points=10;
   plan.entry=100; plan.planned_entry=100; plan.sl=98; plan.tp=104;
   plan.bid=100; plan.ask=100.1; plan.point=0.1; plan.tick=0.1;
   string plan_reason;
   Check(SRMPValidatePositionPlan(plan,plan_reason),"new buy position accepts matching prior plan");
   plan.existing_sl=99;
   Check(!SRMPValidatePositionPlan(plan,plan_reason),"existing SL is never overwritten");
   plan.existing_sl=0; plan.plan_revision=1001;
   Check(!SRMPValidatePositionPlan(plan,plan_reason),"plan changed after entry is rejected");
   plan.plan_revision=999; plan.quote_time=994;
   Check(!SRMPValidatePositionPlan(plan,plan_reason),"stale quote rejected for SLTP");
   plan.quote_time=1005; plan.sl=100.1;
   Check(!SRMPValidatePositionPlan(plan,plan_reason),"wrong-side SL rejected");
   plan.direction=-1; plan.sl=102; plan.tp=96;
   Check(SRMPValidatePositionPlan(plan,plan_reason),"matching sell position and plan accepted");
   plan.existing_tp=95;
   Check(!SRMPValidatePositionPlan(plan,plan_reason),"existing TP is never overwritten");
   plan.existing_tp=0; plan.planned_entry=102;
   Check(!SRMPValidatePositionPlan(plan,plan_reason),"entry too far from plan rejected");
   plan.planned_entry=100; plan.freeze_points=25;
   Check(!SRMPValidatePositionPlan(plan,plan_reason),"broker freeze distance enforced");
   Check(SRMPValidatePositionPlanRisk(-10,25,1,1000,2,2,plan_reason),"actual volume risk and net RR accepted");
   Check(!SRMPValidatePositionPlanRisk(-10,20,1,1000,2,2,plan_reason),"net RR below two rejected");
   Check(!SRMPValidatePositionPlanRisk(-21,50,0,1000,2,2,plan_reason),"position loss above cap rejected");
   SICTDecision executable; ZeroMemory(executable);
   executable.symbol=_Symbol; executable.direction=1; executable.state=ICT_ENTRY_READY;
   executable.data_quality_ok=true; executable.hard_filters_passed=true;
   executable.entry_confirmed=true; executable.risk.valid=true;
   executable.entry=100; executable.stop=98; executable.target=104;
   SSmartSLTPPlan saved; ZeroMemory(saved);
   saved.valid=true; saved.direction=1; saved.entry=100; saved.sl=98; saved.tp=104;
   saved.published=1000;
   Check(SmartSLTPDealTimingValid(saved,1,900,1001,15),"prior confirmed plan accepted for new deal");
   Check(!SmartSLTPDealTimingValid(saved,1,900,1000,15),"same-second plan cannot be proven prior");
   Check(!SmartSLTPDealTimingValid(saved,1,900,1016,15),"stale plan rejected for new deal");
   Check(!SmartSLTPDealTimingValid(saved,-1,900,1001,15),"opposite direction rejected");
   Check(SmartSLTPDecisionReady(executable) && SmartSLTPPlanMatches(saved,executable),
         "SLTP requires a matching confirmed decision");
   executable.stop=97;
   Check(!SmartSLTPPlanMatches(saved,executable),"changed stop invalidates saved SLTP plan");
   executable.stop=98; executable.risk.valid=false;
   Check(!SmartSLTPPlanMatches(saved,executable),"invalid risk blocks SLTP plan");
   executable.risk.valid=true; executable.symbol="__OTHER__";
   Check(!SmartSLTPDecisionReady(executable),"different symbol blocks SLTP plan");
   if(MQLInfoInteger(MQL_TESTER)!=0)
     {
      SICTDecision snapshot; ZeroMemory(snapshot);
      snapshot.state=ICT_ENTRY_READY; snapshot.direction=1;
      snapshot.buy_score=83; snapshot.entry=1.25; snapshot.stop=1.24;
      snapshot.target=1.27; snapshot.entry_confirmed=true;
      snapshot.reason="fixture reason";
      ICTPublishDecision(_Symbol,snapshot);
      Check(GlobalVariableGet(SRMPAdviceKey(_Symbol,"DTS"))>0 &&
            GlobalVariableGet(SRMPAdviceKey(_Symbol,"DSTATE"))==ICT_ENTRY_READY &&
            GlobalVariableGet(SRMPAdviceKey(_Symbol,"DBUY"))==83 &&
            GlobalVariableGet(SRMPAdviceKey(_Symbol,"DE"))==1.25 &&
            SRMPReadAdviceText(_Symbol,"DWHY")=="fixture reason",
            "decision bridge publishes a complete snapshot");
      GlobalVariableSet(SRMPAdviceKey(_Symbol,"DTS"),0);
     }
   PrintFormat("ICTDecisionTests: assertions=%d failures=%d",assertions,failures);
   return INIT_SUCCEEDED;
  }

double OnTester()
  {
   PrintFormat("ICTDecisionTests RESULT assertions=%d failures=%d",assertions,failures);
   return (double)failures;
  }
