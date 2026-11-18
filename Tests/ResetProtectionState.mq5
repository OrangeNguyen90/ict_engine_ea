#property copyright "MT5 Smart Risk Manager Pro"
#property version "2.00"
#property script_show_inputs
#property description "Explicit, one-shot reset. Run only after removing protection EA."

#include "../Include/ProtectionPersistence.mqh"

input long Confirm_Account_Login=0;
input string Confirmation_Phrase="";
input bool Reset_Reference_Capital=false;
input bool Clear_Emergency_Lock=false;

void OnStart()
  {
   if(Confirm_Account_Login!=AccountInfoInteger(ACCOUNT_LOGIN) ||
      Confirmation_Phrase!="I CONFIRM RESET SRMP" ||
      (!Reset_Reference_Capital && !Clear_Emergency_Lock))
     { Print("Reset refused: explicit account and phrase confirmation required"); return; }
   if(PositionsTotal()!=0 || OrdersTotal()!=0)
     { Print("Reset refused: account still has positions or pending orders"); return; }
   int handle=FileOpen(SRMPLockFile(),FILE_READ|FILE_WRITE|FILE_BIN|
                       SRMPFileScope());
   if(handle==INVALID_HANDLE)
     { Print("Reset refused: protection controller is active or lock unavailable"); return; }
   SProtectionSnapshot snapshot;
   if(!FileIsExist(SRMPStateFile(),SRMPFileScope()) ||
      !SRMPLoadSnapshot(snapshot))
     {
      Print("Reset refused: saved account state not found or invalid");
      FileClose(handle);
      return;
     }
   if(Reset_Reference_Capital)
      snapshot.reference_capital=AccountInfoDouble(ACCOUNT_BALANCE);
   if(Clear_Emergency_Lock)
     {
      snapshot.state=SRMP_NORMAL;
      snapshot.trigger_ticket=0;
      snapshot.trigger_time=0;
      snapshot.trigger_equity=0.0;
     }
   if(snapshot.reference_capital<=0.0 || !SRMPSaveSnapshot(snapshot))
      Print("Reset failed: state could not be saved");
   else
      PrintFormat("Reset completed for account %I64d: reference %.2f state %s",
                  AccountInfoInteger(ACCOUNT_LOGIN),snapshot.reference_capital,
                  SRMPStateName(snapshot.state));
   FileClose(handle);
  }
