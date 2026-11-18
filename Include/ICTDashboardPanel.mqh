#ifndef ICT_DASHBOARD_PANEL_MQH
#define ICT_DASHBOARD_PANEL_MQH
#include "DashboardComponents.mqh"
#include "ICTDashboardVietnamese.mqh"
// Bank 0 is the established analysis panel; bank 1 is the live risk panel.
bool g_ict_panel_group_collapsed[32];

bool ICTPanelEvent(const string prefix,const int id,const string name,
                     int &page,int &x,int &y,bool &hidden,const int group_bank=0)
  {
   string group_prefix=prefix+"group_";
   if(id==CHARTEVENT_OBJECT_CLICK && StringFind(name,group_prefix)==0)
     {
      int group=(int)StringToInteger(StringSubstr(name,StringLen(group_prefix)));
      if(group<0 || group>=16) return false;
      int slot=group+(group_bank==1 ? 16 : 0);
      g_ict_panel_group_collapsed[slot]=!g_ict_panel_group_collapsed[slot];
      return true;
     }
   if(id==CHARTEVENT_OBJECT_CLICK && name==prefix+"eye")
     {
      x=(int)ObjectGetInteger(0,name,OBJPROP_XDISTANCE)-10;
      y=(int)ObjectGetInteger(0,name,OBJPROP_YDISTANCE)-10;
      hidden=!hidden;
      ObjectSetInteger(0,name,OBJPROP_STATE,false);
      return true;
     }
   if(id==CHARTEVENT_OBJECT_CLICK && !hidden && (name==prefix+"prev" || name==prefix+"next"))
     {
      page+=(name==prefix+"next" ? 1 : -1);
      ObjectSetInteger(0,name,OBJPROP_STATE,false);
      return true;
     }
   if(id==CHARTEVENT_OBJECT_DRAG && name==prefix+"panel")
     {
      x=(int)ObjectGetInteger(0,name,OBJPROP_XDISTANCE);
      y=(int)ObjectGetInteger(0,name,OBJPROP_YDISTANCE);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
      return true;
     }
   return false;
  }

// Shared left panel for the standalone decision EA and service dashboard.
// Measure the same point-sized font used by OBJ_LABEL, including Windows DPI.
int ICTPanelTextWidth(const string value,const int font_size)
  {
   uint width=0,height=0;
   if(TextGetSize(value,width,height)) return (int)width;
   return (int)MathCeil(StringLen(value)*font_size*0.85);
  }

int ICTPanelFit(const string value,const int pixels,const int font_size)
  {
   int low=0,high=StringLen(value);
   while(low<high)
     {
      int mid=(low+high+1)/2;
      if(ICTPanelTextWidth(StringSubstr(value,0,mid),font_size)<=pixels) low=mid;
      else high=mid-1;
     }
   return low;
  }

void ICTPanelLabel(const string name,const string value,const int x,const int y,
                     const color ink,const int font_size)
  {
   RMTextLeft(name,value,x,y,ink);
   ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,value);
  }

void ICTPanelButton(const string name,const string text,const string tooltip,
                      const int x,const int y,const int width,const int height,
                      const int font_size=10)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_BUTTON,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_COLOR,C'234,240,248');
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'43,59,79');
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,C'77,101,129');
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
   ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);
  }

void ICTRenderPagedPanel(const string prefix,const string title,const string status,
                           const color status_ink,const string body,
                           const ENUM_BASE_CORNER corner,const int margin_x,const int margin_y,
                           const int requested_width,const int requested_height,const int font_size,
                           int &page,const int moved_x,const int moved_y,const bool hidden,const int group_bank=0)
  {
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(cw<60 || ch<60) { ObjectsDeleteAll(0,prefix); return; }
   int width=(int)MathMin(MathMax(180,requested_width),cw-8);
   int available_h=(int)MathMax(60,ch-MathMin(margin_y,ch-60)-4);
   int height_limit=(int)MathMin(MathMax(180,requested_height),available_h);
   bool right=corner==CORNER_RIGHT_UPPER || corner==CORNER_RIGHT_LOWER;
   bool bottom=corner==CORNER_LEFT_LOWER || corner==CORNER_RIGHT_LOWER;
   int x=(moved_x>=0 ? moved_x : (right ? cw-margin_x-width : margin_x));
   int y=(moved_y>=0 ? moved_y : (bottom ? ch-margin_y-height_limit : margin_y));
   x=(int)MathMax(0,MathMin(x,cw-width-4));
   y=(int)MathMax(0,y);

   // Retain only this panel's eye control; never delete analysis overlays.
   if(hidden || height_limit<150)
     {
      y=(int)MathMin(y,ch-48);
      for(int i=ObjectsTotal(0)-1;i>=0;i--)
        {
         string name=ObjectName(0,i);
         if(StringFind(name,prefix)==0 && name!=prefix+"eye") ObjectDelete(0,name);
        }
      ICTPanelButton(prefix+"eye","👁","Hiện dashboard ICT",x+10,y+10,36,28,14);
      ObjectSetString(0,prefix+"eye",OBJPROP_FONT,"Segoe UI Emoji");
      return;
     }

   TextSetFont("Segoe UI",-font_size*10,0);
   uint tw=0,th=0;
   int line=(TextGetSize("Ag",tw,th) ? (int)th+7 : font_size*2+5);
   int header=(int)MathMax(74,line*2+22),footer=44;
   string rows[]; color inks[]; int groups[];
   string source[]; int count=StringSplit(body,'\n',source);
   int section_index=-1;
   int group_offset=(group_bank==1 ? 16 : 0);
   for(int i=0;i<count;i++)
     {
      string rest=source[i];
      bool section=StringFind(rest,"[")==0;
      if(section) section_index++;
      bool collapsible=section_index>=0 && section_index<16;
      if(!section && collapsible && g_ict_panel_group_collapsed[group_offset+section_index]) continue;
      if(section && collapsible) rest=(g_ict_panel_group_collapsed[group_offset+section_index] ? "[+] " : "[-] ")+rest;
      bool first_line=true;
      do
        {
         int cut=(int)MathMax(1,ICTPanelFit(rest,width-32,font_size));
         if(cut<StringLen(rest))
            for(int j=cut;j>cut/2;j--) if(StringGetCharacter(rest,j)==' ') { cut=j; break; }
         int n=ArraySize(rows); ArrayResize(rows,n+1); ArrayResize(inks,n+1); ArrayResize(groups,n+1);
         rows[n]=StringSubstr(rest,0,cut);
         groups[n]=(section && collapsible && first_line ? section_index : -1); first_line=false;
         inks[n]=(section ? C'111,190,255' : C'229,236,246');
         rest=StringSubstr(rest,cut); StringTrimLeft(rest);
        }
      while(StringLen(rest)>0);
     }
   int capacity=(int)MathMax(1,(height_limit-header-footer)/line);
   int pages=(int)MathMax(1,(ArraySize(rows)+capacity-1)/capacity);
   page=(int)MathMax(0,MathMin(page,pages-1));
   int first=page*capacity,visible=(int)MathMin(capacity,ArraySize(rows)-first);
   int height=(int)MathMin(height_limit,header+visible*line+footer);
   if(bottom && moved_y<0) y=(int)MathMax(0,ch-margin_y-height);
   y=(int)MathMax(0,MathMin(y,ch-height));

   int old=(int)ObjectGetInteger(0,prefix+"panel",OBJPROP_ZORDER);
   RMPanelLeft(prefix+"panel",x,y,width,height);
   ObjectSetInteger(0,prefix+"panel",OBJPROP_BACK,false);
   ObjectSetInteger(0,prefix+"panel",OBJPROP_SELECTABLE,true);
   ObjectSetInteger(0,prefix+"panel",OBJPROP_ZORDER,visible);
   ObjectSetString(0,prefix+"panel",OBJPROP_TOOLTIP,"Chọn và kéo nền để di chuyển dashboard");
   RMPanelLeft(prefix+"header",x+1,y+1,width-2,header-8);
   ObjectSetInteger(0,prefix+"header",OBJPROP_BACK,false);
   ObjectSetInteger(0,prefix+"header",OBJPROP_BGCOLOR,C'30,43,61');
   int fit=ICTPanelFit(title,width-72,font_size);
   string short_title=(fit<StringLen(title) ? StringSubstr(title,0,(int)MathMax(1,fit-3))+"..." : title);
   ICTPanelLabel(prefix+"title",short_title,x+56,y+12,C'243,247,252',font_size);
   ObjectSetString(0,prefix+"title",OBJPROP_TOOLTIP,title);
   fit=ICTPanelFit(status,width-32,font_size);
   string short_status=(fit<StringLen(status) ? StringSubstr(status,0,(int)MathMax(1,fit-3))+"..." : status);
   ICTPanelLabel(prefix+"status",short_status,x+16,y+line+18,status_ink,font_size);
   ObjectSetString(0,prefix+"status",OBJPROP_TOOLTIP,status);
   bool shown_groups[16]; ArrayInitialize(shown_groups,false);
   for(int i=0;i<visible;i++)
     {
      int group=groups[first+i]; string row=prefix+"row"+IntegerToString(i);
      if(group>=0)
        { ObjectDelete(0,row); row=prefix+"group_"+IntegerToString(group); shown_groups[group]=true; }
      ICTPanelLabel(row,rows[first+i],x+16,y+header+i*line,inks[first+i],font_size);
      if(group>=0) ObjectSetString(0,row,OBJPROP_TOOLTIP,"Nhấn để thu gọn hoặc mở rộng nhóm");
     }
   for(int i=0;i<16;i++) if(!shown_groups[i]) ObjectDelete(0,prefix+"group_"+IntegerToString(i));
   for(int i=visible;i<old;i++) ObjectDelete(0,prefix+"row"+IntegerToString(i));
   ICTPanelButton(prefix+"prev","<","Trang trước",x+16,y+height-34,48,26);
   ICTPanelButton(prefix+"next",">","Trang tiếp theo",x+width-64,y+height-34,48,26);
   ICTPanelLabel(prefix+"page",StringFormat("Trang %d / %d",page+1,pages),x+78,y+height-31,C'162,181,203',font_size);
   ICTPanelButton(prefix+"eye","👁","Ẩn dashboard ICT",x+10,y+10,36,28,14);
   ObjectSetString(0,prefix+"eye",OBJPROP_FONT,"Segoe UI Emoji");
  }
#endif
