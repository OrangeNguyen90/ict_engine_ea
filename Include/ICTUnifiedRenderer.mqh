#ifndef ICT_UNIFIED_RENDERER_MQH
#define ICT_UNIFIED_RENDERER_MQH
#include "ICTUnifiedInputs.mqh"
#include "DashboardComponents.mqh"
#include "ICTDashboardPanel.mqh"
#include "ICTRejectionBreakerDetector.mqh"

struct SICTBlockOverlayCache
  {
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime asof;
   bool analyzed;
   bool rejection_ready;
   bool breaker_ready;
   SICTChartBlockSignal rejection;
   SICTChartBlockSignal breaker;
  };
SICTBlockOverlayCache g_ict_block_overlay_cache[3];

string ICTUnifiedTF(const ENUM_TIMEFRAMES tf)
  { if(tf==PERIOD_CURRENT) return "--"; string value=EnumToString(tf); StringReplace(value,"PERIOD_",""); return value; }
string ICTUnifiedBias(const SICTTierSnapshot &tier)
  {
   if(tier.timeframe==PERIOD_CURRENT) return "Chưa có";
   if(tier.status==ICT_CONTEXT_INSUFFICIENT) return "Không đủ dữ liệu";
   return tier.status==ICT_CONTEXT_BULLISH ? "Tăng" : tier.status==ICT_CONTEXT_BEARISH ? "Giảm" : "Trung tính";
  }
string ICTUnifiedStructureText(const ENUM_ICT_MTF_STRUCTURE state)
  {
   string names[]={"Không đủ dữ liệu","Cùng hướng","Ngược xu hướng","Chuyển tiếp","Trung tính"};
   return (int)state>=0 && (int)state<5 ? names[(int)state] : "Không đủ dữ liệu";
  }
string ICTDashboardSignalState(const ENUM_ICT_SIGNAL_STATE state)
  {
   if(state==ICT_SIGNAL_BUY_CONFIRMED) return "MUA ĐÃ XÁC NHẬN";
   if(state==ICT_SIGNAL_SELL_CONFIRMED) return "BÁN ĐÃ XÁC NHẬN";
   if(state==ICT_SIGNAL_WATCH_BUY) return "THEO DÕI MUA";
   if(state==ICT_SIGNAL_WATCH_SELL) return "THEO DÕI BÁN";
   return "KHÔNG GIAO DỊCH";
  }
bool ICTShowSourceTier(const SICTUnifiedSnapshot &s,const ENUM_TIMEFRAMES tf)
  {
   return tf==s.frames.ltf ? Context_ShowLTF : tf==s.frames.mtf ? Context_ShowMTF :
      tf==s.frames.htf ? Context_ShowHTF : true;
  }
void ICTKeepObject(string &keep[],const string name)
  { int n=ArraySize(keep); ArrayResize(keep,n+1); keep[n]=name; }
void ICTReconcileObjects(const string prefix,const string &keep[])
  {
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
     {
      string name=ObjectName(0,i,0,-1); if(StringFind(name,prefix)!=0) continue;
      bool exists=false; for(int j=0;j<ArraySize(keep);j++) if(keep[j]==name) { exists=true; break; }
      if(!exists) ObjectDelete(0,name);
     }
  }
void ICTFiniteLine(const string name,const datetime first,const datetime last,const double price,
                    const color ink,const ENUM_LINE_STYLE style=STYLE_DOT)
  {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,first,price,last,price);
   ObjectMove(0,name,0,first,price); ObjectMove(0,name,1,last,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink); ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }
void ICTRenderBlockSignal(const string prefix,const string id,const string title,
                  const SICTChartBlockSignal &signal,const ENUM_TIMEFRAMES tf,
                  const datetime edge,const color active_color,string &keep[])
  {
  if(signal.formed_at<=0 || signal.confirmed_at<=0 || signal.upper<=signal.lower ||
    (signal.state==ICT_CHART_BLOCK_INVALIDATED && !Show_Invalid_Block_Signals) ||
    !ICTChartReserveZone(tf,signal.formed_at,edge,signal.lower,signal.upper)) return;
  string zone=prefix+id,tag=zone+"t",mid=zone+"m";
  color ink=(signal.state==ICT_CHART_BLOCK_INVALIDATED ? clrSlateGray : active_color);
  RMContextZone(zone,signal.formed_at,edge,signal.lower,signal.upper,ink);
  ObjectSetInteger(0,zone,OBJPROP_FILL,signal.state!=ICT_CHART_BLOCK_INVALIDATED);
  ObjectSetInteger(0,zone,OBJPROP_STYLE,signal.state==ICT_CHART_BLOCK_INVALIDATED ? STYLE_DASH : STYLE_SOLID);
  string details=title+" | "+ICTUnifiedTF(tf)+" | "+ICTChartBlockStateText(signal.state)+
    " | sweep "+(signal.swept ? TimeToString(signal.sweep_at,TIME_DATE|TIME_MINUTES) : "none")+
    " | displacement PASS | MSS PASS | formed "+TimeToString(signal.formed_at,TIME_DATE|TIME_MINUTES)+
    " | confirmed "+TimeToString(signal.confirmed_at,TIME_DATE|TIME_MINUTES);
  ObjectSetString(0,zone,OBJPROP_TOOLTIP,details);
  RMContextLine(mid,signal.mean,ink,title+" mean threshold");
  RMContextMarker(tag,signal.confirmed_at,signal.upper,title+" | "+ICTChartBlockStateText(signal.state),ink);
  ObjectSetString(0,tag,OBJPROP_TOOLTIP,details);
  ICTKeepObject(keep,zone); ICTKeepObject(keep,mid); ICTKeepObject(keep,tag);
  }
void ICTRenderRejectionAndBreaker(const string prefix,const SICTUnifiedSnapshot &s,
                       const datetime edge,string &keep[])
  {
  if(!Show_Rejection_Blocks && !Show_Breaker_Blocks) return;
  for(int tier=0;tier<3;tier++)
    {
    SICTTierSnapshot context=s.tiers[tier];
    ENUM_TIMEFRAMES tf=context.timeframe;
    if(!ICTUnifiedTierAvailable(s,tf) || !ICTShowSourceTier(s,tf) || !ICTChartZoneTimeframe(tf)) continue;
    SICTBlockOverlayCache cache=g_ict_block_overlay_cache[tier];
    bool refresh=cache.symbol!=s.symbol || cache.timeframe!=tf || cache.asof!=s.asof;
    if(refresh)
      {
       cache.symbol=s.symbol; cache.timeframe=tf; cache.asof=s.asof; cache.analyzed=false;
       cache.rejection_ready=false; cache.breaker_ready=false;
      }
    if(!cache.analyzed)
      {
       MqlRates rates[]; ArraySetAsSeries(rates,false);
       int copied=CopyRates(s.symbol,tf,1,BlockSignal_LookbackBars,rates);
       if(copied<40) { g_ict_block_overlay_cache[tier]=cache; continue; }
       int count=copied;
       while(count>0 && rates[count-1].time+PeriodSeconds(tf)>s.asof) count--;
       if(count<40 || !SRMPValidDetectorRates(rates,count))
         { g_ict_block_overlay_cache[tier]=cache; continue; }
       cache.analyzed=true;
       if(Show_Rejection_Blocks)
      cache.rejection_ready=ICTFindRejectionBlockFromRates(rates,count,RB_MinWickRangeRatio,
         BlockSignal_MinBodyRatio,BlockSignal_MinRangeAverage,BlockSignal_ConfirmBars,PeriodSeconds(tf),cache.rejection);
       if(Show_Breaker_Blocks)
      cache.breaker_ready=ICTFindBreakerBlockFromRates(rates,count,OB_Bounds_Mode,
         Breaker_OB_DisplacementFactor,BlockSignal_MinBodyRatio,BlockSignal_MinRangeAverage,
         BlockSignal_ConfirmBars,PeriodSeconds(tf),cache.breaker);
       g_ict_block_overlay_cache[tier]=cache;
      }
    if(cache.rejection_ready)
      ICTRenderBlockSignal(prefix,"rb_"+IntegerToString((int)tf),
      (cache.rejection.direction>0 ? "BULLISH REJECTION BLOCK" : "BEARISH REJECTION BLOCK"),
      cache.rejection,tf,edge,cache.rejection.direction>0 ? RB_BullColor : RB_BearColor,keep);
    if(cache.breaker_ready)
      ICTRenderBlockSignal(prefix,"bb_"+IntegerToString((int)tf),
      (cache.breaker.direction>0 ? "BB BUY | FAILED BEARISH OB" : "BB SELL | FAILED BULLISH OB"),
      cache.breaker,tf,edge,cache.breaker.direction>0 ? Breaker_BullColor : Breaker_BearColor,keep);
    }
  }
datetime ICTVisualEdge(const ENUM_TIMEFRAMES tf,const datetime from,const int bars)
  {
   datetime edge=from;
   for(int i=0;i<bars;i++) { datetime next=ICTBarClose(tf,edge); if(next<=edge) break; edge=next; }
   return edge;
  }
void ICTRenderUnifiedOverlays(const string prefix,const SICTUnifiedSnapshot &s,
                              const bool show_smt=true,const bool show_ob=true,const bool show_fvg=true,
                              const bool show_bpr=true,const bool show_pd=true,const bool show_structure=true,
                              const bool show_liquidity=true)
  {
   string keep[];
   if(!s.valid)
     {
      // Missing live context must not erase already confirmed SMT history.
      for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
        {
         string name=ObjectName(0,i,0,-1);
         if(StringFind(name,prefix+"smt_")==0) ICTKeepObject(keep,name);
        }
      // A journal failure can invalidate the decision while the closed
      // market tiers remain independently usable as chart context.
      bool context_available=false;
      for(int i=0;i<3;i++) if(ICTUnifiedTierAvailable(s,s.tiers[i].timeframe)) context_available=true;
      if(!context_available) { ICTReconcileObjects(prefix,keep); return; }
     }
   double tick=SymbolInfoDouble(s.symbol,SYMBOL_TRADE_TICK_SIZE);
   datetime context_edge=ICTVisualEdge(s.chart_tf,s.asof,OB_ExtendBars);
   for(int tier=0;tier<3;tier++)
     {
      string id=prefix+"context_"+IntegerToString(tier);
      SICTTierSnapshot t=s.tiers[tier];
      if(!ICTUnifiedTierAvailable(s,t.timeframe) || !ICTShowSourceTier(s,t.timeframe)) continue;
      SMarketStructure context=t.structure;
      if(show_pd && ICTChartZoneTimeframe(t.timeframe) && context.recent_high>context.recent_low && context.recent_low>0)
        {
         datetime formed=(datetime)MathMax(context.recent_high_confirmed_time,context.recent_low_confirmed_time);
         if(formed>0 && formed<=s.asof)
           {
            double midpoint=(context.recent_high+context.recent_low)*0.5;
            RMContextZone(id+"premium",formed,context_edge,midpoint,context.recent_high,C'244,209,214');
            RMContextZone(id+"discount",formed,context_edge,context.recent_low,midpoint,C'206,238,211');
            ICTKeepObject(keep,id+"premium"); ICTKeepObject(keep,id+"discount");
            RMContextMarker(id+"pd_p",formed,(midpoint+context.recent_high)*0.5,"PREMIUM | "+ICTUnifiedTF(t.timeframe),clrMaroon);
            RMContextMarker(id+"pd_d",formed,(midpoint+context.recent_low)*0.5,"DISCOUNT | "+ICTUnifiedTF(t.timeframe),clrDarkGreen);
            ICTKeepObject(keep,id+"pd_p"); ICTKeepObject(keep,id+"pd_d");
           }
        }
      if(show_liquidity && context.recent_high_confirmed_time>0 && context.recent_high_confirmed_time<=s.asof &&
         context.recent_low_confirmed_time>0 && context.recent_low_confirmed_time<=s.asof)
        {
         ICTFiniteLine(id+"bsl",context.recent_high_confirmed_time,context_edge,context.recent_high,clrDarkOrange);
         ICTFiniteLine(id+"ssl",context.recent_low_confirmed_time,context_edge,context.recent_low,clrDeepSkyBlue);
         ObjectSetString(0,id+"bsl",OBJPROP_TOOLTIP,s.symbol+" | "+ICTUnifiedTF(t.timeframe)+" BSL | CONFIRMED | "+
            TimeToString(context.recent_high_confirmed_time,TIME_DATE|TIME_MINUTES));
         ObjectSetString(0,id+"ssl",OBJPROP_TOOLTIP,s.symbol+" | "+ICTUnifiedTF(t.timeframe)+" SSL | CONFIRMED | "+
            TimeToString(context.recent_low_confirmed_time,TIME_DATE|TIME_MINUTES));
         ICTKeepObject(keep,id+"bsl"); ICTKeepObject(keep,id+"ssl");
        }
      if(show_bpr && t.bpr_ready &&
         ICTChartReserveZone(t.timeframe,t.bpr.confirmed_at,context_edge,t.bpr.lower,t.bpr.upper))
        {
         RMContextZone(id+"b",t.bpr.confirmed_at,context_edge,t.bpr.lower,t.bpr.upper,t.bpr.direction>0 ? C'145,206,185' : C'222,169,187');
         ObjectSetString(0,id+"b",OBJPROP_TOOLTIP,ICTUnifiedTF(t.timeframe)+" "+(t.bpr.direction>0 ? "BULL BPR" : "BEAR BPR"));
         RMContextMarker(id+"bt",t.bpr.confirmed_at,t.bpr.upper,
            ICTUnifiedTF(t.timeframe)+" "+(t.bpr.direction>0 ? "BULL BPR" : "BEAR BPR"),t.bpr.direction>0 ? clrDarkGreen : clrMaroon);
         ICTKeepObject(keep,id+"b"); ICTKeepObject(keep,id+"bt");
        }
      if(show_fvg && t.fvg_ready && t.gap.status<=SRMP_FVG_PARTIALLY_FILLED &&
         ICTChartReserveZone(t.timeframe,t.gap.formed_time,context_edge,t.gap.lower,t.gap.upper))
        {
         RMContextZone(id+"f",t.gap.formed_time,context_edge,t.gap.lower,t.gap.upper,C'153,184,227');
         ObjectSetString(0,id+"f",OBJPROP_TOOLTIP,ICTUnifiedTF(t.timeframe)+" "+(t.gap.direction>0 ? "BULL FVG" : "BEAR FVG"));
         RMContextMarker(id+"ft",ICTBarClose(t.timeframe,t.gap.formed_time),t.gap.upper,
            ICTUnifiedTF(t.timeframe)+" "+(t.gap.direction>0 ? "BULL FVG" : "BEAR FVG"),clrRoyalBlue);
         ICTKeepObject(keep,id+"f"); ICTKeepObject(keep,id+"ft");
        }
      if(show_structure && t.structure.bos_time>0)
        {
         RMContextMarker(id+"ms",ICTBarClose(t.timeframe,t.structure.bos_time),t.structure.bos_level,
            (t.structure.mss ? "MSS | " : "BOS | ")+ICTUnifiedTF(t.timeframe),clrDarkCyan);
         ObjectSetString(0,id+"ms",OBJPROP_TOOLTIP,"Confirmed at "+TimeToString(ICTBarClose(t.timeframe,t.structure.bos_time),TIME_DATE|TIME_MINUTES));
         ICTKeepObject(keep,id+"ms");
        }
     }
   // No new SMT drawings from an invalid snapshot. Independently verified OB
   // and price context below remain visible; they never approve an entry.
   for(int i=0;i<s.event_count && show_smt && s.valid;i++)
     {
      SICTSMTEvent e=s.events[i]; ENUM_TIMEFRAMES tf=e.signal.timeframe;
      bool enabled=(tf==s.frames.ltf ? SMT_ShowLTF : tf==s.frames.mtf ? SMT_ShowMTF : tf==s.frames.htf ? SMT_ShowHTF : SMT_ShowCurrentChart);
      if(!enabled || e.signal.confirmation_time<=0 || e.seed_context ||
         !ICTSMTInsideDisplayWindow(e.signal.confirmation_time,s.display_start,s.asof)) continue;
      string line=prefix+"smt_"+IntegerToString((long)ICTStableHash(e.signal.event_id)),label=line+"t";
      if(ObjectFind(0,line)<0) ObjectCreate(0,line,OBJ_TREND,0,e.signal.primary_prior_time,e.signal.primary_prior,
                                          e.signal.primary_pivot_time,e.signal.primary_recent);
      ObjectMove(0,line,0,e.signal.primary_prior_time,e.signal.primary_prior);
      ObjectMove(0,line,1,e.signal.primary_pivot_time,e.signal.primary_recent);
      color ink=e.signal.direction>0 ? clrSeaGreen : clrCrimson;
      ObjectSetInteger(0,line,OBJPROP_COLOR,ink); ObjectSetInteger(0,line,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,line,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,line,OBJPROP_WIDTH,tf==s.frames.htf ? 3 : 1);
      ObjectSetInteger(0,line,OBJPROP_STYLE,tf==s.frames.mtf ? STYLE_DASH : STYLE_SOLID);
      string text="SMT "+(e.signal.direction>0 ? "BULL" : "BEAR")+" | "+ICTUnifiedTF(tf)+" | "+e.signal.comparison;
      string tooltip=text+" | relation "+(e.signal.relation>0 ? "POSITIVE" : "INVERSE")+
         " | source "+(e.signal.comparator_extreme ? "COMPARATOR EXTREME" : "PRIMARY EXTREME")+
         " | pivot "+TimeToString(e.signal.primary_pivot_time,TIME_DATE|TIME_MINUTES)+
         " | confirmed "+TimeToString(e.signal.confirmation_time,TIME_DATE|TIME_MINUTES);
      ObjectSetString(0,line,OBJPROP_TOOLTIP,tooltip);
      double offset=tick*(12+(i%3)*12)*(e.signal.direction>0 ? -1 : 1);
      RMContextMarker(label,e.signal.confirmation_time,e.signal.primary_recent+offset,text,ink);
      ObjectSetString(0,label,OBJPROP_TOOLTIP,tooltip);
      ICTKeepObject(keep,line); ICTKeepObject(keep,label);
     }
   double price=SymbolInfoDouble(s.symbol,SYMBOL_BID);
   bool selected[ICT_SMART_OB_MAX]; ArrayInitialize(selected,false);
   datetime edge=ICTVisualEdge(s.chart_tf,s.asof,OB_ExtendBars);
   int drawn=0;
   for(int attempt=0;attempt<s.ob_count && drawn<OB_MaxVisibleZones && show_ob && EnableAutoOB;attempt++)
     {
      int best=-1; double rank=-DBL_MAX;
      for(int i=0;i<s.ob_count;i++)
        {
         SICTStrongOrderBlock z=s.zones[i];
         if(selected[i] || !ICTUnifiedTierAvailable(s,z.timeframe) || z.ob.confirmation_time<=0 || z.ob.confirmation_time>s.asof ||
            !ICTShowSourceTier(s,z.timeframe) || !ICTChartZoneTimeframe(z.timeframe) || z.confirmation_score<OB_MinStrengthToDraw ||
            (EnableStrongOBOnly && z.grade!=ICT_OB_STRONG) ||
            (!OB_ShowMitigated && z.life==ICT_OB_MITIGATED) ||
            (!OB_ShowInvalidated && (z.life==ICT_OB_INVALIDATED || z.life==ICT_OB_EXPIRED))) continue;
         double distance=(price>0 && tick>0 ? MathAbs(z.ob.midpoint-price)/tick : 0);
         double value=(ICTOBActive(z) ? 10000000 : 0)+(int)z.grade*1000000+z.confirmation_score*1000-MathMin(999.0,distance);
         if(best<0 || value>rank) { best=i; rank=value; }
        }
      if(best<0) break; selected[best]=true;
      SICTStrongOrderBlock z=s.zones[best];
      if(!ICTChartReserveZone(z.timeframe,z.ob.formation_time,edge,z.ob.lower,z.ob.upper)) continue;
      string name=prefix+"ob_"+IntegerToString((long)ICTStableHash(z.id));
      color ink=(z.grade==ICT_OB_STRONG ? (z.ob.direction>0 ? OB_StrongBullColor : OB_StrongBearColor) :
                 z.grade==ICT_OB_MEDIUM ? (z.ob.direction>0 ? OB_MediumBullColor : OB_MediumBearColor) : OB_WeakColor);
      bool inactive=z.life==ICT_OB_MITIGATED || z.life==ICT_OB_INVALIDATED || z.life==ICT_OB_EXPIRED;
      if(inactive) ink=clrSlateGray;
      RMContextZone(name,z.ob.formation_time,edge,z.ob.lower,z.ob.upper,ink);
      ObjectSetInteger(0,name,OBJPROP_FILL,!inactive);
      ObjectSetInteger(0,name,OBJPROP_STYLE,inactive ? STYLE_DASH : STYLE_SOLID);
      string title=ICTUnifiedTF(z.timeframe)+" "+(z.ob.direction>0 ? "BULL " : "BEAR ")+ICTOBGradeText(z.grade)+" OB"+
         (OB_ShowStrengthScore ? " | "+IntegerToString(z.confirmation_score)+"/100" : "")+" | "+ICTOBLifeText(z.life);
      string details=title+" | Displacement="+(z.ob.displacement ? "PASS" : "FAIL")+
         " BOS/MSS="+(z.ob.break_confirmed ? "PASS" : "FAIL")+" FVG/BPR="+(z.ob.fvg ? "FVG" : "N/A")+
         " Sweep="+(z.ob.liquidity_sweep ? "YES" : "NO")+" HTF Alignment="+(z.bias_points>0 ? "PASS" : "N/A")+
         " Freshness="+ICTOBLifeText(z.life)+" current score="+IntegerToString(z.current_context_score)+
         " | "+IntegerToString(z.candles)+" candles | sweep #"+IntegerToString(z.sweep_count)+
         " | touches "+IntegerToString(z.touch_count)+" | mitigation "+DoubleToString(z.mitigation_depth*100,1)+"% | "+z.gate_reason+
         " | formed "+TimeToString(z.ob.formation_time,TIME_DATE|TIME_MINUTES)+
         " | confirmed "+TimeToString(z.ob.confirmation_time,TIME_DATE|TIME_MINUTES);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,details); ICTKeepObject(keep,name);
      if(OB_ShowMidline) { ICTFiniteLine(name+"m",z.ob.formation_time,edge,z.ob.midpoint,ink); ICTKeepObject(keep,name+"m"); }
      if(OB_ShowOpenReference) { ICTFiniteLine(name+"o",z.ob.formation_time,edge,z.open_reference,ink); ICTKeepObject(keep,name+"o"); }
      RMContextMarker(name+"t",z.ob.confirmation_time,z.ob.upper+tick*(drawn%3)*10,title,ink);
      ObjectSetString(0,name+"t",OBJPROP_TOOLTIP,details); ICTKeepObject(keep,name+"t");
      drawn++;
     }
    ICTRenderRejectionAndBreaker(prefix,s,edge,keep);
   ICTReconcileObjects(prefix,keep);
  }

string ICTStrongOBDetails(const SICTStrongOrderBlock &z)
  {
   return ICTUnifiedTF(z.timeframe)+" "+(z.ob.direction>0 ? "TĂNG " : "GIẢM ")+ICTDashboardText(ICTOBGradeText(z.grade))+" "+
      IntegerToString(z.confirmation_score)+"/100 | "+ICTDashboardText(ICTOBLifeText(z.life))+
      "\nVùng "+DoubleToString(z.ob.lower,_Digits)+" - "+DoubleToString(z.ob.upper,_Digits)+
      " | số lần chạm "+IntegerToString(z.touch_count)+" | độ lấp "+DoubleToString(z.mitigation_depth*100,1)+"%"+
      "\nQuét "+IntegerToString(z.sweep_points)+" Dịch chuyển "+IntegerToString(z.displacement_points)+
      " Cấu trúc "+IntegerToString(z.structure_points)+" FVG "+IntegerToString(z.fvg_points)+
      " Xu hướng "+IntegerToString(z.bias_points)+" PD "+IntegerToString(z.pd_points)+" Mới "+IntegerToString(z.freshness_points)+
      "\n"+ICTDashboardText(z.gate_reason)+(z.invalidation_reason!="" ? " | "+ICTDashboardText(z.invalidation_reason) : "");
  }
string ICTUnifiedDashboardBody(const SICTUnifiedSnapshot &s,const string decision,const string plan,const string reason)
  {
   string body="[BỐI CẢNH ĐA KHUNG]\nChế độ: "+(s.frames.mode==ICT_MTF_AUTO ? "Tự động" : "Thủ công")+
      " | "+(s.frames.status==ICT_MTF_FULL ? "3 khung" : s.frames.status==ICT_MTF_TWO_TIER ? "2 khung" : "1 khung")+"\n";
   body+="Khung hiển thị vùng: "+ICTUnifiedTF(g_ict_chart_zone_tf)+" | số vùng trùng đã ẩn: "+
         IntegerToString(g_ict_chart_zone_suppressed)+"\n";
   string tier_names[3]={"LTF","MTF","HTF"};
   for(int i=0;i<3;i++)
     {
      body+=tier_names[i]+" "+ICTUnifiedTF(s.tiers[i].timeframe)+" "+ICTUnifiedBias(s.tiers[i]);
      if(s.tiers[i].closed_at>0) body+=" | đóng lúc "+TimeToString(s.tiers[i].closed_at,TIME_DATE|TIME_MINUTES);
      else if(s.tiers[i].reason!="") body+=" | "+ICTDashboardText(s.tiers[i].reason);
      body+="\n";
     }
   body+="MTF: "+ICTUnifiedStructureText(s.mtf_state)+"\n"+ICTDashboardText(s.reason)+"\n[QUYẾT ĐỊNH HTF / MTF / LTF]\n";
   SICTSignalResult signal=s.signal;
   bool shared=signal.symbol==s.symbol && signal.asof==s.asof && signal.asof>0;
   if(shared)
     {
      body+=ICTDashboardSignalState(signal.state)+" | "+TimeToString(signal.asof,TIME_DATE|TIME_MINUTES)+"\n";
      // Mirror the order in ICTEvaluateSignal. A false downstream flag can
      // simply mean the legacy analysis stopped at an earlier gate.
      bool data_gate=signal.data_ready && signal.frames.status==ICT_MTF_FULL;
      bool context_gate=data_gate && (signal.direction==1 || signal.direction==-1) && signal.htf_pass && signal.mtf_pass;
      bool trigger_gate=context_gate && signal.ltf_pass && signal.trigger_bar>0 &&
         signal.asof>signal.trigger_bar && signal.source_event_time<=signal.asof;
      bool smt_gate=trigger_gate && (!signal.smt_required || signal.smt_pass);
      bool target_gate=smt_gate && signal.tp1>0 && signal.target_pool_id!="";
      string risk_gate=(!target_gate ? "Chưa đánh giá" : signal.confirmed ? "Đạt" :
         StringFind(signal.reason,"RISK FILTER FAIL")==0 ? "Không đạt" : "Chưa rõ");
      body+="Dữ liệu: "+(data_gate ? "Đạt" : "Không đủ")+"\n";
      body+="HTF "+(!data_gate ? "Chưa đánh giá" : signal.htf_pass ? "Đạt" : "Không đạt")+
         " / MTF "+(!data_gate ? "Chưa đánh giá" : signal.mtf_pass ? "Đạt" : "Không đạt")+"\n";
      body+="Tín hiệu LTF: "+(!context_gate ? "Chưa đánh giá" : trigger_gate ? "Đạt" : "Chờ")+"\n";
      body+="Điều kiện SMT: "+(!trigger_gate ? "Chưa đánh giá" : !signal.smt_required ? "Tùy chọn" : signal.smt_pass ? "Đạt" : "Không đạt")+"\n";
      body+="Mục tiêu "+(!smt_gate ? "Chưa đánh giá" : target_gate ? "Đạt" : "Chưa có")+
         " / Rủi ro "+risk_gate+"\n";
      body+="Điểm chất lượng "+IntegerToString(signal.score)+"/100 (điểm bằng chứng, không phải xác suất)\n";
      if(data_gate) body+=ICTDashboardText(signal.htf_reason)+"\n"+ICTDashboardText(signal.mtf_reason)+"\n";
      if(context_gate) body+=ICTDashboardText(signal.ltf_reason)+"\n";
      body+="Quyết định: "+ICTDashboardText(signal.reason)+"\n";
      if(signal.id!="") body+="ID "+signal.id+"\n";
     }
   else body+=decision+"\n"+ICTDashboardText(reason)+"\n";
   body+="[PHÂN TÍCH SMT]\n";
   body+="SMT 1: "+(s.comparison1=="" ? "Đã tắt / chưa có" : s.comparison1)+
      " | SMT 2: "+(s.comparison2=="" ? "Đã tắt / chưa có" : s.comparison2)+"\n";
   if(s.comparator_reason!="") body+=ICTDashboardText(s.comparator_reason)+"\n";
   body+="Biểu đồ "+ICTUnifiedTF(s.chart_tf)+" | phát hiện: "+IntegerToString(s.detection_bars)+" nến mỗi khung | hiển thị: "+IntegerToString(s.display_bars)+" nến biểu đồ\n";
   for(int layer=0;layer<s.layer_count;layer++)
     {
      SICTSMTLayer l=s.layers[layer];
      body+=ICTUnifiedTF(l.timeframe)+(l.timeframe==s.chart_tf ? " (khung biểu đồ)" : "")+" phát hiện "+IntegerToString(l.detected)+" | đang hiển thị "+IntegerToString(l.displayed)+
         " | tăng / giảm còn hiệu lực "+IntegerToString(l.bullish)+"/"+IntegerToString(l.bearish)+" | "+ICTDashboardText(l.reason)+"\n";
      for(int peer=0;peer<2;peer++)
        {
         SICTSMTPeerSnapshot p=l.peers[peer];
         body+="Mã so sánh "+IntegerToString(peer+1)+" "+(p.comparison=="" ? "--" : p.comparison)+" | "+
            (p.relation_known ? (p.relation>0 ? "+ Cùng chiều" : "- Ngược chiều") : "Chưa rõ tương quan")+
            " | "+(p.reason=="DISABLED" ? "Đã tắt" : p.conflict ? "Xung đột" :
                   p.state==ICT_SMT_PEER_NA ? "Chưa có dữ liệu" : ICTDashboardText(ICTSMTPeerStateText(p.state)))+"\n";
         if(p.primary_pivot_time>0)
            body+="Điểm xoay "+DoubleToString(p.primary_pivot,_Digits)+" lúc "+TimeToString(p.primary_pivot_time,TIME_DATE|TIME_MINUTES)+
               " | xác nhận "+TimeToString(p.confirmation_time,TIME_DATE|TIME_MINUTES)+"\n";
         body+=ICTDashboardText(p.reason)+"\n";
        }
     }
   if(shared) body+=ICTDashboardText(signal.smt_reason)+"\n";
   body+="[THANH KHOẢN VÀ PHÁ VỠ]\n";
   if(shared)
     {
      body+="Nguồn thanh khoản: "+(signal.source_pool_id=="" ? "Chưa có" : signal.source_pool_id)+"\n";
      body+="Sự kiện quét / phá vỡ: "+ICTDashboardText(signal.liquidity_event)+" "+(signal.source_event_time>0 ? TimeToString(signal.source_event_time,TIME_DATE|TIME_MINUTES) : "--")+"\n";
      body+="Vùng thanh khoản mục tiêu: "+(signal.target_pool_id=="" ? "Chưa có mục tiêu" : signal.target_pool_id)+"\n";
      body+="Khoảng cách đến thanh khoản: "+(signal.tp1>0 && signal.entry>0 ? DoubleToString(MathAbs(signal.tp1-signal.entry),_Digits) : "Chưa có")+"\n";
     }
   else body+="Chưa có quyết định hoặc kế hoạch thanh khoản chung\n";
   body+="BSL / SSL là vùng thanh khoản suy ra từ cấu trúc; OB / FVG / BPR là vùng giá mục tiêu.\n[KHỐI LỆNH OB]\n";
   double price=SymbolInfoDouble(s.symbol,SYMBOL_BID),point=SymbolInfoDouble(s.symbol,SYMBOL_POINT);
   int nearest=ICTNearestActiveOB(s,price),bull=-1,bear=-1;
   for(int i=0;i<s.ob_count;i++)
     {
      if(!ICTOBActive(s.zones[i])) continue;
      if(s.zones[i].ob.direction>0 && (bull<0 || s.zones[i].confirmation_score>s.zones[bull].confirmation_score)) bull=i;
      if(s.zones[i].ob.direction<0 && (bear<0 || s.zones[i].confirmation_score>s.zones[bear].confirmation_score)) bear=i;
     }
   if(nearest>=0)
     { body+="Gần nhất: "+ICTStrongOBDetails(s.zones[nearest])+"\n";
       if(price>0 && point>0) body+="Khoảng cách đến trung điểm "+DoubleToString(MathAbs(s.zones[nearest].ob.midpoint-price)/point,1)+" điểm giá\n"; }
   else body+="Không có OB đang hoạt động đạt điều kiện bắt buộc\n";
   if(bull>=0 && bull!=nearest) body+="OB tăng mạnh nhất: "+ICTStrongOBDetails(s.zones[bull])+"\n";
   if(bear>=0 && bear!=nearest) body+="OB giảm mạnh nhất: "+ICTStrongOBDetails(s.zones[bear])+"\n";
   body+="[KẾ HOẠCH VÀ RỦI RO]\n";
   if(shared)
     {
      body+="Giá vào "+(signal.entry>0 ? DoubleToString(signal.entry,_Digits) : "--")+
         " / SL "+(signal.stop>0 ? DoubleToString(signal.stop,_Digits) : "--")+"\n";
      body+="TP1 "+(signal.tp1>0 ? DoubleToString(signal.tp1,_Digits) : "Chưa có mục tiêu")+
         " / TP2 "+(signal.tp2>0 ? DoubleToString(signal.tp2,_Digits) : "--")+
         " / RR ròng "+(signal.rr>0 ? DoubleToString(signal.rr,2) : "--")+"\n";
      if(signal.confirmed && reason!=signal.reason) body+="Kiểm tra hiện tại: "+ICTDashboardText(reason)+"\n";
     }
   else body+=plan+"\n";
   body+="Thời điểm dữ liệu "+TimeToString(s.asof,TIME_DATE|TIME_SECONDS)+" | độ trễ "+IntegerToString((long)MathMax(0,TimeCurrent()-s.asof))+" giây\n";
   body+="Điểm chỉ phản ánh bằng chứng, không phải xác suất thắng. Chỉ mang tính tham khảo.";
   body+=ICTChartLegend();
   return body;
  }
void ICTRenderUnifiedDashboard(const string prefix,const SICTUnifiedSnapshot &s,const string decision,
                                const string plan,const string reason,const ENUM_BASE_CORNER corner,
                                const int x,const int y,const int width,const int height,const int font,
                                int &page,int &moved_x,int &moved_y,const bool hidden)
  {
   string title="ICT SMART | "+s.symbol+" | Vùng "+ICTUnifiedTF(g_ict_chart_zone_tf);
   ICTRenderPagedPanel(prefix,title,decision,s.valid ? clrGold : clrLightCoral,
      ICTUnifiedDashboardBody(s,decision,plan,reason),corner,x,y,width,height,font,page,moved_x,moved_y,hidden);
  }
#endif
