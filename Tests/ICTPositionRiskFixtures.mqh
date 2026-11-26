#ifndef ICT_POSITION_RISK_FIXTURES_MQH
#define ICT_POSITION_RISK_FIXTURES_MQH
#include "../Include/ICTPositionRiskRenderer.mqh"
#include "../Include/PositionPlanValidation.mqh"

void PositionRiskFixture(SICTPositionRiskInput &p)
  {
   ZeroMemory(p); p.ticket=123; p.symbol="TEST"; p.direction=1; p.digits=2;
   p.volume=0.5; p.entry=100; p.stop=98; p.target=105;
   p.profit=25; p.swap=-2; p.gross_at_stop=-100; p.gross_at_target=250;
   p.stop_valued=true; p.target_valued=true;
  }

void TestLivePositionRisk()
  {
   Check("below three percent stays normal",ICTEvaluatePositionRiskLimit(true,299.99,10000)==ICT_RISK_LIMIT_NORMAL);
   Check("exactly three percent does not exceed the warning boundary",ICTEvaluatePositionRiskLimit(true,300,10000)==ICT_RISK_LIMIT_NORMAL);
   Check("over three percent warns",ICTEvaluatePositionRiskLimit(true,300.01,10000)==ICT_RISK_LIMIT_WARNING);
   Check("exactly five percent warns without crossing the close boundary",ICTEvaluatePositionRiskLimit(true,500,10000)==ICT_RISK_LIMIT_WARNING);
   Check("over five percent requests a close policy",ICTEvaluatePositionRiskLimit(true,500.01,10000)==ICT_RISK_LIMIT_CLOSE);
   Check("a gap past both thresholds goes directly to close policy",ICTEvaluatePositionRiskLimit(true,700,10000)==ICT_RISK_LIMIT_CLOSE);
   Check("unknown stop or loss metric cannot authorize a close",ICTEvaluatePositionRiskLimit(false,700,10000)==ICT_RISK_LIMIT_UNKNOWN);
   Check("zero reference capital cannot authorize a close",ICTEvaluatePositionRiskLimit(true,700,0)==ICT_RISK_LIMIT_UNKNOWN);
   Check("negative reference capital cannot authorize a close",ICTEvaluatePositionRiskLimit(true,700,-100)==ICT_RISK_LIMIT_UNKNOWN);
   Check("negative loss input is not a loss threshold",ICTEvaluatePositionRiskLimit(true,-700,10000)==ICT_RISK_LIMIT_UNKNOWN);
   Check("reversed warning and closing thresholds are rejected",ICTEvaluatePositionRiskLimit(true,700,10000,5,3)==ICT_RISK_LIMIT_UNKNOWN);
   Check("threshold policy honors a selected positive reference",ICTEvaluatePositionRiskLimit(true,500,8000)==ICT_RISK_LIMIT_CLOSE);
   SICTPositionRiskInput p; PositionRiskFixture(p);
   SICTPositionRisk r;
   Check("position risk uses real broker money and actual volume",ICTCalculatePositionRisk(p,10000,10,r) &&
      r.valid && r.stop_valid && r.target_valid && r.costs==5 && r.risk_money==107 && r.net_at_target==243);
   Check("actual SL TP and floating percentages use the selected account capital",
      MathAbs(r.risk_percent-1.07)<1e-9 && MathAbs(r.target_percent-2.43)<1e-9 &&
      r.floating==23 && MathAbs(r.floating_percent-0.23)<1e-9);
   Check("net position RR includes swap and configured cost reserve",
      r.rr_valid && MathAbs(r.rr-243.0/107.0)<1e-9);
   ICTCalculatePositionRisk(p,8000,10,r);
   Check("equity denominator changes percent without changing risk money",
      r.risk_money==107 && MathAbs(r.risk_percent-1.3375)<1e-9);
   p.volume=0.25; p.swap=-1; p.profit=12.5; p.gross_at_stop=-50; p.gross_at_target=125;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("partial close values only remaining exposure",
      r.costs==2.5 && r.risk_money==53.5 && r.net_at_target==121.5 && r.floating==11.5);
   PositionRiskFixture(p); p.direction=-1; p.stop=102; p.target=95;
   p.volume=0.2; p.swap=1; p.gross_at_stop=-40; p.gross_at_target=120;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("sell risk uses broker valuation and positive swap",
      r.risk_money==41 && r.net_at_target==119 && MathAbs(r.risk_percent-0.41)<1e-9);
   PositionRiskFixture(p); p.stop=0;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("missing SL cannot reuse an earlier valid stop result",!r.stop_valid && r.target_valid && !r.rr_valid);
   SICTPositionRiskTotals totals; ZeroMemory(totals); ICTAccumulatePositionRisk(r,totals);
   Check("a missing stop makes aggregate risk explicitly incomplete",totals.count==1 && totals.unknown_stops==1);
   PositionRiskFixture(p); p.stop_valued=false;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("failed broker stop valuation is unknown not zero risk",r.valid && !r.stop_valid && !r.rr_valid);
   PositionRiskFixture(p); p.target=0;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("missing TP preserves known stop risk but has no invented reward",
      r.stop_valid && r.risk_money==107 && !r.target_valid && !r.rr_valid);
   PositionRiskFixture(p); p.stop=101; p.gross_at_stop=20;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("profitable trailing stop reports locked money without infinite RR",
      r.stop_valid && r.risk_money==0 && r.locked_money==13 && !r.rr_valid);
   Check("a profitable SL still has additional equity giveback risk",r.floating==23 && r.remaining_risk_money==10);
   p.gross_at_stop=7; ICTCalculatePositionRisk(p,10000,10,r);
   Check("net break even after fees is distinct from a missing stop",
      r.stop_valid && r.risk_money==0 && r.locked_money==0 && !r.rr_valid);
   PositionRiskFixture(p); p.gross_at_target=3;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("a target below net break even remains a negative P L",
      r.target_valid && r.net_at_target==-4 && r.target_percent<0 && !r.rr_valid);
   PositionRiskFixture(p); ICTCalculatePositionRisk(p,0,10,r);
   Check("zero capital keeps valid money figures without claiming a valid percent",
      r.valid && !r.capital_valid && r.risk_money==107 && r.risk_percent==0);
   ICTCalculatePositionRisk(p,-100,10,r);
   Check("negative equity never divides or produces a negative risk percentage",!r.capital_valid);
   Check("negative configured fees cannot inflate projected reward",!ICTCalculatePositionRisk(p,10000,-1,r) && !r.valid);
   p.volume=0;
   Check("zero actual position volume is invalid",!ICTCalculatePositionRisk(p,10000,10,r));
   PositionRiskFixture(p); p.direction=0;
   Check("unknown position direction is invalid",!ICTCalculatePositionRisk(p,10000,10,r));
   PositionRiskFixture(p); ICTCalculatePositionRisk(p,10000,10,r);
   ZeroMemory(totals); ICTAccumulatePositionRisk(r,totals);
   p.direction=-1; p.stop=102; p.gross_at_stop=-50;
   ICTCalculatePositionRisk(p,10000,10,r); ICTAccumulatePositionRisk(r,totals);
   Check("hedged positions sum loss exposures instead of cancelling each other",
      totals.count==2 && totals.risk_money==164 && totals.unknown_stops==0);
   p.gross_at_stop=50; ICTCalculatePositionRisk(p,10000,10,r); ICTAccumulatePositionRisk(r,totals);
   Check("locked stop profit never offsets another position risk",totals.count==3 && totals.risk_money==164);
   TestLiveAccountRiskBudgets();
  }

void TestLiveAccountRiskBudgets()
  {
   Check("entry capital shrinks with equity",ICTConservativeRiskCapital(10000,9000,8000)==8000);
   Check("floating profit cannot enlarge trade capital above balance",ICTConservativeRiskCapital(10000,9000,11000)==9000);
   Check("deposits cannot enlarge a fixed protection reference",ICTConservativeRiskCapital(10000,11000,12000)==10000);
   Check("invalid current equity blocks sizing",ICTConservativeRiskCapital(10000,10000,0)==0);
   SICTPositionRiskSnapshot s; ZeroMemory(s);
   s.balance=10000; s.equity=10000; s.capital=10000; s.connected=true; s.daily_valid=true; s.daily_opened_valid=true;
   string reason="";
   Check("automatic SL TP accepts the exact requested three percent risk",SRMPValidatePositionPlanRisk(-300,600,0,10000,3,2,reason));
   Check("automatic SL TP rejects more than three percent risk",!SRMPValidatePositionPlanRisk(-300.01,700,0,10000,3,2,reason));
   Check("automatic SL TP cannot configure a ceiling above three percent",!SRMPValidatePositionPlanRisk(-25,60,0,10000,3.01,2,reason));
   Check("small entry fits an empty account budget",ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   Check("exact portfolio and projected daily boundary may be reserved",ICTPositionEntryBudgetAllowed(s,100,10000,1,1,reason));
   Check("portfolio boundary cannot be crossed by a new SL",!ICTPositionEntryBudgetAllowed(s,100.01,10000,1,1,reason));
   s.totals.risk_money=80; s.totals.remaining_risk_money=80;
   Check("individually small trades cannot stack past the aggregate cap",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.totals.risk_money=65; s.totals.remaining_risk_money=65; s.pending_risk_money=10; s.pending_count=1;
   Check("pending risk reserves the same budget as open exposure",ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.pending_risk_money=10.01;
   Check("a pending order can consume the final available risk",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.pending_risk_money=10; s.totals.remaining_risk_money=80;
   Check("equity giveback also enforces the portfolio cap",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.totals.risk_money=0; s.totals.remaining_risk_money=487; s.pending_risk_money=0; s.daily_net=500;
   Check("locked SL profit cannot hide large floating-profit giveback",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.totals.remaining_risk_money=0; s.daily_net=-90;
   Check("new risk is reserved before reaching the daily stop",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason) && StringFind(reason,"Daily")>=0);
   s.daily_net=-75;
   Check("exact remaining daily budget is allowed",ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.daily_net=-100;
   Check("at the daily loss threshold no fresh entry is allowed",!ICTPositionEntryBudgetAllowed(s,1,10000,1,1,reason));
   s.daily_net=0; s.daily_valid=false;
   Check("missing daily history blocks a live daily budget",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   Check("daily budget cannot be disabled to bypass the user limit",!ICTPositionEntryBudgetAllowed(s,25,10000,1,0,reason));
   Check("daily budget cannot exceed the user six percent ceiling",!ICTPositionEntryBudgetAllowed(s,25,10000,10,6.01,reason));
   Check("one trade cannot exceed three percent even under a larger portfolio cap",!ICTPositionEntryBudgetAllowed(s,301,10000,10,6,reason));
   s.daily_valid=true;
   Check("exact user three percent per trade boundary is supported",ICTPositionEntryBudgetAllowed(s,300,10000,3,6,reason));
   s.daily_net=-300;
   Check("a second three percent SL can reserve the remaining six percent day budget",ICTPositionEntryBudgetAllowed(s,300,10000,3,6,reason));
   s.daily_net=-300.01;
   Check("a new SL cannot take the day beyond six percent",!ICTPositionEntryBudgetAllowed(s,300,10000,3,6,reason));
   s.daily_net=0;
   s.daily_opened_risk_money=575;
   Check("cumulative daily risk can use exactly the remaining six percent",ICTPositionEntryBudgetAllowed(s,25,10000,3,6,reason));
   s.daily_opened_risk_money=575.01;
   Check("cumulative daily risk cannot cross six percent",!ICTPositionEntryBudgetAllowed(s,25,10000,3,6,reason));
   s.daily_opened_risk_money=600; s.daily_net=1000;
   Check("a winning trade never refunds cumulative daily risk",!ICTPositionEntryBudgetAllowed(s,25,10000,3,6,reason));
   Check("loss-only mode still permits an explicit cumulative-risk opt-out",ICTPositionEntryBudgetAllowed(s,25,10000,3,6,reason,false));
   s.daily_opened_risk_money=0; s.daily_net=0; s.daily_opened_valid=false;
   Check("missing original SL history blocks a cumulative daily budget",!ICTPositionEntryBudgetAllowed(s,25,10000,3,6,reason));
   s.daily_opened_valid=true;
   s.daily_valid=true; s.unknown_pending=1;
   Check("a pending order without a valued SL blocks entry",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.unknown_pending=0; s.totals.unknown_stops=1;
   Check("a manual position without SL blocks entry",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.totals.unknown_stops=0; s.totals.unknown_floating=1;
   Check("unknown floating prevents hiding equity giveback",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.totals.unknown_floating=0; s.selection_errors=1;
   Check("an incomplete account scan blocks new risk",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.selection_errors=0; s.symbol_filter="TEST";
   Check("symbol-only data cannot authorize an account budget",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.symbol_filter=""; s.connected=false;
   Check("disconnected data cannot authorize an account budget",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.connected=true; s.equity=8000;
   Check("portfolio percentages use reduced current equity",!ICTPositionEntryBudgetAllowed(s,81,10000,1,1,reason));
   s.equity=10000;
   Check("negative aggregate risk cannot subsidize a new trade",(s.totals.risk_money=-1)<0 && !ICTPositionEntryBudgetAllowed(s,25,10000,1,1,reason));
   s.totals.risk_money=0;
   Check("negative policy limits do not silently disable safety",!ICTPositionEntryBudgetAllowed(s,25,10000,-1,1,reason));
   Check("invalid zero candidate risk is rejected",!ICTPositionEntryBudgetAllowed(s,0,10000,1,1,reason));
   Check("risk sum overflow fails closed",(s.pending_risk_money=DBL_MAX)>0 && !ICTPositionEntryBudgetAllowed(s,DBL_MAX,10000,1,1,reason));
  }

void TestLivePositionRiskDisplay()
  {
   SICTPositionRiskSnapshot s; ZeroMemory(s); s.currency="USD"; s.currency_digits=2;
   s.capital_mode=ICT_POSITION_BALANCE; s.balance=10000; s.equity=10023; s.capital=10000;
   s.symbol_filter="TEST"; s.cost_per_lot=10; s.connected=true;
   Check("no positions shows an explicit waiting state",ICTPositionRiskStatus(s)=="CHƯA CÓ VỊ THẾ");
   SICTPositionRiskInput p; PositionRiskFixture(p);
   SICTPositionRisk r; ICTCalculatePositionRisk(p,s.capital,s.cost_per_lot,r);
   ArrayResize(s.positions,1); s.positions[0]=r; ICTAccumulatePositionRisk(r,s.totals);
   string body=ICTPositionRiskBody(s);
   Check("live risk panel shows actual ticket and money percentages",
      StringFind(body,"#123")>=0 && StringFind(body,"107.00 USD (1.07%)")>=0 &&
      StringFind(body,"+243.00 USD (2.43%)")>=0 && StringFind(body,"+23.00 USD (0.23%)")>=0);
   Check("risk summary shows RR for the highest-risk open position",
      StringFind(ICTPositionSummaryValue(s,10,3,6),"RR 1:2.27")>=0);
   Check("risk summary uses five distinct headline metrics",
      ICTPositionSummaryCount()==5 && ICTPositionSummaryMetric(0)==0 &&
      ICTPositionSummaryMetric(1)==1 && ICTPositionSummaryMetric(2)==2 &&
      ICTPositionSummaryMetric(3)==4 && ICTPositionSummaryMetric(4)==10 &&
      ICTPositionSummaryMetric(5)==-1);
   Check("cost treatment and actual entry basis are visible in risk panel",
      StringFind(body,"chưa trừ commission")>=0 && StringFind(body,"giá vào thực tế")>=0 && StringFind(body,"10.00 USD/lot")>=0);
   s.symbol_filter=""; s.protection_online=true; s.protection_armed=true; s.protection_healthy=true;
   Check("armed healthy protection has an explicit monitored state",ICTPositionSummaryValue(s,0,1,1)=="ĐANG GIÁM SÁT" && ICTPositionSummarySeverity(s,0,1,1)==1);
   s.protection_armed=false;
   Check("a fresh heartbeat alone does not imply automatic protection",ICTPositionSummaryValue(s,0,1,1)=="CHƯA BẬT TỰ ĐỘNG" && ICTPositionSummarySeverity(s,0,1,1)==2);
   s.protection_armed=true; s.protection_state=1;
   Check("a latched emergency overrides the healthy heartbeat",ICTPositionSummarySeverity(s,0,1,1)==3 && StringFind(ICTPositionSummaryValue(s,0,1,1),"KHÓA")>=0);
   s.protection_state=0; s.daily_valid=true; s.daily_net=23;
   Check("account pending risk is included in the compact SL total",(s.pending_risk_money=10)>0 && StringFind(ICTPositionSummaryValue(s,2,1,1),"117.00")>=0);
   s.pending_risk_money=0; s.unknown_pending=1;
   Check("unknown pending risk gets a critical text warning",StringFind(ICTPositionSummaryValue(s,2,1,1),"CHƯA ĐỦ")==0 && ICTPositionSummarySeverity(s,2,1,1)==3);
   Check("unknown pending risk never presents a known daily headroom",ICTPositionSummaryValue(s,6,1,1)=="CHƯA XÁC ĐỊNH");
   s.unknown_pending=0;
   p.stop=0; ICTCalculatePositionRisk(p,s.capital,s.cost_per_lot,r); s.positions[0]=r;
   ZeroMemory(s.totals); ICTAccumulatePositionRisk(r,s.totals); body=ICTPositionRiskBody(s);
   Check("missing SL is prominently shown as unknown with partial totals",
      StringFind(ICTPositionRiskStatus(s),"CHƯA XÁC ĐỊNH")>=0 && StringFind(body,"CHƯA ĐẶT")>=0 &&
      StringFind(body,"chưa đầy đủ")>=0 && StringFind(body,"(chưa có SL)")>=0);
   s.capital=0; body=ICTPositionRiskBody(s);
   Check("display never presents zero capital as a genuine 0 percent risk",StringFind(body,"chưa có vốn hợp lệ")>=0);
   s.connected=false; body=ICTPositionRiskBody(s);
   Check("disconnected account data is visibly labelled",StringFind(body,"MẤT KẾT NỐI")>=0);
   s.connected=true; s.capital=10000; s.selection_errors=1; ZeroMemory(s.totals);
   Check("a failed position read cannot be mistaken for an empty account",ICTPositionRiskStatus(s)=="ĐANG ĐỒNG BỘ VỊ THẾ");
  }
#endif
