#ifndef ICT_SMART_AUTO_POSITION_SLTP_MQH
#define ICT_SMART_AUTO_POSITION_SLTP_MQH

#include "ICTDecisionEngine.mqh"
#include "PositionPlanValidation.mqh"

input group "Smart Decision: automatic SL / TP"
input bool Auto_SLTP_Enable=false; // Explicitly opt in; never opens a position.
input bool Auto_SLTP_Allow_Real_Account=false;
input long Auto_SLTP_Confirm_Real_Account=0;
input int Auto_SLTP_Max_Entry_Deviation_Points=50;
input int Auto_SLTP_Max_Plan_Age_Seconds=15;
input int Auto_SLTP_Max_Position_Age_Seconds=120;
input int Auto_SLTP_Max_Quote_Age_Seconds=10;
input group "ICT analysis and dashboard"

struct SSmartSLTPPlan
  {
   bool valid;
   int direction;
   double entry,sl,tp;
   datetime first_seen,published;
  };
struct SSmartSLTPPending
  {
   ulong deal,position_id;
   datetime opened;
   SSmartSLTPPlan plan;
  };
SSmartSLTPPlan g_smart_sltp_plan;
SSmartSLTPPending g_smart_sltp_pending[16];
datetime g_smart_sltp_started=0;
string g_smart_sltp_account="";
int g_smart_sltp_lock=INVALID_HANDLE;

bool SmartSLTPDecisionReady(const SICTDecision &d)
  {
   return d.symbol==_Symbol && d.data_quality_ok && d.state==ICT_ENTRY_READY &&
          d.hard_filters_passed && d.entry_confirmed && d.risk.valid &&
          (d.direction==1 || d.direction==-1) && d.entry>0 && d.stop>0 && d.target>0;
  }

bool SmartSLTPPlanMatches(const SSmartSLTPPlan &p,const SICTDecision &d)
  {
   return p.valid && SmartSLTPDecisionReady(d) && p.direction==d.direction &&
          p.sl==d.stop && p.tp==d.target;
  }

bool SmartSLTPDealTimingValid(const SSmartSLTPPlan &p,const int direction,
                              const datetime started,const datetime opened,const int max_age)
  {
   return p.valid && direction==p.direction && opened>started && p.published>0 &&
          p.published<opened && max_age>0 && opened-p.published<=max_age;
  }

int SmartSLTPInit()
  {
   ZeroMemory(g_smart_sltp_plan);
   for(int i=0;i<ArraySize(g_smart_sltp_pending);i++) ZeroMemory(g_smart_sltp_pending[i]);
   g_smart_sltp_account=SRMPAccountStem();
   g_smart_sltp_started=TimeTradeServer();
   if(Auto_SLTP_Max_Entry_Deviation_Points<0 || Auto_SLTP_Max_Plan_Age_Seconds<1 ||
      Auto_SLTP_Max_Position_Age_Seconds<1 || Auto_SLTP_Max_Quote_Age_Seconds<1)
      return INIT_PARAMETERS_INCORRECT;
   if(Auto_SLTP_Enable && MQLInfoInteger(MQL_TESTER)==0 &&
      AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL &&
      (!Auto_SLTP_Allow_Real_Account || Auto_SLTP_Confirm_Real_Account!=AccountInfoInteger(ACCOUNT_LOGIN)))
     { Print("Smart SLTP: real account requires explicit account confirmation"); return INIT_PARAMETERS_INCORRECT; }
   if(Auto_SLTP_Enable)
     {
      uint hash=2166136261;
      for(int i=0;i<StringLen(_Symbol);i++) hash=(hash^(uint)StringGetCharacter(_Symbol,i))*16777619;
      string lock=SRMPAccountStem()+".smart_sltp."+IntegerToString((long)hash)+".lock";
      g_smart_sltp_lock=FileOpen(lock,FILE_READ|FILE_WRITE|FILE_BIN|SRMPFileScope());
      if(g_smart_sltp_lock==INVALID_HANDLE)
        { Print("Smart SLTP: another instance holds the account/symbol lock"); return INIT_FAILED; }
     }
   Print("Smart SLTP: ",Auto_SLTP_Enable ? "enabled" : "disabled", "; new same-symbol positions, no existing SL/TP; no position opening.");
   return INIT_SUCCEEDED;
  }

void SmartSLTPDeinit()
  {
   if(g_smart_sltp_lock!=INVALID_HANDLE) FileClose(g_smart_sltp_lock);
   g_smart_sltp_lock=INVALID_HANDLE;
  }

// Track the exact plan before a deal arrives. A changed entry, direction, SL or
// TP starts a new revision; no hypothetical future plan can be applied.
void SmartSLTPObserveDecision(const SICTDecision &d)
  {
   if(!Auto_SLTP_Enable || !SmartSLTPDecisionReady(d) || SRMPAccountStem()!=g_smart_sltp_account)
     { g_smart_sltp_plan.valid=false; return; }
   datetime now=TimeTradeServer();
   if(now<=0) { g_smart_sltp_plan.valid=false; return; }
   if(!g_smart_sltp_plan.valid || g_smart_sltp_plan.direction!=d.direction ||
      g_smart_sltp_plan.entry!=d.entry || g_smart_sltp_plan.sl!=d.stop || g_smart_sltp_plan.tp!=d.target)
      g_smart_sltp_plan.first_seen=now;
   g_smart_sltp_plan.valid=true;
   g_smart_sltp_plan.direction=d.direction;
   g_smart_sltp_plan.entry=d.entry; g_smart_sltp_plan.sl=d.stop; g_smart_sltp_plan.tp=d.target;
   g_smart_sltp_plan.published=now;
  }

// Queue only entry deals received while the EA is active. In particular, do
// not scan older unprotected positions on startup or after a restart.
void SmartSLTPOnTrade(const MqlTradeTransaction &trans)
  {
   if(!Auto_SLTP_Enable || trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0 ||
      SRMPAccountStem()!=g_smart_sltp_account ||
      !HistoryDealSelect(trans.deal) || HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol ||
      HistoryDealGetInteger(trans.deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) return;
   ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal,DEAL_TYPE);
   int direction=(type==DEAL_TYPE_BUY ? 1 : type==DEAL_TYPE_SELL ? -1 : 0);
   ulong identifier=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
   datetime opened=(datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME);
   // Time fields have one-second resolution: equal timestamps cannot prove
   // the plan was observed before the fill, so fail closed.
   if(identifier==0 || !SmartSLTPDealTimingValid(g_smart_sltp_plan,direction,
                                  g_smart_sltp_started,opened,Auto_SLTP_Max_Plan_Age_Seconds))
     { PrintFormat("Smart SLTP: deal %I64u skipped: no matching plan observed before fill",trans.deal); return; }
   for(int i=0;i<ArraySize(g_smart_sltp_pending);i++)
     {
      if(g_smart_sltp_pending[i].deal==trans.deal) return;
      if(g_smart_sltp_pending[i].deal==0)
        {
         g_smart_sltp_pending[i].deal=trans.deal;
         g_smart_sltp_pending[i].position_id=identifier;
         g_smart_sltp_pending[i].opened=opened;
         g_smart_sltp_pending[i].plan=g_smart_sltp_plan;
         return;
        }
     }
   Print("Smart SLTP: pending queue full; no stops were modified for this deal");
  }

bool SmartSLTPSingleEntry(const ulong identifier,const ulong expected_deal)
  {
   if(!HistorySelectByPosition(identifier)) return false;
   int entries=0;
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0) return false;
      ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(deal,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      if(HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN || deal!=expected_deal) return false;
      entries++;
     }
   return entries==1;
  }

void SmartSLTPProcess(const SICTDecision &current,const double max_risk,const double min_rr,
                       const double cost_per_lot,const double slippage_points)
  {
   if(!Auto_SLTP_Enable) return;
   for(int i=0;i<ArraySize(g_smart_sltp_pending);i++)
     {
      if(g_smart_sltp_pending[i].deal==0) continue;
      SSmartSLTPPending item=g_smart_sltp_pending[i];
      datetime now=TimeTradeServer();
      if(now<=0 || now<item.opened || now-item.opened>Auto_SLTP_Max_Plan_Age_Seconds ||
         SRMPAccountStem()!=g_smart_sltp_account)
        { PrintFormat("Smart SLTP: deal %I64u expired or account changed",item.deal); ZeroMemory(g_smart_sltp_pending[i]); continue; }
      ulong ticket=0;
      for(int n=PositionsTotal()-1;n>=0;n--)
        {
         ulong candidate=PositionGetTicket(n);
         if(candidate>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
            (ulong)PositionGetInteger(POSITION_IDENTIFIER)==item.position_id) { ticket=candidate; break; }
        }
      if(ticket==0) continue; // Position may not yet be visible after DEAL_ADD.
      ZeroMemory(g_smart_sltp_pending[i]); // Never retry the same event automatically.
      string key=SRMPGlobalKey("SLTP_"+IntegerToString((long)item.position_id));
      if(MQLInfoInteger(MQL_TESTER)==0 && GlobalVariableCheck(key)) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetDouble(POSITION_SL)>0 || PositionGetDouble(POSITION_TP)>0)
        { PrintFormat("Smart SLTP: ticket %I64u already has SL or TP; preserved",ticket); continue; }
      double reference=0;
      if(!SmartSLTPPlanMatches(item.plan,current) || !ICTProtectionReady(reference) ||
         !TerminalInfoInteger(TERMINAL_CONNECTED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
         !MQLInfoInteger(MQL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
         !AccountInfoInteger(ACCOUNT_TRADE_EXPERT) || !SmartSLTPSingleEntry(item.position_id,item.deal) ||
         !PositionSelectByTicket(ticket))
        { PrintFormat("Smart SLTP: ticket %I64u blocked: plan/protection/permission/history",ticket); continue; }
      int direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1);
      MqlTick quote; SPositionPlanValidation v; ZeroMemory(v);
      if(!SymbolInfoTick(_Symbol,quote)) { Print("Smart SLTP: quote unavailable"); continue; }
      v.direction=direction; v.opened_at=(datetime)PositionGetInteger(POSITION_TIME); v.now=now;
      v.plan_revision=item.plan.first_seen; v.plan_published=item.plan.published; v.quote_time=quote.time;
      v.max_position_age=Auto_SLTP_Max_Position_Age_Seconds; v.max_plan_age=Auto_SLTP_Max_Plan_Age_Seconds;
      v.max_quote_age=Auto_SLTP_Max_Quote_Age_Seconds; v.max_entry_deviation_points=Auto_SLTP_Max_Entry_Deviation_Points;
      v.entry=PositionGetDouble(POSITION_PRICE_OPEN); v.planned_entry=item.plan.entry;
      v.sl=item.plan.sl; v.tp=item.plan.tp; v.existing_sl=PositionGetDouble(POSITION_SL); v.existing_tp=PositionGetDouble(POSITION_TP);
      v.bid=quote.bid; v.ask=quote.ask; v.point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
      v.tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      v.stops_points=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
      v.freeze_points=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
      long mode=SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
      string reason="";
      if(direction!=item.plan.direction || (mode & SYMBOL_ORDER_SL)==0 || (mode & SYMBOL_ORDER_TP)==0 ||
         !SRMPValidatePositionPlan(v,reason))
        { PrintFormat("Smart SLTP: ticket %I64u blocked: %s",ticket,reason); continue; }
      double volume=PositionGetDouble(POSITION_VOLUME),loss=0,reward=0;
      ENUM_ORDER_TYPE side=(direction>0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      double adverse=item.plan.sl-direction*slippage_points*v.point;
      if(volume<=0 || adverse<=0 || !OrderCalcProfit(side,_Symbol,volume,v.entry,adverse,loss) ||
         !OrderCalcProfit(side,_Symbol,volume,v.entry,item.plan.tp,reward) ||
         !SRMPValidatePositionPlanRisk(loss,reward,cost_per_lot*volume,
            ICTConservativeRiskCapital(reference,AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_EQUITY)),max_risk,min_rr,reason))
        { PrintFormat("Smart SLTP: ticket %I64u blocked: risk %s",ticket,reason); continue; }
      MqlTradeRequest req={}; MqlTradeCheckResult check={}; MqlTradeResult result={};
      req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=_Symbol; req.sl=item.plan.sl; req.tp=item.plan.tp;
      if(!OrderCheck(req,check) || check.retcode!=0)
        { PrintFormat("Smart SLTP: ticket %I64u order check %u %s",ticket,check.retcode,check.comment); continue; }
      double check_reference=0;
      if(!ICTProtectionReady(check_reference) || check_reference!=reference || !PositionSelectByTicket(ticket) ||
         (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=item.position_id || PositionGetDouble(POSITION_SL)>0 ||
         PositionGetDouble(POSITION_TP)>0 || PositionGetDouble(POSITION_VOLUME)!=volume ||
         PositionGetDouble(POSITION_PRICE_OPEN)!=v.entry)
        { PrintFormat("Smart SLTP: ticket %I64u changed before send",ticket); continue; }
      if(MQLInfoInteger(MQL_TESTER)==0 && GlobalVariableSet(key,(double)now)==0)
        { Print("Smart SLTP: cannot persist attempt; request blocked"); continue; }
      if(MQLInfoInteger(MQL_TESTER)==0) GlobalVariablesFlush();
      bool sent=OrderSend(req,result);
      PrintFormat("Smart SLTP: ticket=%I64u send=%d retcode=%u SL=%.*f TP=%.*f %s",
                  ticket,(int)sent,result.retcode,_Digits,req.sl,_Digits,req.tp,result.comment);
     }
  }
#endif
