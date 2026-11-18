#property copyright "MT5 Smart Risk Manager Pro"
#property version "2.00"
#property description "Account-wide emergency protection. Attach to DEMO first."

#include "../Include/ProtectionPersistence.mqh"
#include "../Include/PositionMonitor.mqh"
#include "../Include/EmergencyController.mqh"

enum ENUM_SRMP_SCOPE { ALL_ACCOUNT_POSITIONS=0 };
enum ENUM_SRMP_ACTION { CLOSE_ALL_POSITIONS=0 };
enum ENUM_SRMP_REFERENCE { INITIAL_BALANCE=0 };

input double Emergency_Loss_Per_Position=3.0;
input ENUM_SRMP_SCOPE Protection_Scope=ALL_ACCOUNT_POSITIONS;
input ENUM_SRMP_ACTION Emergency_Action=CLOSE_ALL_POSITIONS;
input ENUM_SRMP_REFERENCE Reference_Capital_Mode=INITIAL_BALANCE;
input bool Enable_Auto_Protection=false;
input long Confirm_Protection_Account=0; // Enter this account's login to authorize account-wide closes.
input bool Enable_New_Trade_Execution=false;
input bool Enable_Alerts=true;
input bool Enable_Sound=false;
input bool Enable_Push=false;
input bool Enable_Trade_Lock=true;
input double Exit_Cost_Buffer_Per_Lot=10.0;       // Account currency
input double Missing_History_Buffer_Per_Lot=10.0; // Account currency
input int Max_Close_Attempts_Per_Ticket=5;
input int Retry_Delay_Seconds=3;
input int Close_Deviation_Points=50;

int g_controller_handle=INVALID_HANDLE;
SProtectionSnapshot g_snapshot;
CTrade g_trade;
int g_highest_alert_level=0;
datetime g_last_health_alert=0;
string g_last_health_message="";
bool g_state_loaded=false;
string g_account_stem="";

void NotifyRisk(const string message,const int level)
  {
   if(level<=g_highest_alert_level) return;
   g_highest_alert_level=level;
   Print(message);
   if(!Enable_Alerts) return;
   Alert(message);
   if(Enable_Sound) PlaySound("alert.wav");
   if(Enable_Push) SendNotification(message);
  }

void NotifyHealth(const string message)
  {
   if(message==g_last_health_message && TimeLocal()-g_last_health_alert<60) return;
   g_last_health_alert=TimeLocal();
   g_last_health_message=message;
   Print(message);
   if(Enable_Alerts) Alert(message);
  }

bool BecomeController()
  {
   if(g_controller_handle!=INVALID_HANDLE) return true;
   ResetLastError();
   g_controller_handle=FileOpen(SRMPLockFile(),FILE_READ|FILE_WRITE|FILE_BIN|
                                SRMPFileScope());
   if(g_controller_handle==INVALID_HANDLE) return false;

   if(FileIsExist(SRMPStateFile(),SRMPFileScope()))
     {
      if(!SRMPLoadSnapshot(g_snapshot))
        {
         Print("CRITICAL: persistent protection state invalid; refusing to reset reference");
         FileClose(g_controller_handle);
         g_controller_handle=INVALID_HANDLE;
         return false;
        }
      if(!FileIsExist(SRMPMarkerFile(),SRMPFileScope()) &&
         !SRMPMarkInitialized())
        {
         Print("CRITICAL: cannot create initial-balance marker");
         FileClose(g_controller_handle);
         g_controller_handle=INVALID_HANDLE;
         return false;
        }
     }
   else
     {
      if(FileIsExist(SRMPMarkerFile(),SRMPFileScope()))
        {
         Print("CRITICAL: saved reference file is missing; refusing automatic reinitialization");
         FileClose(g_controller_handle);
         g_controller_handle=INVALID_HANDLE;
         return false;
        }
      if(!SRMPMarkInitialized())
        {
         Print("CRITICAL: cannot create initial-balance marker");
         FileClose(g_controller_handle);
         g_controller_handle=INVALID_HANDLE;
         return false;
        }
      ZeroMemory(g_snapshot);
      g_snapshot.reference_capital=AccountInfoDouble(ACCOUNT_BALANCE);
      g_snapshot.state=SRMP_NORMAL;
      if(g_snapshot.reference_capital<=0.0 || !SRMPSaveSnapshot(g_snapshot))
        {
         Print("CRITICAL: cannot establish persistent initial balance");
         FileClose(g_controller_handle);
         g_controller_handle=INVALID_HANDLE;
         return false;
        }
      PrintFormat("Initial balance reference saved: %.2f %s",
                  g_snapshot.reference_capital,AccountInfoString(ACCOUNT_CURRENCY));
     }
   // Refresh dashboard globals from the authoritative file on every restart.
   if(!SRMPSaveSnapshot(g_snapshot))
     {
      FileClose(g_controller_handle);
      g_controller_handle=INVALID_HANDLE;
      return false;
     }
   g_state_loaded=true;
   PrintFormat("Protection controller active: account %I64d server %s reference %.2f state %s",
               AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_SERVER),
               g_snapshot.reference_capital,SRMPStateName(g_snapshot.state));
   return true;
  }

int OnInit()
  {
   if(Emergency_Loss_Per_Position<=0.0 || Exit_Cost_Buffer_Per_Lot<0.0 ||
      Missing_History_Buffer_Per_Lot<0.0 || Max_Close_Attempts_Per_Ticket<1 ||
      Retry_Delay_Seconds<1 || Close_Deviation_Points<0 ||
      Protection_Scope!=ALL_ACCOUNT_POSITIONS ||
      Emergency_Action!=CLOSE_ALL_POSITIONS ||
      Reference_Capital_Mode!=INITIAL_BALANCE ||
      (Enable_Auto_Protection &&
       Confirm_Protection_Account!=AccountInfoInteger(ACCOUNT_LOGIN)) ||
      Enable_New_Trade_Execution || !Enable_Trade_Lock)
      return INIT_PARAMETERS_INCORRECT;
   g_trade.SetAsyncMode(false);
   g_trade.SetDeviationInPoints((ulong)Close_Deviation_Points);
   g_account_stem=SRMPAccountStem();
   EventSetTimer(1);
   if(!BecomeController())
      Print("Protection EA is passive or state unavailable; another chart may be controller");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_controller_handle!=INVALID_HANDLE)
     {
      GlobalVariableSet(SRMPGlobalKey("HB"),0.0);
      GlobalVariableSet(SRMPGlobalKey("AUTO"),0.0);
      GlobalVariablesFlush();
      FileClose(g_controller_handle);
     }
   Print("Protection EA stopped; reason=",reason);
  }

void OnTimer()
  {
   if(SRMPAccountStem()!=g_account_stem)
     {
      NotifyHealth("CRITICAL: account identity changed; protection EA must restart");
      return;
     }
   if(!BecomeController() || !g_state_loaded) return;
   GlobalVariableSet(SRMPGlobalKey("HB"),(double)TimeLocal());
   GlobalVariableSet(SRMPGlobalKey("AUTO"),Enable_Auto_Protection ? 1.0 : 0.0);

   SPositionRisk worst;
   int positions=0,missing_history=0;
   bool scan_ok=SRMPWorstPosition(g_snapshot.reference_capital,
                         Exit_Cost_Buffer_Per_Lot,Missing_History_Buffer_Per_Lot,
                         worst,positions,missing_history);
   if(!scan_ok)
     {
      NotifyHealth("CRITICAL: position risk scan failed; protection status unknown");
      GlobalVariableSet(SRMPGlobalKey("HEALTH"),1.0);
      if(g_snapshot.state==SRMP_NORMAL) return;
     }
   if(missing_history>0)
      NotifyHealth("Position deal history unavailable; configured cost buffer used");
   GlobalVariableSet(SRMPGlobalKey("WORST"),worst.loss_percent);
   int level=SRMPWarningLevel(worst.loss_percent,Emergency_Loss_Per_Position);
   GlobalVariableSet(SRMPGlobalKey("LEVEL"),(double)level);
   if(level>0 && (level<4 || !Enable_Auto_Protection) &&
      g_snapshot.state==SRMP_NORMAL)
      NotifyRisk(StringFormat("Risk level %d: position #%I64u loss %.2f%% of initial balance",
                              level,worst.ticket,worst.loss_percent),level);

   if(g_snapshot.state==SRMP_NORMAL && level==4 && Enable_Auto_Protection)
     {
      SProtectionSnapshot before_trigger=g_snapshot;
      g_snapshot.state=SRMP_EMERGENCY;
      g_snapshot.trigger_ticket=worst.ticket;
      g_snapshot.trigger_time=TimeCurrent();
      g_snapshot.trigger_equity=AccountInfoDouble(ACCOUNT_EQUITY);
      if(!SRMPSaveSnapshot(g_snapshot))
        {
         g_snapshot=before_trigger;
         NotifyHealth("CRITICAL: emergency latch could not be persisted; close requests withheld");
         return;
        }
      PrintFormat("EMERGENCY trigger ticket #%I64u time %s equity %.2f reference %.2f loss %.2f%%",
                  g_snapshot.trigger_ticket,TimeToString(g_snapshot.trigger_time),
                  g_snapshot.trigger_equity,g_snapshot.reference_capital,worst.loss_percent);
      NotifyRisk("EMERGENCY_CLOSE_ALL: position loss threshold reached",4);
     }

   if(g_snapshot.state==SRMP_NORMAL)
     {
      GlobalVariableSet(SRMPGlobalKey("HEALTH"),
                        TerminalInfoInteger(TERMINAL_CONNECTED)==0 ? 2.0 : 0.0);
      if(TerminalInfoInteger(TERMINAL_CONNECTED)==0)
         NotifyHealth("Protection unavailable: terminal disconnected");
      return;
     }

   bool exhausted=false,had_failure=false;
   // A persisted lock is retained when disarmed, but it must not bypass the
   // separate execution input and explicit account confirmation.
   if(!Enable_Auto_Protection ||
      Confirm_Protection_Account!=AccountInfoInteger(ACCOUNT_LOGIN))
     {
      GlobalVariableSet(SRMPGlobalKey("HEALTH"),4.0);
      NotifyHealth("Emergency lock retained; account-wide closing is not armed");
      return;
     }
   bool operational=(TerminalInfoInteger(TERMINAL_CONNECTED)!=0 &&
                     TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0 &&
                     AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);
   bool completed=SRMPProcessEmergency(g_trade,Max_Close_Attempts_Per_Ticket,
                                       Retry_Delay_Seconds,Close_Deviation_Points,
                                       exhausted,had_failure);
   ENUM_SRMP_STATE desired=g_snapshot.state;
   if(completed) desired=SRMP_LOCKED;
   else if(exhausted || had_failure || g_snapshot.state==SRMP_CRITICAL ||
           !operational)
      desired=SRMP_CRITICAL;
   else desired=SRMP_EMERGENCY;
   if(desired!=g_snapshot.state)
     {
      g_snapshot.state=desired;
      if(!SRMPSaveSnapshot(g_snapshot))
         NotifyHealth("CRITICAL: failed to persist emergency state update");
      PrintFormat("Protection state: %s; open positions=%d pending orders=%d",
                  SRMPStateName(g_snapshot.state),PositionsTotal(),OrdersTotal());
     }
   GlobalVariableSet(SRMPGlobalKey("HEALTH"),completed ? 0.0 :
                     (!operational ? 2.0 : (exhausted ? 3.0 : 0.0)));
   if(exhausted)
      NotifyHealth("CRITICAL: close/cancel retry limit reached; manual intervention required");
   if(!operational)
      NotifyHealth("CRITICAL: disconnected or trading disabled during emergency");
  }

void OnTick() {} // Account-wide monitoring runs on a timer, independent of chart ticks.
