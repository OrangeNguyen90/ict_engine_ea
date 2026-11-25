#ifndef ICT_SWEEP_FOCUS_RENDERER_MQH
#define ICT_SWEEP_FOCUS_RENDERER_MQH
#include "ICTSweepFocus.mqh"
#include "ICTRangeRenderer.mqh"
#include "ICTStatisticalDashboard.mqh"

input group "Liquidity sweep: clear annotations / MSS / DL (read-only)"
input bool Sweep_Focus_Enable=true;
input int Sweep_Focus_Maximum=3; // Distinct wick candles, H1 alignment then recency; 1..6.
input int Sweep_Focus_History_Bars=360; // 80..2000 closed candles.
input int Sweep_Focus_Font_Size=10; // Actual size; independent of the old 75% scaling.
input int Sweep_Focus_Arrow_Size=1; // Compact arrows, 1..3; independent of label font.
input bool Sweep_Focus_Prefer_H1=true; // Prioritize sweeps aligned with H1 at reclaim; no trade veto.
input bool Sweep_Focus_Compact_Duplicates=true;
input bool Sweep_Focus_Show_MSS=true;
input int Sweep_Focus_MSS_Window_Bars=12;
input double Sweep_Focus_MSS_Buffer_Ticks=1;
input bool Sweep_Focus_MSS_Require_Displacement=true;

SICTSweepFocus g_sweep_focus[];
string g_sweep_focus_reason="",g_sweep_focus_compact="";

string ICTSweepFocusH1Text(const SICTSweepFocus &v)
  {
   if(!v.h1_ready) return "H1 chưa đủ dữ liệu / cấu trúc";
   if(v.h1_bias==0) return "H1 trung tính";
   return (ICTSweepFocusAlignedH1(v) ? "Thuận H1 " : "Ngược H1 ")+(v.h1_bias>0 ? "tăng" : "giảm");
  }

string ICTSweepFocusState(const SICTSweepFocus &v)
  {
   if(v.status==ICT_FOCUS_MSS) return "MSS "+IRTimeframe(v.event.event_tf)+" "+(v.event.side>0 ? "giảm" : "tăng")+" đã xác nhận";
   if(v.status==ICT_FOCUS_BOS) return "Đã phá swing; chưa đủ xu hướng trước đó để gọi MSS";
   if(v.status==ICT_FOCUS_WEAK_BREAK) return "Phá swing nhưng thiếu displacement";
   if(v.status==ICT_FOCUS_EXPIRED) return "Hết cửa sổ chờ MSS";
   if(v.status==ICT_FOCUS_INVALIDATED) return "Chờ MSS thất bại: đóng vượt cực trị sweep";
   if(v.status==ICT_FOCUS_PREBROKEN) return "Swing đã bị phá trước / ngay nến sweep";
   if(v.status==ICT_FOCUS_NO_SWING) return "Thiếu swing đối diện xác nhận trước sweep";
   return "Chờ MSS sau sweep ("+IntegerToString(v.closed_after)+"/"+IntegerToString(Sweep_Focus_MSS_Window_Bars)+")";
  }
string ICTSweepFocusDL(const SICTSweepFocus &v)
  {
   if(!ML_Statistics_Enable) return "DL: đã tắt trong Inputs";
   if(!v.forecast_ready) return "DL: "+v.forecast_reason;
   return "DL +"+IntegerToString(g_stat_config.horizon)+" nến: "+ICTStatProbabilities(v.dl);
  }
string ICTSweepFocusDetails(const SICTSweepFocus &v)
  {
   SICTRangeLiquidityEvent e=v.event;
   string text=(e.side>0 ? "BSL" : "SSL")+" liquidity sweep | "+IRTimeframe(e.event_tf)+
      " | source "+IRTimeframe(e.source_tf)+" | level "+IRPrice(e.level)+" | wick "+IRPrice(e.wick)+
      "\nNến quét: "+TimeToString(e.wick_time,TIME_DATE|TIME_MINUTES)+
      " | xác nhận reclaim: "+TimeToString(e.confirmed_at,TIME_DATE|TIME_MINUTES)+
      "\n"+ICTSweepFocusState(v)+" | swing "+IRPrice(v.pivot_level);
   if(v.mss_confirmed_at>0) text+=" | close "+TimeToString(v.mss_confirmed_at,TIME_DATE|TIME_MINUTES);
   text+="\n"+ICTSweepFocusH1Text(v)+" tại reclaim";
   if(v.h1_ready) text+=" | H1 đóng: "+TimeToString(v.h1_closed_at,TIME_DATE|TIME_MINUTES);
   text+="\n"+ICTSweepFocusDL(v);
   if(v.forecast_ready)
      text+="\nML đối chứng: "+ICTStatProbabilities(v.ml)+
         (v.forecast_calibrated ? "\nTemperature từ tập hiệu chỉnh riêng" : "\nChưa hiệu chỉnh đủ lớp")+
         "\nDNN dùng đặc trưng OHLC; chưa được huấn luyện riêng với nhãn sweep/MSS native."+
         "\nDự báo hướng sau xác nhận sweep; không phải xác suất sweep đúng / TP trước SL."+
         "\nChấm lại bằng mô hình hiện có; không phải bản ghi dự báo live tại thời điểm đó.";
   return text+"\nNative event: "+e.id+" | pool: "+e.pool_id;
  }

void ICTSweepFocusLine(const string name,const datetime first,const double p1,
                       const datetime last,const double p2,const color ink,
                       const int width,const ENUM_LINE_STYLE style,const string details)
  {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,first,p1,last,p2);
   ObjectMove(0,name,0,first,p1); ObjectMove(0,name,1,last,p2);
   ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false); ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink); ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style); ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,details);
  }

// Called once per native refresh for both EAs. No native snapshot is modified.
void ICTRenderSweepFocus(const string prefix,const SICTRangeSnapshot &s,const bool enabled,
                         const ENUM_TIMEFRAMES display_tf,const int left,const int right,
                         const double displacement_atr,const double displacement_fraction)
  {
   ArrayResize(g_sweep_focus,0); g_sweep_focus_compact=""; g_sweep_focus_reason="";
   string keep[];
   if(!enabled || !Sweep_Focus_Enable)
     { IRReconcileLiquidityObjects(prefix,keep); return; }
   g_sweep_focus_reason="Chưa có liquidity sweep đã xác nhận trong cửa sổ hiển thị";
   if(Sweep_Focus_Maximum<1 || Sweep_Focus_Maximum>6 || Sweep_Focus_History_Bars<80 ||
      Sweep_Focus_History_Bars>2000 || Sweep_Focus_Font_Size<8 || Sweep_Focus_Font_Size>16 ||
      Sweep_Focus_Arrow_Size<1 || Sweep_Focus_Arrow_Size>3 ||
      Sweep_Focus_MSS_Window_Bars<1 || Sweep_Focus_MSS_Window_Bars>100 ||
      !MathIsValidNumber(Sweep_Focus_MSS_Buffer_Ticks) || Sweep_Focus_MSS_Buffer_Ticks<0)
     { g_sweep_focus_reason="Kiểm tra Inputs Sweep_Focus"; IRReconcileLiquidityObjects(prefix,keep); return; }
   if(!s.valid || !s.range.valid)
     { g_sweep_focus_reason="Chờ snapshot liquidity native hợp lệ"; IRReconcileLiquidityObjects(prefix,keep); return; }
   if(s.ltf!=display_tf || s.ltf==PERIOD_MN1)
     { g_sweep_focus_reason="Sweep native "+IRTimeframe(s.ltf)+"; vùng hiển thị "+IRTimeframe(display_tf); IRReconcileLiquidityObjects(prefix,keep); return; }
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   int n=CopyRates(s.symbol,s.ltf,1,Sweep_Focus_History_Bars,rates);
   if(n<80) { g_sweep_focus_reason="Chờ lịch sử nến sweep"; IRReconcileLiquidityObjects(prefix,keep); return; }
   SICTSweepFocusConfig c; c.left=left; c.right=right; c.max_bars=Sweep_Focus_MSS_Window_Bars;
   c.buffer_ticks=Sweep_Focus_MSS_Buffer_Ticks; c.require_displacement=Sweep_Focus_MSS_Require_Displacement;
   c.body_atr=displacement_atr; c.body_fraction=displacement_fraction;
   double tick=SymbolInfoDouble(s.symbol,SYMBOL_TRADE_TICK_SIZE);
   int seconds=PeriodSeconds(s.ltf);
   // Validate before ranking: an inconsistent record cannot occupy a focus slot.
   // Reuse each exact reclaim's H1 history within this refresh for shared pools.
   SICTSweepFocus candidates[];
   for(int i=0;i<s.liquidity_event_count && i<ICT_RANGE_LIQUIDITY_EVENTS;i++)
     {
      SICTRangeLiquidityEvent e=s.liquidity_events[i];
      if(!ICTSweepFocusEligible(e,s.as_of,s.liquidity_display_start,display_tf,Range_Show_IRL,Range_Show_ERL) ||
         (e.sweep_number==1 && !ShowSweep1) ||
         (e.sweep_number==2 && (!ShowSweep2 || !EnableMultiSweepAnalysis)) ||
         (e.sweep_number>2 && (!ShowSweep3Plus || !EnableMultiSweepAnalysis))) continue;
      SICTSweepFocus v;
      if(!ICTSweepFocusAnalyze(rates,n,e,s.as_of,seconds,tick,c,v)) continue;
      int size=ArraySize(candidates),cached=-1;
      for(int j=0;j<size;j++)
         if(candidates[j].event.confirmed_at==e.confirmed_at) { cached=j; break; }
      if(cached>=0)
        {
         v.h1_ready=candidates[cached].h1_ready; v.h1_bias=candidates[cached].h1_bias;
         v.h1_closed_at=candidates[cached].h1_closed_at;
        }
      else
        {
         // H1 has a fixed duration: stop at an open at least one hour before
         // reclaim, so even the history fetch excludes its containing candle.
         MqlRates h1[]; ArraySetAsSeries(h1,false);
         datetime cutoff=e.confirmed_at-PeriodSeconds(PERIOD_H1);
         int copied=CopyRates(s.symbol,PERIOD_H1,cutoff,ICT_SWEEP_FOCUS_H1_BARS,h1);
         ICTSweepFocusH1Context(h1,copied,left,right,v);
        }
      ArrayResize(candidates,size+1); candidates[size]=v;
     }
   string selected="";
   for(int slot=0;slot<Sweep_Focus_Maximum;)
     {
      int best=-1;
      for(int i=0;i<ArraySize(candidates);i++)
        {
         SICTRangeLiquidityEvent e=candidates[i].event;
         if(StringFind(selected,IRLiquidityCandleKey(e.wick_time,e.side))>=0) continue;
         if(best<0) best=i;
         else if(ICTSweepFocusPrefer(candidates[i],candidates[best],Sweep_Focus_Prefer_H1)) best=i;
        }
      if(best<0) break;
      SICTSweepFocus v=candidates[best];
      if(ML_Statistics_Enable) ICTSweepFocusForecast(rates,n,_Point,g_stat_model,g_stat_timeframe,v);
      ArrayResize(g_sweep_focus,slot+1); g_sweep_focus[slot]=v; slot++;
      selected+=IRLiquidityCandleKey(v.event.wick_time,v.event.side);
      string id=prefix+IntegerToString((long)IRLiquidityObjectHash(v.event.id));
      string level=id+"_LEVEL",pool=id+"_POOL",stem=id+"_WICK",arrow=id+"_ARROW",label=id+"_SWEEP";
      color background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
      bool dark=ICTChartLuminance(background)<0.179;
      color ink=ICTChartReadableColor(v.event.side>0 ? clrCrimson : clrSeaGreen,background,dark);
      if(Sweep_Focus_Prefer_H1 && v.h1_ready && v.h1_bias!=0 && !ICTSweepFocusAlignedH1(v))
         ink=ICTChartReadableColor(clrSlateGray,background,dark);
      color level_ink=ICTChartReadableColor(clrDimGray,background,dark);
      string details=ICTSweepFocusDetails(v),side=(v.event.side>0 ? "BSL" : "SSL");
      ICTSweepFocusLine(level,v.anchor_time,v.event.level,v.event.wick_time,v.event.level,level_ink,3,STYLE_SOLID,details);
      ICTSweepFocusLine(stem,v.event.wick_time,v.event.level,v.event.wick_time,v.event.wick,ink,3,STYLE_SOLID,details);
      if(ObjectFind(0,arrow)<0) ObjectCreate(0,arrow,OBJ_ARROW,0,v.event.wick_time,v.event.wick);
      ObjectMove(0,arrow,0,v.event.wick_time,v.event.wick);
      ObjectSetInteger(0,arrow,OBJPROP_ARROWCODE,v.event.side>0 ? 234 : 233);
      ObjectSetInteger(0,arrow,OBJPROP_ANCHOR,v.event.side>0 ? ANCHOR_BOTTOM : ANCHOR_TOP);
      ObjectSetInteger(0,arrow,OBJPROP_COLOR,ink); ObjectSetInteger(0,arrow,OBJPROP_WIDTH,Sweep_Focus_Arrow_Size);
      ObjectSetInteger(0,arrow,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,arrow,OBJPROP_HIDDEN,true);
      ObjectSetString(0,arrow,OBJPROP_TOOLTIP,details);
      RMContextMarker(pool,v.anchor_time,v.event.level,side+" liquidity | "+IRPrice(v.event.level),level_ink);
      RMContextMarker(label,v.event.wick_time,v.event.wick+v.event.side*MathMax(v.atr*0.35,tick*6),
         "Nến sweep "+side+" #"+IntegerToString(v.event.sweep_number)+" | "+IRTimeframe(v.event.event_tf)+
         " | "+ICTSweepFocusH1Text(v),ink);
      ICTChartLabelFont(pool,Sweep_Focus_Font_Size); ICTChartLabelFont(label,Sweep_Focus_Font_Size);
      ObjectSetString(0,pool,OBJPROP_TOOLTIP,details); ObjectSetString(0,label,OBJPROP_TOOLTIP,details);
      IRKeepLiquidityObject(keep,level); IRKeepLiquidityObject(keep,stem); IRKeepLiquidityObject(keep,arrow);
      IRKeepLiquidityObject(keep,pool); IRKeepLiquidityObject(keep,label);
      if(Sweep_Focus_Show_MSS && v.pivot_level>0 && v.status!=ICT_FOCUS_PREBROKEN)
        {
         string line=id+"_MSS_LINE",tag=id+"_MSS";
         bool confirmed=v.status==ICT_FOCUS_MSS || v.status==ICT_FOCUS_BOS;
         datetime end=(confirmed ? v.mss_time : (datetime)MathMin(s.as_of,v.event.confirmed_at+seconds*c.max_bars));
         color mss_ink=ICTChartReadableColor(confirmed ? clrRoyalBlue : clrSlateGray,background,dark);
         ICTSweepFocusLine(line,v.pivot_time,v.pivot_level,end,v.pivot_level,mss_ink,confirmed ? 2 : 1,STYLE_DASH,details);
         string title=v.status==ICT_FOCUS_MSS ? "MSS "+IRTimeframe(v.event.event_tf)+" "+(v.event.side>0 ? "↓" : "↑")+" | close" :
            v.status==ICT_FOCUS_BOS ? "Phá swing | close" : v.status==ICT_FOCUS_WAIT ? "Chờ MSS" :
            v.status==ICT_FOCUS_WEAK_BREAK ? "Thiếu displacement" : v.status==ICT_FOCUS_EXPIRED ? "MSS hết hạn" : "MSS không xác nhận";
         RMContextMarker(tag,end,v.pivot_level,title,mss_ink); ICTChartLabelFont(tag,Sweep_Focus_Font_Size);
         ObjectSetString(0,tag,OBJPROP_TOOLTIP,details); IRKeepLiquidityObject(keep,line); IRKeepLiquidityObject(keep,tag);
        }
     }
   if(Sweep_Focus_Compact_Duplicates) g_sweep_focus_compact=selected;
   IRReconcileLiquidityObjects(prefix,keep);
  }

string ICTSweepFocusDashboardBody()
  {
   if(!Sweep_Focus_Enable || g_sweep_focus_reason=="") return "";
   string body="[SWEEP / MSS THAM KHẢO]\n";
   body+=(Sweep_Focus_Prefer_H1 ? "Ưu tiên thuận H1 tại reclaim; sau đó mới nhất" : "Ưu tiên sweep mới nhất")+"\n";
   if(ArraySize(g_sweep_focus)==0) return body+g_sweep_focus_reason+"\n";
   SICTSweepFocus v=g_sweep_focus[0];
   body+=(v.event.side>0 ? "BSL" : "SSL")+" "+IRTimeframe(v.event.event_tf)+" | mức "+IRPrice(v.event.level)+
      " | nến "+TimeToString(v.event.wick_time,TIME_MINUTES)+"\n";
   body+=ICTSweepFocusH1Text(v)+" tại reclaim"+
      (v.h1_ready ? " | H1 đóng "+TimeToString(v.h1_closed_at,TIME_MINUTES) : "")+"\n";
   body+=ICTSweepFocusState(v)+(v.mss_confirmed_at>0 ? " | "+TimeToString(v.mss_confirmed_at,TIME_MINUTES) : "")+"\n";
   body+=ICTSweepFocusDL(v)+"\n";
   if(v.forecast_ready) body+="Hướng giá sau xác nhận; không phải P(TP trước SL).\n";
   return body;
  }
#endif
