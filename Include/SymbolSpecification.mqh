#ifndef SMART_RISK_SYMBOL_SPECIFICATION_MQH
#define SMART_RISK_SYMBOL_SPECIFICATION_MQH

struct SSymbolSpecification
  {
   int    digits;
   double point;
   double tick_size;
   double tick_value;
   double contract_size;
   double volume_min;
   double volume_max;
   double volume_step;
   int    stops_level;
   int    freeze_level;
  };

bool LoadSymbolSpecification(const string symbol,SSymbolSpecification &spec,string &reason)
  {
   ZeroMemory(spec);
   reason="";
   if(!SymbolSelect(symbol,true))
     { reason="Symbol unavailable"; return false; }
   spec.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   spec.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   spec.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   spec.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   spec.contract_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   spec.volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   spec.volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   spec.volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   spec.stops_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   spec.freeze_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   if(!MathIsValidNumber(spec.point) || !MathIsValidNumber(spec.tick_size) ||
      !MathIsValidNumber(spec.tick_value) || !MathIsValidNumber(spec.contract_size) ||
      !MathIsValidNumber(spec.volume_min) || !MathIsValidNumber(spec.volume_max) ||
      !MathIsValidNumber(spec.volume_step) ||
      spec.digits<0 || spec.point<=0.0 || spec.tick_size<=0.0 ||
      spec.tick_value<=0.0 || spec.contract_size<=0.0 ||
      spec.volume_min<=0.0 || spec.volume_max<spec.volume_min ||
      spec.volume_step<=0.0 || spec.stops_level<0 || spec.freeze_level<0)
     { reason="Invalid broker symbol specification"; return false; }
   return true;
  }

#endif
