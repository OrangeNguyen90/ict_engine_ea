#ifndef ICT_POSITION_RISK_FIXTURES_MQH
#define ICT_POSITION_RISK_FIXTURES_MQH
#include "../Include/ICTPositionRiskRenderer.mqh"

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
   Check("cost treatment and actual entry basis are visible in risk panel",
      StringFind(body,"chưa trừ commission")>=0 && StringFind(body,"giá vào thực tế")>=0 && StringFind(body,"10.00 USD/lot")>=0);
   p.stop=0; ICTCalculatePositionRisk(p,s.capital,s.cost_per_lot,r); s.positions[0]=r;
   ZeroMemory(s.totals); ICTAccumulatePositionRisk(r,s.totals); body=ICTPositionRiskBody(s);
   Check("missing SL is prominently shown as unknown with partial totals",
      StringFind(ICTPositionRiskStatus(s),"CHƯA XÁC ĐỊNH")>=0 && StringFind(body,"CHƯA ĐẶT")>=0 &&
      StringFind(body,"chưa đầy đủ")>=0 && StringFind(body,"(chưa có SL)")>=0);
   s.capital=0; body=ICTPositionRiskBody(s);
   Check("display never presents zero capital as a genuine 0 percent risk",StringFind(body,"chưa có vốn hợp lệ")>=0);
   s.connected=false; body=ICTPositionRiskBody(s);
   Check("disconnected account data is visibly labelled",StringFind(body,"MẤT KẾT NỐI")>=0);
   s.selection_errors=1; ZeroMemory(s.totals);
   Check("a failed position read cannot be mistaken for an empty account",ICTPositionRiskStatus(s)=="ĐANG ĐỒNG BỘ VỊ THẾ");
  }
#endif
