#property script_show_inputs
#property strict

// Export broker-server timestamps without assuming a UTC offset. The importer
// must be given the broker's actual historical timezone.
input ENUM_TIMEFRAMES Export_Timeframe = PERIOD_H1;
input int Closed_Bars = 1000;
input string Output_File = "ict_market_candles.csv";

void OnStart()
{
   if(Closed_Bars < 1 || Closed_Bars > 100000 || Output_File == "")
   {
      Print("Invalid bar count or output filename");
      return;
   }
   MqlRates rates[];
   int count = CopyRates(_Symbol, Export_Timeframe, 1, Closed_Bars, rates);
   if(count <= 0)
   {
      Print("CopyRates failed: ", GetLastError());
      return;
   }
   int file = FileOpen(Output_File, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(file == INVALID_HANDLE)
   {
      Print("Cannot open export file: ", GetLastError());
      return;
   }
   FileWrite(file, "timestamp", "open", "high", "low", "close", "volume");
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   for(int i = 0; i < count; ++i)
   {
      MqlDateTime t;
      TimeToStruct(rates[i].time, t);
      string stamp = StringFormat("%04d-%02d-%02dT%02d:%02d:%02d", t.year, t.mon, t.day, t.hour, t.min, t.sec);
      FileWrite(file, stamp, DoubleToString(rates[i].open, digits), DoubleToString(rates[i].high, digits),
                DoubleToString(rates[i].low, digits), DoubleToString(rates[i].close, digits), rates[i].tick_volume);
   }
   FileClose(file);
   PrintFormat("Exported %d closed %s bars for %s to MQL5/Files/%s (broker-server time)",
               count, EnumToString(Export_Timeframe), _Symbol, Output_File);
}
