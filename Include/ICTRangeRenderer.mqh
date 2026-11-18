#ifndef ICT_RANGE_RENDERER_MQH
#define ICT_RANGE_RENDERER_MQH
#include "ICTRangeTypes.mqh"
#include "DashboardComponents.mqh"
#include "ICTDashboardPanel.mqh"
int g_range_panel_page=0,g_range_panel_x=-1,g_range_panel_y=-1;
bool g_range_panel_hidden=false;

string IRPrice(const double p) { return p>0 ? DoubleToString(p,_Digits) : "unavailable"; }
string IRAction(const int d) { return d>0 ? "BUY (advisory)" : (d<0 ? "SELL (advisory)" : "NO TRADE"); }
string IRDashboardPrice(const double p) { return p>0 ? DoubleToString(p,_Digits) : "Chưa có"; }
string IRTimeframe(const ENUM_TIMEFRAMES tf)
  { if(tf==PERIOD_CURRENT) return "--"; string name=EnumToString(tf); StringReplace(name,"PERIOD_",""); return name; }

string ICTRangeLiquidityDetails(const SICTRangeSnapshot &s)
  {
   string source=(s.source_pool_id=="" ? "Chưa có vùng thanh khoản nguồn; chỉ có thiết lập cấu trúc / vùng giá nội bộ" :
      s.source_pool_id+" | "+IRTimeframe(s.source_pool_tf)+" | "+ICTDashboardText(ICTRangeLevelEventText(s.source_event))+
      (s.source_event_at>0 ? " | "+TimeToString(s.source_event_at,TIME_DATE|TIME_MINUTES) : ""));
   return "Nguồn thanh khoản: "+source+"\n"+
      "Vùng mục tiêu TP1: "+(s.target1_pool_id!="" ? s.target1_pool_id+" | "+IRTimeframe(s.target1_pool_tf) : "Chưa có mục tiêu")+"\n"+
      "Vùng mục tiêu TP2: "+(s.target2_pool_id!="" ? s.target2_pool_id+" | "+IRTimeframe(s.target2_pool_tf) : "Chưa có")+"\n"+
      "Khoảng cách từ giá vào đến TP1: "+(s.target1_pool_id!="" && s.target_distance>0 ? IRDashboardPrice(s.target_distance) : "Chưa có");
  }

uint IRLiquidityObjectHash(const string value)
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(value);i++) { hash^=(uint)StringGetCharacter(value,i); hash*=16777619; }
   return hash;
  }
void IRKeepLiquidityObject(string &keep[],const string name)
  { int n=ArraySize(keep); ArrayResize(keep,n+1); keep[n]=name; }
void IRReconcileLiquidityObjects(const string prefix,const string &keep[])
  {
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
     {
      string name=ObjectName(0,i,0,-1); if(StringFind(name,prefix)!=0) continue;
      bool found=false;
      for(int j=0;j<ArraySize(keep);j++) if(keep[j]==name) { found=true; break; }
      if(!found) ObjectDelete(0,name);
     }
  }
void ICTRenderRangeLiquidityEvents(const string prefix,const SICTRangeSnapshot &s,
                                   const bool show_irl,const bool show_erl,const int maximum=24)
  {
   string keep[]; int drawn=0;
   double tick=SymbolInfoDouble(s.symbol,SYMBOL_TRADE_TICK_SIZE);
   for(int i=s.liquidity_event_count-1;i>=0 && s.valid && drawn<maximum;i--)
     {
      SICTRangeLiquidityEvent e=s.liquidity_events[i];
      bool external=e.membership==IR_OUTSIDE || e.membership==IR_BOUNDARY;
      if(e.bar_time<s.liquidity_display_start || e.confirmed_at>s.as_of ||
         (external ? !show_erl : e.membership!=IR_INTERNAL || !show_irl)) continue;
      string id=prefix+IntegerToString((long)IRLiquidityObjectHash(e.id));
      string arrow=id+"A",wick=id+"W",label=id+"T";
      int direction=(e.type==IR_EVENT_LIQUIDITY_SWEEP || e.type==IR_EVENT_FALSE_BREAKOUT ? -e.side : e.side);
      color ink=(e.type==IR_EVENT_FALSE_BREAKOUT ? clrTomato : e.type==IR_EVENT_RETEST_CONFIRMED ? clrSeaGreen :
                 e.type==IR_EVENT_BREAKOUT_CONFIRMED ? clrDodgerBlue : clrDarkGoldenrod);
      string text=(external ? "ERL " : "IRL ")+IRTimeframe(e.source_tf)+" "+(e.side>0 ? "BSL " : "SSL ")+
         ICTRangeLevelEventText(e.type)+(e.type==IR_EVENT_LIQUIDITY_SWEEP ? " #"+IntegerToString(e.sweep_number) : "")+
         " | "+IRTimeframe(e.event_tf)+" close";
      string details=text+" | symbol "+s.symbol+" | event ID "+e.id+" | pool "+e.pool_id+" | range "+e.range_id+" | level "+IRPrice(e.level)+
         " | wick "+IRPrice(e.wick)+" at "+TimeToString(e.wick_time,TIME_DATE|TIME_MINUTES)+
         " | close "+IRPrice(e.close)+" confirmed "+TimeToString(e.confirmed_at,TIME_DATE|TIME_MINUTES);
      if(ObjectFind(0,arrow)<0) ObjectCreate(0,arrow,OBJ_ARROW,0,e.confirmed_at,e.close);
      ObjectMove(0,arrow,0,e.confirmed_at,e.close);
      ObjectSetInteger(0,arrow,OBJPROP_ARROWCODE,direction>0 ? 233 : 234);
      ObjectSetInteger(0,arrow,OBJPROP_COLOR,ink); ObjectSetInteger(0,arrow,OBJPROP_SELECTABLE,false);
      if(ObjectFind(0,wick)<0) ObjectCreate(0,wick,OBJ_ARROW,0,e.wick_time,e.wick);
      ObjectMove(0,wick,0,e.wick_time,e.wick); ObjectSetInteger(0,wick,OBJPROP_ARROWCODE,159);
      ObjectSetInteger(0,wick,OBJPROP_COLOR,ink); ObjectSetInteger(0,wick,OBJPROP_SELECTABLE,false);
      int lane=(int)(IRLiquidityObjectHash(e.pool_id)%3);
      RMContextMarker(label,e.confirmed_at,e.close+direction*MathMax(tick,0.0)*(10+lane*8),text,ink);
      ObjectSetString(0,arrow,OBJPROP_TOOLTIP,details); ObjectSetString(0,wick,OBJPROP_TOOLTIP,details);
      ObjectSetString(0,label,OBJPROP_TOOLTIP,details);
      IRKeepLiquidityObject(keep,arrow); IRKeepLiquidityObject(keep,wick); IRKeepLiquidityObject(keep,label); drawn++;
     }
   IRReconcileLiquidityObjects(prefix,keep);
  }

void ICTRenderSweepSequence(const string prefix,const SICTRangeSnapshot &s,const int maximum,
                            const bool show1,const bool show2,const bool show_more,
                            const bool multi,const bool connect)
  {
   int drawn=0;
   for(int i=0;i<ICT_SWEEP_SNAPSHOT_MAX;i++)
     {
      string label=prefix+"E"+IntegerToString(i),line=label+"L";
      if(!s.valid || i>=s.sweep_event_count)
        { ObjectDelete(0,label); ObjectDelete(0,line); continue; }
      SICTSweepRecord e=s.sweep_events[i];
      bool enabled=(e.number==1 ? show1 : e.number==2 ? show2 && multi : show_more && multi);
      // Reserve capacity for first/second sweeps in later pools before drawing
      // less important #3+ labels; this keeps the double-sweep pair visible.
      int reserved=0;
      if(e.number>=3)
         for(int j=i+1;j<s.sweep_event_count;j++)
           {
            SICTSweepRecord later=s.sweep_events[j];
            if(later.event_time>0 && later.status!=ICT_SWEEP_INVALIDATED &&
               ((later.number==1 && show1) || (later.number==2 && show2 && multi))) reserved++;
           }
      if(!enabled || e.status==ICT_SWEEP_INVALIDATED || drawn>=maximum ||
         (e.number>=3 && drawn+reserved>=maximum) || e.event_time<=0)
        { ObjectDelete(0,label); ObjectDelete(0,line); continue; }
      drawn++;
      color ink=(e.number>=3 ? clrPurple : e.side<0 ? (e.number==1 ? clrGoldenrod : clrDarkGreen) :
                 (e.number==1 ? clrDarkOrange : clrMaroon));
      double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double at=e.extreme+(e.side>0 ? 1 : -1)*MathMax(0.0,tick)*(10+(e.number%3)*8);
       ENUM_TIMEFRAMES source_tf=s.range.timeframe;
       bool failed_breakout=false;
       for(int j=0;j<s.liquidity_event_count;j++)
          if(s.liquidity_events[j].pool_id==e.pool_id && s.liquidity_events[j].confirmed_at==e.confirmed_at &&
             s.liquidity_events[j].type==IR_EVENT_FALSE_BREAKOUT) failed_breakout=true;
       for(int j=0;j<s.level_count;j++) if(s.levels[j].id==e.pool_id) { source_tf=s.levels[j].timeframe; break; }
      RMContextMarker(label,e.event_time,at,
          "ERL "+IRTimeframe(source_tf)+" "+(e.side>0 ? "BSL" : "SSL")+
          (failed_breakout ? " FALSE_BREAKOUT" : " SWEEP #"+IntegerToString(e.number))+
         (e.status==ICT_SWEEP_CONFIRMED ? " CONFIRMED" : " CANDIDATE"),ink);
      ObjectSetString(0,label,OBJPROP_TOOLTIP,e.pool_id+" | level "+DoubleToString(e.level,_Digits)+
         " | extreme "+DoubleToString(e.extreme,_Digits)+" | confirmed "+TimeToString(e.confirmed_at,TIME_DATE|TIME_MINUTES));
      int previous=-1;
      if(connect && e.status==ICT_SWEEP_CONFIRMED && e.number>1)
         for(int j=0;j<i;j++)
            if(s.sweep_events[j].pool_id==e.pool_id && s.sweep_events[j].number==e.number-1 &&
               s.sweep_events[j].status==ICT_SWEEP_CONFIRMED) { previous=j; break; }
      if(previous>=0)
        {
         SICTSweepRecord p=s.sweep_events[previous];
         if(ObjectFind(0,line)<0) ObjectCreate(0,line,OBJ_TREND,0,p.event_time,p.extreme,e.event_time,e.extreme);
         ObjectMove(0,line,0,p.event_time,p.extreme); ObjectMove(0,line,1,e.event_time,e.extreme);
         ObjectSetInteger(0,line,OBJPROP_STYLE,STYLE_DASH); ObjectSetInteger(0,line,OBJPROP_COLOR,ink);
         ObjectSetInteger(0,line,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,line,OBJPROP_SELECTABLE,false);
        }
      else ObjectDelete(0,line);
     }
  }

void ICTRenderRange(const string prefix,const SICTRangeSnapshot &s,
                      const bool show_range,const bool show_irl,const bool show_erl,
                      const bool show_targets,const bool show_rotation,
                       const bool active_levels_only=false,const int maximum_liquidity_events=24)
  {
   if(!s.valid || !s.range.valid) { ObjectsDeleteAll(0,prefix); return; }
    ICTRenderRangeLiquidityEvents(prefix+"LE_",s,show_irl,show_erl,maximum_liquidity_events);
   datetime edge=s.as_of; // Real last confirmed timestamp; no fixed bar-ratio projection across sessions.
   RMContextLine(prefix+"RH",show_range ? s.range.high : 0,clrOrange,"Range High | "+IRTimeframe(s.range.timeframe)+" | "+s.range.id);
   RMContextLine(prefix+"RL",show_range ? s.range.low : 0,clrDeepSkyBlue,"Range Low | "+IRTimeframe(s.range.timeframe)+" | "+s.range.id);
   RMContextLine(prefix+"EQ",show_range ? s.range.midpoint : 0,clrDarkGoldenrod,"Equilibrium 50% | "+IRTimeframe(s.range.timeframe)+" | "+s.range.id);
   if(show_range && ICTChartZoneTimeframe(s.range.timeframe))
     {
      RMContextZone(prefix+"PREM",s.range.confirmed_at,edge,s.range.midpoint,s.range.high,C'238,216,218');
      RMContextZone(prefix+"DISC",s.range.confirmed_at,edge,s.range.low,s.range.midpoint,C'211,237,220');
      RMContextMarker(prefix+"LABEL",s.range.confirmed_at,s.range.high,
         "Range "+EnumToString(s.range.timeframe)+" v"+IntegerToString(s.range.version),clrDarkGoldenrod);
     }
   else { ObjectDelete(0,prefix+"PREM"); ObjectDelete(0,prefix+"DISC"); ObjectDelete(0,prefix+"LABEL"); }
   for(int i=0;i<ICT_RANGE_LEVELS;i++)
     {
      string name=prefix+"L"+IntegerToString(i),label=name+"T";
      bool external=i<s.level_count && ICTRangeExternal(s.levels[i],s.range);
      bool internal=i<s.level_count && s.levels[i].range_id==s.range.id && s.levels[i].membership==IR_INTERNAL;
      bool visible=(show_erl && external) || (show_irl && internal);
      if(visible && active_levels_only &&
         (s.levels[i].state==IR_SWEPT || s.levels[i].state==IR_CONSUMED ||
          s.levels[i].state==IR_LEVEL_INVALIDATED)) visible=false;
      if(!visible) { ObjectDelete(0,name); ObjectDelete(0,label); continue; }
      SICTRangeLevel l=s.levels[i];
      color ink=(l.state>=IR_SWEPT ? clrGray : (l.side>0 ? clrDarkOrange : clrSteelBlue));
       string category=(external ? "ERL " : "IRL ")+IRTimeframe(l.timeframe)+" "+(l.side>0 ? "BSL " : "SSL ");
       string details=category+l.name+" "+ICTRangeLevelText(l.state)+" | sweeps "+IntegerToString(l.sweep_count);
       RMContextLine(name,l.price,ink,details+" | "+l.id+" | "+l.range_id);
       RMContextMarker(label,edge,l.price,details,ink);
       ObjectSetInteger(0,name,OBJPROP_WIDTH,l.id==s.source_pool_id || l.id==s.target1_pool_id || l.id==s.target2_pool_id ? 2 : 1);
     }
    double source_price=0; bool source_visible=false;
    for(int i=0;i<s.liquidity_event_count;i++)
       if(s.liquidity_events[i].pool_id==s.source_pool_id && s.liquidity_events[i].confirmed_at==s.source_event_at)
         {
          SICTRangeLiquidityEvent e=s.liquidity_events[i]; source_price=e.level;
          source_visible=(e.membership==IR_INTERNAL ? show_irl : show_erl); break;
         }
    RMContextLine(prefix+"SOURCE_POOL",source_visible ? source_price : 0,clrDarkGoldenrod,
       "Liquidity source | "+ICTRangeSourceExplanation(s));
    if(source_visible) ObjectSetInteger(0,prefix+"SOURCE_POOL",OBJPROP_WIDTH,2);
   bool plan=s.active_zone.id!="" && s.phase!=IR_SETUP_INVALIDATED && s.phase!=IR_TARGET_REACHED;
   if(show_irl && plan && ICTChartReserveZone(s.active_zone.timeframe,s.active_zone.confirmed_at,edge,
                                             s.active_zone.lower,s.active_zone.upper))
     {
      RMContextZone(prefix+"ENTRY",s.active_zone.confirmed_at,edge,s.active_zone.lower,s.active_zone.upper,C'176,198,228');
      ObjectSetString(0,prefix+"ENTRY",OBJPROP_TOOLTIP,"Active "+IRTimeframe(s.active_zone.timeframe)+" "+
                      ICTRangeZoneText(s.active_zone.type)+" price objective | "+s.active_zone.id);
     }
   else ObjectDelete(0,prefix+"ENTRY");
   for(int i=0;i<ICT_RANGE_ZONES;i++)
     {
      string name=prefix+"Z"+IntegerToString(i),label=name+"T";
      bool visible=show_irl && i<s.zone_count && s.zones[i].membership==IR_INTERNAL &&
                   s.zones[i].state<=IR_TOUCHED && s.zones[i].range_id==s.range.id;
      if(visible)
         visible=ICTChartReserveZone(s.zones[i].timeframe,s.zones[i].confirmed_at,edge,
                                     s.zones[i].lower,s.zones[i].upper);
      if(!visible) { ObjectDelete(0,name); ObjectDelete(0,label); continue; }
      SICTRangeZone z=s.zones[i];
      color ink=(z.direction>0 ? C'154,207,174' : C'222,169,172');
      RMContextZone(name,z.confirmed_at,edge,z.lower,z.upper,ink);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,z.id+" | "+z.range_id+" | PD array, not observed resting liquidity");
       RMContextMarker(label,z.confirmed_at,z.upper,IRTimeframe(z.timeframe)+" "+ICTRangeZoneText(z.type)+" | "+
         (z.direction>0 ? "BULL" : "BEAR")+StringFormat(" | %d",z.quality),
         z.direction>0 ? clrDarkGreen : clrMaroon);
      ObjectSetString(0,label,OBJPROP_TOOLTIP,z.id+" | "+z.range_id+" | "+
         (z.state==IR_FRESH ? "Fresh" : "Touched")+" | quality "+IntegerToString(z.quality)+" | price objective");
     }
   RMContextLine(prefix+"TP1",show_targets && plan ? s.tp1 : 0,clrGold,"Scenario TP1, conditional; "+s.target_reason);
    RMContextLine(prefix+"TP2",show_targets && plan ? s.tp2 : 0,clrDarkKhaki,
       "Scenario TP2, conditional | "+s.target2_pool_id+" | "+IRTimeframe(s.target2_pool_tf));
   ObjectSetInteger(0,prefix+"TP1",OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,prefix+"TP2",OBJPROP_STYLE,STYLE_DASH);
   RMContextLine(prefix+"SL",show_targets && plan ? s.stop : 0,clrTomato,"Proposed scenario SL; advisory, not placed");
   string rotation=prefix+"ROT";
    if(show_erl && s.sweep_at>0)
       RMContextMarker(prefix+"SWEEP",s.sweep_at,s.sweep_extreme,"ERL "+IRTimeframe(s.source_pool_tf)+" "+
          ICTRangeLevelEventText(s.source_event)+" (confirmed close)",
                        s.direction>0 ? clrDarkGreen : clrMaroon);
   else ObjectDelete(0,prefix+"SWEEP");
   if(show_rotation && plan && s.tp1>0)
     {
      if(ObjectFind(0,rotation)<0) ObjectCreate(0,rotation,OBJ_TREND,0,s.as_of,s.entry,edge,s.tp1);
      ObjectMove(0,rotation,0,s.as_of,s.entry); ObjectMove(0,rotation,1,edge,s.tp1);
      ObjectSetInteger(0,rotation,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,rotation,OBJPROP_COLOR,clrSlateGray);
      ObjectSetInteger(0,rotation,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,rotation,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,rotation,OBJPROP_TOOLTIP,"Conditional ERL -> IRL -> ERL scenario, not future price data");
     }
   else ObjectDelete(0,rotation);
   string retrace=prefix+"RETRACE";
   if(show_rotation && s.sweep_at>0 && s.reaction_at>s.sweep_at && s.entry>0)
     {
      if(ObjectFind(0,retrace)<0) ObjectCreate(0,retrace,OBJ_TREND,0,s.sweep_at,s.sweep_level,s.reaction_at,s.entry);
      ObjectMove(0,retrace,0,s.sweep_at,s.sweep_level); ObjectMove(0,retrace,1,s.reaction_at,s.entry);
      ObjectSetInteger(0,retrace,OBJPROP_STYLE,STYLE_DOT); ObjectSetInteger(0,retrace,OBJPROP_COLOR,clrSlateGray);
      ObjectSetInteger(0,retrace,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,retrace,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,retrace,OBJPROP_TOOLTIP,"Schematic ERL -> IRL observations; not an intrabar price path");
     }
   else ObjectDelete(0,retrace);
  }

void ICTRenderRangeDashboard(const string prefix,const SICTRangeSnapshot &s,
                              const ENUM_BASE_CORNER corner,const int margin_x,const int margin_y,
                              const int requested_width,const int requested_height,const int font_size,
                              const bool show_market=true,const bool show_ict=true,const bool show_plan=true)
  {
   string title="ICT IRL / ERL | "+s.symbol+" | "+IRTimeframe(s.ltf);
   string status=(s.valid ? (s.proposed_action>0 ? "ƯU TIÊN MUA" : s.proposed_action<0 ? "ƯU TIÊN BÁN" : "KHÔNG GIAO DỊCH")+
                  StringFormat(" | Điểm %d/100",s.score) : "DỮ LIỆU CHƯA SẴN SÀNG");
   color status_ink=(!s.valid ? C'247,135,140' : (s.proposed_action>0 ? C'105,218,154' :
                     (s.proposed_action<0 ? C'247,135,140' : C'250,201,91')));
   if(!s.valid)
     {
      string error_body="[TRẠNG THÁI DỮ LIỆU]\n"+ICTDashboardText(s.reason)+"\n[KHUNG THỜI GIAN PHÂN TÍCH]\nHTF: "+IRTimeframe(s.range.timeframe)+
         " | MTF: "+IRTimeframe(s.mtf)+" | LTF: "+IRTimeframe(s.ltf)+
         "\nĐang chờ dữ liệu nến đóng hợp lệ.";
      ICTRenderPagedPanel(prefix,title,status,status_ink,error_body,corner,margin_x,margin_y,
         requested_width,requested_height,font_size,g_range_panel_page,
         g_range_panel_x,g_range_panel_y,g_range_panel_hidden);
      return;
     }
   string body="[TRẠNG THÁI]\nDiễn biến: "+ICTDashboardText(ICTRangePhaseText(s.phase))+"\n";
   if(show_market)
     {
      body+="[THỊ TRƯỜNG / VÙNG GIÁ]\n";
      body+="HTF: "+(s.htf_bias>0 ? "Tăng" : (s.htf_bias<0 ? "Giảm" : "Trung tính"))+" | "+IRTimeframe(s.range.timeframe)+"\n";
      body+="Vùng giá: "+IRDashboardPrice(s.range.low)+" - "+IRDashboardPrice(s.range.high)+" | Cân bằng "+IRDashboardPrice(s.range.midpoint)+"\n";
      body+="Mã vùng: "+s.range.id+" | phiên bản "+IntegerToString(s.range.version)+"\n";
      body+="Vị trí: "+ICTDashboardText(ICTRangeLocation(s.range,s.last_close))+" | Giá đóng "+IRDashboardPrice(s.last_close)+"\n";
     }
   if(show_ict)
     {
      body+="[THIẾT LẬP ICT]\n";
       body+="Vùng giá nội bộ: "+(s.active_zone.id!="" ? (s.active_zone.type==IR_BREAKER ? ICTDashboardText("BREAKER") : ICTRangeZoneText(s.active_zone.type)) : "Không có")+
         (s.active_zone.id!="" ? StringFormat(" | chất lượng %d/100 | ",s.active_zone.quality)+ICTDashboardText(ICTRangeZoneStateText(s.active_zone.state)) : "")+"\n";
       body+="Giới hạn vùng giá: "+IRDashboardPrice(s.active_zone.lower)+" - "+IRDashboardPrice(s.active_zone.upper)+" (không phải vùng thanh khoản)\n";
       body+=ICTRangeLiquidityDetails(s)+"\n";
      body+="Quét thanh khoản: "+(s.sweep_at>0 ? TimeToString(s.sweep_at,TIME_DATE|TIME_MINUTES) : "Chưa có")+
            " | Cấu trúc: "+(s.structure_confirmed ? "Đã xác nhận" : "Chờ")+
            " | Dịch chuyển: "+(s.displacement ? "Đã xác nhận" : "Chờ")+"\n";
      double above=0,below=0; string a="",b="";
      for(int i=0;i<s.level_count;i++)
        {
         SICTRangeLevel l=s.levels[i]; if(!ICTRangeExternal(l,s.range)) continue;
         if(l.side>0 && (above==0 || l.price<above)) { above=l.price; a=ICTRangeLevelText(l.state); }
         if(l.side<0 && (below==0 || l.price>below)) { below=l.price; b=ICTRangeLevelText(l.state); }
        }
      body+="ERL phía trên: "+IRDashboardPrice(above)+(a!="" ? " "+ICTDashboardText(a) : "")+
            " | phía dưới: "+IRDashboardPrice(below)+(b!="" ? " "+ICTDashboardText(b) : "")+"\n";
     }
   if(show_plan)
     {
      body+="[KẾ HOẠCH GIAO DỊCH]\n";
      body+="Giá vào đề xuất / SL: "+IRDashboardPrice(s.entry)+" / "+IRDashboardPrice(s.stop)+"\n";
      body+="Mục tiêu kịch bản TP1 / TP2: "+IRDashboardPrice(s.tp1)+" / "+IRDashboardPrice(s.tp2)+"\n";
      body+=(s.rr>0 ? StringFormat("RR ròng %.2f | Khối lượng %.4f | Rủi ro %.2f %s\n",s.rr,s.volume,s.risk_money,AccountInfoString(ACCOUNT_CURRENCY)) :
                     "Chưa có RR / khối lượng / tiền rủi ro cho đến khi đạt điều kiện rủi ro\n");
      if(s.entry>0 && s.stop>0 && _Point>0) body+=StringFormat("Khoảng cách SL %.1f điểm\n",MathAbs(s.entry-s.stop)/_Point);
      body+="Mức mất hiệu lực: "+IRDashboardPrice(s.invalidation)+" | "+ICTDashboardText(s.target_reason)+"\n";
     }
   body+="[CHI TIẾT QUYẾT ĐỊNH]\nLý do ["+IntegerToString((int)s.reason_code)+"]: "+ICTDashboardText(s.reason)+"\n";
   body+="Nến đóng xác nhận: "+(s.as_of>0 ? TimeToString(s.as_of,TIME_DATE|TIME_MINUTES) : "Chưa có")+"\n";
   body+="Điểm chất lượng / hợp lưu không phải xác suất thắng. Mục tiêu nét đứt có điều kiện.";
   body+=ICTChartLegend();
   ICTRenderPagedPanel(prefix,title,status,status_ink,body,corner,margin_x,margin_y,
      requested_width,requested_height,font_size,g_range_panel_page,
      g_range_panel_x,g_range_panel_y,g_range_panel_hidden);
  }
#endif
