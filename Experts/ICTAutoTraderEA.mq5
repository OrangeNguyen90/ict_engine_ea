#property strict
#property version "1.30"
#property description "Experimental ICT automatic entry; requires separate account protection EA."

#include "../Include/TradeAdvisor.mqh"
#include "../Include/ICTDecisionEngine.mqh"

input bool Enable_Auto_Entry=false;
input bool Tester_Simulated_Protection=true; // Tester only: initial deposit reference, SL/TP; no emergency controller.
input bool Enable_Diagnostics=true;
input bool Require_Latest_H1_BOS=false; // Only the legacy latest-bar BOS gate is relaxed.
input int Minimum_Decision_Evidence_Score=50;
input bool Allow_Real_Account=false;
input long Confirm_Real_Account=0;
input ulong Magic_Number=73112026;
input ENUM_TIMEFRAMES Context_Timeframe=PERIOD_H4;
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H1;
input ENUM_TIMEFRAMES Setup_Timeframe=PERIOD_M15;
input ENUM_TIMEFRAMES Trigger_Timeframe=PERIOD_M5;
input double Risk_Percent=1.0;
input double Max_Risk_Percent=2.0;
input double Minimum_RR=2.0;
input double Max_Spread_Points=30.0;
input double Commission_Per_Lot=0.0;
input double Cost_Buffer_Per_Lot=10.0;
input int Max_Entry_Deviation_Points=2;
input double Stop_Slippage_Points=2.0;
input int Max_Quote_Age_Seconds=10;

int g_lock=INVALID_HANDLE;
string g_state_file;
datetime g_last_signal=0;
double g_tester_reference=0;
string g_last_status="";
datetime g_last_status_time=0;

bool SimulatedProtection()
  { return MQLInfoInteger(MQL_TESTER)!=0 && Tester_Simulated_Protection; }

void ReportStatus(const string status)
  {
   if(!Enable_Diagnostics) return;
   Comment("ICTAutoTraderEA\n",status);
   datetime now=TimeCurrent();
   // One diagnostic per minute at most, but show every change on the chart.
   if(status==g_last_status && now-g_last_status_time<300) return;
   if(g_last_status_time>0 && now-g_last_status_time<60) return;
   Print("ICT auto: ",status);
   g_last_status=status;
   g_last_status_time=now;
  }

uint SymbolHash(const string value)
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(value);i++)
      hash=(hash^(uint)StringGetCharacter(value,i))*16777619;
   return hash;
  }

bool ProtectionReady(double &reference)
  {
   if(SimulatedProtection())
     {
      reference=g_tester_reference;
      return MathIsValidNumber(reference) && reference>0;
     }
   string names[]={"HB","STATE","HEALTH","AUTO","REF"};
   for(int i=0;i<ArraySize(names);i++)
      if(!GlobalVariableCheck(SRMPGlobalKey(names[i]))) return false;
   datetime heartbeat=(datetime)GlobalVariableGet(SRMPGlobalKey("HB"));
   datetime now=TimeLocal();
   reference=GlobalVariableGet(SRMPGlobalKey("REF"));
   return heartbeat>0 && heartbeat<=now && now-heartbeat<=3 &&
          GlobalVariableGet(SRMPGlobalKey("STATE"))==SRMP_NORMAL &&
          GlobalVariableGet(SRMPGlobalKey("HEALTH"))==0 &&
          GlobalVariableGet(SRMPGlobalKey("AUTO"))>=0.5 &&
          MathIsValidNumber(reference) && reference>0;
  }

// A separate common file per account and symbol survives terminal restarts.
// It is written before sending: uncertain/rejected sends are never retried.
bool RecordSignal(const datetime bar)
  {
   // A tester pass must not consume signals in subsequent passes.
   if(MQLInfoInteger(MQL_TESTER)!=0) { g_last_signal=bar; return true; }
   int f=FileOpen(g_state_file,FILE_WRITE|FILE_CSV|FILE_ANSI|SRMPFileScope(),';');
   if(f==INVALID_HANDLE) return false;
   bool ok=FileWrite(f,"ICTAUTO1",IntegerToString((long)bar))>0;
   FileFlush(f);
   FileClose(f);
   if(ok) g_last_signal=bar;
   return ok;
  }

bool LoadSignal()
  {
   if(MQLInfoInteger(MQL_TESTER)!=0) { g_last_signal=0; return true; }
   int scope=SRMPFileScope();
   if(!FileIsExist(g_state_file,scope)) return true;
   int f=FileOpen(g_state_file,FILE_READ|FILE_CSV|FILE_ANSI|scope,';');
   if(f==INVALID_HANDLE) return false;
   string version=FileReadString(f), value=FileReadString(f);
   FileClose(f);
   long bar=StringToInteger(value);
   if(version!="ICTAUTO1" || bar<=0) return false;
   g_last_signal=(datetime)bar;
   return true;
  }

int OnInit()
  {
   g_last_signal=0;
   g_tester_reference=AccountInfoDouble(ACCOUNT_BALANCE);
   g_last_status="";
   g_last_status_time=0;
   if(Magic_Number==0 || !MathIsValidNumber(Risk_Percent) || !MathIsValidNumber(Max_Risk_Percent) ||
      !MathIsValidNumber(Minimum_RR) || !MathIsValidNumber(Max_Spread_Points) ||
      !MathIsValidNumber(Commission_Per_Lot) || !MathIsValidNumber(Cost_Buffer_Per_Lot) ||
      !MathIsValidNumber(Stop_Slippage_Points) || Risk_Percent<=0 || Risk_Percent>Max_Risk_Percent ||
      Max_Risk_Percent>2 || Minimum_RR<2 || Max_Spread_Points<=0 ||
      Commission_Per_Lot<0 || Cost_Buffer_Per_Lot<0 || Stop_Slippage_Points<0 ||
      Max_Entry_Deviation_Points<0 || Max_Quote_Age_Seconds<1 ||
      Minimum_Decision_Evidence_Score<0 || Minimum_Decision_Evidence_Score>100)
      return INIT_PARAMETERS_INCORRECT;
   string stem=SRMPAccountStem();
   g_lock=FileOpen(stem+".autotrader.lock",FILE_READ|FILE_WRITE|FILE_BIN|SRMPFileScope());
   if(g_lock==INVALID_HANDLE) { Print("Another auto trader holds the account lock"); return INIT_FAILED; }
   g_state_file=stem+".autotrader."+IntegerToString((long)SymbolHash(_Symbol))+".csv";
   if(!LoadSignal()) { Print("Invalid auto trader signal state; entry disabled"); FileClose(g_lock); g_lock=INVALID_HANDLE; return INIT_FAILED; }
   if(MQLInfoInteger(MQL_TESTER)==0) EventSetTimer(2);
   PrintFormat("ICT auto initialized: tester=%d simulated_protection=%d auto_entry=%d reference=%.2f",
               (int)MQLInfoInteger(MQL_TESTER),(int)SimulatedProtection(),(int)Enable_Auto_Entry,g_tester_reference);
   if(SimulatedProtection()) Print("TESTER ONLY: protection heartbeat simulated; no account-wide emergency closes. SL/TP and numeric risk gates remain active.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_lock!=INVALID_HANDLE) FileClose(g_lock);
   if(Enable_Diagnostics) Comment("");
  }

void EvaluateEntry();

void OnTick()
  {
   // Historical timers can run between generated ticks with stale quotes.
   if(MQLInfoInteger(MQL_TESTER)!=0) EvaluateEntry();
  }

void OnTimer()
  {
   if(MQLInfoInteger(MQL_TESTER)==0) EvaluateEntry();
  }

void EvaluateEntry()
  {
   double reference=0;
   if(!ProtectionReady(reference))
     { ReportStatus("BLOCKED: protection offline, unhealthy or locked (Tester: enable Tester_Simulated_Protection)"); return; }
   STradeAdvice a;
   bool analyzed=SRMPAnalyzeAdvice(_Symbol,Context_Timeframe,Structure_Timeframe,Setup_Timeframe,Trigger_Timeframe,
                         reference,Risk_Percent,Max_Risk_Percent,Minimum_RR,Max_Spread_Points,
                         Commission_Per_Lot,Cost_Buffer_Per_Lot,Stop_Slippage_Points,Max_Quote_Age_Seconds,a,
                         SimulatedProtection(),Require_Latest_H1_BOS);
   string status=StringFormat("%s: %s | Auto entry %s",a.status==SRMP_TRADE_READY ? "TRADE READY" :
                             (a.status==SRMP_WAIT ? "WAIT" : "NO TRADE"),a.reasons,Enable_Auto_Entry ? "ON" : "OFF");
   ReportStatus(status);
   // Analysis remains visible even when automatic execution is disabled.
   if(!analyzed || a.status!=SRMP_TRADE_READY || !a.risk.valid) return;
   if(!Enable_Auto_Entry) return;
   // Reuse DecisionSupport evidence, without treating its score as a full
   // ENTRY READY decision. All original advisory and execution risk gates remain.
   SICTDecisionConfig cfg={};
   cfg.higher_tf=Context_Timeframe; cfg.structure_tf=Structure_Timeframe;
   cfg.setup_tf=Setup_Timeframe; cfg.trigger_tf=Trigger_Timeframe; cfg.smt_tf=PERIOD_H1;
   cfg.lookback=120; cfg.swing_strength=2; cfg.max_setup_bars=48;
   cfg.displacement_body_atr=1.0; cfg.displacement_body_fraction=0.60; cfg.min_gap_atr=0.05;
   SICTConfluenceConfig scoring; ICTDefaultConfluenceConfig(scoring);
   bool quality=false;
   uint evidence=ICTCollectEvidence(_Symbol,cfg,scoring,a.direction,quality);
   int evidence_score=ICTWeightedScore(evidence,scoring);
   if(!quality || evidence_score<Minimum_Decision_Evidence_Score)
     { ReportStatus(StringFormat("BLOCKED: DecisionSupport evidence score=%d minimum=%d quality=%d",evidence_score,Minimum_Decision_Evidence_Score,(int)quality)); return; }
   if((MQLInfoInteger(MQL_TESTER)==0 && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL &&
      (!Allow_Real_Account || Confirm_Real_Account!=AccountInfoInteger(ACCOUNT_LOGIN))) ||
      (MQLInfoInteger(MQL_TESTER)==0 && !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     { ReportStatus("BLOCKED: trading permission or real-account confirmation"); return; }
   // Avoid netting/hedging interference and exposure stacking across the account.
   if(PositionsTotal()>0 || OrdersTotal()>0) { ReportStatus("BLOCKED: existing account exposure"); return; }
   if(a.signal_bar<=g_last_signal) { ReportStatus("BLOCKED: signal already attempted"); return; }
   MqlTick q;
   if(!SymbolInfoTick(_Symbol,q) || q.bid<=0 || q.ask<q.bid)
     { ReportStatus("BLOCKED: invalid current quote"); return; }
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(point<=0 || tick<=0 || (q.ask-q.bid)/point>Max_Spread_Points)
     { ReportStatus("BLOCKED: tick specification or spread"); return; }
   bool buy=a.direction==1;
   if(!buy && a.direction!=-1) { ReportStatus("BLOCKED: invalid signal direction"); return; }
   double price=buy?q.ask:q.bid;
   if(price<a.zone_low || price>a.zone_high) { ReportStatus("BLOCKED: price left FVG entry zone"); return; }
   double market=buy?q.bid:q.ask;
   double gap=MathMax((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                      (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*point;
   if((buy && (a.stop_loss>=market-gap || a.take_profit<=market+gap)) ||
      (!buy && (a.stop_loss<=market+gap || a.take_profit>=market-gap)))
     { ReportStatus("BLOCKED: SL/TP inside broker stop/freeze distance"); return; }
   // Reserve for adverse entry deviation; actual execution can exceed it.
   double adverse=price+(buy?1:-1)*Max_Entry_Deviation_Points*point;
   adverse=NormalizeDouble((buy?MathCeil(adverse/tick):MathFloor(adverse/tick))*tick,digits);
   SRiskResult risk;
   if(!CalculateRisk(_Symbol,buy?RM_BUY:RM_SELL,adverse,a.stop_loss,a.take_profit,
                     reference,Risk_Percent,Max_Risk_Percent,Minimum_RR,Commission_Per_Lot,
                     Cost_Buffer_Per_Lot,Stop_Slippage_Points,Max_Quote_Age_Seconds,risk))
     { ReportStatus("BLOCKED: adverse-entry risk gate: "+risk.reason); return; }
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
   if((mode & SYMBOL_ORDER_MARKET)==0 || (mode & SYMBOL_ORDER_SL)==0 || (mode & SYMBOL_ORDER_TP)==0)
     { ReportStatus("BLOCKED: symbol does not support market orders with SL/TP"); return; }
   MqlTradeRequest req={}; MqlTradeCheckResult check={}; MqlTradeResult result={};
   req.action=TRADE_ACTION_DEAL; req.symbol=_Symbol; req.magic=Magic_Number;
   req.type=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL; req.volume=risk.volume;
   req.price=price; req.sl=a.stop_loss; req.tp=a.take_profit;
   req.deviation=(ulong)Max_Entry_Deviation_Points; req.type_time=ORDER_TIME_GTC;
   long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK)!=0) req.type_filling=ORDER_FILLING_FOK;
   else if((filling & SYMBOL_FILLING_IOC)!=0) req.type_filling=ORDER_FILLING_IOC;
   else if(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_EXEMODE)!=SYMBOL_TRADE_EXECUTION_MARKET) req.type_filling=ORDER_FILLING_RETURN;
   else { Print("No supported filling mode"); return; }
   req.comment="ICT auto";
   if(!OrderCheck(req,check) || check.retcode!=0) { PrintFormat("Entry check rejected: %u %s",check.retcode,check.comment); return; }
   double checked_reference=0;
   if(!ProtectionReady(checked_reference) || checked_reference!=reference || PositionsTotal()>0 || OrdersTotal()>0)
     { ReportStatus("BLOCKED: protection/reference/exposure changed before send"); return; }
   if(!RecordSignal(a.signal_bar)) { Print("Cannot persist signal: entry blocked"); return; }
   bool sent=OrderSend(req,result);
   PrintFormat("ICT entry send=%d retcode=%u order=%I64u deal=%I64u comment=%s",sent,result.retcode,result.order,result.deal,result.comment);
  }
