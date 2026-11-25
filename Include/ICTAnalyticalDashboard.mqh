#ifndef ICT_ANALYTICAL_DASHBOARD_MQH
#define ICT_ANALYTICAL_DASHBOARD_MQH
#include "ICTAnalyticalConsensus.mqh"
#include "ICTStatisticalDashboard.mqh"
#include "ICTDecisionEngine.mqh"
#include "DashboardComponents.mqh"
#include "ICTAnalyticalChartRenderer.mqh"

input group "Multi-factor early analysis (advisory)"
input bool Analysis_Enable=true;
input bool Analysis_Show_On_Chart=true;
input double Analysis_Minimum_Score=55; // Evidence score, not a win probability; >50..95.
input int Analysis_Minimum_Groups=2; // Directional groups, 2..6; neutral observations do not dilute the mean.
input int Analysis_Minimum_Supporters=1; // Groups with signed support >=0.1.
input int Analysis_Liquidity_Window_Bars=12; // Elapsed LTF periods; no forward fill across sessions.
input bool Analysis_Require_Deep_Learning=true;
input bool Analysis_Strict_MTF=false; // Early DL analysis may precede MTF agreement; native confirmation is unchanged.
input bool Analysis_Allow_Experimental_DL=true; // Explicitly label and downweight a calibrated DNN that has not beaten prior.
input double Analysis_Minimum_DL_Margin=0.04;
input int Analysis_History_Bars=60; // Reconstruct only bars after the model's evaluation cutoff; 0..120.
input bool Analysis_Export_Diagnostics=true;
input bool Analysis_Save_Chart_Evidence=true; // One chart-only PNG per attachment after DL becomes available.

SICTAnalyticalResult g_analysis_result;
SICTAnalyticalVotes g_analysis_votes;
string g_analysis_deep_reason="";
MqlRates g_analysis_rates[];
double g_analysis_atr=0;
SICTAnalyticalDeepState g_analysis_deep;
SICTAnalyticalContext g_analysis_context;
int g_analysis_left=2,g_analysis_right=2,g_analysis_lookback=60;
datetime g_analysis_history_asof=0,g_analysis_history_train_end=0;
string g_analysis_native_reason="";
ulong g_analysis_last_audit_ms=0;
bool g_analysis_screenshot_saved=false;

void ICTAnalyticalInputs(SICTAnalyticalPolicy &c)
  {
   ICTAnalyticalPolicyDefaults(c); c.minimum_score=Analysis_Minimum_Score; c.minimum_groups=Analysis_Minimum_Groups;
   c.minimum_supporters=Analysis_Minimum_Supporters; c.require_deep=Analysis_Require_Deep_Learning;
   c.strict_context=Analysis_Strict_MTF; c.allow_experimental=Analysis_Allow_Experimental_DL;
   c.minimum_dl_margin=Analysis_Minimum_DL_Margin;
  }
void ICTAnalyticalStart(const SICTAnalyticalContext &context,const SICTRangeSnapshot &range,
                        const SICTUnifiedSnapshot &unified,const bool use_unified)
  {
   ZeroMemory(g_analysis_votes); ZeroMemory(g_analysis_result); ArrayResize(g_analysis_rates,0); g_analysis_atr=0;
   ZeroMemory(g_analysis_deep); g_analysis_context=context;
   g_analysis_deep_reason="Chờ DNN hiệu chỉnh / vượt baseline / đúng nến LTF / feature trong miền train";
   g_analysis_deep.reason=g_analysis_deep_reason;
   if(!Analysis_Enable) return;
   SICTAnalyticalPolicy c; ICTAnalyticalInputs(c);
   if(!ICTAnalyticalPolicyValid(c) || !ICTAnalyticalPriceContextReady(context) ||
      Analysis_History_Bars<0 || Analysis_History_Bars>120 || Analysis_Liquidity_Window_Bars<1 || Analysis_Liquidity_Window_Bars>60)
     { ICTAnalyticalEvaluateEarly(c,context,g_analysis_votes,g_analysis_deep,g_analysis_result); return; }
   datetime latest=iTime(context.symbol,context.ltf,1);
   if(latest<=0 || ICTBarClose(context.ltf,latest)!=context.asof)
     { g_analysis_result.asof=context.asof; g_analysis_result.reason="Chờ snapshot khớp nến LTF đóng mới nhất"; return; }
   if(!ICTCopyClosedAsOf(context.symbol,context.ltf,context.asof,40+Analysis_History_Bars,g_analysis_rates) ||
      !ICTAnalyticalPriceVotes(g_analysis_rates,context.ltf,context.asof,_Point,g_analysis_votes,g_analysis_atr))
     { g_analysis_result.asof=context.asof; g_analysis_result.reason="Chờ 40 nến LTF đóng hợp lệ và ATR"; return; }
   MqlRates bar=g_analysis_rates[ArraySize(g_analysis_rates)-1];
   ICTAnalyticalLiquidityVote(range,context.symbol,context.asof,context.ltf,Analysis_Liquidity_Window_Bars,g_analysis_votes);
   ICTAnalyticalRangeZonesVote(range,context.symbol,context.asof,bar,g_analysis_atr,g_analysis_votes);
   if(use_unified) ICTAnalyticalUnifiedVotes(unified,bar,g_analysis_atr,g_analysis_votes);
   if(ML_Statistics_Enable && ICTAnalyticalDeepEvidence(g_stat_model,g_stat_snapshot,g_analysis_rates,
      g_stat_timeframe,context.ltf,context.asof,_Point,g_analysis_deep,g_analysis_votes))
      g_analysis_deep_reason="DNN 32-12-6-3: "+ICTStatProbabilities(g_stat_snapshot.dl)+
         " | H="+IntegerToString(g_stat_snapshot.horizon)+" nến LTF | "+g_analysis_deep.reason;
   else if(!ML_Statistics_Enable) g_analysis_deep_reason="DL đã tắt trong Inputs";
   else if(!g_stat_snapshot.ready) g_analysis_deep_reason="DL: "+g_stat_snapshot.reason;
   else if(g_stat_timeframe!=context.ltf) g_analysis_deep_reason="DL khác khung LTF; không gộp hai bài toán thời gian";
   if(!g_analysis_deep.ready) g_analysis_deep.reason=g_analysis_deep_reason;
   ICTAnalyticalEvaluateEarly(c,context,g_analysis_votes,g_analysis_deep,g_analysis_result);
  }
void ICTAnalyticalObserveUnified(const SICTUnifiedSnapshot &u,const SICTRangeSnapshot &range,
                                  const int left=2,const int right=2,const int lookback=60)
  {
   SICTAnalyticalContext c; ZeroMemory(c);
   c.symbol=u.symbol; c.asof=u.asof; c.valid=u.symbol!="" && u.frames.status==ICT_MTF_FULL;
   c.ltf=u.frames.ltf; c.mtf=u.frames.mtf; c.htf=u.frames.htf;
   c.ltf_closed=u.asof; c.mtf_closed=u.tiers[1].closed_at; c.htf_closed=u.tiers[2].closed_at;
   c.htf_bias=u.tiers[2].structure.bias; c.mtf_bias=u.tiers[1].structure.bias;
   g_analysis_left=left; g_analysis_right=right; g_analysis_lookback=lookback; g_analysis_native_reason=u.reason;
   ICTAnalyticalStart(c,range,u,true);
  }
void ICTAnalyticalObserveLegacy(const SICTDecision &d,const SICTDecisionConfig &config,
                                const SICTRangeSnapshot &range,const bool range_mode)
  {
   if(!Analysis_Enable) return;
   SICTAnalyticalContext c; ZeroMemory(c);
   c.symbol=d.symbol; c.valid=d.symbol!="";
   c.ltf=range_mode ? range.ltf : config.trigger_tf; c.mtf=range_mode ? range.mtf : config.structure_tf;
   c.htf=range_mode ? range.range.timeframe : config.higher_tf;
   c.asof=range_mode ? range.as_of : ICTBarClose(c.ltf,d.as_of);
   c.htf_bias=d.higher_bias;
   c.ltf_closed=c.asof; g_analysis_native_reason=d.reason;
   g_analysis_left=config.swing_strength; g_analysis_right=config.swing_strength; g_analysis_lookback=config.lookback;
   // Consume the existing range structure confirmation; never run a second MTF detector.
   c.mtf_bias=range_mode ? (range.structure_confirmed ? range.direction : 0) : d.structure_bias;
   MqlRates bars[];
   if(ICTCopyClosedAsOf(c.symbol,c.ltf,c.asof,1,bars)) c.ltf_closed=ICTBarClose(c.ltf,bars[0].time);
   if(ICTCopyClosedAsOf(c.symbol,c.mtf,c.asof,1,bars)) c.mtf_closed=ICTBarClose(c.mtf,bars[0].time);
   if(ICTCopyClosedAsOf(c.symbol,c.htf,c.asof,1,bars)) c.htf_closed=ICTBarClose(c.htf,bars[0].time);
   SICTUnifiedSnapshot unused; ZeroMemory(unused); ICTAnalyticalStart(c,range,unused,false);
  }
string ICTAnalyticalDashboardBody()
  {
   if(!Analysis_Enable) return "";
   SICTAnalyticalResult s=g_analysis_result;
   string body="[TÍN HIỆU PHÂN TÍCH TỔNG HỢP]\n";
   body+=(s.signal ? (s.direction>0 ? "PHÂN TÍCH SỚM: MUA" : "PHÂN TÍCH SỚM: BÁN") : "THEO DÕI")+" | "+s.reason+"\n";
   if(s.ready)
      body+="Điểm trung bình "+DoubleToString(s.score,1)+"/100 | ngưỡng "+DoubleToString(Analysis_Minimum_Score,1)+
         " | ủng hộ "+IntegerToString(s.supporters)+" / "+IntegerToString(s.groups)+" nhóm"+
         " | phản đối "+IntegerToString(s.opponents)+"\n";
   string names[ICT_ANALYSIS_GROUPS]={"Đường giá / động lượng / hiệu suất","Thân / râu / đóng cửa / mẫu nến",
      "Quét / reclaim / breakout native","Phản ứng OB / FVG / BPR","SMT liên thị trường","Deep learning"};
   for(int i=0;i<ICT_ANALYSIS_GROUPS;i++)
      body+=names[i]+": "+(g_analysis_votes.available[i] ?
         DoubleToString(50*(1+s.direction*g_analysis_votes.value[i]),1)+"/100" : "chưa có dữ liệu")+"\n";
   body+=g_analysis_deep_reason+"\n";
   body+=(s.deep_used ? "Đã gộp DNN vào một nhóm bằng chứng. " : "DL chưa tham gia. ");
   body+=(s.context_aligned ? "Bối cảnh MTF đồng thuận.\n" : "Bối cảnh MTF chưa đồng thuận / thiếu dữ liệu; đây là phân tích sớm.\n");
   if(s.experimental) body+="DL THAM KHẢO: chưa đạt điều kiện chất lượng của chế độ xác nhận chặt.\n";
   body+="Điểm là mức đồng thuận, không phải xác suất thắng.\n";
   body+="Tín hiệu sớm cần xác nhận điểm vào và rủi ro ở phần quyết định native.\n";
   if(s.asof>0) body+="Nến dữ liệu: "+TimeToString(s.asof,TIME_DATE|TIME_MINUTES)+"\n";
   return body;
  }
void ICTAnalyticalRenderHistory(const string prefix)
  {
   if(!Analysis_Enable || !Analysis_Show_On_Chart || Analysis_History_Bars<=0)
     { ObjectsDeleteAll(0,prefix); return; }
   if(!g_stat_model.fitted || !g_stat_snapshot.ready || g_stat_timeframe!=g_analysis_context.ltf || ArraySize(g_analysis_rates)<40) return;
   if(g_analysis_history_asof==g_analysis_context.asof && g_analysis_history_train_end==g_stat_model.train_end) return;
   MqlRates upper[],middle[];
   ICTCopyClosedAsOf(_Symbol,g_analysis_context.htf,g_analysis_context.asof,g_analysis_lookback+Analysis_History_Bars,upper);
   ICTCopyClosedAsOf(_Symbol,g_analysis_context.mtf,g_analysis_context.asof,g_analysis_lookback+Analysis_History_Bars,middle);
   SICTAnalyticalPolicy policy; ICTAnalyticalInputs(policy); string keep[];
   int n=ArraySize(g_analysis_rates),first=(int)MathMax(33,n-Analysis_History_Bars);
   for(int i=first;i<n;i++)
     {
      datetime asof=ICTBarClose(g_analysis_context.ltf,g_analysis_rates[i].time);
      if(ICTBarClose(g_stat_timeframe,g_stat_model.test_end)>asof) continue;
      SICTStatSample sample; SICTStatSnapshot forecast=g_stat_snapshot;
      if(!ICTStatFeatures(g_analysis_rates,i,_Point,sample) || !ICTStatPredict(g_stat_model,sample,forecast)) continue;
      SICTAnalyticalContext context=g_analysis_context; context.asof=asof; context.ltf_closed=asof;
      SMarketStructure high,mid;
      ICTAnalyticalStructureAt(upper,context.htf,asof,g_analysis_lookback,g_analysis_left,g_analysis_right,high,context.htf_closed);
      ICTAnalyticalStructureAt(middle,context.mtf,asof,g_analysis_lookback,g_analysis_left,g_analysis_right,mid,context.mtf_closed);
      context.htf_bias=high.bias; context.mtf_bias=mid.bias;
      SICTAnalyticalVotes votes; ZeroMemory(votes); double atr=0;
      if(!ICTAnalyticalPriceVotes(g_analysis_rates,context.ltf,asof,_Point,votes,atr)) continue;
      SICTAnalyticalDeepState deep; SICTAnalyticalResult result;
      ICTAnalyticalDeepEvidence(g_stat_model,forecast,g_analysis_rates,g_stat_timeframe,context.ltf,asof,_Point,deep,votes);
      if(!ICTAnalyticalEvaluateEarly(policy,context,votes,deep,result)) continue;
      string name=prefix+IntegerToString((long)g_analysis_rates[i].time);
      string details="DL REPLAY (nến sau cutoff kiểm định) | "+TimeToString(asof,TIME_DATE|TIME_MINUTES)+
         "\n"+ICTStatProbabilities(deep.probability)+"\n"+deep.reason+"\n"+result.reason+
         "\nĐiểm "+DoubleToString(result.score,1)+"/100; chưa phải xác nhận vào lệnh";
      if(ICTAnalyticalChartMark(0,name,g_analysis_rates[i],atr,result,details)) IRKeepLiquidityObject(keep,name);
     }
   IRReconcileLiquidityObjects(prefix,keep); g_analysis_history_asof=g_analysis_context.asof;
   g_analysis_history_train_end=g_stat_model.train_end;
  }
void ICTAnalyticalExportEvidence(const string prefix)
  {
   if(!Analysis_Enable || (!Analysis_Export_Diagnostics && !Analysis_Save_Chart_Evidence)) return;
   ulong now=GetTickCount64();
   if(g_analysis_last_audit_ms>0 && now-g_analysis_last_audit_ms<3000) return;
   g_analysis_last_audit_ms=now; FolderCreate("ICTAnalysisEvidence");
   string stem="ICTAnalysisEvidence\\"+_Symbol+"_"+IntegerToString((int)_Period)+"_"+IntegerToString(ChartID());
   int historical=0;
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) if(StringFind(ObjectName(0,i,0,-1),prefix+"history_")==0) historical++;
   if(Analysis_Export_Diagnostics)
     {
      int file=FileOpen(stem+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
      if(file!=INVALID_HANDLE)
        {
         FileWrite(file,"build","symbol","ltf","asof","model_ready","calibrated","dl_ready","dl_validated","up","down","neutral",
            "score","current_signal","history_arrows","mtf_aligned","experimental","reason","native_reason");
         FileWrite(file,"1.10",_Symbol,(int)g_analysis_context.ltf,(long)g_analysis_result.asof,
            g_stat_model.fitted,g_stat_model.calibrated,g_analysis_deep.ready,g_analysis_deep.validated,
            g_analysis_deep.probability[0],g_analysis_deep.probability[1],g_analysis_deep.probability[2],
            g_analysis_result.score,g_analysis_result.signal,historical,g_analysis_result.context_aligned,
            g_analysis_result.experimental,g_analysis_result.reason,g_analysis_native_reason);
         FileClose(file);
        }
     }
   if(Analysis_Save_Chart_Evidence && !g_analysis_screenshot_saved && g_analysis_deep.ready)
     { ChartRedraw(0); g_analysis_screenshot_saved=ChartScreenShot(0,stem+".png",1280,800,ALIGN_RIGHT); }
  }
void ICTAnalyticalRender(const string prefix)
  {
   ICTAnalyticalRenderHistory(prefix+"history_");
   if(Analysis_Enable && Analysis_Show_On_Chart)
      ICTAnalyticalChartBadge(0,prefix+"deep_",g_analysis_deep.ready ? "DL 32-12-6-3 | "+ICTStatProbabilities(g_analysis_deep.probability) :
         "DL 32-12-6-3 | "+g_stat_snapshot.status+" "+IntegerToString(g_stat_snapshot.progress)+"%",
         g_analysis_result.reason,g_analysis_deep.ready);
   else { ObjectDelete(0,prefix+"deep_0"); ObjectDelete(0,prefix+"deep_1"); }
   ICTAnalyticalExportEvidence(prefix);
   string arrow=prefix+"arrow",label=prefix+"label";
   if(!Analysis_Enable || !Analysis_Show_On_Chart || !g_analysis_result.signal || ArraySize(g_analysis_rates)<1)
     { ObjectDelete(0,arrow); ObjectDelete(0,label); return; }
   MqlRates bar=g_analysis_rates[ArraySize(g_analysis_rates)-1]; int direction=g_analysis_result.direction;
   double price=(direction>0 ? bar.low-0.25*g_analysis_atr : bar.high+0.25*g_analysis_atr);
   color background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   color ink=ICTChartReadableColor(direction>0 ? clrSeaGreen : clrCrimson,background,ICTChartLuminance(background)<0.179);
   if(ObjectFind(0,arrow)<0) ObjectCreate(0,arrow,OBJ_ARROW,0,bar.time,price);
   ObjectMove(0,arrow,0,bar.time,price); ObjectSetInteger(0,arrow,OBJPROP_ARROWCODE,direction>0 ? 233 : 234);
   ObjectSetInteger(0,arrow,OBJPROP_COLOR,ink); ObjectSetInteger(0,arrow,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,arrow,OBJPROP_SELECTABLE,false); ObjectSetString(0,arrow,OBJPROP_TOOLTIP,ICTAnalyticalDashboardBody());
   // Training updates can redraw between normal chart layout passes. Keep the
   // same pixel label registered instead of alternating OBJ_LABEL / OBJ_TEXT.
   bool collecting=g_ict_chart_collect; g_ict_chart_collect=true;
   RMContextMarker(label,bar.time,price+(direction>0 ? -0.15 : 0.15)*g_analysis_atr,
      (direction>0 ? "PHÂN TÍCH SỚM MUA" : "PHÂN TÍCH SỚM BÁN")+" | "+DoubleToString(g_analysis_result.score,0)+"/100",ink);
   g_ict_chart_collect=collecting;
   ICTChartLabelBold(label,true); ObjectSetString(0,label,OBJPROP_TOOLTIP,ICTAnalyticalDashboardBody());
  }
#endif
