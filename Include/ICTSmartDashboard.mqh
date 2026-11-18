#ifndef ICT_SMART_DASHBOARD_MQH
#define ICT_SMART_DASHBOARD_MQH
#include "ICTDecisionRenderer.mqh"
#include "ICTRangeRenderer.mqh"

string ICTSmartEvidence(const SICTDecision &d,const uint bit,const bool range_mode)
  {
   if(!d.data_quality_ok) return "DATA UNAVAILABLE";
   if(range_mode && d.direction==0) return "NOT CONFIRMED";
   if(range_mode)
      return (d.confirmed&bit)!=0 ? (d.direction>0 ? "BUY CONFIRMED" : "SELL CONFIRMED") : "NOT CONFIRMED";
   bool buy=(d.buy_confirmed&bit)!=0,sell=(d.sell_confirmed&bit)!=0;
   if(buy && sell) return "BUY / SELL CONFIRMED";
   if(buy) return "BUY CONFIRMED";
   if(sell) return "SELL CONFIRMED";
   return "NOT CONFIRMED";
  }

string ICTSmartSMTSlotText(const string selected,const bool manual,const bool automatic)
  {
   if(manual) return "MANUAL: "+(selected=="" ? "--" : selected);
   if(automatic) return "AUTO: "+(selected=="" ? "WAIT DATA" : selected);
   return "OFF";
  }

string ICTSmartTimeframe(const ENUM_TIMEFRAMES timeframe)
  {
   string text=EnumToString(timeframe);
   StringReplace(text,"PERIOD_","");
   return text;
  }

void ICTSmartEye(const string prefix,const int x,const int y,const bool hidden)
  {
   ICTPanelButton(prefix+"eye","👁",hidden ? "Show ICT dashboard" : "Hide ICT dashboard",x,y,32,25,12);
   ObjectSetString(0,prefix+"eye",OBJPROP_FONT,"Segoe UI Emoji");
  }

int ICTSmartPanelHeight(const int row,const bool show_market,const bool show_ict,
                        const bool show_plan,const bool has_reason,const int extra_rows=0)
  {
   int rows=(show_market ? 1 : 0)+(show_ict ? 6 : 0)+
            (show_plan ? 2 : 0)+(has_reason ? 1 : 0);
   return 113+2+(rows+extra_rows)*row+8;
  }

string ICTSmartSweepText(const SICTRangeSnapshot &s,const int number)
  {
   int selected=-1,anchor=-1;
   for(int i=0;i<s.sweep_event_count;i++)
      if((s.direction==0 || s.sweep_events[i].side==-s.direction) &&
         (anchor<0 || s.sweep_events[i].event_time>s.sweep_events[anchor].event_time)) anchor=i;
   if(anchor>=0)
      for(int i=0;i<s.sweep_event_count;i++)
         if(s.sweep_events[i].number==number && s.sweep_events[i].pool_id==s.sweep_events[anchor].pool_id)
            { selected=i; break; }
   if(selected<0) return "--";
   SICTSweepRecord e=s.sweep_events[selected];
   string state=e.status==ICT_SWEEP_CONFIRMED ? "CONFIRMED" :
                (e.status==ICT_SWEEP_CANDIDATE ? "CANDIDATE" : "INVALIDATED");
   return (e.side>0 ? "BSL " : "SSL ")+TimeToString(e.event_time,TIME_DATE|TIME_MINUTES)+
          " "+ICTPriceLabel(e.extreme)+" "+state;
  }

void ICTSmartBox(const string name,const int x,const int y,const int w,const int h,const color bg)
  {
   RMPanelLeft(name,x,y,w,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

void ICTSmartText(const string name,const string value,const int x,const int y,
                  const color ink,const int size,const int width)
  {
   int fit=ICTPanelFit(value,width,size);
   string shown=(fit<StringLen(value) ? StringSubstr(value,0,(int)MathMax(0,fit-3))+"..." : value);
   ICTPanelLabel(name,shown,x,y,ink,size);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,value);
  }

// Dashboard receives the decision already computed by the active engine.
// Range mode only computes directional scores after its risk gates; show --
// beforehand, rather than presenting the uncomputed side as a zero score.
void ICTRenderSmartDashboard(const string prefix,const SICTDecision &d,
                             const SICTRangeSnapshot &range,const bool range_mode,
                             const ENUM_BASE_CORNER corner,const int margin_x,const int margin_y,
                             const int requested_width,const int requested_height,const int font_size,
                             const int moved_x,const int moved_y,const bool hidden,
                             const bool show_market,const bool show_ict,const bool show_plan,
                             const string smt1,const string smt2,
                             const bool manual1,const bool auto1,
                             const bool manual2,const bool auto2,
                             const ENUM_TIMEFRAMES analysis_tf,
                             const ENUM_TIMEFRAMES mtf,const ENUM_TIMEFRAMES htf,
                             const bool automatic_mapping)
  {
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(cw<60 || ch<60) { ObjectsDeleteAll(0,prefix); return; }
   int width=(int)MathMin(MathMax(300,requested_width),cw-8);
   int available_height=(int)MathMin(MathMax(120,requested_height),ch-8);
   int fs=(int)MathMax(7,MathMin(font_size,10));
   uint measured_width=0,measured_height=0;
   bool has_reason=(d.reason!="");
   int row=0,content_height=0;
   do
     {
      TextSetFont("Segoe UI",-fs*10,0);
      row=(TextGetSize("Ag",measured_width,measured_height) ?
           (int)MathMax(16,(int)measured_height+3) : (int)MathMax(16,fs*2));
      content_height=ICTSmartPanelHeight(row,show_market,show_ict,show_plan,has_reason,(range_mode && show_ict ? 2 : 0));
      if(content_height<=available_height || fs<=7) break;
      fs--;
     }
   while(true);
   int height=(int)MathMin(content_height,available_height);
   bool right=corner==CORNER_RIGHT_UPPER || corner==CORNER_RIGHT_LOWER;
   bool bottom=corner==CORNER_LEFT_LOWER || corner==CORNER_RIGHT_LOWER;
   int x=(moved_x>=0 ? moved_x : (right ? cw-margin_x-width : margin_x));
   int y=(moved_y>=0 ? moved_y : (bottom ? ch-margin_y-height : margin_y));
   x=(int)MathMax(0,MathMin(x,cw-width-4)); y=(int)MathMax(0,MathMin(y,ch-height));
   if(hidden)
     {
      ObjectsDeleteAll(0,prefix);
      ICTSmartEye(prefix,x+10,y+10,true);
      return;
     }
   // Small charts or a low height limit use the existing paged panel rather
   // than drawing text outside the background.
   static bool paged=false;
   bool use_paged=width<280 || content_height>available_height;
   if(paged!=use_paged) { ObjectsDeleteAll(0,prefix); paged=use_paged; }
   if(use_paged)
     {
      string title=_Symbol+" | CHART "+ICTSmartTimeframe((ENUM_TIMEFRAMES)_Period)+" | ICT SMART DECISION";
      string status=d.data_quality_ok ? ICTPriorityLabel(d) : "DATA UNAVAILABLE";
      bool available=d.data_quality_ok && (!range_mode || d.hard_filters_passed);
      string buy=(available && (!range_mode || d.direction>0) ? IntegerToString(d.buy_score) : "--");
      string sell=(available && (!range_mode || d.direction<0) ? IntegerToString(d.sell_score) : "--");
      string body="BUY "+buy+" | SELL "+sell+
                  "\nAnalysis timeframe: "+ICTSmartTimeframe(analysis_tf)+
                  "\nMTF: "+(mtf==PERIOD_CURRENT ? "N/A" : ICTSmartTimeframe(mtf))+
                  " | HTF: "+(htf==PERIOD_CURRENT ? "N/A" : ICTSmartTimeframe(htf))+
                  (automatic_mapping ? " | AUTO" : " | MANUAL")+
                  "\nState: "+ICTStateText(d.state)+"\nReason: "+d.reason+
                  "\nSMT 1: "+ICTSmartSMTSlotText(smt1,manual1,auto1)+
                  "\nSMT 2: "+ICTSmartSMTSlotText(smt2,manual2,auto2)+
                  (range_mode && show_ict ? "\nSweep #1: "+ICTSmartSweepText(range,1)+"\nSweep #2: "+ICTSmartSweepText(range,2) : "")+
                  "\nResize chart or increase Dashboard_Height for compact overview.";
      ICTRenderPagedPanel(prefix,title,status,C'250,201,91',body,corner,margin_x,margin_y,
         requested_width,available_height,fs,g_ict_dashboard_page,moved_x,moved_y,false);
      return;
     }
   color ink=C'226,232,239',muted=C'162,172,184',green=C'46,207,125',red=C'245,112,112',yellow=C'239,191,88';
   ICTSmartBox(prefix+"panel",x,y,width,height,C'35,39,45');
   ObjectSetInteger(0,prefix+"panel",OBJPROP_SELECTABLE,true);
   ObjectSetString(0,prefix+"panel",OBJPROP_TOOLTIP,"Drag dashboard to move");
   ICTSmartEye(prefix,x+10,y+10,false);
   ICTSmartText(prefix+"title",_Symbol+" | CHART "+ICTSmartTimeframe((ENUM_TIMEFRAMES)_Period)+" | ICT SMART DECISION",x+48,y+9,ink,fs,width-56);
   string status=(!d.data_quality_ok ? "DATA UNAVAILABLE" : ICTPriorityLabel(d));
   color status_color=(!d.data_quality_ok ? yellow : d.priority==ICT_PRIORITY_BUY ? green : d.priority==ICT_PRIORITY_SELL ? red : yellow);
   ICTSmartText(prefix+"status",status+" | LTF "+ICTSmartTimeframe(analysis_tf)+
      " | MTF "+(mtf==PERIOD_CURRENT ? "N/A" : ICTSmartTimeframe(mtf))+
      " | HTF "+(htf==PERIOD_CURRENT ? "N/A" : ICTSmartTimeframe(htf))+
      (automatic_mapping ? " | AUTO" : " | MANUAL"),x+12,y+35,status_color,fs,width-24);
   int top=y+58,card=(width-30)/2;
   ICTSmartBox(prefix+"buybox",x+10,top,card,48,C'18,21,25');
   ICTSmartBox(prefix+"sellbox",x+20+card,top,card,48,C'18,21,25');
   bool scores_available=d.data_quality_ok && (!range_mode || d.hard_filters_passed);
   bool buy_available=scores_available && (!range_mode || d.direction>0);
   bool sell_available=scores_available && (!range_mode || d.direction<0);
   string buy=buy_available ? IntegerToString(d.buy_score)+" / 100" : "-- / 100";
   string sell=sell_available ? IntegerToString(d.sell_score)+" / 100" : "-- / 100";
   ICTSmartText(prefix+"buylabel","BUY SCORE",x+18,top+4,muted,fs,card-12);
   ICTSmartText(prefix+"buyvalue",buy,x+18,top+23,green,fs,card-12);
   ICTSmartText(prefix+"selllabel","SELL SCORE",x+28+card,top+4,muted,fs,card-12);
   ICTSmartText(prefix+"sellvalue",sell,x+28+card,top+23,red,fs,card-12);
   int bar_width=card-16;
   ICTSmartBox(prefix+"buytrack",x+18,top+43,bar_width,3,C'70,75,82');
   ICTSmartBox(prefix+"selltrack",x+28+card,top+43,bar_width,3,C'70,75,82');
   int buy_width=buy_available ? (int)MathRound(bar_width*MathMax(0,MathMin(100,d.buy_score))/100.0) : 0;
   int sell_width=sell_available ? (int)MathRound(bar_width*MathMax(0,MathMin(100,d.sell_score))/100.0) : 0;
   if(buy_width>0) ICTSmartBox(prefix+"buybar",x+18,top+43,buy_width,3,green); else ObjectDelete(0,prefix+"buybar");
   if(sell_width>0) ICTSmartBox(prefix+"sellbar",x+28+card,top+43,sell_width,3,red); else ObjectDelete(0,prefix+"sellbar");
   int start=top+55;
   string names[7]={"HTF bias","Liquidity sweep","Market structure","Fair value gap","Order block","SMT divergence","SMT symbols"};
   uint bits[7]={ICT_E_HTF,ICT_E_SWEEP,ICT_E_MSS,ICT_E_FVG,ICT_E_OB,ICT_E_SMT,0};
   int visible_row=0;
   for(int i=0;i<7;i++)
     {
      string value=(i==6 ? ICTSmartSMTSlotText(smt1,manual1,auto1)+" | "+ICTSmartSMTSlotText(smt2,manual2,auto2) :
                    i==0 && d.data_quality_ok ? ICTBiasLabel(d.higher_bias) : ICTSmartEvidence(d,bits[i],range_mode));
      string label=prefix+"key"+IntegerToString(i),val=prefix+"val"+IntegerToString(i);
      if((i==0 && !show_market) || (i>0 && !show_ict))
        { ObjectDelete(0,label); ObjectDelete(0,val); continue; }
      ICTSmartText(label,names[i],x+12,start+visible_row*row,ink,fs,width/2-15);
      ICTSmartText(val,value,x+width/2,start+visible_row*row,(StringFind(value,"CONFIRMED")>=0 && value!="NOT CONFIRMED" ? green : muted),fs,width/2-12);
      visible_row++;
     }
   for(int i=1;i<=2;i++)
     {
      string key=prefix+"sweepkey"+IntegerToString(i),value=prefix+"sweepval"+IntegerToString(i);
      if(!range_mode || !show_ict) { ObjectDelete(0,key); ObjectDelete(0,value); continue; }
      ICTSmartText(key,"Sweep #"+IntegerToString(i),x+12,start+visible_row*row,ink,fs,width/2-15);
      ICTSmartText(value,ICTSmartSweepText(range,i),x+width/2,start+visible_row*row,muted,fs,width/2-12);
      visible_row++;
     }
   int plan_y=start+visible_row*row+2;
   bool ready=d.data_quality_ok && d.state==ICT_ENTRY_READY && d.hard_filters_passed && d.entry_confirmed && d.risk.valid;
   string plan=ready ? "ADVISORY PLAN | NET RR "+DoubleToString(d.risk.rr,2) : "PLAN BLOCKED / WAIT";
   if(show_plan) ICTSmartText(prefix+"planhead",plan,x+12,plan_y,ready ? green : yellow,fs,width-24);
   else ObjectDelete(0,prefix+"planhead");
   string values=ready ? "ENTRY "+ICTPriceLabel(d.entry)+"   SL "+ICTPriceLabel(d.stop)+"   TP "+ICTPriceLabel(d.target) :
                         "ENTRY --    SL --    TP --";
   if(show_plan) ICTSmartText(prefix+"plan",values,x+12,plan_y+row,ink,fs,width-24);
   else ObjectDelete(0,prefix+"plan");
   if(has_reason)
     {
      ICTSmartText(prefix+"reason",d.reason,x+12,plan_y+(show_plan ? row*2 : 0),muted,fs,width-24);
      ObjectSetString(0,prefix+"reason",OBJPROP_TOOLTIP,d.reason+" | Closed bar: "+ICTTimeLabel(d.as_of));
     }
   else ObjectDelete(0,prefix+"reason");
  }
#endif
