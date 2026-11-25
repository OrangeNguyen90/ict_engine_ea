#ifndef ICT_STATISTICAL_DASHBOARD_MQH
#define ICT_STATISTICAL_DASHBOARD_MQH
#include "ICTStatisticalLearning.mqh"
#include "ICTRangeEngine.mqh"

input group "ML / DL: local price statistics (both decision EAs)"
input bool ML_Statistics_Enable=true;
input ENUM_TIMEFRAMES ML_Statistics_Timeframe=PERIOD_CURRENT;
input int ML_Statistics_History_Bars=6000;
input int ML_Statistics_Horizon_Bars=4;
input double ML_Statistics_Move_ATR=0.25;
input int ML_Statistics_Minimum_Train=400;
input int ML_Statistics_Minimum_Validation=80;
input int ML_Statistics_Minimum_Pattern=30;
input int ML_Statistics_Retrain_Bars=64;
input int ML_Statistics_Replay_Reserve_Bars=64; // Keep the latest bars after train/calibration/test for causal chart replay.

input group "Native untouched liquidity: first-touch ML / DL (read-only)"
input bool ML_Liquidity_Enable=true;
input bool ML_Liquidity_Show_On_Chart=true; // Keep first-touch result visible when the dashboard panel is hidden.
input int ML_Liquidity_History_Bars=12000;
input int ML_Liquidity_Horizon_Bars=12;
input ENUM_TIMEFRAMES ML_Liquidity_Trend_Timeframe=PERIOD_D1;
input int ML_Liquidity_Minimum_Train=200;
input int ML_Liquidity_Minimum_Validation=50;
input bool ML_Liquidity_Prefer_Long_Trend=true;
input bool ML_Liquidity_Save_Evidence=true; // Sample / validation CSVs in this terminal's MQL5/Files.

SICTStatConfig g_stat_config;
SICTStatModel g_stat_model;
SICTStatSnapshot g_stat_snapshot;
SICTStatSample g_stat_samples[];
ENUM_TIMEFRAMES g_stat_timeframe=PERIOD_CURRENT;
datetime g_stat_fit_bar=0,g_stat_prediction_bar=0;
ulong g_stat_retry_ms=0;
int g_stat_phase=0;

SICTStatConfig g_liq_config;
SICTStatModel g_liq_model;
SICTStatSnapshot g_liq_metrics,g_liq_prediction;
SICTStatLiquidityPair g_liq_pair;
SICTStatLiquidityAudit g_liq_audit;
SICTStatSample g_liq_samples[];
SICTStatLiquidityRecord g_liq_records[];
SICTRangeSnapshot g_liq_native,g_liq_reference;
SICTRangeConfig g_liq_range_config;
CICTRangeEngine g_liq_replay;
MqlRates g_liq_low[],g_liq_high[],g_liq_mid[],g_liq_day[],g_liq_week[],g_liq_month[],g_liq_trend[];
int g_liq_phase=0,g_liq_cursor=32,g_liq_next_sample=32;
datetime g_liq_fit_bar=0;
ulong g_liq_retry_ms=0;
bool g_liq_enabled=false,g_liq_native_parity=false;
string g_liq_reason="Chờ snapshot liquidity native";

void ICTLiquidityClearHistory()
  {
   ArrayResize(g_liq_low,0); ArrayResize(g_liq_high,0); ArrayResize(g_liq_mid,0);
   ArrayResize(g_liq_day,0); ArrayResize(g_liq_week,0); ArrayResize(g_liq_month,0); ArrayResize(g_liq_trend,0);
  }
void ICTLiquidityInit()
  {
   ICTStatDefaultConfig(g_liq_config);
   g_liq_config.history_bars=ML_Liquidity_History_Bars; g_liq_config.horizon=ML_Liquidity_Horizon_Bars;
   g_liq_config.min_train=ML_Liquidity_Minimum_Train; g_liq_config.min_evaluation=ML_Liquidity_Minimum_Validation;
   ZeroMemory(g_liq_model); ZeroMemory(g_liq_metrics); ZeroMemory(g_liq_prediction);
   ZeroMemory(g_liq_native); ZeroMemory(g_liq_reference); ZeroMemory(g_liq_pair); ZeroMemory(g_liq_audit);
   ArrayResize(g_liq_samples,0); ArrayResize(g_liq_records,0); ICTLiquidityClearHistory(); g_liq_replay.Reset();
   g_liq_phase=0; g_liq_cursor=32; g_liq_next_sample=32; g_liq_fit_bar=0; g_liq_retry_ms=0; g_liq_enabled=false;
   g_liq_reason="Chờ snapshot liquidity native"; g_liq_native_parity=false;
  }
void ICTLiquidityObserve(const SICTRangeSnapshot &s,const SICTRangeConfig &c,const bool enabled)
  { g_liq_native=s; g_liq_range_config=c; g_liq_enabled=enabled; }

bool ICTLiquidityCopySeries(const ENUM_TIMEFRAMES tf,const datetime from,const datetime asof,
                           const int warmup,MqlRates &rates[])
  {
   ArrayResize(rates,0); ArraySetAsSeries(rates,false);
   int seconds=PeriodSeconds(tf);
   if(seconds<=0) return false;
   datetime first=(datetime)MathMax(1,(long)from-(long)seconds*warmup*2);
   int n=CopyRates(_Symbol,tf,first,(datetime)(asof-1),rates);
   if(n<warmup) return false;
   for(int i=0;i<n;i++) if(rates[i].time<=0 || (i>0 && rates[i].time<=rates[i-1].time)) return false;
   return true; // OHLC is validated only in the closed historical prefix below.
  }
bool ICTLiquidityStructure(const MqlRates &rates[],const ENUM_TIMEFRAMES tf,const datetime asof,
                           const int lookback,SMarketStructure &s)
  {
   ZeroMemory(s);
   int n=ICTClosedPrefix(rates,ArraySize(rates),tf,asof);
   if(n<lookback) return false;
   MqlRates window[]; ArrayResize(window,lookback);
   if(ArrayCopy(window,rates,0,n-lookback,lookback)!=lookback) return false;
   return SRMPAnalyzeStructureFromRates(window,lookback,g_liq_range_config.left,g_liq_range_config.right,s);
  }
bool ICTLiquidityPriorPeriod(const MqlRates &rates[],const MqlRates &bar,const ENUM_TIMEFRAMES tf,
                             const string prefix,SICTRangeLevel &levels[],int &used)
  {
   int lo=0,hi=ArraySize(rates)-1,at=-1;
   while(lo<=hi)
     { int middle=(lo+hi)/2; if(rates[middle].time<=bar.time) { at=middle; lo=middle+1; } else hi=middle-1; }
   if(at<1 || used+2>ArraySize(levels)) return false;
   // The containing period's OPEN timestamp is known; its future OHLC is not.
   // Reuse the native evidence function with a harmless placeholder for it.
   MqlRates observed[2]; observed[0]=rates[at-1]; ZeroMemory(observed[1]);
   observed[1].time=rates[at].time;
   observed[1].open=1; observed[1].high=1; observed[1].low=1; observed[1].close=1;
   SLiquidityLevelEvidence e;
   if(!SRMPPriorPeriodEvidenceFromRates(observed,2,bar,e)) return false;
   for(int side=-1;side<=1;side+=2)
     {
      ZeroMemory(levels[used]); levels[used].name=prefix+(side>0 ? "H" : "L");
      levels[used].side=side; levels[used].timeframe=tf; levels[used].available_at=e.available_from;
      levels[used].price=(side>0 ? e.high : e.low); used++;
     }
   return true;
  }
bool ICTLiquidityLoadHistory()
  {
   ICTLiquidityClearHistory(); ArraySetAsSeries(g_liq_low,false);
   int n=CopyRates(_Symbol,g_liq_range_config.ltf,1,ML_Liquidity_History_Bars,g_liq_low);
   if(n<1000 || !ICTStatValidRates(g_liq_low)) return false;
   datetime from=g_liq_low[0].time,asof=ICTBarClose(g_liq_range_config.ltf,g_liq_low[n-1].time);
   if(asof!=g_liq_native.as_of) return false;
   bool ok=ICTLiquidityCopySeries(g_liq_range_config.htf,from,asof,g_liq_range_config.lookback,g_liq_high) &&
      ICTLiquidityCopySeries(g_liq_range_config.mtf,from,asof,g_liq_range_config.lookback,g_liq_mid) &&
      ICTLiquidityCopySeries(PERIOD_D1,from,asof,122,g_liq_day) &&
      ICTLiquidityCopySeries(PERIOD_W1,from,asof,3,g_liq_week) &&
      ICTLiquidityCopySeries(PERIOD_MN1,from,asof,3,g_liq_month) &&
      ICTLiquidityCopySeries(ML_Liquidity_Trend_Timeframe,from,asof,120,g_liq_trend);
   if(!ok) return false;
   g_liq_replay.Reset(); ZeroMemory(g_liq_audit); ArrayResize(g_liq_samples,0); ArrayResize(g_liq_records,0);
   g_liq_cursor=32; g_liq_next_sample=32; g_liq_fit_bar=g_liq_low[n-1].time;
   g_liq_reference=g_liq_native; g_liq_native_parity=false;
   return true;
  }
void ICTLiquidityReplayBar(const int i)
  {
   int seconds=PeriodSeconds(g_liq_range_config.ltf),lookback=g_liq_range_config.lookback;
   datetime asof=g_liq_low[i].time+seconds;
   SMarketStructure hs; SMarketStructure ms; SMarketStructure ls;
   if(!ICTLiquidityStructure(g_liq_high,g_liq_range_config.htf,asof,lookback,hs) ||
      !ICTLiquidityStructure(g_liq_mid,g_liq_range_config.mtf,asof,lookback,ms)) return;
   int first=(int)MathMax(0,i+1-lookback);
   MqlRates local[]; ArrayResize(local,i+1-first); ArrayCopy(local,g_liq_low,0,first,i+1-first);
   if(!SRMPAnalyzeStructureFromRates(local,ArraySize(local),g_liq_range_config.left,g_liq_range_config.right,ls)) return;
   SICTDealingRange range;
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(!ICTRangeFromStructure(_Symbol,g_liq_range_config.htf,hs,g_liq_range_config.min_range_ticks*tick,asof,range)) return;
   SICTRangeLevel periods[8]; int used=0;
   if(!ICTLiquidityPriorPeriod(g_liq_day,g_liq_low[i],PERIOD_D1,"PD",periods,used) ||
      !ICTLiquidityPriorPeriod(g_liq_week,g_liq_low[i],PERIOD_W1,"PW",periods,used) ||
      !ICTLiquidityPriorPeriod(g_liq_month,g_liq_low[i],PERIOD_MN1,"PM",periods,used)) return;
   int mn=ICTClosedPrefix(g_liq_mid,ArraySize(g_liq_mid),g_liq_range_config.mtf,asof);
   MqlRates mid[]; ArrayResize(mid,lookback); ArrayCopy(mid,g_liq_mid,0,mn-lookback,lookback);
   SICTRangeConfig replay_config=g_liq_range_config;
   replay_config.log_events=false; replay_config.export_history=false;
   int low_first=(int)MathMax(0,i+1-replay_config.liquidity_seed_bars);
   MqlRates low[]; ArrayResize(low,i+1-low_first); ArrayCopy(low,g_liq_low,0,low_first,i+1-low_first);
   if(!g_liq_replay.Step(_Symbol,replay_config,range,ms,ls,mid,lookback,low,ArraySize(low),periods,used,tick,
      g_liq_low[i].spread*_Point,ICTBarClose(replay_config.htf,hs.recent_high_confirmed_time),
      ICTBarClose(replay_config.htf,hs.recent_low_confirmed_time))) return;
   if(i<g_liq_next_sample || i+g_liq_config.horizon>=ArraySize(g_liq_low)) return;
   g_liq_next_sample=i+g_liq_config.horizon; g_liq_audit.attempted++;
   SICTRangeSnapshot snapshot; g_liq_replay.Snapshot(snapshot);
   SICTStatLiquidityPair pair;
   if(!ICTStatLiquiditySelectPair(snapshot,g_liq_low,i+1,pair,Range_Show_IRL,Range_Show_ERL))
     { g_liq_audit.missing_pair++; return; }
   SMarketStructure trend;
   if(!ICTLiquidityStructure(g_liq_trend,ML_Liquidity_Trend_Timeframe,asof,120,trend))
     { g_liq_audit.missing_trend++; return; }
   pair.trend_bias=trend.bias; pair.trend_closed_at=ICTBarClose(ML_Liquidity_Trend_Timeframe,trend.latest_closed_bar);
   SICTStatSample sample;
   if(!ICTStatLiquidityFeatures(g_liq_low,i,seconds,_Point,pair,sample)) { g_liq_audit.censored++; return; }
   sample.label=ICTStatLiquidityLabel(g_liq_low,ArraySize(g_liq_low),i,g_liq_config.horizon,seconds,pair,sample.label_end);
   if(sample.label==-2) { g_liq_audit.ambiguous++; return; }
   if(sample.label<0) { g_liq_audit.censored++; return; }
   int size=ArraySize(g_liq_samples); ArrayResize(g_liq_samples,size+1); g_liq_samples[size]=sample;
   ArrayResize(g_liq_records,size+1); g_liq_records[size].pair=pair;
   g_liq_records[size].label=sample.label; g_liq_records[size].label_end=sample.label_end;
   g_liq_audit.eligible++;
  }

void ICTLiquiditySaveEvidence()
  {
   if(!ML_Liquidity_Save_Evidence) return;
   string prefix="ICTLiquidity_"+IntegerToString((long)ICTStableHash(_Symbol))+"_"+IntegerToString((int)g_liq_range_config.ltf)+
      "_H"+IntegerToString(g_liq_config.horizon)+"_"+IntegerToString((long)g_liq_fit_bar);
   int file=FileOpen(prefix+"_samples.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(file==INVALID_HANDLE) { Print("First-touch sample export unavailable: ",GetLastError()); return; }
   string header="asof_server,ltf,ssl_id,bsl_id,ssl,bsl,spot,ssl_tf,bsl_tf,ssl_available,bsl_available,trend_tf,trend_bias,trend_closed_at,label,label_end_server";
   for(int k=0;k<32;k++) header+=",x"+IntegerToString(k);
   FileWriteString(file,header+"\r\n");
   for(int i=0;i<ArraySize(g_liq_records);i++)
     {
      SICTStatLiquidityPair p=g_liq_records[i].pair;
      string row=IntegerToString((long)p.asof)+","+IntegerToString((int)g_liq_range_config.ltf)+","+
         ICTRangeCSV(p.ssl_id)+","+ICTRangeCSV(p.bsl_id)+","+DoubleToString(p.ssl,10)+","+DoubleToString(p.bsl,10)+","+
         DoubleToString(p.spot,10)+","+IntegerToString((int)p.ssl_tf)+","+IntegerToString((int)p.bsl_tf)+","+
         IntegerToString((long)p.ssl_available)+","+IntegerToString((long)p.bsl_available)+","+
         IntegerToString((int)ML_Liquidity_Trend_Timeframe)+","+IntegerToString(p.trend_bias)+","+
         IntegerToString((long)p.trend_closed_at)+","+IntegerToString(g_liq_records[i].label)+","+
         IntegerToString((long)g_liq_records[i].label_end);
      for(int k=0;k<32;k++) row+=","+DoubleToString(g_liq_samples[i].x[k],16);
      FileWriteString(file,row+"\r\n");
     }
   FileClose(file);
   file=FileOpen(prefix+"_validation.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(file==INVALID_HANDLE) return;
   FileWrite(file,"key","value"); FileWrite(file,"schema","native-first-touch-v1-conditional-resolved-OHLC");
   FileWrite(file,"symbol",_Symbol); FileWrite(file,"ltf",(int)g_liq_range_config.ltf);
   FileWrite(file,"ea_version","1.07"); FileWrite(file,"range_htf",(int)g_liq_range_config.htf);
   FileWrite(file,"range_mtf",(int)g_liq_range_config.mtf); FileWrite(file,"range_lookback",g_liq_range_config.lookback);
   FileWrite(file,"swing_left",g_liq_range_config.left); FileWrite(file,"swing_right",g_liq_range_config.right);
   FileWrite(file,"horizon",g_liq_config.horizon); FileWrite(file,"trend_tf",(int)ML_Liquidity_Trend_Timeframe);
   FileWrite(file,"asof_server",(long)g_liq_native.as_of); FileWrite(file,"history_bars",g_liq_metrics.history_n);
   FileWrite(file,"attempted",g_liq_audit.attempted); FileWrite(file,"eligible",g_liq_audit.eligible);
   FileWrite(file,"ambiguous_excluded",g_liq_audit.ambiguous); FileWrite(file,"censored_excluded",g_liq_audit.censored);
   FileWrite(file,"missing_pair",g_liq_audit.missing_pair); FileWrite(file,"missing_trend",g_liq_audit.missing_trend);
   FileWrite(file,"train_n",g_liq_metrics.train_n); FileWrite(file,"cal_n",g_liq_metrics.cal_n); FileWrite(file,"test_n",g_liq_metrics.test_n);
   FileWrite(file,"train_label_end",(long)g_liq_model.train_end); FileWrite(file,"cal_asof_start",(long)g_liq_model.cal_start_time);
   FileWrite(file,"cal_label_end",(long)g_liq_model.cal_end); FileWrite(file,"test_asof_start",(long)g_liq_model.test_start_time);
   FileWrite(file,"test_label_end",(long)g_liq_model.test_end); FileWrite(file,"calibrated",g_liq_model.calibrated);
   FileWrite(file,"brier_ml",g_liq_metrics.brier_ml); FileWrite(file,"brier_dl",g_liq_metrics.brier_dl);
   FileWrite(file,"brier_combined",g_liq_metrics.brier_combined); FileWrite(file,"brier_prior",g_liq_metrics.brier_baseline);
   FileWrite(file,"brier_geometry",g_liq_audit.brier_geometry); FileWrite(file,"log_loss",g_liq_audit.log_loss);
   FileWrite(file,"ece_10_bins",g_liq_audit.ece); FileWrite(file,"validation_pass",g_liq_audit.validation_pass);
   FileWrite(file,"native_pair_parity",g_liq_native_parity);
   FileWrite(file,"ohlc_source","Connected MT5 history; Bid/session provenance not independently certified");
   FileWrite(file,"scope","One chronological holdout; conditional on OHLC-resolvable labels; no economic validation");
   FileClose(file);
  }

bool ICTLiquidityPredict()
  {
   g_liq_prediction.ready=false; ZeroMemory(g_liq_pair);
   if(!g_liq_enabled || !g_liq_native.valid || !g_liq_native.range.valid)
     { g_liq_reason="Chờ snapshot liquidity native hợp lệ"; return false; }
   if(!g_liq_model.fitted) return false;
   if(!g_liq_audit.validation_pass || !g_liq_native_parity)
     { g_liq_reason="Chưa vượt cả prior và đối chứng khoảng cách / chưa đủ lớp hiệu chỉnh, kiểm định"; return false; }
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   int n=CopyRates(_Symbol,g_liq_native.ltf,1,ML_Liquidity_History_Bars,rates);
   if(n<33 || !ICTStatLiquiditySelectPair(g_liq_native,rates,n,g_liq_pair,Range_Show_IRL,Range_Show_ERL))
     { g_liq_reason="Chưa có đủ hai mức SSL / BSL chưa chạm, có lịch sử liên tục bao phủ"; return false; }
   MqlRates trend[];
   if(!ICTLiquidityCopySeries(ML_Liquidity_Trend_Timeframe,g_liq_native.as_of,g_liq_native.as_of,120,trend))
     { g_liq_reason="Chờ 120 nến xu hướng dài hạn đã đóng"; return false; }
   SMarketStructure context;
   if(!ICTLiquidityStructure(trend,ML_Liquidity_Trend_Timeframe,g_liq_native.as_of,120,context))
     { g_liq_reason="Chưa có cấu trúc xu hướng dài hạn hợp lệ"; return false; }
   g_liq_pair.trend_bias=context.bias;
   g_liq_pair.trend_closed_at=ICTBarClose(ML_Liquidity_Trend_Timeframe,context.latest_closed_bar);
   SICTStatSample sample;
   if(g_liq_model.test_end>=g_liq_native.as_of ||
      !ICTStatLiquidityFeatures(rates,n-1,PeriodSeconds(g_liq_native.ltf),_Point,g_liq_pair,sample) ||
      !ICTStatLiquidityInSupport(g_liq_model,sample) ||
      !ICTStatPredict(g_liq_model,sample,g_liq_prediction))
     { g_liq_reason="Chờ LTF liên tục sau kiểm định và đặc trưng trong miền train (5 độ lệch chuẩn)"; return false; }
   // A target hit after the snapshot is no longer an untouched future target.
   MqlRates forming[]; ArraySetAsSeries(forming,false);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int current=CopyRates(_Symbol,g_liq_native.ltf,0,1,forming);
   if(!MathIsValidNumber(bid) || bid<=g_liq_pair.ssl || bid>=g_liq_pair.bsl || current!=1 ||
      forming[0].time!=g_liq_native.as_of || forming[0].high>=g_liq_pair.bsl || forming[0].low<=g_liq_pair.ssl)
     {
      g_liq_prediction.ready=false;
      g_liq_reason="Mức đã chạm trong nến đang chạy hoặc quote / nến hiện tại chưa đồng bộ"; return false;
     }
   g_liq_reason="Ước lượng first-touch của cặp mức cố định tại nến đóng; không phải xác suất lợi nhuận";
   return true;
  }

bool ICTLiquidityPump()
  {
   if(!ML_Liquidity_Enable || !g_liq_enabled) { g_liq_prediction.ready=false; return false; }
   if(!ICTStatValidConfig(g_liq_config) || PeriodSeconds(ML_Liquidity_Trend_Timeframe)<=PeriodSeconds(g_liq_range_config.ltf) ||
      ML_Liquidity_Trend_Timeframe==PERIOD_CURRENT || g_liq_range_config.htf==PERIOD_MN1)
     { g_liq_prediction.ready=false; g_liq_reason="Kiểm tra Inputs first-touch / khung xu hướng phải lớn hơn LTF"; return false; }
   ulong now=GetTickCount64();
   if(g_liq_phase==0)
     {
      if(!g_liq_native.valid || !g_liq_native.range.valid ||
         (g_liq_retry_ms>0 && now-g_liq_retry_ms<5000)) return false;
      g_liq_retry_ms=now; g_liq_prediction.ready=false;
      if(!ICTLiquidityLoadHistory())
        { g_liq_reason="Đang tải lịch sử LTF / HTF / D1 / W1 / MN1 cho replay native"; return true; }
      g_liq_phase=1; g_liq_reason="Đang tái dựng pool native theo thời gian; chưa có xác suất";
      return true;
     }
   if(g_liq_phase==1)
     {
      while(g_liq_cursor<ArraySize(g_liq_low) && GetTickCount64()-now<20)
        { ICTLiquidityReplayBar(g_liq_cursor); g_liq_cursor++; }
      if(g_liq_cursor<ArraySize(g_liq_low)) return true;
      SICTRangeSnapshot replayed; g_liq_replay.Snapshot(replayed);
      SICTStatLiquidityPair observed_pair; SICTStatLiquidityPair replay_pair;
      ICTStatLiquiditySelectPair(g_liq_reference,g_liq_low,ArraySize(g_liq_low),observed_pair,Range_Show_IRL,Range_Show_ERL);
      ICTStatLiquiditySelectPair(replayed,g_liq_low,ArraySize(g_liq_low),replay_pair,Range_Show_IRL,Range_Show_ERL);
      g_liq_native_parity=replayed.valid && replayed.as_of==g_liq_reference.as_of &&
         ICTStatLiquiditySamePair(observed_pair,replay_pair);
      bool prepared=ICTStatPrepare(g_liq_config,g_liq_samples,g_liq_model,g_liq_metrics);
      g_liq_metrics.history_n=ArraySize(g_liq_low);
      g_liq_metrics.timeframe=ICTStatTimeframeText(g_liq_range_config.ltf);
      ICTLiquidityClearHistory();
      if(!g_liq_native_parity)
        { g_liq_phase=4; g_liq_reason="Cặp pool replay khác snapshot native; chưa phát hành xác suất"; ICTLiquiditySaveEvidence(); }
      else if(!prepared)
        { g_liq_phase=4; g_liq_reason=g_liq_metrics.reason; ICTLiquiditySaveEvidence(); }
      else { g_liq_phase=2; g_liq_reason="Đang học logistic + DNN riêng cho thứ tự chạm SSL / BSL"; }
      return true;
     }
   if(g_liq_phase==2)
     {
      while(GetTickCount64()-now<20)
        {
         if(!ICTStatTrainStep(g_liq_model,g_liq_samples,g_liq_metrics))
           {
            if(!ICTStatFinish(g_liq_model,g_liq_samples,g_liq_metrics))
              { g_liq_phase=4; g_liq_reason="Huấn luyện first-touch không hợp lệ; không xuất xác suất"; }
            else
              {
               ICTStatLiquidityAuditModel(g_liq_model,g_liq_samples,g_liq_metrics,g_liq_audit);
               ICTLiquiditySaveEvidence(); g_liq_phase=3; ICTLiquidityPredict();
              }
            return true;
           }
        }
      return true;
     }
   int age=iBarShift(_Symbol,g_liq_range_config.ltf,g_liq_fit_bar,true);
   if(age<0 || age-1>=g_liq_config.retrain_bars)
     { g_liq_phase=0; g_liq_retry_ms=0; g_liq_prediction.ready=false; return true; }
   if(g_liq_phase==3) { ICTLiquidityPredict(); return true; }
   return false;
  }

string ICTLiquidityProbabilities(const double &p[])
  { return "BSL trước "+ICTStatPercent(p[0])+" | SSL trước "+ICTStatPercent(p[1])+" | chưa chạm "+ICTStatPercent(p[2]); }
string ICTLiquidityDashboardBody()
  {
   if(!ML_Liquidity_Enable) return "";
   string body="[SSL / BSL UNTOUCH: MỨC NÀO CHẠM TRƯỚC?]\n";
   body+=ICTStatTimeframeText(g_liq_range_config.ltf)+" | H="+IntegerToString(g_liq_config.horizon)+" nến đóng | xu hướng "+
      ICTStatTimeframeText(ML_Liquidity_Trend_Timeframe)+"\n";
   body+="Ước lượng trên các mẫu OHLC xác định được thứ tự chạm.\n";
   if(g_liq_pair.valid)
     {
      body+="SSL "+DoubleToString(g_liq_pair.ssl,_Digits)+" | BSL "+DoubleToString(g_liq_pair.bsl,_Digits)+"\n";
      body+="Xu hướng dài hạn: "+(g_liq_pair.trend_closed_at<=0 ? "chưa có" : g_liq_pair.trend_bias>0 ? "Tăng" :
         g_liq_pair.trend_bias<0 ? "Giảm" : "Trung tính")+"\n";
     }
   if(!g_liq_prediction.ready)
     {
      body+=g_liq_reason+"\n";
      if(g_liq_phase==1) body+="Replay "+IntegerToString(g_liq_cursor)+" / "+IntegerToString(ArraySize(g_liq_low))+" nến\n";
      if(g_liq_phase==2) body+="Tiến độ học: "+IntegerToString(g_liq_metrics.progress)+"%\n";
     }
   else
     {
      body+="Kết hợp: "+ICTLiquidityProbabilities(g_liq_prediction.combined)+"\n";
      body+="ML logistic: "+ICTLiquidityProbabilities(g_liq_prediction.ml)+"\n";
      body+="DL 32-12-6-3: "+ICTLiquidityProbabilities(g_liq_prediction.dl)+"\n";
      int best=ICTStatArgmax(g_liq_prediction.combined),direction=(best==0 ? 1 : best==1 ? -1 : 0);
      if(direction==0) body+="Chưa chạm trong H nến đang là lớp lớn nhất; chờ.\n";
      else if(ML_Liquidity_Prefer_Long_Trend && direction!=g_liq_pair.trend_bias)
         body+="Chưa ưu tiên: xác suất lệch / xu hướng dài hạn chưa đồng thuận.\n";
      else body+="Ưu tiên tham khảo: "+(direction>0 ? "BSL phía trên" : "SSL phía dưới")+"\n";
      body+="Nến gốc: "+TimeToString(g_liq_prediction.asof,TIME_DATE|TIME_MINUTES)+" (server)\n";
     }
   body+="Mẫu: "+IntegerToString(g_liq_audit.eligible)+" / "+IntegerToString(g_liq_audit.attempted)+
      " | cả hai cùng nến: "+IntegerToString(g_liq_audit.ambiguous)+" | thiếu đường giá: "+IntegerToString(g_liq_audit.censored)+"\n";
   body+="Train / hiệu chỉnh / kiểm định: "+IntegerToString(g_liq_metrics.train_n)+" / "+IntegerToString(g_liq_metrics.cal_n)+" / "+IntegerToString(g_liq_metrics.test_n)+"\n";
   if(g_liq_model.fitted)
     {
      body+="Brier kết hợp / prior / khoảng cách: "+DoubleToString(g_liq_metrics.brier_combined,3)+" / "+
         DoubleToString(g_liq_metrics.brier_baseline,3)+" / "+DoubleToString(g_liq_audit.brier_geometry,3)+"\n";
      body+="Log loss "+DoubleToString(g_liq_audit.log_loss,3)+" | ECE "+DoubleToString(g_liq_audit.ece,3)+"\n";
     }
   body+="Xác suất có điều kiện trên mẫu OHLC xác định được thứ tự; chưa bao gồm mẫu mơ hồ.\n";
   body+="Hai mức cố định lúc dự báo. Loại nến chạm cả hai không rõ thứ tự và gap chưa phân loại.\n";
   body+="Tham khảo trên một đoạn kiểm định thời gian; chưa chứng minh lợi thế giao dịch / P(TP trước SL).\n";
   return body;
  }

string ICTStatTimeframeText(const ENUM_TIMEFRAMES tf)
  { string text=EnumToString(tf); StringReplace(text,"PERIOD_",""); return text; }
void ICTStatInit()
  {
   ICTLiquidityInit();
   ICTStatDefaultConfig(g_stat_config);
   g_stat_config.history_bars=ML_Statistics_History_Bars;
   g_stat_config.horizon=ML_Statistics_Horizon_Bars;
   g_stat_config.move_atr=ML_Statistics_Move_ATR;
   g_stat_config.min_train=ML_Statistics_Minimum_Train;
   g_stat_config.min_evaluation=ML_Statistics_Minimum_Validation;
   g_stat_config.min_pattern=ML_Statistics_Minimum_Pattern;
   g_stat_config.retrain_bars=ML_Statistics_Retrain_Bars;
   g_stat_timeframe=(ML_Statistics_Timeframe==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : ML_Statistics_Timeframe);
   ZeroMemory(g_stat_model); ZeroMemory(g_stat_snapshot); ArrayResize(g_stat_samples,0);
   g_stat_phase=0; g_stat_fit_bar=0; g_stat_prediction_bar=0; g_stat_retry_ms=0;
   g_stat_snapshot.timeframe=ICTStatTimeframeText(g_stat_timeframe);
   g_stat_snapshot.horizon=g_stat_config.horizon; g_stat_snapshot.move_atr=g_stat_config.move_atr;
   g_stat_snapshot.status=ML_Statistics_Enable ? "WAITING_HISTORY" : "DISABLED";
   g_stat_snapshot.reason=ML_Statistics_Enable ? "Đang chờ lịch sử nến đóng để học ML/DL" : "Đã tắt thống kê ML/DL";
   if(!ICTStatValidConfig(g_stat_config) || ML_Statistics_Replay_Reserve_Bars<0 || ML_Statistics_Replay_Reserve_Bars>240)
     { g_stat_snapshot.status="INVALID_CONFIG"; g_stat_snapshot.reason="Kiểm tra history / horizon / số mẫu tối thiểu trong Inputs"; }
  }
void ICTStatDeinit()
  { ArrayResize(g_stat_samples,0); ArrayResize(g_liq_samples,0); ArrayResize(g_liq_records,0); ICTLiquidityClearHistory(); }

// Returns true when UI data changed. Model training is bounded to 30 ms per
// timer pulse (plus one calibration/evaluation pass when training completes).
bool ICTStatPump()
  {
   if(!ML_Statistics_Enable || !ICTStatValidConfig(g_stat_config) ||
      ML_Statistics_Replay_Reserve_Bars<0 || ML_Statistics_Replay_Reserve_Bars>240) return false;
   ulong now=GetTickCount64();
   if(g_stat_phase==1)
     {
      while(GetTickCount64()-now<30)
        {
         if(!ICTStatTrainStep(g_stat_model,g_stat_samples,g_stat_snapshot))
           {
            if(!ICTStatFinish(g_stat_model,g_stat_samples,g_stat_snapshot))
              {
               g_stat_snapshot.ready=false; g_stat_snapshot.status="TRAINING_FAILED";
               g_stat_snapshot.reason="Huấn luyện không cho kết quả hữu hạn; chưa có xác suất";
               g_stat_phase=0; g_stat_retry_ms=GetTickCount64(); return true;
              }
            g_stat_phase=2; g_stat_prediction_bar=0;
            ArrayResize(g_stat_samples,0); break;
           }
        }
      if(g_stat_phase==1) return true;
     }
   datetime latest=iTime(_Symbol,g_stat_timeframe,1);
   if(latest<=0)
     {
      g_stat_snapshot.ready=false; g_stat_snapshot.status="WAITING_HISTORY";
      g_stat_snapshot.reason="MT5 chưa có nến đóng cho khung thống kê"; return true;
     }
   int age=(g_stat_fit_bar>0 ? iBarShift(_Symbol,g_stat_timeframe,g_stat_fit_bar,true) : -1);
   bool retrain=g_stat_phase==0 || (g_stat_phase==2 && (age<0 || age-1>=g_stat_config.retrain_bars));
   if(retrain)
     {
      if(g_stat_retry_ms>0 && now-g_stat_retry_ms<5000) return false;
      g_stat_retry_ms=now;
      MqlRates rates[]; ArraySetAsSeries(rates,false);
      // start_pos=1 excludes the forming candle; physical order is oldest first.
      int copied=CopyRates(_Symbol,g_stat_timeframe,1,g_stat_config.history_bars,rates);
      if(copied<=32 || rates[copied-1].time!=latest)
        {
         g_stat_snapshot.ready=false; g_stat_snapshot.status="WAITING_HISTORY";
         g_stat_snapshot.reason="Đang tải lịch sử MT5; không dùng nến đang hình thành"; return true;
        }
      int fitting_bars=copied-ML_Statistics_Replay_Reserve_Bars;
      if(fitting_bars<=32 || ArrayResize(rates,fitting_bars)!=fitting_bars ||
         !ICTStatBuildSamples(rates,_Point,g_stat_config,g_stat_samples))
        {
         g_stat_snapshot.ready=false; g_stat_snapshot.status="INVALID_HISTORY";
         g_stat_snapshot.reason="Lịch sử thiếu, trùng thời gian hoặc OHLC không hợp lệ"; return true;
        }
      bool prepared=ICTStatPrepare(g_stat_config,g_stat_samples,g_stat_model,g_stat_snapshot);
      g_stat_snapshot.timeframe=ICTStatTimeframeText(g_stat_timeframe); g_stat_snapshot.history_n=copied;
      g_stat_fit_bar=latest; g_stat_prediction_bar=0;
      if(prepared) g_stat_phase=1;
      else { g_stat_phase=0; ArrayResize(g_stat_samples,0); }
      return true;
     }
   if(g_stat_phase!=2 || (latest==g_stat_prediction_bar && g_stat_snapshot.ready)) return false;
   MqlRates recent[]; ArraySetAsSeries(recent,false);
   int copied=CopyRates(_Symbol,g_stat_timeframe,1,64,recent);
   SICTStatSample sample;
   if(copied<=32 || recent[copied-1].time!=latest || !ICTStatValidRates(recent) ||
      !ICTStatFeatures(recent,copied-1,_Point,sample) || !ICTStatPredict(g_stat_model,sample,g_stat_snapshot))
     {
      g_stat_snapshot.ready=false; g_stat_snapshot.status="MISSING_CURRENT_FEATURES";
      g_stat_snapshot.reason="Chờ cửa sổ nến đóng hiện tại; không giữ dự báo cũ"; return true;
     }
   g_stat_prediction_bar=latest;
   g_stat_snapshot.status=g_stat_snapshot.beats_baseline ? "VALIDATION_BETTER" : "BASELINE_NOT_BEATEN";
   g_stat_snapshot.reason=g_stat_snapshot.beats_baseline ? "Brier thấp hơn tần suất train trên đoạn kiểm định" : "Chưa vượt tần suất train trên đoạn kiểm định";
   return true;
  }
string ICTStatPercent(const double p)
  { return DoubleToString(p*100,1)+"%"; }
string ICTStatProbabilities(const double &p[])
  { return "Tăng "+ICTStatPercent(p[0])+" | Giảm "+ICTStatPercent(p[1])+" | Ngang "+ICTStatPercent(p[2]); }
string ICTStatPatternName(const int k)
  {
   if(k/2==0) return "Quét / lấy lại mức";
   if(k/2==1) return "Nến nhấn chìm";
   if(k/2==2) return "Phá đỉnh / đáy 8 nến";
   return "FVG chạm lại lần đầu";
  }
string ICTStatCurrentPatterns(const int mask)
  {
   string text="";
   for(int k=0;k<8;k++)
      if((mask & (1<<k))!=0) text+=(text!="" ? ", " : "")+ICTStatPatternName(k)+(k%2==0 ? " tăng" : " giảm");
   return text!="" ? text : "Chưa có mẫu trong 4 nhóm được thống kê";
  }
string ICTStatDashboardBody()
  {
   if(!ML_Statistics_Enable) return "";
   SICTStatSnapshot s=g_stat_snapshot;
   string body="[XÁC SUẤT ML / DEEP LEARNING]\n";
   body+=s.timeframe+" | Giá đóng sau "+IntegerToString(s.horizon)+" nến | biên "+DoubleToString(s.move_atr,2)+" ATR + spread\n";
   if(!s.ready)
     {
      body+=s.status+(g_stat_phase==1 ? " "+IntegerToString(s.progress)+"%" : "")+" | "+s.reason+"\n";
      body+="Mẫu train / hiệu chỉnh / kiểm định: "+IntegerToString(s.train_n)+" / "+IntegerToString(s.cal_n)+" / "+IntegerToString(s.test_n)+"\n";
      return body;
     }
   body+="Kết hợp: "+ICTStatProbabilities(s.combined)+"\n";
   body+="ML logistic: "+ICTStatProbabilities(s.ml)+"\n";
   body+="DL 32-12-6-3: "+ICTStatProbabilities(s.dl)+"\n";
   body+=(s.calibrated ? "Đã chọn temperature trên tập hiệu chỉnh riêng" : "Chưa đủ lớp để hiệu chỉnh xác suất")+"\n";
   body+="Mẫu hiện tại: "+ICTStatCurrentPatterns(s.mask)+"\n";
   body+="[KIỂM ĐỊNH THEO THỜI GIAN]\n"+s.reason+"\n";
   body+="Train / hiệu chỉnh / kiểm định: "+IntegerToString(s.train_n)+" / "+IntegerToString(s.cal_n)+" / "+IntegerToString(s.test_n)+"\n";
   body+="Brier ML / DL / kết hợp: "+DoubleToString(s.brier_ml,3)+" / "+DoubleToString(s.brier_dl,3)+" / "+DoubleToString(s.brier_combined,3)+"\n";
   body+="Brier tham chiếu: "+DoubleToString(s.brier_baseline,3)+" (thấp hơn tốt hơn)\n";
   body+="Đúng lớp: "+ICTStatPercent(s.accuracy)+" | đoán lớp nhiều nhất: "+ICTStatPercent(s.baseline_accuracy)+"\n";
   body+="[THỐNG KÊ 4 NHÓM MẪU GIÁ]\n";
   for(int k=0;k<8;k++)
     {
      int n=s.pattern_n[k];
      body+=ICTStatPatternName(k)+(k%2==0 ? " tăng" : " giảm")+" | n="+IntegerToString(n);
      if(n<g_stat_config.min_pattern) body+=" | chưa đủ mẫu\n";
      else
        {
         double low=0,high=0; ICTStatWilson(s.pattern_hits[k],n,low,high);
         body+=" | đúng hướng "+ICTStatPercent((double)s.pattern_hits[k]/n)+" | Wilson 95% "+ICTStatPercent(low)+"–"+ICTStatPercent(high)+"\n";
        }
     }
   body+="Tần suất mô tả trên tập kiểm định; chưa chứng minh lợi thế giao dịch.\n";
   body+="Nguồn OHLC MT5 chưa thẩm định Bid lịch sử; không phải P(TP trước SL), không gồm commission/slippage.\n";
   body+="Nến xác nhận (giờ server): "+TimeToString(s.asof,TIME_DATE|TIME_MINUTES)+"\n";
   body+="Không sửa tín hiệu ICT, lệnh hoặc SL/TP.\n";
   return body;
  }
void ICTStatRenderBadge(const string name,const bool visible,const ENUM_BASE_CORNER corner,
                        const int x,const int y,const int panel_height)
  {
   if((!ML_Statistics_Enable && !ML_Liquidity_Enable) || !visible) { ObjectDelete(0,name); return; }
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   bool bottom=corner==CORNER_LEFT_LOWER || corner==CORNER_RIGHT_LOWER;
   bool right=corner==CORNER_RIGHT_UPPER || corner==CORNER_RIGHT_LOWER;
   bool ready=(ML_Liquidity_Enable ? g_liq_prediction.ready : g_stat_snapshot.ready);
   string text=ML_Liquidity_Enable ? "SSL / BSL | "+ICTStatTimeframeText(g_liq_range_config.ltf)+
      " | H="+IntegerToString(g_liq_config.horizon)+" nến" : "ML/DL giá đóng | "+g_stat_snapshot.timeframe+" | ";
   if(ML_Liquidity_Enable)
     {
      if(ready)
        {
         text+="\nSSL "+DoubleToString(g_liq_pair.ssl,_Digits)+" | BSL "+DoubleToString(g_liq_pair.bsl,_Digits);
         text+="\n"+ICTLiquidityProbabilities(g_liq_prediction.combined);
        }
      else
        {
         string status=(g_liq_phase==1 ? "Replay native "+IntegerToString(g_liq_cursor)+"/"+
            IntegerToString(ArraySize(g_liq_low))+" nến" : g_liq_phase==2 ?
            "Đang học "+IntegerToString(g_liq_metrics.progress)+"%" : g_liq_reason);
         text+="\nChưa có xác suất: "+status;
        }
     }
   else if(g_stat_snapshot.ready)
     {
      int best=ICTStatArgmax(g_stat_snapshot.combined);
      text+=(best==0 ? "Tăng " : best==1 ? "Giảm " : "Đi ngang ")+ICTStatPercent(g_stat_snapshot.combined[best]);
      text+=g_stat_snapshot.beats_baseline ? " | Brier tốt hơn" : " | chưa vượt baseline";
     }
   else text+=g_stat_phase==1 ? "Đang học "+IntegerToString(g_stat_snapshot.progress)+"%" : g_stat_snapshot.status;
   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,bottom ? (right ? ANCHOR_RIGHT_LOWER : ANCHOR_LEFT_LOWER) : (right ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER));
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,(int)MathMax(4,x+8));
   // Keep the badge outside the dashboard: below an upper panel or above a lower one.
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y+panel_height+8);
   color background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   bool dark=ICTChartLuminance(background)<0.179;
   ObjectSetInteger(0,name,OBJPROP_COLOR,ICTChartReadableColor(ready ? clrDodgerBlue : clrDarkOrange,background,dark));
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,ML_Liquidity_Enable ? ICTLiquidityDashboardBody() : ICTStatDashboardBody());
  }

#endif
