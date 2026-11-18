#ifndef ICT_UNIFIED_DIAGNOSTIC_FIXTURES_MQH
#define ICT_UNIFIED_DIAGNOSTIC_FIXTURES_MQH
// Both the standalone and unified MQL test suites provide Check().
void TestSMTJournalCursorCompatibility()
  {
   SICTSMTJournalCursor cursor; ZeroMemory(cursor);
   Check("empty SMT slot restores without a comparator",ICTNormalizeSMTJournalCursor(PERIOD_H4,100300,cursor));
   ENUM_TIMEFRAMES legacy_frames[3]={PERIOD_H4,PERIOD_D1,PERIOD_W1};
   for(int i=0;i<3;i++)
     {
      cursor.comparison=""; cursor.timeframe=legacy_frames[i]; cursor.through=100000;
      Check("legacy empty comparator cursor migrates without a fabricated peer",
         ICTNormalizeSMTJournalCursor(legacy_frames[i],100300,cursor) &&
         cursor.comparison=="" && cursor.timeframe==PERIOD_CURRENT && cursor.through==0);
     }
   cursor.comparison="GBPUSD"; cursor.timeframe=PERIOD_H4; cursor.through=100000;
   Check("identified SMT cursor retains its frozen replay boundary",
      ICTNormalizeSMTJournalCursor(PERIOD_H4,100300,cursor) && cursor.comparison=="GBPUSD" && cursor.through==100000);
   Check("SMT cursor from a different mapped frame remains rejected",
      !ICTNormalizeSMTJournalCursor(PERIOD_D1,100300,cursor));
   cursor.comparison="";
   Check("legacy empty cursor cannot conceal a different timeframe",
      !ICTNormalizeSMTJournalCursor(PERIOD_D1,100300,cursor));
   cursor.through=100301;
   Check("legacy empty cursor cannot conceal future history",
      !ICTNormalizeSMTJournalCursor(PERIOD_H4,100300,cursor));
   cursor.timeframe=PERIOD_CURRENT; cursor.through=100000;
   Check("empty cursor without a source frame cannot advance history",
      !ICTNormalizeSMTJournalCursor(PERIOD_H4,100300,cursor));
   cursor.timeframe=PERIOD_H4; cursor.through=100000;
   Check("unused SMT layer cannot import a legacy replay cursor",
      !ICTNormalizeSMTJournalCursor(PERIOD_CURRENT,100300,cursor));
  }

void TestIndependentChartContext()
  {
   SICTUnifiedSnapshot s; ZeroMemory(s);
   s.symbol="USTEC"; s.asof=100300;
   s.tiers[0].timeframe=PERIOD_H4; s.tiers[0].status=ICT_CONTEXT_BULLISH; s.tiers[0].closed_at=100000;
   s.tiers[1].timeframe=PERIOD_D1;
   s.tiers[1].reason="INSUFFICIENT_DATA: waiting for closed history (60 bars)";
   s.tiers[2].timeframe=PERIOD_W1;
   s.tiers[2].reason="INSUFFICIENT_DATA: confirmed swings missing";
   s.reason="SMT payload journal corrupt/unavailable: frozen confirmation history cannot be restored";
   Check("SMT persistence failure retains independently closed price context",
      ICTUnifiedTierAvailable(s,PERIOD_H4) && !s.valid && !ICTUnifiedSMTAligned(s,1));
   Check("missing MTF or absent tier cannot create chart analysis",
      !ICTUnifiedTierAvailable(s,PERIOD_D1) && !ICTUnifiedTierAvailable(s,PERIOD_CURRENT));
   s.tiers[0].closed_at=s.asof+1;
   Check("unfinished future context cannot be drawn",!ICTUnifiedTierAvailable(s,PERIOD_H4));
   s.tiers[0].closed_at=100000; s.tiers[0].status=ICT_CONTEXT_INSUFFICIENT;
   Check("incomplete structure cannot be drawn as confirmed",!ICTUnifiedTierAvailable(s,PERIOD_H4));
   string body=ICTUnifiedDashboardBody(s,"","",s.reason);
   Check("missing tiers identify the frame and the specific history requirement",
      StringFind(body,"MTF "+ICTUnifiedTF(PERIOD_D1))>=0 && StringFind(body,"Đang tải lịch sử nến đóng (cần 60 nến)")>=0 &&
      StringFind(body,"HTF "+ICTUnifiedTF(PERIOD_W1))>=0 && StringFind(body,"Chưa đủ đỉnh/đáy đã xác nhận")>=0);
  }

void RunUnifiedDiagnosticFixtures()
  {
   TestSMTJournalCursorCompatibility();
   TestIndependentChartContext();
   SICTUnifiedSnapshot s; ZeroMemory(s);
   s.valid=true; s.symbol="TEST"; s.asof=100300; s.layer_count=1;
   s.comparison1="PEER1"; s.layers[0].last_close=s.asof;
   s.layers[0].peers[0].comparison="PEER1";
   s.layers[0].peers[1].reason="DISABLED";
   Check("missing data is unavailable",StringFind(ICTUnifiedSMTDiagnostic(s,1),"UNAVAILABLE")==0);
   Check("unknown direction remains unknown",StringFind(ICTUnifiedSMTDiagnostic(s,0),"UNKNOWN:")==0);
   s.layers[0].peers[0].ready=true; s.layers[0].peers[0].relation_known=true;
   s.layers[0].peers[0].last_close=s.asof; s.layers[0].peers[0].state=ICT_SMT_PEER_NONE;
   Check("valid no-divergence is none",StringFind(ICTUnifiedSMTDiagnostic(s,1),"NONE:")==0);
   s.layers[0].peers[0].state=ICT_SMT_PEER_BULLISH;
   Check("aligned is reported and passes existing gate",StringFind(ICTUnifiedSMTDiagnostic(s,1),"ALIGNED:")==0 && ICTUnifiedSMTAligned(s,1));
   Check("opposite is reported and fails existing gate",StringFind(ICTUnifiedSMTDiagnostic(s,-1),"OPPOSITE:")==0 && !ICTUnifiedSMTAligned(s,-1));
   s.layers[0].peers[0].conflict=true;
   Check("peer conflict remains vetoed",StringFind(ICTUnifiedSMTDiagnostic(s,1),"CONFLICT:")==0 && !ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[0].conflict=false;
   s.comparison2="PEER2"; s.layers[0].peers[1].comparison="PEER2"; s.layers[0].peers[1].reason="INSUFFICIENT_DATA";
   Check("partial data reported without changing aligned gate",StringFind(ICTUnifiedSMTDiagnostic(s,1),"some peer data unavailable")>=0 && ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[1].ready=true; s.layers[0].peers[1].relation_known=true;
   s.layers[0].peers[1].last_close=s.asof; s.layers[0].peers[1].state=ICT_SMT_PEER_BEARISH;
   Check("opposite peers conflict and remain vetoed",StringFind(ICTUnifiedSMTDiagnostic(s,1),"CONFLICT:")==0 && !ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[1].state=ICT_SMT_PEER_NONE;
   Check("none on another peer retains aligned result",StringFind(ICTUnifiedSMTDiagnostic(s,1),"ALIGNED:")==0 && ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[0].last_close=s.asof-1;
   Check("stale peer does not become aligned",StringFind(ICTUnifiedSMTDiagnostic(s,1),"NONE:")==0 &&
      StringFind(ICTUnifiedSMTDiagnostic(s,1),"some peer data unavailable")>=0 && !ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[1].relation_known=false;
   Check("unknown relation is unavailable",StringFind(ICTUnifiedSMTDiagnostic(s,1),"UNAVAILABLE:")==0 && !ICTUnifiedSMTAligned(s,1));
   s.signal.symbol=s.symbol; s.signal.asof=s.asof; s.signal.frames.status=ICT_MTF_FULL;
   s.signal.reason="DATA INSUFFICIENT";
   string body=ICTUnifiedDashboardBody(s,"","","");
   Check("downstream gates not labeled failed on missing data",StringFind(body,"HTF Chưa đánh giá / MTF Chưa đánh giá")>=0 &&
      StringFind(body,"Tín hiệu LTF: Chưa đánh giá")>=0 && StringFind(body,"Rủi ro Chưa đánh giá")>=0);
   s.signal.data_ready=true; s.signal.direction=1; s.signal.htf_pass=true; s.signal.mtf_pass=false;
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("failed MTF leaves trigger unevaluated",StringFind(body,"HTF Đạt / MTF Không đạt")>=0 &&
      StringFind(body,"Tín hiệu LTF: Chưa đánh giá")>=0);
   s.signal.mtf_pass=true; s.signal.trigger_bar=s.asof-300; s.signal.ltf_pass=false;
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("missing trigger is wait and leaves SMT unevaluated",StringFind(body,"Tín hiệu LTF: Chờ")>=0 &&
      StringFind(body,"Điều kiện SMT: Chưa đánh giá")>=0);
   s.signal.ltf_pass=true; s.signal.smt_required=true;
   s.signal.reason="NO_TRADE: required SMT unavailable, conflicting or unaligned";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("required SMT veto precedes target and risk",StringFind(body,"Điều kiện SMT: Không đạt")>=0 &&
      StringFind(body,"Mục tiêu Chưa đánh giá / Rủi ro Chưa đánh giá")>=0);
   s.signal.smt_required=false; s.signal.reason="TARGET UNAVAILABLE";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("missing target precedes risk",StringFind(body,"Điều kiện SMT: Tùy chọn")>=0 &&
      StringFind(body,"Mục tiêu Chưa có / Rủi ro Chưa đánh giá")>=0);
   s.signal.tp1=105; s.signal.target_pool_id="POOL";
   s.signal.reason="RISK FILTER FAIL: invalid plan";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("risk failure only after target",StringFind(body,"Điều kiện SMT: Tùy chọn")>=0 &&
      StringFind(body,"Mục tiêu Đạt / Rủi ro Không đạt")>=0);
   s.signal.reason="RISK FILTER FAIL: invalid plan or net RR below configured minimum";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("dashboard displays the Vietnamese risk cause while retaining the original signal",
      StringFind(body,"Bộ lọc rủi ro không đạt")>=0 &&
      s.signal.reason=="RISK FILTER FAIL: invalid plan or net RR below configured minimum");
   s.signal.confirmed=true; s.signal.reason="confirmed";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("confirmed result shows risk pass",StringFind(body,"Mục tiêu Đạt / Rủi ro Đạt")>=0);
   // Exercise the real evaluator as well as the presentation-only cases.
   // A true risk precheck does not imply that plan geometry has passed.
   s.signal.entry=100; s.signal.stop=100; s.signal.tp1=103; s.signal.rr=3;
   s.signal.risk_pass=true; s.signal.smt_required=false;
   bool result=ICTEvaluateSignal(s.signal,2);
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("invalid geometry is reported as risk failure despite precheck",!result &&
      StringFind(body,"Mục tiêu Đạt / Rủi ro Không đạt")>=0);
   s.signal.stop=99;
   result=ICTEvaluateSignal(s.signal,2);
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("valid optional-SMT setup stays confirmed",result && StringFind(body,"Điều kiện SMT: Tùy chọn")>=0 &&
      StringFind(body,"Mục tiêu Đạt / Rủi ro Đạt")>=0);
   s.signal.smt_required=true; s.signal.smt_pass=false;
   result=ICTEvaluateSignal(s.signal,2);
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("same setup retains required SMT veto",!result && StringFind(body,"Điều kiện SMT: Không đạt")>=0 &&
      StringFind(body,"Mục tiêu Chưa đánh giá / Rủi ro Chưa đánh giá")>=0);
  }
#endif
