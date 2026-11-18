#property strict
#property description "Deterministic ICT detector fixtures; no market data or trade requests."
#include "../Include/FVGDetector.mqh"
#include "../Include/MarketStructure.mqh"
#include "../Include/LiquidityDetector.mqh"
#include "../Include/OrderBlockDetector.mqh"
#include "../Include/SymbolCorrelationEngine.mqh"
#include "../Include/ICTTimeframeMapper.mqh"

int failures=0,checks=0;
void Check(const string name,const bool passed)
  {
   checks++;
   Print(name,passed ? " PASS" : " FAIL");
   if(!passed) failures++;
  }
void Bar(MqlRates &bar,const datetime time,const double high,const double low,const double close)
  {
   ZeroMemory(bar);
   bar.time=time; bar.high=high; bar.low=low; bar.open=close; bar.close=close;
  }
void TestFVG()
  {
   SFairValueGap gap;
   ZeroMemory(gap);
   gap.direction=1; gap.lower=100; gap.upper=110; gap.formed_time=1000;
   MqlRates bar;
   Bar(bar,1000,112,99,105);
   SRMPUpdateFVGEvidence(bar,gap);
   Check("formation candle cannot mitigate itself",!gap.mitigated && gap.status==SRMP_FVG_ACTIVE);
   Bar(bar,1060,115,110,112);
   SRMPUpdateFVGEvidence(bar,gap);
   Check("edge touch preserves legacy mitigation",gap.mitigated && gap.status==SRMP_FVG_PARTIALLY_FILLED && gap.first_touch_time==1060);
   Bar(bar,1120,111,100,105);
   SRMPUpdateFVGEvidence(bar,gap);
   Check("far edge wick fully fills without inversion",gap.status==SRMP_FVG_FULLY_FILLED && gap.fully_filled_time==1120 && !gap.inversion_evidence);
   Bar(bar,1180,106,98,99);
   SRMPUpdateFVGEvidence(bar,gap);
   Check("close through far edge records inversion",gap.status==SRMP_FVG_INVALIDATED && gap.inversion_direction==-1 && gap.inversion_time==1180);
   Bar(bar,1240,115,105,112);
   SRMPUpdateFVGEvidence(bar,gap);
   Check("invalidation sticky and first timestamps retained",gap.status==SRMP_FVG_INVALIDATED && gap.invalidated_time==1180 && gap.first_touch_time==1060);
   ZeroMemory(gap);
   gap.direction=-1; gap.lower=100; gap.upper=110; gap.formed_time=1000;
   Bar(bar,1060,115,112,114);
   SRMPUpdateFVGEvidence(bar,gap);
   Check("bearish gap-over invalidates legacy entry",gap.mitigated && gap.status==SRMP_FVG_INVALIDATED && gap.inversion_direction==1);

   MqlRates bars[6];
   Bar(bars[0],1000,100,90,95);
   Bar(bars[1],1060,115,95,110);
   Bar(bars[2],1120,120,110,115);
   Bar(bars[3],1180,120,111,115);
   Bar(bars[4],1240,120,111,115);
   Bar(bars[5],1300,116,99,101);
   Check("prefix excludes future mitigation",SRMPFindFVGFromRates(bars,5,5,gap) && gap.formed_time==1120 && !gap.mitigated);
   Check("next closed bar adds full fill evidence",SRMPFindFVGFromRates(bars,6,5,gap) && gap.mitigated && gap.status==SRMP_FVG_FULLY_FILLED);
  }
void TestStructure()
  {
   MqlRates bars[36];
   for(int i=0;i<36;i++)
     {
      double center=100+(i%4==1 ? 5 : (i%4==3 ? -5 : 0));
      Bar(bars[i],1000+i*60,center+1,center-1,center);
     }
   SMarketStructure before,after;
   bool a=SRMPAnalyzeStructureFromRates(bars,30,1,1,before);
   bool b=SRMPAnalyzeStructureFromRates(bars,31,1,1,after);
   Check("structure fixtures have confirmed pivots",a && b);
   Check("unconfirmed newest high excluded",before.recent_high_time==bars[25].time && before.recent_high_confirmed_time==bars[26].time);
   Check("right bar confirms pivot",after.recent_high_time==bars[29].time && after.recent_high_confirmed_time==bars[30].time);
   Check("prior confirmation shifts with pivot",after.prior_high_confirmed_time==before.recent_high_confirmed_time);
   Check("low confirmation recorded",before.recent_low_time==bars[27].time && before.recent_low_confirmed_time==bars[28].time);
   bars[35].high=100000;
   SMarketStructure unchanged;
   SRMPAnalyzeStructureFromRates(bars,30,1,1,unchanged);
   Check("future array suffix does not affect structure",unchanged.recent_high==before.recent_high && unchanged.recent_high_confirmed_time==before.recent_high_confirmed_time);
  }
void TestLiquidity()
  {
   MqlRates periods[3],bar;
   Bar(periods[0],1000,120,90,100);
   Bar(periods[1],2000,999,1,100); // Current period OHLC must never leak.
   Bar(periods[2],3000,9999,1,100);
   SLiquidityLevelEvidence e;
   Bar(bar,2200,121,95,119);
   Check("prior period selected without current/future OHLC",SRMPPriorPeriodEvidenceFromRates(periods,3,bar,e) && e.high==120 && e.low==90 && e.available_from==2000);
   Check("high rejection sweep and touch evidence",e.high_touched && e.high_swept && e.high_sweep_time==2200 && !e.low_swept);
   Bar(bar,2300,120,90,100);
   SRMPPriorPeriodEvidenceFromRates(periods,3,bar,e);
   Check("exact boundaries touch but do not sweep",e.high_touched && e.low_touched && !e.high_swept && !e.low_swept);
   Bar(bar,2400,115,89,91);
   SRMPPriorPeriodEvidenceFromRates(periods,3,bar,e);
   Check("low rejection sweep",e.low_swept && e.low_sweep_time==2400 && !e.high_swept);
   Bar(bar,2500,125,95,122);
   SRMPPriorPeriodEvidenceFromRates(periods,3,bar,e);
   Check("breakout close is touch without sweep",e.high_touched && !e.high_swept);
   Bar(bar,1500,121,95,119);
   Check("missing completed predecessor fails cleanly",!SRMPPriorPeriodEvidenceFromRates(periods,3,bar,e) && !e.valid);
   Check("future availability rejected",!SRMPEvaluateLiquidityLevels(bar,120,90,1000,2000,e));
  }
void TestOrderBlock()
  {
   SOrderBlock block; ZeroMemory(block);
   block.direction=1; block.state=SRMP_OB_CONFIRMED;
   block.lower=100; block.upper=110; block.midpoint=105; block.confirmation_time=1000;
   MqlRates bars[3];
   Bar(bars[0],1060,120,111,115);
   Bar(bars[1],1120,112,105,108);
   Bar(bars[2],1180,105,98,99);
   SRMPValidateOrderBlockFromRates(bars,1,SRMP_OB_TOUCH,SRMP_OB_CLOSE,48,block);
   Check("OB future suffix cannot mitigate",block.state==SRMP_OB_CONFIRMED);
   SRMPValidateOrderBlockFromRates(bars,2,SRMP_OB_TOUCH,SRMP_OB_CLOSE,48,block);
   Check("OB closed touch mitigates",block.state==SRMP_OB_MITIGATED && block.state_time==1120);
   // Reconstruct from immutable confirmation as the live finder does each refresh.
   block.state=SRMP_OB_CONFIRMED;
   SRMPValidateOrderBlockFromRates(bars,3,SRMP_OB_TOUCH,SRMP_OB_CLOSE,48,block);
   Check("OB invalidates after mitigation",block.state==SRMP_OB_INVALIDATED && block.state_time==1180);
   block.state=SRMP_OB_CONFIRMED;
   SRMPValidateOrderBlockFromRates(bars,1,SRMP_OB_TOUCH,SRMP_OB_CLOSE,1,block);
   Check("OB expiry boundary",block.state==SRMP_OB_EXPIRED);
  }
void TestComparisonRanking()
  {
   string first="",second=""; double a=-1,b=-1;
   SRMPRankComparison("GBPUSD",0.72,first,a,second,b);
   SRMPRankComparison("DXY",-0.91,first,a,second,b);
   SRMPRankComparison("AUDUSD",0.91,first,a,second,b);
   SRMPRankComparison("AUDUSD",0.99,first,a,second,b);
   Check("SMT ranking uses absolute correlation and stable tie order",
         first=="AUDUSD" && second=="DXY" && a==0.91 && b==0.91);
  }
void TestTimeframeMapping()
  {
   ENUM_TIMEFRAMES charts[]={PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,
      PERIOD_M10,PERIOD_M12,PERIOD_M15,PERIOD_M20,PERIOD_M30,PERIOD_H1,PERIOD_H2,PERIOD_H3,
      PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
   ENUM_TIMEFRAMES middle[]={PERIOD_M15,PERIOD_M15,PERIOD_M15,PERIOD_M15,PERIOD_H1,PERIOD_H1,
      PERIOD_H1,PERIOD_H1,PERIOD_H1,PERIOD_H1,PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_H4,
      PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_W1,PERIOD_MN1,PERIOD_CURRENT};
   ENUM_TIMEFRAMES higher[]={PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_D1,PERIOD_D1,
      PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_W1,PERIOD_W1,
      PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_MN1,PERIOD_CURRENT,PERIOD_CURRENT};
   SICTTimeframes f;
   for(int i=0;i<ArraySize(charts);i++)
      Check("mapping "+EnumToString(charts[i]),ICTMapTimeframes(charts[i],ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f) &&
            f.ltf==charts[i] && f.mtf==middle[i] && f.htf==higher[i] &&
            f.status==(i==20 ? ICT_MTF_ONE_TIER : i==19 ? ICT_MTF_TWO_TIER : ICT_MTF_FULL));
   Check("manual ordered",ICTMapTimeframes(PERIOD_M5,ICT_MTF_MANUAL,PERIOD_H1,PERIOD_D1,f));
   Check("manual out of order rejected",!ICTMapTimeframes(PERIOD_M5,ICT_MTF_MANUAL,PERIOD_H1,PERIOD_M15,f));
   Check("manual missing intermediate rejected",!ICTMapTimeframes(PERIOD_M5,ICT_MTF_MANUAL,PERIOD_CURRENT,PERIOD_D1,f));
   Check("unsupported period rejected",!ICTMapTimeframes((ENUM_TIMEFRAMES)12345,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f));
   Check("aligned bullish tiers",ICTTierAlignment(true,1,1,1)==ICT_TIER_ALIGNED);
   Check("aligned bearish tiers",ICTTierAlignment(true,-1,-1,-1)==ICT_TIER_ALIGNED);
   Check("countertrend MTF waits",ICTTierAlignment(true,1,-1,1)==ICT_TIER_CONFLICT);
   Check("countertrend LTF waits",ICTTierAlignment(true,-1,-1,1)==ICT_TIER_CONFLICT);
   Check("neutral HTF blocks",ICTTierAlignment(true,0,1,1)==ICT_TIER_NEUTRAL);
   Check("missing MTF blocks",ICTTierAlignment(false,1,1,1)==ICT_TIER_INSUFFICIENT);
  }
int OnInit()
  {
   TestFVG(); TestStructure(); TestLiquidity(); TestOrderBlock(); TestComparisonRanking(); TestTimeframeMapping();
   PrintFormat("ICTDetectorTests: %d failure(s)",failures);
   return INIT_SUCCEEDED;
  }

double OnTester()
  {
   PrintFormat("ICTDetectorTests RESULT checks=%d failures=%d",checks,failures);
   return (double)failures;
  }
