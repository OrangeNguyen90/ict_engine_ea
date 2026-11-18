#ifndef SMART_RISK_DASHBOARD_COMPONENTS_MQH
#define SMART_RISK_DASHBOARD_COMPONENTS_MQH
#include "ICTChartLayout.mqh"

bool RMPanel(const string name,const int x,const int y,const int width,const int height)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0)) return false;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   // Fixed-size objects are anchored at their upper-left corner even when
   // their coordinates are measured from the chart's right edge.
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x+width);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'24,29,38');
   ObjectSetInteger(0,name,OBJPROP_COLOR,C'58,68,81');
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   return true;
  }

bool RMPanelLeft(const string name,const int x,const int y,const int width,const int height)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0)) return false;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'24,29,38');
   ObjectSetInteger(0,name,OBJPROP_COLOR,C'58,68,81');
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   return true;
  }

void RMText(const string name,const string value,const int x,const int y,
            const color ink,const int font_size=9)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,value=="" ? " " : value);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void RMTextLeft(const string name,const string value,const int x,const int y,
                const color ink)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,value=="" ? " " : value);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void RMButton(const string name,const string caption,const int x,const int y,
              const int width,const color background)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_BUTTON,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   // Callers specify the button's right margin, not its left-edge distance.
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x+width);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,24);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,name,OBJPROP_TEXT,caption);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void RMLine(const string name,const double price,const color ink)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_HLINE,0,0,price)) return;
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
  }

void RMContextLine(const string name,const double price,const color ink,
                   const string description)
  {
   if(price<=0.0) { ObjectDelete(0,name); return; }
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_HLINE,0,0,price)) return;
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,description);
  }

void RMContextMarker(const string name,const datetime bar,const double price,
                     const string label,const color ink)
  {
   if(bar<=0 || price<=0.0) { ObjectDelete(0,name); return; }
   ENUM_OBJECT kind=(g_ict_chart_collect ? OBJ_LABEL : OBJ_TEXT);
   if(ObjectFind(0,name)>=0 && (ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE)!=kind)
      ObjectDelete(0,name);
   if(ObjectFind(0,name)<0)
     {
      bool created=(g_ict_chart_collect ? ObjectCreate(0,name,OBJ_LABEL,0,0,0) :
                                          ObjectCreate(0,name,OBJ_TEXT,0,bar,price));
      if(!created) return;
     }
   if(!g_ict_chart_collect) ObjectMove(0,name,0,bar,price);
   ObjectSetString(0,name,OBJPROP_TEXT,label);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,g_ict_chart_collect ? g_ict_chart_font : 8);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,label);
   ICTChartRegisterLabel(name,bar,price,label,ink);
  }

void RMContextZone(const string name,const datetime from_time,
                   const datetime to_time,const double lower,const double upper,
                   const color ink)
  {
   if(from_time<=0 || to_time<=from_time || lower<=0.0 || upper<=lower)
     { ObjectDelete(0,name); return; }
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_RECTANGLE,0,
                                            from_time,upper,to_time,lower)) return;
   ObjectMove(0,name,0,from_time,upper);
   ObjectMove(0,name,1,to_time,lower);
   ObjectSetInteger(0,name,OBJPROP_COLOR,ink);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

#endif
