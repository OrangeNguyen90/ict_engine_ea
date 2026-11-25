#property script_show_inputs
#property strict
#property description "Read-only, date-ranged research export; never sends orders."

// All file operations are restricted to this script's own terminal sandbox
// subdirectory. It does not modify charts, live EAs, accounts or trade settings.
input string Research_Symbol = "US500";
input bool Export_All_Timeframes = true; // M1, M15, H1 and D1, separately
input ENUM_TIMEFRAMES Research_Timeframe = PERIOD_M15;
input datetime Research_From = D'2020.01.01 00:00:00';
input datetime Research_To = 0; // exclusive; 0 freezes TimeCurrent() at start
input int Chunk_Days = 7;
input int Copy_Attempts = 4;
input int Retry_Delay_Milliseconds = 500;
input string Price_Type = "unknown"; // exactly: unknown, bid, last
input bool Price_Type_Historically_Verified = false;
input string Export_Tag = ""; // safe filename suffix, e.g. initial_audit
input bool Overwrite_Existing_Export = false;

const string RESEARCH_DIRECTORY = "ICTResearch";

string ResearchStamp(const datetime value)
{
   MqlDateTime parts;
   if(!TimeToStruct(value, parts)) return "";
   return StringFormat("%04d-%02d-%02dT%02d:%02d:%02d", parts.year,
                       parts.mon, parts.day, parts.hour, parts.min, parts.sec);
}

string ResearchCompactStamp(const datetime value)
{
   string result = ResearchStamp(value);
   StringReplace(result, "-", "");
   StringReplace(result, ":", "");
   return result;
}

string ResearchSafeName(const string value)
{
   string result = "";
   for(int i = 0; i < StringLen(value); ++i)
   {
      ushort ch = StringGetCharacter(value, i);
      bool allowed = ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                      (ch >= '0' && ch <= '9') || ch == '_' || ch == '-');
      result += allowed ? ShortToString(ch) : "_";
   }
   return StringSubstr(result, 0, 64);
}

string ResearchJsonString(const string value)
{
   string escaped = "\"";
   for(int i = 0; i < StringLen(value); ++i)
   {
      ushort ch = StringGetCharacter(value, i);
      if(ch == '"') escaped += "\\\"";
      else if(ch == '\\') escaped += "\\\\";
      else if(ch < 32) escaped += StringFormat("\\u%04x", (int)ch);
      else escaped += ShortToString(ch);
   }
   return escaped + "\"";
}

string ResearchBool(const bool value) { return value ? "true" : "false"; }

string ResearchTimeframeName(const ENUM_TIMEFRAMES timeframe)
{
   string name = EnumToString(timeframe);
   StringReplace(name, "PERIOD_", "");
   return name;
}

bool ResearchAllowedTimeframe(const ENUM_TIMEFRAMES timeframe)
{
   return timeframe == PERIOD_M1 || timeframe == PERIOD_M15 ||
          timeframe == PERIOD_H1 || timeframe == PERIOD_D1;
}

// Counts only the API's currently available bars. Synchronization and a count
// match cannot identify a broker-side hole or classify a scheduled closure.
bool ResearchCopyChunk(const string symbol, const ENUM_TIMEFRAMES timeframe,
                       const datetime from, const datetime to_exclusive,
                       MqlRates &rates[], int &expected, int &last_error)
{
   expected = 0;
   last_error = 0;
   ArraySetAsSeries(rates, false);
   for(int attempt = 0; attempt < Copy_Attempts && !IsStopped(); ++attempt)
   {
      ArrayResize(rates, 0);
      ResetLastError();
      int copied = CopyRates(symbol, timeframe, from, to_exclusive - 1, rates);
      int copy_error = GetLastError();
      expected = Bars(symbol, timeframe, from, to_exclusive - 1);
      bool synced = (bool)SeriesInfoInteger(symbol, timeframe, SERIES_SYNCHRONIZED);
      if(copied >= 0 && copied == expected && synced && copy_error == 0)
         return true;
      last_error = copy_error;
      if(attempt + 1 < Copy_Attempts) Sleep(Retry_Delay_Milliseconds);
   }
   return false;
}

bool ResearchExportTimeframe(const string symbol,
                             const ENUM_TIMEFRAMES timeframe,
                             const datetime snapshot_server_time)
{
   int seconds = PeriodSeconds(timeframe);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(seconds <= 0 || digits < 0 || digits > 12 || point <= 0 || tick_size <= 0)
   {
      Print("Research export rejected: invalid symbol contract information.");
      return false;
   }
   datetime to_exclusive = Research_To == 0 ? snapshot_server_time : Research_To;
   datetime effective_end = to_exclusive < snapshot_server_time ? to_exclusive : snapshot_server_time;
   if(effective_end <= Research_From)
   {
      Print("Research export rejected: no closed historical interval.");
      return false;
   }

   string tf_name = ResearchTimeframeName(timeframe);
   string stem = ResearchSafeName(symbol) + "_" + tf_name + "_" +
                 ResearchCompactStamp(Research_From) + "_" + ResearchCompactStamp(to_exclusive);
   if(Export_Tag != "") stem += "_" + ResearchSafeName(Export_Tag);
   string csv_name = stem + ".csv";
   string csv_path = RESEARCH_DIRECTORY + "\\" + csv_name;
   string metadata_path = csv_path + ".meta.json";
   if(!Overwrite_Existing_Export && (FileIsExist(csv_path) || FileIsExist(metadata_path)))
   {
      Print("Research export refused to overwrite: ", csv_path,
            ". Use another Export_Tag or explicitly enable Overwrite_Existing_Export.");
      return false;
   }

   string unique = ".partial." + (string)GetTickCount64();
   string csv_partial = csv_path + unique;
   string metadata_partial = metadata_path + unique;
   // Even temporary filenames are never opened over an existing export.
   if(FileIsExist(csv_partial) || FileIsExist(metadata_partial))
   {
      Print("Research export rejected: temporary filename already exists.");
      return false;
   }
   int file = FileOpen(csv_partial, FILE_WRITE | FILE_CSV | FILE_ANSI, ',', CP_UTF8);
   if(file == INVALID_HANDLE)
   {
      Print("Research export could not create CSV: ", GetLastError());
      return false;
   }

   bool io_ok = FileWrite(file, "timestamp", "open", "high", "low", "close",
                          "volume", "spread_points") > 0;
   bool retrieval_ok = true;
   int chunks = 0, failed_chunks = 0, last_copy_error = 0;
   long count = 0, raw_count = 0, expected_count = 0, excluded_unclosed = 0;
   long invalid_rows = 0, gap_count = 0, gap_periods = 0;
   datetime first = 0, last = 0;
   datetime cursor = Research_From;
   MqlRates rates[];
   while(cursor < effective_end && !IsStopped() && io_ok)
   {
      datetime next = (datetime)((long)cursor + (long)Chunk_Days * 86400);
      if(next > effective_end) next = effective_end;
      int expected = 0, copy_error = 0;
      bool copied_ok = ResearchCopyChunk(symbol, timeframe, cursor, next,
                                          rates, expected, copy_error);
      ++chunks;
      if(!copied_ok)
      {
         retrieval_ok = false;
         ++failed_chunks;
         last_copy_error = copy_error;
         PrintFormat("Research export incomplete %s %s: chunk %s to %s; error=%d.",
                     symbol, tf_name, ResearchStamp(cursor), ResearchStamp(next), copy_error);
         // Do not silently advance past an unavailable chunk. Publish the
         // successfully written prefix with an explicit incomplete sidecar.
         break;
      }
      int available = ArraySize(rates);
      expected_count += expected;
      raw_count += available;
      for(int i = 0; i < available && io_ok && !IsStopped(); ++i)
      {
         MqlRates bar = rates[i];
         if(bar.time < cursor || bar.time >= next || (last != 0 && bar.time <= last))
         {
            ++invalid_rows;
            retrieval_ok = false;
            continue;
         }
         if(bar.time + seconds > effective_end)
         {
            ++excluded_unclosed;
            continue;
         }
         if(!MathIsValidNumber(bar.open) || !MathIsValidNumber(bar.high) ||
            !MathIsValidNumber(bar.low) || !MathIsValidNumber(bar.close) ||
            bar.open <= 0 || bar.low <= 0 || bar.high < bar.low ||
            bar.high < bar.open || bar.high < bar.close || bar.low > bar.open ||
            bar.low > bar.close || bar.tick_volume < 0 || bar.spread < 0)
         {
            ++invalid_rows;
            retrieval_ok = false;
            continue;
         }
         if(last != 0 && bar.time - last > seconds)
         {
            ++gap_count;
            gap_periods += (long)(bar.time - last) / seconds - 1;
         }
         io_ok = FileWrite(file, ResearchStamp(bar.time), DoubleToString(bar.open, digits),
                           DoubleToString(bar.high, digits), DoubleToString(bar.low, digits),
                           DoubleToString(bar.close, digits), bar.tick_volume, bar.spread) > 0;
         if(io_ok)
         {
            if(first == 0) first = bar.time;
            last = bar.time;
            ++count;
         }
      }
      cursor = next;
   }
   ResetLastError();
   FileFlush(file);
   if(GetLastError() != 0) io_ok = false;
   long csv_bytes = (long)FileSize(file);
   FileClose(file);

   bool synchronized = (bool)SeriesInfoInteger(symbol, timeframe, SERIES_SYNCHRONIZED);
   datetime server_first = (datetime)SeriesInfoInteger(symbol, timeframe, SERIES_SERVER_FIRSTDATE);
   datetime series_first = (datetime)SeriesInfoInteger(symbol, timeframe, SERIES_FIRSTDATE);
   bool requested_before_server_history = server_first == 0 || Research_From < server_first;
   bool complete = io_ok && retrieval_ok && !IsStopped() && cursor == effective_end &&
                   synchronized && count > 0 && invalid_rows == 0 &&
                   expected_count == raw_count && !requested_before_server_history;

   // This is an API extraction manifest, never evidence of tradable history,
   // a timezone assertion, a historical execution cost or a model probability.
   string json = "{\n";
   json += "  \"schema_version\": 1,\n";
   json += "  \"exporter\": \"ExportResearchCandles.mq5\",\n";
   json += "  \"csv_file\": " + ResearchJsonString(csv_name) + ",\n";
   json += "  \"broker\": " + ResearchJsonString(AccountInfoString(ACCOUNT_COMPANY)) + ",\n";
   json += "  \"server\": " + ResearchJsonString(AccountInfoString(ACCOUNT_SERVER)) + ",\n";
   json += "  \"symbol\": " + ResearchJsonString(symbol) + ",\n";
   json += "  \"timeframe\": " + ResearchJsonString(tf_name) + ",\n";
   json += "  \"timeframe_seconds\": " + (string)seconds + ",\n";
   json += "  \"timestamp_basis\": \"broker_server\",\n";
   json += "  \"source_timezone\": \"unknown\",\n";
   json += "  \"timestamp_semantics\": \"bar_open\",\n";
   json += "  \"price_type\": " + ResearchJsonString(Price_Type) + ",\n";
   json += "  \"price_type_historically_verified\": " + ResearchBool(Price_Type_Historically_Verified) + ",\n";
   json += "  \"point\": " + DoubleToString(point, 12) + ",\n";
   json += "  \"tick_size\": " + DoubleToString(tick_size, 12) + ",\n";
   json += "  \"digits\": " + (string)digits + ",\n";
   json += "  \"volume_basis\": \"tick_volume\",\n";
   json += "  \"spread_basis\": \"MqlRates.spread_per_bar_not_executable_quote\",\n";
   json += "  \"requested_start\": " + ResearchJsonString(ResearchStamp(Research_From)) + ",\n";
   json += "  \"requested_end\": " + ResearchJsonString(ResearchStamp(to_exclusive)) + ",\n";
   json += "  \"requested_end_exclusive\": true,\n";
   json += "  \"effective_end\": " + ResearchJsonString(ResearchStamp(effective_end)) + ",\n";
   json += "  \"snapshot_server_time\": " + ResearchJsonString(ResearchStamp(snapshot_server_time)) + ",\n";
   json += "  \"actual_first\": " + (first == 0 ? "null" : ResearchJsonString(ResearchStamp(first))) + ",\n";
   json += "  \"actual_last\": " + (last == 0 ? "null" : ResearchJsonString(ResearchStamp(last))) + ",\n";
   json += "  \"count\": " + (string)count + ",\n";
   json += "  \"csv_bytes\": " + (string)csv_bytes + ",\n";
   json += "  \"complete\": " + ResearchBool(complete) + ",\n";
   json += "  \"status\": " + ResearchJsonString(complete ? "api_extraction_complete" : "incomplete") + ",\n";
   json += "  \"coverage_verified\": false,\n";
   json += "  \"complete_scope\": \"synchronized_API_chunks_match_Bars_counts_only\",\n";
   json += "  \"synchronized\": " + ResearchBool(synchronized) + ",\n";
   json += "  \"chunk_days\": " + (string)Chunk_Days + ",\n";
   json += "  \"chunks\": " + (string)chunks + ",\n";
   json += "  \"failed_chunks\": " + (string)failed_chunks + ",\n";
   json += "  \"last_copy_error\": " + (string)last_copy_error + ",\n";
   json += "  \"api_expected_count\": " + (string)expected_count + ",\n";
   json += "  \"api_raw_count\": " + (string)raw_count + ",\n";
   json += "  \"invalid_rows\": " + (string)invalid_rows + ",\n";
   json += "  \"excluded_unclosed\": " + (string)excluded_unclosed + ",\n";
   json += "  \"gap_count\": " + (string)gap_count + ",\n";
   json += "  \"gap_missing_periods_unclassified\": " + (string)gap_periods + ",\n";
   json += "  \"gaps_classified\": false,\n";
   json += "  \"series_first_available\": " + (series_first == 0 ? "null" : ResearchJsonString(ResearchStamp(series_first))) + ",\n";
   json += "  \"server_first_available\": " + (server_first == 0 ? "null" : ResearchJsonString(ResearchStamp(server_first))) + ",\n";
   json += "  \"requested_before_server_history\": " + ResearchBool(requested_before_server_history) + ",\n";
   json += "  \"commissions\": \"unknown\",\n";
   json += "  \"historical_slippage\": \"unknown\",\n";
   json += "  \"historical_contract_verified\": false,\n";
   json += "  \"contract_scope\": \"current_snapshot_informational_not_historical\",\n";
   json += "  \"current_contract_size\": " + DoubleToString(SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE), 8) + ",\n";
   json += "  \"current_chart_mode\": " + (string)SymbolInfoInteger(symbol, SYMBOL_CHART_MODE) + "\n";
   json += "}\n";

   int metadata = FileOpen(metadata_partial, FILE_WRITE | FILE_TXT | FILE_ANSI, 0, CP_UTF8);
   if(metadata == INVALID_HANDLE)
   {
      Print("Research export metadata failed; CSV retained as .partial: ", GetLastError());
      return false;
   }
   bool metadata_ok = FileWriteString(metadata, json) > 0;
   ResetLastError();
   FileFlush(metadata);
   if(GetLastError() != 0) metadata_ok = false;
   FileClose(metadata);
   if(!metadata_ok)
   {
      Print("Research export metadata write failed; .partial files retained.");
      return false;
   }
   int move_flags = Overwrite_Existing_Export ? FILE_REWRITE : 0;
   // If an explicitly authorized overwrite is interrupted between publication
   // of the two files, a stale sidecar must never describe the replacement CSV.
   if(Overwrite_Existing_Export && FileIsExist(metadata_path) && !FileDelete(metadata_path))
   {
      Print("Research export cannot invalidate old sidecar; .partial files retained: ", GetLastError());
      return false;
   }
   if(!FileMove(csv_partial, 0, csv_path, move_flags))
   {
      Print("Research export CSV publish failed; .partial files retained: ", GetLastError());
      return false;
   }
   if(!FileMove(metadata_partial, 0, metadata_path, move_flags))
   {
      Print("Research export sidecar publish failed. CSV is NOT USABLE without its matching sidecar: ", GetLastError());
      return false;
   }
   PrintFormat("Research export %s: %s %s, %I64d closed bars, %I64d unclassified gaps; MQL5/Files/%s.",
               complete ? "API COMPLETE (coverage unverified)" : "INCOMPLETE - DO NOT TRAIN",
               symbol, tf_name, count, gap_count, csv_path);
   return complete;
}

void OnStart()
{
   if(Research_Symbol == "" || Research_From <= 0 || Chunk_Days < 1 || Chunk_Days > 31 ||
      Copy_Attempts < 1 || Copy_Attempts > 10 || Retry_Delay_Milliseconds < 0 ||
      Retry_Delay_Milliseconds > 5000 || (!Export_All_Timeframes && !ResearchAllowedTimeframe(Research_Timeframe)) ||
      (Price_Type != "unknown" && Price_Type != "bid" && Price_Type != "last") ||
      (Price_Type != "unknown" && !Price_Type_Historically_Verified) ||
      (Price_Type == "unknown" && Price_Type_Historically_Verified))
   {
      Print("Invalid research export inputs. A bid/last label requires historical verification; unknown must remain unverified.");
      return;
   }
   datetime snapshot = TimeCurrent();
   datetime requested_end = Research_To == 0 ? snapshot : Research_To;
   // Bound date scanning independently of terminal availability.
   if(requested_end <= Research_From || (long)(requested_end - Research_From) / 86400 > 36525)
   {
      Print("Research export rejected: date range must be positive and at most 100 years.");
      return;
   }
   bool was_selected = (bool)SymbolInfoInteger(Research_Symbol, SYMBOL_SELECT);
   if(!SymbolSelect(Research_Symbol, true))
   {
      Print("Research export cannot select symbol: ", GetLastError());
      return;
   }
   // FolderCreate can report that a directory already exists. FileOpen below
   // is the definitive check. This directory is fixed, not user supplied.
   FolderCreate(RESEARCH_DIRECTORY);
   int successful = 0, attempted = 0;
   ENUM_TIMEFRAMES frames[4] = {PERIOD_M1, PERIOD_M15, PERIOD_H1, PERIOD_D1};
   if(Export_All_Timeframes)
   {
      for(int i = 0; i < 4 && !IsStopped(); ++i)
      {
         ++attempted;
         if(ResearchExportTimeframe(Research_Symbol, frames[i], snapshot)) ++successful;
      }
   }
   else
   {
      ++attempted;
      if(ResearchExportTimeframe(Research_Symbol, Research_Timeframe, snapshot)) ++successful;
   }
   // Restore Market Watch selection if this script added the symbol. The
   // terminal can refuse deselection when the symbol is otherwise in use.
   if(!was_selected) SymbolSelect(Research_Symbol, false);
   PrintFormat("Research export finished: %d/%d API-complete timeframe files. Review sidecars, timezone, gaps and historical costs before research.",
               successful, attempted);
}
