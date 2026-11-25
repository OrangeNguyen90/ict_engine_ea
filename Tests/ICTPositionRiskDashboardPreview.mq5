#property strict
#property description "Synthetic, read-only risk dashboard preview; never sends trade requests."
#include "../Include/ICTPositionRiskRenderer.mqh"

void OnStart()
  {
   string prefix="ICT_RISK_PREVIEW_",folder="RiskDashboardPreview";
   FolderCreate(folder);
   SICTPositionRiskSnapshot s; ZeroMemory(s);
   s.observed_at=TimeCurrent(); s.currency="USD"; s.currency_digits=2;
   s.balance=10000; s.equity=10009.2; s.capital=10000;
   s.capital_mode=ICT_POSITION_CONSERVATIVE; s.connected=true;
   s.cost_per_lot=10; s.daily_valid=true; s.daily_net=9.2;
   s.daily_opened_valid=true; s.daily_opened_risk_money=42.8;
   s.margin_valid=true; s.margin=1000; s.free_margin=s.equity-s.margin;
   s.margin_level=s.equity/s.margin*100;
   s.protection_online=true; s.protection_armed=true; s.protection_healthy=true;
   ArrayResize(s.positions,2);
   for(int i=0;i<2;i++)
     {
      SICTPositionRiskInput p; ZeroMemory(p);
      p.ticket=(ulong)(10001+i); p.symbol=i==0 ? "EURUSD" : "XAUUSD";
      p.direction=i==0 ? 1 : -1; p.digits=2; p.volume=0.1;
      p.entry=100; p.stop=i==0 ? 98 : 102; p.target=i==0 ? 105 : 95;
      p.profit=5; p.swap=-0.4; p.gross_at_stop=-20; p.gross_at_target=50;
      p.stop_valued=true; p.target_valued=true;
      ICTCalculatePositionRisk(p,s.capital,s.cost_per_lot,s.positions[i]);
      ICTAccumulatePositionRisk(s.positions[i],s.totals);
     }
   int page=7;
   int report=FileOpen(folder+"/geometry.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(report!=INVALID_HANDLE) FileWrite(report,"scenario","page","rows","overflow","pagination","screenshot");
   string scenarios[]={"normal","missing_sl","drawdown","small"};
   for(int scenario=0;scenario<4;scenario++)
     {
      if(scenario==1) { s.totals.unknown_stops=1; s.unknown_pending=1; s.pending_count=1; s.protection_armed=false; }
      if(scenario==2)
        {
         s.totals.unknown_stops=0; s.unknown_pending=0; s.pending_count=0;
         s.protection_armed=true; s.protection_state=1; s.daily_net=-105;
         s.totals.floating=-80; s.totals.risk_money=150; s.totals.remaining_risk_money=75;
         s.margin=3500; s.free_margin=s.equity-s.margin;
        }
      if(scenario==3) ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrWhite);
      ICTRenderPositionRiskPanel(prefix,s,CORNER_RIGHT_UPPER,12,60,scenario==3 ? 340 : 420,
         scenario==3 ? 240 : 420,11,page,-1,-1,false,3,6);
      ChartRedraw(); Sleep(150);
      int rows=0,overflow=0;
      long left=ObjectGetInteger(0,prefix+"panel",OBJPROP_XDISTANCE);
      long top=ObjectGetInteger(0,prefix+"panel",OBJPROP_YDISTANCE);
      long right=left+ObjectGetInteger(0,prefix+"panel",OBJPROP_XSIZE);
      long bottom=top+ObjectGetInteger(0,prefix+"panel",OBJPROP_YSIZE);
      for(int i=0;i<12;i++)
        {
         string name=prefix+"value_"+IntegerToString(i);
         if(ObjectFind(0,name)<0) continue;
         rows++;
         long lx=ObjectGetInteger(0,name,OBJPROP_XDISTANCE),ly=ObjectGetInteger(0,name,OBJPROP_YDISTANCE);
         if(lx<left || lx+ObjectGetInteger(0,name,OBJPROP_XSIZE)>right ||
            ly<top || ly+ObjectGetInteger(0,name,OBJPROP_YSIZE)>bottom) overflow++;
        }
      bool pagination=ObjectFind(0,prefix+"prev")>=0 || ObjectFind(0,prefix+"next")>=0;
      bool shot=ChartScreenShot(0,folder+"/"+scenarios[scenario]+".png",
         (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS),ALIGN_RIGHT);
      if(report!=INVALID_HANDLE) FileWrite(report,scenarios[scenario],page,rows,overflow,(int)pagination,(int)shot);
     }
   if(report!=INVALID_HANDLE) { FileFlush(report); FileClose(report); }
   ObjectsDeleteAll(0,prefix);
   Print("ICT_RISK_PREVIEW completed; synthetic account values only, no trading.");
  }
