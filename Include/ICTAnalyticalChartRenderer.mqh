#ifndef ICT_ANALYTICAL_CHART_RENDERER_MQH
#define ICT_ANALYTICAL_CHART_RENDERER_MQH
#include "ICTAnalyticalConsensus.mqh"
#include "DashboardComponents.mqh"

bool ICTAnalyticalChartMark(const long chart,const string name,const MqlRates &bar,const double atr,
                             const SICTAnalyticalResult &result,const string details)
  {
   if(!result.signal || !SRMPValidDetectorBar(bar) || atr<=0 || (result.direction!=1 && result.direction!=-1)) return false;
   double price=(result.direction>0 ? bar.low-0.25*atr : bar.high+0.25*atr);
   color background=(color)ChartGetInteger(chart,CHART_COLOR_BACKGROUND);
   color ink=ICTChartReadableColor(result.experimental ? clrDarkOrange : result.direction>0 ? clrSeaGreen : clrCrimson,
      background,ICTChartLuminance(background)<0.179);
   if(ObjectFind(chart,name)<0 && !ObjectCreate(chart,name,OBJ_ARROW,0,bar.time,price)) return false;
   ObjectMove(chart,name,0,bar.time,price); ObjectSetInteger(chart,name,OBJPROP_ARROWCODE,result.direction>0 ? 233 : 234);
   ObjectSetInteger(chart,name,OBJPROP_COLOR,ink); ObjectSetInteger(chart,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(chart,name,OBJPROP_BACK,false); ObjectSetInteger(chart,name,OBJPROP_SELECTABLE,false);
   ObjectSetString(chart,name,OBJPROP_TOOLTIP,details); return true;
  }
void ICTAnalyticalChartBadge(const long chart,const string prefix,const string headline,const string detail,const bool ready)
  {
   color background=(color)ChartGetInteger(chart,CHART_COLOR_BACKGROUND);
   color ink=ICTChartReadableColor(ready ? clrRoyalBlue : clrDarkOrange,background,ICTChartLuminance(background)<0.179);
   for(int i=0;i<2;i++)
     {
      string name=prefix+IntegerToString(i);
      if(ObjectFind(chart,name)<0) ObjectCreate(chart,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(chart,name,OBJPROP_CORNER,CORNER_RIGHT_LOWER); ObjectSetInteger(chart,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);
      ObjectSetInteger(chart,name,OBJPROP_XDISTANCE,12); ObjectSetInteger(chart,name,OBJPROP_YDISTANCE,i==0 ? 26 : 10);
      ObjectSetInteger(chart,name,OBJPROP_COLOR,ink); ObjectSetInteger(chart,name,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(chart,name,OBJPROP_SELECTABLE,false); ObjectSetInteger(chart,name,OBJPROP_BACK,false);
      ObjectSetString(chart,name,OBJPROP_FONT,"Segoe UI Semibold"); ObjectSetString(chart,name,OBJPROP_TEXT,i==0 ? headline : detail);
     }
  }
#endif
