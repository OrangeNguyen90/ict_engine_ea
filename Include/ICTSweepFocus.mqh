#ifndef ICT_SWEEP_FOCUS_MQH
#define ICT_SWEEP_FOCUS_MQH
#include "ICTRangeTypes.mqh"
#include "ICTBarSnapshot.mqh"
#include "ICTStatisticalLearning.mqh"

#define ICT_SWEEP_FOCUS_H1_BARS 120

// A read-only explanation of an EXISTING native liquidity event. This module
// neither discovers replacement pools nor changes the engine's MSS/risk gates.
enum ENUM_ICT_FOCUS_MSS { ICT_FOCUS_WAIT=0, ICT_FOCUS_MSS, ICT_FOCUS_BOS,
   ICT_FOCUS_WEAK_BREAK, ICT_FOCUS_EXPIRED, ICT_FOCUS_INVALIDATED,
   ICT_FOCUS_NO_SWING, ICT_FOCUS_PREBROKEN };
struct SICTSweepFocusConfig
  {
   int left,right,max_bars;
   bool require_displacement;
   double buffer_ticks,body_atr,body_fraction;
  };
struct SICTSweepFocus
  {
   bool valid,forecast_ready,forecast_calibrated,h1_ready;
   SICTRangeLiquidityEvent event;
   ENUM_ICT_FOCUS_MSS status;
   datetime anchor_time,pivot_time,mss_time,mss_confirmed_at,forecast_asof,h1_closed_at;
   double pivot_level,mss_close,body_ratio,atr,ml[3],dl[3];
   int prior_bias,closed_after,h1_bias;
   string forecast_reason;
  };

bool ICTSweepFocusEligible(const SICTRangeLiquidityEvent &e,const datetime asof,
                          const datetime oldest,const ENUM_TIMEFRAMES tf,
                          const bool show_irl,const bool show_erl)
  {
   bool external=e.membership==IR_BOUNDARY || e.membership==IR_OUTSIDE;
   return e.type==IR_EVENT_LIQUIDITY_SWEEP && (e.side==1 || e.side==-1) &&
      e.id!="" && e.event_tf==tf && e.bar_time>=oldest && e.wick_time>0 &&
      e.wick_time<=e.bar_time && e.confirmed_at>e.bar_time && e.confirmed_at<=asof &&
      MathIsValidNumber(e.level) && MathIsValidNumber(e.wick) && MathIsValidNumber(e.close) &&
      e.level>0 && (e.wick-e.level)*e.side>0 &&
      (external ? show_erl : e.membership==IR_INTERNAL && show_irl);
  }

// Freeze the H1 structure at reclaim, using the same confirmed-swing detector.
// Later H1 candles (including malformed future OHLC) cannot re-rank this event.
bool ICTSweepFocusH1Context(const MqlRates &bars[],const int count,
                            const int left,const int right,SICTSweepFocus &v)
  {
   v.h1_ready=false; v.h1_bias=0; v.h1_closed_at=0;
   if(!v.valid || v.event.confirmed_at<=0 || count<1 || count>ArraySize(bars) ||
      ArrayGetAsSeries(bars)) return false;
   int n=ICTClosedPrefix(bars,count,PERIOD_H1,v.event.confirmed_at);
   if(n<ICT_SWEEP_FOCUS_H1_BARS) return false;
   datetime closed=ICTBarClose(PERIOD_H1,bars[n-1].time);
   // A missing most-recent H1 bar must not reuse an old directional bias.
   if(closed<=0 || v.event.confirmed_at-closed>=PeriodSeconds(PERIOD_H1)) return false;
   MqlRates window[]; ArrayResize(window,ICT_SWEEP_FOCUS_H1_BARS);
   if(ArrayCopy(window,bars,0,n-ICT_SWEEP_FOCUS_H1_BARS,ICT_SWEEP_FOCUS_H1_BARS)!=ICT_SWEEP_FOCUS_H1_BARS)
      return false;
   SMarketStructure structure;
   if(!SRMPAnalyzeStructureFromRates(window,ICT_SWEEP_FOCUS_H1_BARS,left,right,structure)) return false;
   v.h1_ready=true; v.h1_bias=structure.bias; v.h1_closed_at=closed;
   return true;
  }

bool ICTSweepFocusAlignedH1(const SICTSweepFocus &v)
  { return v.valid && v.h1_ready && (v.event.side==1 || v.event.side==-1) && v.h1_bias==-v.event.side; }

bool ICTSweepFocusPrefer(const SICTSweepFocus &candidate,const SICTSweepFocus &current,
                         const bool prefer_h1)
  {
   if(!candidate.valid) return false;
   if(!current.valid) return true;
   bool aligned=ICTSweepFocusAlignedH1(candidate),other=ICTSweepFocusAlignedH1(current);
   if(prefer_h1 && aligned!=other) return aligned;
   if(candidate.event.confirmed_at!=current.event.confirmed_at)
      return candidate.event.confirmed_at>current.event.confirmed_at;
   return PeriodSeconds(candidate.event.source_tf)>PeriodSeconds(current.event.source_tf);
  }

bool ICTSweepFocusAnalyze(const MqlRates &r[],const int count,
                         const SICTRangeLiquidityEvent &e,const datetime asof,
                         const int seconds,const double tick,const SICTSweepFocusConfig &c,
                         SICTSweepFocus &v)
  {
   ZeroMemory(v); v.event=e; v.status=ICT_FOCUS_NO_SWING;
   if(seconds<=0 || !MathIsValidNumber(tick) || tick<=0 ||
      c.left<1 || c.right<1 || c.max_bars<1 || c.max_bars>100 ||
      !MathIsValidNumber(c.buffer_ticks) || c.buffer_ticks<0 ||
      !MathIsValidNumber(c.body_atr) || c.body_atr<=0 ||
      !MathIsValidNumber(c.body_fraction) || c.body_fraction<=0 || c.body_fraction>1 ||
      !ICTSweepFocusEligible(e,asof,1,e.event_tf,true,true) ||
      count<1 || count>ArraySize(r) || ArrayGetAsSeries(r)) return false;
   int wick=-1,confirmation=-1,last=-1;
   for(int i=0;i<count;i++)
     {
      if(r[i].time+seconds>asof) break; // Never inspect the forming candle.
      last=i;
      if(r[i].time==e.wick_time) wick=i;
      if(r[i].time==e.bar_time) confirmation=i;
     }
   if(wick<15 || confirmation<wick || last<confirmation || !SRMPValidDetectorRates(r,last+1) ||
      e.confirmed_at<r[confirmation].time+seconds) return false;
   // Verify the native record against this history; reject revised OHLC.
   double actual_wick=(e.side>0 ? r[wick].high : r[wick].low);
   if(MathAbs(actual_wick-e.wick)>tick*0.51 ||
      MathAbs(r[confirmation].close-e.close)>tick*0.51 ||
      (e.close-e.level)*e.side>=0) return false;
   v.valid=true; v.atr=ICTStatATR(r,wick);
   v.anchor_time=r[(int)MathMax(0,wick-20)].time;
   // The segment marks the same native level. Prefer a real earlier touch;
   // otherwise its left endpoint is just a bounded visual extension.
   double tolerance=MathMax(tick*2,v.atr*0.02);
   for(int p=wick-1;p>=MathMax(0,wick-80);p--)
      if(MathAbs((e.side>0 ? r[p].high : r[p].low)-e.level)<=tolerance)
        { v.anchor_time=r[p].time; break; }
   // Freeze the last opposing pivot known BEFORE the sweep wick candle.
   // Using count=wick prevents a later swing from rewriting the MSS level.
   int pivot=-1;
   for(int p=wick-c.right-1;p>=c.left;p--)
      if(SRMPConfirmedSwingAt(r,wick,p,c.left,c.right,e.side<0)) { pivot=p; break; }
   if(pivot<0) return true;
   v.pivot_time=r[pivot].time; v.pivot_level=(e.side>0 ? r[pivot].low : r[pivot].high);
   SMarketStructure structure;
   if(SRMPAnalyzeStructureFromRates(r,wick,c.left,c.right,structure)) v.prior_bias=structure.bias;
   double buffer=c.buffer_ticks*tick;
   for(int i=pivot+c.right+1;i<=confirmation;i++)
      if((r[i].close-v.pivot_level)*(-e.side)>buffer)
        { v.status=ICT_FOCUS_PREBROKEN; return true; }
   v.status=ICT_FOCUS_WAIT;
   int end=(int)MathMin(last,confirmation+c.max_bars);
   for(int i=confirmation+1;i<=end;i++)
     {
      v.closed_after=i-confirmation;
      if((r[i].close-e.wick)*e.side>buffer)
        { v.status=ICT_FOCUS_INVALIDATED; return true; }
      double beyond=(r[i].close-v.pivot_level)*(-e.side);
      double previous=(r[i-1].close-v.pivot_level)*(-e.side);
      if(beyond<=buffer || previous>buffer) continue;
      double atr=ICTStatATR(r,i-1),body=MathAbs(r[i].close-r[i].open),range=r[i].high-r[i].low;
      bool directional=(r[i].close-r[i].open)*(-e.side)>0;
      bool displacement=atr>0 && range>0 && directional && body>=c.body_atr*atr && body/range>=c.body_fraction;
      if(c.require_displacement && !displacement) { v.status=ICT_FOCUS_WEAK_BREAK; continue; }
      v.body_ratio=(atr>0 ? body/atr : 0); v.mss_time=r[i].time;
      v.mss_confirmed_at=r[i].time+seconds; v.mss_close=r[i].close;
      // A break with unknown/aligned prior structure is BOS, not a proven shift.
      v.status=(v.prior_bias==e.side ? ICT_FOCUS_MSS : ICT_FOCUS_BOS); return true;
     }
   if(last-confirmation>=c.max_bars && v.status==ICT_FOCUS_WAIT) v.status=ICT_FOCUS_EXPIRED;
   return true;
  }

bool ICTSweepFocusForecast(const MqlRates &r[],const int count,const double point,
                          const SICTStatModel &model,const ENUM_TIMEFRAMES model_tf,
                          SICTSweepFocus &v)
  {
   v.forecast_ready=false; v.forecast_calibrated=false;
   ArrayInitialize(v.ml,0); ArrayInitialize(v.dl,0);
   if(!v.valid) { v.forecast_reason="Chưa có sweep hợp lệ"; return false; }
   if(model_tf!=v.event.event_tf) { v.forecast_reason="Khung DL khác khung nến sweep"; return false; }
   if(!model.fitted) { v.forecast_reason="Đang chờ mô hình DL học xong"; return false; }
   // train_end/cal_end are the OPEN timestamps of the final label candles.
   // Strictly earlier than the feature candle excludes their future outcomes.
   if(model.train_end<=0 || model.cal_end<model.train_end ||
      model.cal_end>=v.event.bar_time)
     { v.forecast_reason="Train/hiệu chỉnh chưa kết thúc trước sweep"; return false; }
   int index=-1;
   for(int i=0;i<count && i<ArraySize(r);i++) if(r[i].time==v.event.bar_time) { index=i; break; }
   SICTStatSample sample; SICTStatSnapshot prediction;
   if(index<32 || !ICTStatFeatures(r,index,point,sample) || !ICTStatPredict(model,sample,prediction))
     { v.forecast_reason="Thiếu cửa sổ giá tại nến xác nhận sweep"; return false; }
   for(int k=0;k<3;k++) { v.ml[k]=prediction.ml[k]; v.dl[k]=prediction.dl[k]; }
   v.forecast_ready=true; v.forecast_calibrated=model.calibrated;
   v.forecast_asof=v.event.confirmed_at; v.forecast_reason="Dự báo hướng sau nến xác nhận, không phải P(TP trước SL)";
   return true;
  }
#endif
