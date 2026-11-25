#property strict
#property description "Offline chart replay of captured broker candles and the production DNN. No trade requests."
#include "../Include/ICTAnalyticalChartRenderer.mqh"

int ReplayReadRates(const string symbol,const string timeframe,MqlRates &rates[])
  {
   ArrayResize(rates,0);
   int file=FileOpen("AnalysisReplayInputs\\"+symbol+"_"+timeframe+".csv",FILE_READ|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(file==INVALID_HANDLE) return 0;
   for(int i=0;i<8;i++) FileReadString(file);
   ArrayResize(rates,6000); int n=0;
   while(!FileIsEnding(file) && n<6000)
     {
      MqlRates bar; ZeroMemory(bar); bar.time=(datetime)FileReadNumber(file);
      bar.open=FileReadNumber(file); bar.high=FileReadNumber(file); bar.low=FileReadNumber(file); bar.close=FileReadNumber(file);
      bar.tick_volume=(long)FileReadNumber(file); bar.spread=(int)FileReadNumber(file); bar.real_volume=(long)FileReadNumber(file);
      if(bar.time>0) rates[n++]=bar;
     }
   FileClose(file); ArrayResize(rates,n); return n;
  }
void ReplayOne(const string symbol,const double point,const int digits,const int report)
  {
   MqlRates rates[],upper[],middle[];
   int n=ReplayReadRates(symbol,"M5",rates);
   if(n<2000 || ReplayReadRates(symbol,"H1",middle)<60 || ReplayReadRates(symbol,"D1",upper)<60)
     { FileWrite(report,symbol,"MISSING_INPUT",0,0,0,0,0,0,false,false); FileFlush(report); return; }
   int fit_count=n-64; MqlRates training[]; ArrayResize(training,fit_count); ArrayCopy(training,rates,0,0,fit_count);
   SICTStatConfig config; ICTStatDefaultConfig(config); SICTStatSample samples[];
   SICTStatModel model; SICTStatSnapshot forecast; ZeroMemory(model); ZeroMemory(forecast);
   if(!ICTStatBuildSamples(training,point,config,samples) || !ICTStatPrepare(config,samples,model,forecast))
     { FileWrite(report,symbol,"PREPARE_FAILED",0,0,0,0,0,0,false,false); FileFlush(report); return; }
   int steps=0;
   while(ICTStatTrainStep(model,samples,forecast)) if(++steps>20000 || IsStopped()) return;
   if(!ICTStatFinish(model,samples,forecast))
     { FileWrite(report,symbol,"TRAIN_FAILED",0,0,0,0,0,0,false,false); FileFlush(report); return; }
   string custom="ICTR_"+symbol;
   bool is_custom=false;
   if(!SymbolExist(custom,is_custom))
     { if(!CustomSymbolCreate(custom,"ICTReplay")) { Print("Replay custom symbol error ",GetLastError()); return; } }
   else if(!is_custom) return;
   CustomSymbolSetInteger(custom,SYMBOL_DIGITS,digits); CustomSymbolSetDouble(custom,SYMBOL_POINT,point);
   CustomSymbolSetDouble(custom,SYMBOL_TRADE_TICK_SIZE,point); CustomSymbolSetInteger(custom,SYMBOL_TRADE_MODE,SYMBOL_TRADE_MODE_DISABLED);
   // Sparse M1 storage preserves each original M5 OHLC when viewed at M5.
   // This is chart rendering only and does not invent intrabar tick paths.
   if(CustomRatesReplace(custom,rates[0].time,rates[n-1].time,rates,n)<0 || !SymbolSelect(custom,true)) return;
   long chart=ChartOpen(custom,PERIOD_M5); if(chart<=0) { Print("Replay ChartOpen error ",GetLastError()); return; }
   ChartSetInteger(chart,CHART_COLOR_BACKGROUND,clrWhite); ChartSetInteger(chart,CHART_COLOR_FOREGROUND,clrBlack);
   ChartSetInteger(chart,CHART_COLOR_CANDLE_BULL,clrSeaGreen); ChartSetInteger(chart,CHART_COLOR_CANDLE_BEAR,clrIndianRed);
   ChartSetInteger(chart,CHART_MODE,CHART_CANDLES); ChartSetInteger(chart,CHART_SHOW_GRID,false);
   ChartSetInteger(chart,CHART_AUTOSCROLL,false); ChartSetInteger(chart,CHART_SHIFT,true); ChartSetInteger(chart,CHART_SCALE,3);
   ChartNavigate(chart,CHART_END,0);
   SICTAnalyticalPolicy policy; ICTAnalyticalPolicyDefaults(policy); int signals=0,experimental=0;
   for(int i=fit_count;i<n;i++)
     {
      datetime asof=ICTBarClose(PERIOD_M5,rates[i].time);
      SICTStatSample sample;
      if(!ICTStatFeatures(rates,i,point,sample) || !ICTStatPredict(model,sample,forecast)) continue;
      SICTAnalyticalContext context; ZeroMemory(context); context.symbol=symbol; context.valid=true;
      context.ltf=PERIOD_M5; context.mtf=PERIOD_H1; context.htf=PERIOD_D1; context.asof=asof; context.ltf_closed=asof;
      SMarketStructure high,mid;
      ICTAnalyticalStructureAt(upper,PERIOD_D1,asof,60,2,2,high,context.htf_closed);
      ICTAnalyticalStructureAt(middle,PERIOD_H1,asof,60,2,2,mid,context.mtf_closed);
      context.htf_bias=high.bias; context.mtf_bias=mid.bias;
      SICTAnalyticalVotes votes; ZeroMemory(votes); double atr=0;
      if(!ICTAnalyticalPriceVotes(rates,PERIOD_M5,asof,point,votes,atr)) continue;
      SICTAnalyticalDeepState deep; SICTAnalyticalResult result;
      ICTAnalyticalDeepEvidence(model,forecast,rates,PERIOD_M5,PERIOD_M5,asof,point,deep,votes);
      if(!ICTAnalyticalEvaluateEarly(policy,context,votes,deep,result)) continue;
      string details="DL REPLAY | "+symbol+" | "+TimeToString(asof,TIME_DATE|TIME_MINUTES)+"\n"+deep.reason+"\n"+result.reason;
      if(ICTAnalyticalChartMark(chart,"ICT_DL_REPLAY_"+IntegerToString((long)rates[i].time),rates[i],atr,result,details))
        { signals++; if(result.experimental) experimental++; }
     }
   ICTAnalyticalChartBadge(chart,"ICT_REPLAY_INFO_","REAL MT5 CANDLES / M5 / DNN 32-12-6-3 / OFFLINE REPLAY",
      symbol+" | DL arrows "+IntegerToString(signals)+" | experimental "+IntegerToString(experimental)+" | no trade execution",true);
   ChartRedraw(chart); Sleep(500);
   string screenshot="AnalysisReplayEvidence\\"+symbol+"_M5_DL.png";
   bool captured=ChartScreenShot(chart,screenshot,1280,800,ALIGN_RIGHT);
   for(int wait=0;wait<30 && captured && !FileIsExist(screenshot);wait++) Sleep(100);
   FileWrite(report,symbol,"OK",signals,experimental,model.train_n,model.cal_n,model.test_n,forecast.brier_dl,
      forecast.brier_baseline,captured && FileIsExist(screenshot)); FileFlush(report);
   PrintFormat("DL_CHART_REPLAY %s signals=%d experimental=%d screenshot=%d",symbol,signals,experimental,(int)(captured && FileIsExist(screenshot)));
  }
void OnStart()
  {
   FolderCreate("AnalysisReplayEvidence");
   int report=FileOpen("AnalysisReplayEvidence\\native-results.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(report==INVALID_HANDLE) return;
   FileWrite(report,"symbol","status","signals","experimental","train","calibration","test","brier_dl","brier_prior","screenshot"); FileFlush(report);
   int metadata=FileOpen("AnalysisReplayInputs\\symbols.csv",FILE_READ|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(metadata==INVALID_HANDLE) { FileClose(report); return; }
   for(int i=0;i<3;i++) FileReadString(metadata);
   while(!FileIsEnding(metadata) && !IsStopped())
     {
      string symbol=FileReadString(metadata); double point=FileReadNumber(metadata); int digits=(int)FileReadNumber(metadata);
      if(symbol!="" && point>0) ReplayOne(symbol,point,digits,report);
     }
   FileClose(metadata); FileClose(report);
   int completed=FileOpen("AnalysisReplayEvidence\\completed.txt",FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(completed!=INVALID_HANDLE) { FileWriteString(completed,"DL_CHART_REPLAY_COMPLETED"); FileClose(completed); }
  }
