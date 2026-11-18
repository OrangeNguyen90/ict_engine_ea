#ifndef SMART_RISK_BRIDGE_MQH
#define SMART_RISK_BRIDGE_MQH

// Terminal Global Variables carry numeric snapshots between the indicator and
// the calculation-only EA on the same chart. RESP is written last as a commit.
int RMReasonCode(const string reason)
  {
   if(reason=="SAFE preview (no order sent)") return 0;
   if(reason=="Symbol unavailable") return 1;
   if(reason=="Invalid broker symbol specification") return 2;
   if(reason=="Invalid risk inputs") return 3;
   if(reason=="Invalid price") return 4;
   if(reason=="SL/TP on wrong side of entry") return 5;
   if(reason=="Price is off the symbol tick grid") return 6;
   if(reason=="SL/TP inside broker stop/freeze distance") return 7;
   if(reason=="Terminal disconnected") return 8;
   if(reason=="Valid bid/ask unavailable") return 9;
   if(reason=="Market quote is stale") return 10;
   if(reason=="OrderCalcProfit failed") return 11;
   if(reason=="Nonpositive loss or reward estimate") return 12;
   if(reason=="Minimum lot exceeds risk budget") return 13;
   if(reason=="No lot fits risk budget") return 14;
   if(reason=="OrderCalcMargin failed") return 15;
   if(reason=="Insufficient free margin") return 16;
   if(reason=="RR below minimum") return 17;
   return 99;
  }

string RMReasonText(const int code)
  {
   switch(code)
     {
      case 0: return "Valid preview (no order sent)";
      case 1: return "Symbol unavailable";
      case 2: return "Invalid broker symbol specification";
      case 3: return "Invalid risk inputs";
      case 4: return "Invalid price";
      case 5: return "SL/TP on wrong side of entry";
      case 6: return "Price is off the symbol tick grid";
      case 7: return "SL/TP inside broker stop/freeze distance";
      case 8: return "Terminal disconnected";
      case 9: return "Valid bid/ask unavailable";
      case 10: return "Market quote is stale";
      case 11: return "OrderCalcProfit failed";
      case 12: return "Nonpositive loss or reward estimate";
      case 13: return "Minimum lot exceeds risk budget";
      case 14: return "No lot fits risk budget";
      case 15: return "OrderCalcMargin failed";
      case 16: return "Insufficient free margin";
      case 17: return "RR below minimum";
     }
   return "Calculator error; inspect Experts log";
  }

string RMBridgePrefix(const string instance_id)
  { return "SRMP_"+IntegerToString(ChartID())+"_"+instance_id+"_"; }

#endif
