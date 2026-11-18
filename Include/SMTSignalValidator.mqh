#ifndef SRMP_SMT_SIGNAL_VALIDATOR_MQH
#define SRMP_SMT_SIGNAL_VALIDATOR_MQH

#include "SymbolCorrelationEngine.mqh"

enum ENUM_SRMP_SMT_STATE { SRMP_SMT_NOT_CONFIGURED=0, SRMP_SMT_INVALID_SYMBOL=1,
                           SRMP_SMT_INSUFFICIENT=2, SRMP_SMT_WEAK=3,
                           SRMP_SMT_UNCONFIRMED=4, SRMP_SMT_BULLISH=5,
                           SRMP_SMT_BEARISH=6, SRMP_SMT_COMP_ONLY=7 };

string SRMPSMTStateText(const ENUM_SRMP_SMT_STATE state)
  {
   if(state==SRMP_SMT_NOT_CONFIGURED) return "NOT CONFIGURED";
   if(state==SRMP_SMT_INVALID_SYMBOL) return "UNAVAILABLE: INVALID SYMBOL";
   if(state==SRMP_SMT_INSUFFICIENT) return "UNAVAILABLE: DATA/TIME ALIGNMENT";
   if(state==SRMP_SMT_WEAK) return "UNAVAILABLE: CORRELATION";
   if(state==SRMP_SMT_UNCONFIRMED) return "UNCONFIRMED";
   if(state==SRMP_SMT_BULLISH) return "BULLISH SMT";
   if(state==SRMP_SMT_BEARISH) return "BEARISH SMT";
   return "COMPARISON ONLY BREAK";
  }

bool SRMPValidateComparisonSymbol(const string primary,const string comparison)
  {
   if(comparison=="" || comparison==primary ||
      StringFind(comparison," ")>=0 || StringFind(comparison,"\t")>=0)
      return false;
   bool custom=false;
   if(!SymbolExist(comparison,custom)) return false;
   if(!SymbolSelect(comparison,true)) return false;
   return true;
  }

#endif
