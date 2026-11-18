#ifndef ICT_CHART_LAYOUT_MQH
#define ICT_CHART_LAYOUT_MQH

// This layout is enabled only by the decision EA. Other dashboard consumers
// keep the normal marker and zone behaviour.
struct SICTChartLabel
  {
   string name,text;
   datetime time;
   double price;
   color ink;
  };
struct SICTChartRect { int left,top,right,bottom; };
struct SICTChartZone { datetime first,last; double low,high; };

SICTChartLabel g_ict_chart_labels[];
SICTChartZone g_ict_chart_zones[];
bool g_ict_chart_collect=false;
string g_ict_chart_prefix="";
ENUM_TIMEFRAMES g_ict_chart_zone_tf=PERIOD_CURRENT;
int g_ict_chart_font=10;
int g_ict_chart_zone_suppressed=0;

string ICTChartLegend()
  {
   return "\n[CHÚ THÍCH BIỂU ĐỒ]\n"
          "OB: khối lệnh | FVG: vùng giá mất cân bằng\n"
          "BPR: vùng giá cân bằng | BSL / SSL: thanh khoản bên mua / bán\n"
          "BOS: phá cấu trúc | MSS: thay đổi cấu trúc\n"
          "Premium / Discount: vùng giá cao / thấp so với điểm cân bằng\n"
          "HTF / MTF / LTF: khung lớn / trung gian / nhỏ\n"
          "SL / TP: dừng lỗ / chốt lời | RR: tỷ lệ lợi nhuận / rủi ro";
  }

bool ICTChartRectOverlap(const SICTChartRect &a,const SICTChartRect &b)
  { return a.left<b.right && b.left<a.right && a.top<b.bottom && b.top<a.bottom; }

bool ICTChartRectTooClose(const SICTChartRect &a,const SICTChartRect &b,const int gap)
  {
   return a.left<b.right+gap && b.left<a.right+gap &&
          a.top<b.bottom+gap && b.top<a.bottom+gap;
  }

// Return the pixel rectangle reserved for the text.
// A finite number of nearby rows keeps an annotation associated with its event;
// lower-priority labels are hidden when all nearby slots are occupied.
bool ICTChartFindLabelRect(const int x,const int y,const int width,const int height,
                           const int chart_width,const int chart_height,
                           const SICTChartRect &occupied[],SICTChartRect &result)
  {
   if(width<=0 || height<=0 || chart_width<=0 || chart_height<=0) return false;
   for(int lane=0;lane<7;lane++)
      for(int side=0;side<2;side++)
        {
         int offset=(lane==0 ? 0 : ((lane+1)/2)*(height+4)*(lane%2==1 ? -1 : 1));
         SICTChartRect candidate;
         candidate.left=(side==0 ? x+5 : x-width-5); candidate.top=y+offset-height/2;
         candidate.right=candidate.left+width; candidate.bottom=candidate.top+height;
         if(candidate.left<2 || candidate.right>chart_width-2 ||
            candidate.top<2 || candidate.bottom>chart_height-2) continue;
         bool collision=false;
         for(int j=0;j<ArraySize(occupied);j++)
            if(ICTChartRectTooClose(candidate,occupied[j],4)) { collision=true; break; }
         if(collision) continue;
         result.left=candidate.left; result.top=candidate.top;
         result.right=candidate.right; result.bottom=candidate.bottom;
         return true;
        }
   return false;
  }

bool ICTChartZoneOverlap(const datetime first,const datetime last,const double low,const double high,
                         const datetime other_first,const datetime other_last,const double other_low,const double other_high)
  { return first<other_last && other_first<last && low<other_high && other_low<high; }

int ICTChartScaledFontSize(const int base_size)
  { return (int)MathMax(1,MathRound((double)base_size*0.75)); }

void ICTChartLayoutBegin(const string prefix,const ENUM_TIMEFRAMES zone_tf,const int font_size)
  {
   g_ict_chart_prefix=prefix; g_ict_chart_zone_tf=zone_tf; g_ict_chart_font=font_size;
   ArrayResize(g_ict_chart_zones,0); g_ict_chart_zone_suppressed=0; g_ict_chart_collect=true;
  }

bool ICTChartZoneTimeframe(const ENUM_TIMEFRAMES tf)
  { return !g_ict_chart_collect || tf==g_ict_chart_zone_tf; }

// Reserve only meaningful price objectives. Premium/discount is a separate
// backdrop and deliberately does not suppress the more specific objectives.
bool ICTChartReserveZone(const ENUM_TIMEFRAMES tf,const datetime first,const datetime last,
                         const double low,const double high)
  {
   if(!g_ict_chart_collect) return true;
   if(tf!=g_ict_chart_zone_tf || first<=0 || last<=first || low<=0 || high<=low) return false;
   for(int i=0;i<ArraySize(g_ict_chart_zones);i++)
      if(ICTChartZoneOverlap(first,last,low,high,g_ict_chart_zones[i].first,g_ict_chart_zones[i].last,
                             g_ict_chart_zones[i].low,g_ict_chart_zones[i].high))
        { g_ict_chart_zone_suppressed++; return false; }
   int n=ArraySize(g_ict_chart_zones); ArrayResize(g_ict_chart_zones,n+1);
   g_ict_chart_zones[n].first=first; g_ict_chart_zones[n].last=last;
   g_ict_chart_zones[n].low=low; g_ict_chart_zones[n].high=high;
   return true;
  }

void ICTChartRegisterLabel(const string name,const datetime time,const double price,
                           const string text,const color ink)
  {
   if(!g_ict_chart_collect) return;
   int n=ArraySize(g_ict_chart_labels),index=-1;
   for(int i=0;i<n;i++) if(g_ict_chart_labels[i].name==name) { index=i; break; }
   if(index<0) { index=n; ArrayResize(g_ict_chart_labels,n+1); }
   g_ict_chart_labels[index].name=name;
   g_ict_chart_labels[index].time=time; g_ict_chart_labels[index].price=price;
   g_ict_chart_labels[index].text=text; g_ict_chart_labels[index].ink=ink;
  }

double ICTChartChannel(const int channel)
  { double v=channel/255.0; return v<=0.04045 ? v/12.92 : MathPow((v+0.055)/1.055,2.4); }
double ICTChartLuminance(const color value)
  {
   int c=(int)value;
   return 0.2126*ICTChartChannel(c&255)+0.7152*ICTChartChannel((c>>8)&255)+0.0722*ICTChartChannel((c>>16)&255);
  }
double ICTChartContrast(const color a,const color b)
  {
   double x=ICTChartLuminance(a),y=ICTChartLuminance(b);
   return (MathMax(x,y)+0.05)/(MathMin(x,y)+0.05);
  }
color ICTChartReadableColor(const color ink,const color background,const bool dark)
  {
   int c=(int)ink,r=c&255,g=(c>>8)&255,b=(c>>16)&255;
   color result=ink;
   for(int i=0;i<20 && ICTChartContrast(result,background)<4.5;i++)
     {
      int target=dark ? 255 : 0;
      r=(int)MathRound(r+(target-r)*0.2); g=(int)MathRound(g+(target-g)*0.2); b=(int)MathRound(b+(target-b)*0.2);
      result=(color)(r|(g<<8)|(b<<16));
     }
   return result;
  }

int ICTChartLabelPriority(const string name)
  {
   if(StringFind(name,"signals_")>=0) return 0;
   if(StringFind(name,"sweep")>=0 || StringFind(name,"LE_")>=0) return 1;
   if(StringFind(name,"ob_")>=0 || StringFind(name,"range_Z")>=0) return 2;
   if(StringFind(name,"smt_")>=0) return 3;
   return 4;
  }

void ICTChartLayoutApply(const string panel_prefix,const string second_panel_prefix="")
  {
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(cw<80 || ch<60) return;
   SICTChartRect occupied[];
   string panel_prefixes[2]; panel_prefixes[0]=panel_prefix; panel_prefixes[1]=second_panel_prefix;
   for(int p=0;p<2;p++)
     {
      if(panel_prefixes[p]=="") continue;
      string panel=panel_prefixes[p]+"panel";
      if(ObjectFind(0,panel)<0) panel=panel_prefixes[p]+"eye";
      if(ObjectFind(0,panel)<0) continue;
      int n=ArraySize(occupied); ArrayResize(occupied,n+1);
      occupied[n].left=(int)ObjectGetInteger(0,panel,OBJPROP_XDISTANCE)-4;
      occupied[n].top=(int)ObjectGetInteger(0,panel,OBJPROP_YDISTANCE)-4;
      occupied[n].right=occupied[n].left+(int)ObjectGetInteger(0,panel,OBJPROP_XSIZE)+8;
      occupied[n].bottom=occupied[n].top+(int)ObjectGetInteger(0,panel,OBJPROP_YSIZE)+8;
     }
   color background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   // Choose the black/white endpoint with the greater possible contrast.
   bool dark=ICTChartLuminance(background)<0.179;
   TextSetFont("Segoe UI",-g_ict_chart_font*10,0);
   for(int priority=0;priority<5;priority++)
      for(int i=0;i<ArraySize(g_ict_chart_labels);i++)
        {
         SICTChartLabel label=g_ict_chart_labels[i];
         if(ICTChartLabelPriority(label.name)!=priority || ObjectFind(0,label.name)<0) continue;
         int x=0,y=0; uint width=0,height=0;
         string display=label.text;
         int max_width=(int)MathMax(80,MathMin(260,cw/2));
         if(!TextGetSize(display,width,height)) { width=(uint)(StringLen(display)*g_ict_chart_font); height=(uint)(g_ict_chart_font*2); }
         while((int)width>max_width && StringLen(display)>4)
           {
            display=StringSubstr(display,0,StringLen(display)-1);
            string shortened=display+"...";
            if(!TextGetSize(shortened,width,height)) width=(uint)(StringLen(shortened)*g_ict_chart_font);
           }
         if(display!=label.text) display+="...";
         int w=(int)width+8,h=(int)MathMax((int)height,g_ict_chart_font+4)+4;
         bool placed=false; SICTChartRect candidate={0,0,0,0};
         if(ChartTimePriceToXY(0,0,label.time,label.price,x,y) && x>=0 && x<cw && y>=0 && y<ch)
            placed=ICTChartFindLabelRect(x,y,w,h,cw,ch,occupied,candidate);
         if(placed)
           {
            // OBJ_LABEL uses screen pixels directly. Converting the chosen
            // position back to candle time can snap multiple labels to the
            // same bar, so it must not be used for collision placement.
            ObjectSetInteger(0,label.name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
            ObjectSetInteger(0,label.name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
            ObjectSetInteger(0,label.name,OBJPROP_XDISTANCE,candidate.left+4);
            ObjectSetInteger(0,label.name,OBJPROP_YDISTANCE,candidate.top+2);
            ObjectSetString(0,label.name,OBJPROP_FONT,"Segoe UI");
            ObjectSetInteger(0,label.name,OBJPROP_FONTSIZE,g_ict_chart_font);
            ObjectSetInteger(0,label.name,OBJPROP_COLOR,ICTChartReadableColor(label.ink,background,dark));
            ObjectSetString(0,label.name,OBJPROP_TEXT,display);
            ObjectSetInteger(0,label.name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
            int n=ArraySize(occupied); ArrayResize(occupied,n+1); occupied[n]=candidate;
           }
         if(!placed)
           {
            ObjectSetInteger(0,label.name,OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);
           }
        }
   for(int i=ArraySize(g_ict_chart_labels)-1;i>=0;i--)
      if(ObjectFind(0,g_ict_chart_labels[i].name)<0)
        {
         for(int j=i+1;j<ArraySize(g_ict_chart_labels);j++) g_ict_chart_labels[j-1]=g_ict_chart_labels[j];
         ArrayResize(g_ict_chart_labels,ArraySize(g_ict_chart_labels)-1);
        }
  }

void ICTChartLayoutEnd(const string panel_prefix,const string second_panel_prefix="")
  { g_ict_chart_collect=false; ICTChartLayoutApply(panel_prefix,second_panel_prefix); }
#endif
