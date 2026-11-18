#ifndef SRMP_PROTECTION_PERSISTENCE_MQH
#define SRMP_PROTECTION_PERSISTENCE_MQH

enum ENUM_SRMP_STATE
  {
   SRMP_NORMAL=0,
   SRMP_EMERGENCY=1,
   SRMP_CRITICAL=2,
   SRMP_LOCKED=3
  };

struct SProtectionSnapshot
  {
   double             reference_capital;
   ENUM_SRMP_STATE    state;
   ulong              trigger_ticket;
   datetime           trigger_time;
   double             trigger_equity;
  };

string SRMPAccountStem()
  {
   string server=AccountInfoString(ACCOUNT_SERVER);
   uint hash=2166136261;
   for(int i=0;i<StringLen(server);i++)
      hash=(hash^(uint)StringGetCharacter(server,i))*16777619;
   string prefix=(MQLInfoInteger(MQL_TESTER)!=0 ? "SRMP2T_" : "SRMP2_");
   return prefix+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+
          IntegerToString((long)hash);
  }

int SRMPFileScope()
  { return (MQLInfoInteger(MQL_TESTER)!=0 ? 0 : FILE_COMMON); }

string SRMPStateFile()
  { return SRMPAccountStem()+".state.csv"; }

string SRMPLockFile()
  { return SRMPAccountStem()+".controller.lock"; }

string SRMPMarkerFile()
  { return SRMPAccountStem()+".initialized"; }

bool SRMPMarkInitialized()
  {
   int handle=FileOpen(SRMPMarkerFile(),FILE_WRITE|FILE_TXT|FILE_UNICODE|
                       SRMPFileScope());
   if(handle==INVALID_HANDLE) return false;
   FileWriteString(handle,AccountInfoString(ACCOUNT_SERVER));
   FileFlush(handle);
   FileClose(handle);
   return true;
  }

string SRMPGlobalKey(const string suffix)
  { return SRMPAccountStem()+"_"+suffix; }

string SRMPStateName(const ENUM_SRMP_STATE state)
  {
   if(state==SRMP_NORMAL) return "NORMAL";
   if(state==SRMP_EMERGENCY) return "EMERGENCY_CLOSE_ALL";
   if(state==SRMP_CRITICAL) return "CRITICAL";
   return "LOCKED";
  }

// Only the account's controller may call this. A separate exclusive lock file
// is held open during the controller's lifetime.
bool SRMPSaveSnapshot(const SProtectionSnapshot &snapshot)
  {
   string temp=SRMPStateFile()+".tmp_"+IntegerToString(ChartID());
   int scope=SRMPFileScope();
   int handle=FileOpen(temp,FILE_WRITE|FILE_CSV|FILE_UNICODE|scope,';');
   if(handle==INVALID_HANDLE)
     { Print("Protection state temp open failed: ",GetLastError()); return false; }
   FileWrite(handle,"SRMP2",IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),
             AccountInfoString(ACCOUNT_SERVER),
             DoubleToString(snapshot.reference_capital,8),
             IntegerToString((int)snapshot.state),
             IntegerToString(snapshot.trigger_ticket),
             IntegerToString(snapshot.trigger_time),
             DoubleToString(snapshot.trigger_equity,8));
   FileFlush(handle);
   FileClose(handle);
   if(!FileMove(temp,scope,SRMPStateFile(),scope|FILE_REWRITE))
     { Print("Protection state replace failed: ",GetLastError()); return false; }
   if(!GlobalVariableSet(SRMPGlobalKey("REF"),snapshot.reference_capital) ||
      !GlobalVariableSet(SRMPGlobalKey("STATE"),(double)snapshot.state) ||
      !GlobalVariableSet(SRMPGlobalKey("TRIGGER"),(double)snapshot.trigger_ticket))
     { Print("Protection dashboard state publish failed: ",GetLastError()); return false; }
   GlobalVariablesFlush();
   return true;
  }

bool SRMPLoadSnapshot(SProtectionSnapshot &snapshot)
  {
   ZeroMemory(snapshot);
   int handle=FileOpen(SRMPStateFile(),FILE_READ|FILE_CSV|FILE_UNICODE|
                       SRMPFileScope(),';');
   if(handle==INVALID_HANDLE)
     { Print("Protection state open failed: ",GetLastError()); return false; }
   string magic=FileReadString(handle);
   string login=FileReadString(handle);
   string server=FileReadString(handle);
   string reference=FileReadString(handle);
   string state=FileReadString(handle);
   string ticket=FileReadString(handle);
   string time=FileReadString(handle);
   string equity=FileReadString(handle);
   FileClose(handle);
   if(magic!="SRMP2" || login!=IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) ||
      server!=AccountInfoString(ACCOUNT_SERVER)) return false;
   snapshot.reference_capital=StringToDouble(reference);
   snapshot.state=(ENUM_SRMP_STATE)StringToInteger(state);
   snapshot.trigger_ticket=(ulong)StringToInteger(ticket);
   snapshot.trigger_time=(datetime)StringToInteger(time);
   snapshot.trigger_equity=StringToDouble(equity);
   if(!MathIsValidNumber(snapshot.reference_capital) ||
      snapshot.reference_capital<=0.0 || snapshot.state<SRMP_NORMAL ||
      snapshot.state>SRMP_LOCKED) return false;
   return true;
  }

#endif
