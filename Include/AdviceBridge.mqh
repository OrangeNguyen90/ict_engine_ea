#ifndef SRMP_ADVICE_BRIDGE_MQH
#define SRMP_ADVICE_BRIDGE_MQH

#include "ProtectionPersistence.mqh"

enum ENUM_SRMP_ADVICE_STATUS
  {
   SRMP_NO_TRADE=0,
   SRMP_WAIT=1,
   SRMP_TRADE_READY=2
  };

string SRMPAdviceKey(const string symbol,const string suffix)
  {
   return SRMPAccountStem()+"_AD_"+IntegerToString(ChartID())+"_"+suffix;
  }

void SRMPPublishAdviceSymbol(const string chart_symbol,const string suffix,
                             const string value)
  {
   int length=(int)MathMin(StringLen(value),24);
   GlobalVariableSet(SRMPAdviceKey(chart_symbol,suffix+"N"),(double)length);
   for(int i=0;i<length;i++)
      GlobalVariableSet(SRMPAdviceKey(chart_symbol,suffix+IntegerToString(i)),
                        (double)StringGetCharacter(value,i));
  }

// The same bounded transport carries human-readable reasons, including spaces.
// Symbol-only callers continue to use their original 24-character maximum.
void SRMPPublishAdviceText(const string chart_symbol,const string suffix,
                           const string value)
  {
   int length=(int)MathMin(StringLen(value),512);
   GlobalVariableSet(SRMPAdviceKey(chart_symbol,suffix+"N"),(double)length);
   for(int i=0;i<length;i++)
      GlobalVariableSet(SRMPAdviceKey(chart_symbol,suffix+IntegerToString(i)),
                        (double)StringGetCharacter(value,i));
  }

string SRMPReadAdviceText(const string chart_symbol,const string suffix)
  {
   int length=(int)GlobalVariableGet(SRMPAdviceKey(chart_symbol,suffix+"N"));
   if(length<0 || length>512) return "";
   string result="";
   for(int i=0;i<length;i++)
     {
      int code=(int)GlobalVariableGet(SRMPAdviceKey(chart_symbol,suffix+IntegerToString(i)));
      if(code<32 || code>65535) return "";
      result+=" ";
      StringSetCharacter(result,i,(ushort)code);
     }
   return result;
  }

string SRMPReadAdviceSymbol(const string chart_symbol,const string suffix)
  {
   int length=(int)GlobalVariableGet(SRMPAdviceKey(chart_symbol,suffix+"N"));
   if(length<0 || length>24) return "";
   string result="";
   for(int i=0;i<length;i++)
     {
      int code=(int)GlobalVariableGet(SRMPAdviceKey(chart_symbol,
                                      suffix+IntegerToString(i)));
      if(code<32 || code>126) return "";
      int at=StringLen(result);
      result+=" ";
      StringSetCharacter(result,at,(ushort)code);
     }
   return result;
  }

int SRMPAdviceReasonCode(const string reason)
  {
   if(reason=="Aligned closed-bar structure, sweep, FVG, trigger and risk gates") return 0;
   if(reason=="Protection offline, unhealthy or locked") return 1;
   if(reason=="Insufficient closed bars or swing structure") return 2;
   if(reason=="Multi-timeframe bias not aligned") return 3;
   if(reason=="Awaiting closed H1 BOS in bias direction") return 4;
   if(reason=="Closed-bar ATR unavailable") return 5;
   if(reason=="No confirmed M15 FVG") return 6;
   if(reason=="FVG direction/mitigation not valid") return 7;
   if(reason=="FVG outside discount/premium zone") return 8;
   if(reason=="Previous day or trigger candles unavailable") return 9;
   if(reason=="Awaiting closed PDH/PDL liquidity sweep") return 10;
   if(reason=="Closed trigger candles unavailable") return 11;
   if(reason=="M5 close has not confirmed trigger") return 12;
   if(reason=="Current quote unavailable") return 13;
   if(reason=="Invalid symbol tick specification") return 14;
   if(reason=="Spread above configured limit") return 15;
   if(reason=="Current price outside FVG entry zone") return 16;
   if(StringFind(reason,"Risk gate:")==0) return 17;
   if(reason=="Terminal disconnected") return 18;
   if(reason=="Protection reference unavailable") return 19;
   if(reason=="Invalid advisory risk limits") return 20;
   return 99;
  }

string SRMPAdviceReasonText(const int code)
  {
   switch(code)
     {
      case 0: return "Closed-bar setup and numeric gates passed";
      case 1: return "Protection offline, unhealthy or locked";
      case 2: return "Insufficient closed bars or swing structure";
      case 3: return "H4/H1 bias not aligned";
      case 4: return "Awaiting H1 BOS";
      case 5: return "ATR unavailable";
      case 6: return "No confirmed M15 FVG";
      case 7: return "FVG direction/mitigation invalid";
      case 8: return "FVG outside premium/discount zone";
      case 9: return "Daily or trigger candles unavailable";
      case 10: return "Awaiting PDH/PDL sweep";
      case 11: return "Closed M5 candles unavailable";
      case 12: return "Awaiting M5 close trigger";
      case 13: return "Current quote unavailable";
      case 14: return "Invalid tick specification";
      case 15: return "Spread above limit";
      case 16: return "Price outside FVG entry zone";
      case 17: return "Risk/RR/margin gate blocked";
      case 18: return "Terminal disconnected";
      case 19: return "Protection reference unavailable";
      case 20: return "Invalid advisory risk limits";
     }
   return "No validated setup";
  }

#endif
