#property strict
#property description "Shared MTF, SMT and Strong OB deterministic fixtures. Never sends trade requests."
#include "../Include/ICTUnifiedBridge.mqh"
#include "../Include/ICTRangeEngine.mqh"
#include "../Include/ICTUnifiedDecisionAdapter.mqh"
#include "../Include/ICTUnifiedRenderer.mqh"
#include "../Include/ICTAnalyticalConsensus.mqh"
int failures=0,checks=0;
void Check(const string name,const bool value)
  { checks++; if(!value) failures++; Print(name,value ? " PASS" : " FAIL"); }
#include "ICTUnifiedCoreFixtures.mqh"
#include "ICTUnifiedDiagnosticFixtures.mqh"
#include "ICTRejectionBreakerFixtures.mqh"
#include "ICTAnalyticalFixtures.mqh"
void TestChartLayout()
  {
   Check("default chart font is 75 percent rounded",ICTChartScaledFontSize(10)==8);
   Check("custom chart fonts use 75 percent",ICTChartScaledFontSize(8)==6 && ICTChartScaledFontSize(12)==9 && ICTChartScaledFontSize(16)==12);
   Check("odd chart font sizes round to the nearest point",ICTChartScaledFontSize(9)==7);
   Check("scaled chart font stays positive",ICTChartScaledFontSize(1)==1);
   SICTChartRect first;
   SICTChartRect adjacent;
   SICTChartRect overlap;
   first.left=10; first.top=10; first.right=50; first.bottom=30;
   adjacent.left=50; adjacent.top=10; adjacent.right=80; adjacent.bottom=30;
   overlap.left=49; overlap.top=29; overlap.right=80; overlap.bottom=40;
   Check("chart labels can touch without overlapping",!ICTChartRectOverlap(first,adjacent));
   Check("chart labels detect pixel collisions",ICTChartRectOverlap(first,overlap));
   Check("chart labels require a visible gap",ICTChartRectTooClose(first,adjacent,4));
   SICTChartRect slots[];
   int placed=0,hidden=0; bool separated=true;
   for(int i=0;i<20;i++)
     {
      SICTChartRect slot;
      if(!ICTChartFindLabelRect(300,160,110,20,600,320,slots,slot)) { hidden++; continue; }
      for(int j=0;j<ArraySize(slots);j++)
         if(ICTChartRectTooClose(slot,slots[j],4)) separated=false;
      ArrayResize(slots,placed+1); slots[placed]=slot; placed++;
     }
   Check("dense annotations use separate pixel rows with padding",separated && placed==14 && hidden==6);
   SICTChartRect panel_slots[]; ArrayResize(panel_slots,1);
   panel_slots[0].left=0; panel_slots[0].top=0;
   panel_slots[0].right=250; panel_slots[0].bottom=320;
   SICTChartRect blocked;
   Check("annotations stay out of the dashboard and chart edge",
      !ICTChartFindLabelRect(300,160,110,20,350,320,panel_slots,blocked));
   ICTChartLayoutBegin("test_",PERIOD_M5,10);
   Check("chart zones use only the selected timeframe",!ICTChartReserveZone(PERIOD_H1,100,200,10,20));
   Check("chart accepts a valid selected-timeframe zone",ICTChartReserveZone(PERIOD_M5,100,200,10,20));
   Check("chart rejects overlapping price and time",!ICTChartReserveZone(PERIOD_M5,150,250,15,25));
   Check("chart counts only hidden overlaps",g_ict_chart_zone_suppressed==1);
   Check("chart accepts touching price boundaries",ICTChartReserveZone(PERIOD_M5,100,200,20,25));
   Check("chart accepts non-overlapping time spans",ICTChartReserveZone(PERIOD_M5,200,300,10,20));
   Check("chart rejects invalid zones",!ICTChartReserveZone(PERIOD_M5,100,100,10,20));
   Check("other timeframe and invalid zones do not inflate overlap count",g_ict_chart_zone_suppressed==1);
   color dark=C'24,29,38',light=C'250,250,250';
   Check("dark chart label contrast",ICTChartContrast(ICTChartReadableColor(clrMaroon,dark,true),dark)>=4.5);
   Check("light chart label contrast",ICTChartContrast(ICTChartReadableColor(clrYellow,light,false),light)>=4.5);
   color medium=C'128,128,128';
   Check("medium chart background chooses a readable text color",
      ICTChartContrast(ICTChartReadableColor(clrYellow,medium,ICTChartLuminance(medium)<0.179),medium)>=4.5);
   g_ict_chart_collect=false;
  }
void TestDashboardVietnamese()
  {
   string risk="RISK FILTER FAIL: invalid plan or net RR below configured minimum";
   string translated=ICTDashboardText(risk);
   Check("dashboard translates the risk veto",StringFind(translated,"rủi ro không đạt")>=0 && StringFind(translated,"RR ròng")>=0);
   Check("dashboard translation does not mutate the engine reason",risk=="RISK FILTER FAIL: invalid plan or net RR below configured minimum");
   string context="HTF PERIOD_H4 bullish bias / MTF PERIOD_M15 bearish structure + valid zone";
   translated=ICTDashboardText(context);
   Check("dashboard translates compound timeframe context",StringFind(translated,"HTF H4 xu hướng tăng")>=0 &&
      StringFind(translated,"MTF M15 cấu trúc giảm và vùng giá hợp lệ")>=0);
   Check("dashboard keeps unknown diagnostics visible",ICTDashboardText("UNMAPPED_CODE|EURUSD") == "Chi tiết gốc: UNMAPPED_CODE|EURUSD");
   Check("dashboard translates risk detail without discarding it",
      ICTDashboardText("Risk gate: Insufficient free margin")=="Điều kiện rủi ro: Ký quỹ khả dụng không đủ");
  }
void TestSignalBridge()
  {
   SICTUnifiedSnapshot source; ZeroMemory(source); source.schema=ICT_UNIFIED_SCHEMA;
   SignalFixture(source.signal); ICTEvaluateSignal(source.signal,2);
   source.symbol=source.signal.symbol; source.frames=source.signal.frames; source.asof=source.signal.asof; source.chart_tf=PERIOD_M5;
   source.valid=true; source.capacity_ok=true; source.display_start=100000;
   source.comparison1="PEER1"; source.comparison2="PEER2";
   ENUM_TIMEFRAMES frames[3]={PERIOD_M5,PERIOD_H1,PERIOD_D1};
   datetime opens[3]={100000,96000,1000};
   for(int i=0;i<3;i++)
     {
      source.tiers[i].timeframe=frames[i]; source.tiers[i].status=ICT_CONTEXT_BULLISH;
      FixtureBar(source.tiers[i].last_bar,opens[i],99,102,98,101);
      source.tiers[i].closed_at=ICTBarClose(frames[i],opens[i]);
     }
   source.tiers[0].displacement_up=true;
   source.layer_count=1; source.layers[0].timeframe=PERIOD_M5; source.layers[0].last_close=source.asof;
   source.layers[0].peers[0].comparison="PEER1"; source.layers[0].peers[0].ready=true;
   source.layers[0].peers[0].relation_known=true; source.layers[0].peers[0].relation=1;
   source.layers[0].peers[0].state=ICT_SMT_PEER_BULLISH; source.layers[0].peers[0].last_close=source.asof;
   source.layers[0].peers[1].comparison="PEER2"; source.layers[0].peers[1].reason="DATA INSUFFICIENT";
   double values[]; string texts[]; SICTUnifiedSnapshot decoded;
   Check("central signal packs",ICTUnifiedPack(source,values,texts));
   Check("central signal bridge roundtrip",ICTUnifiedUnpack(values,texts,decoded) && decoded.signal.id==source.signal.id &&
      decoded.signal.entry==source.signal.entry && decoded.signal.confirmation_time==source.signal.confirmation_time &&
      decoded.tiers[0].last_bar.time==source.tiers[0].last_bar.time && decoded.tiers[0].displacement_up && decoded.chart_tf==PERIOD_M5);
   Check("bridge retains independent unavailable peer",decoded.layers[0].peers[0].state==ICT_SMT_PEER_BULLISH &&
      decoded.layers[0].peers[1].state==ICT_SMT_PEER_NA && decoded.layers[0].peers[1].reason=="DATA INSUFFICIENT");
   source.signal.ltf_pass=false; ICTUnifiedPack(source,values,texts);
   Check("bridge refuses confirmed label without LTF gate",!ICTUnifiedUnpack(values,texts,decoded));
   source.signal.ltf_pass=true; source.signal.asof++; ICTUnifiedPack(source,values,texts);
   Check("bridge refuses decision-context timestamp mismatch",!ICTUnifiedUnpack(values,texts,decoded));
   source.signal.asof--; ICTUnifiedPack(source,values,texts); ArrayResize(values,ArraySize(values)-1);
   Check("bridge rejects truncated snapshot",!ICTUnifiedUnpack(values,texts,decoded));
   SICTSMTEvent original; ZeroMemory(original); original.signal.comparison="PEER1";
   original.signal.timeframe=PERIOD_M5; original.signal.direction=1; original.signal.relation=1;
   original.signal.state=SRMP_SMT_BULLISH;
   original.signal.primary_prior_time=99000; original.signal.primary_pivot_time=99300;
   original.signal.comparison_prior_time=99000; original.signal.comparison_pivot_time=99600;
   original.signal.primary_prior=100; original.signal.primary_recent=95;
   original.signal.comparison_prior=100; original.signal.comparison_recent=101;
   original.signal.pivot_confirmation_time=100000; original.signal.confirmation_time=100300;
   original.signal.event_id="TEST|PEER1|"+IntegerToString((int)PERIOD_M5)+"|1|1|99000|99300|99000|99600";
   original.life=ICT_SMT_CONFIRMED; original.changed_at=100300;
   SICTSMTEvent restored; ICTPackSMTPayload(original,values);
   Check("SMT journal payload preserves original confirmation",ICTUnpackSMTPayload("TEST","PEER1",original.signal.event_id,values,100300,restored) &&
      restored.signal.confirmation_time==original.signal.confirmation_time && restored.signal.primary_pivot_time==99300 &&
      restored.signal.comparison_pivot_time==99600 && restored.signal.primary_recent==95);
   Check("SMT journal rejects identity corruption",!ICTUnpackSMTPayload("TEST","PEER1","BAD_ID",values,100300,restored));
   values[12]=100600;
   Check("SMT journal rejects future confirmation",!ICTUnpackSMTPayload("TEST","PEER1",original.signal.event_id,values,100300,restored));
   ICTPackSMTPayload(original,values); ArrayResize(values,ArraySize(values)-1);
   Check("SMT journal rejects truncated payload",!ICTUnpackSMTPayload("TEST","PEER1",original.signal.event_id,values,100300,restored));
  }
int OnInit()
  {
   RunUnifiedCoreFixtures();
   RunUnifiedDiagnosticFixtures();
   RunICTAnalyticalFixtures();
   TestICTRejectionBreakerDetectors();
   TestChartLayout();
   TestDashboardVietnamese();
   TestSignalBridge();
   PrintFormat("ICTUnifiedTests RESULT checks=%d failures=%d",checks,failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
  }
double OnTester() { return failures; }
