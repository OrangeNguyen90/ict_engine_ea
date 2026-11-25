#property strict
#property description "Pure independent ML advisory protocol fixtures; no orders or account access."
#include "../Include/ICTMLPrediction.mqh"

int checks=0,failures=0;
void Check(const string name,const bool value)
  { checks++; if(!value) failures++; Print(name,value ? " PASS" : " FAIL"); }

string ICTMLFixtureModel()
  { return "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"; }

string ICTMLFixtureLine()
  {
   return "ICTML1;"+ICTMLFixtureModel()+";TEST;M15;1700000010;1700000000;1700000900;1699999990;1699999900;"+
      "0123456789abcdef01234567;SWEEP_RECLAIM;1;SELECTED;FORECAST;3;0.4;0.6;123;RESEARCH_ADVISORY;0;VERIFIED;END\n";
  }

string ICTMLFixtureField(const string source,const int index,const string replacement)
  {
   string fields[]; int count=StringSplit(source,';',fields); string line="";
   for(int i=0;i<count;i++) line+=(i>0 ? ";" : "")+(i==index ? replacement : fields[i]);
   return line;
  }

bool ICTMLFixtureParse(const string line,SICTMLPrediction &snapshot)
  { return ICTMLParsePrediction(line,ICTMLFixtureModel(),"TEST","M15",(datetime)1700000000,(datetime)1700000050,snapshot); }

void ICTMLFixtureReject(const string name,const string line,const string expected_status)
  {
   SICTMLPrediction snapshot;
   bool accepted=ICTMLFixtureParse(line,snapshot);
   Check(name,!accepted && !snapshot.valid && snapshot.status==expected_status);
  }

void RunICTMLPredictionFixtures()
  {
   string line=ICTMLFixtureLine(); SICTMLPrediction snapshot;
   Check("ML selected record",ICTMLFixtureParse(line,snapshot) && snapshot.valid && snapshot.prediction_status=="SELECTED" &&
      snapshot.direction==1 && snapshot.train_n==123 && snapshot.has_selected_target && snapshot.selected_target_r==3 &&
      snapshot.has_expected_net_r && snapshot.expected_net_r==0.4 && snapshot.has_p_tp && snapshot.p_tp==0.6);
   Check("ML selected permits unavailable one-class probability",ICTMLFixtureParse(ICTMLFixtureField(line,16,"NA"),snapshot) && !snapshot.has_p_tp);
   string abstain=ICTMLFixtureField(ICTMLFixtureField(ICTMLFixtureField(line,12,"ABSTAIN"),13,"EXPECTED_NET_R_NOT_ABOVE_THRESHOLD"),14,"NA");
   Check("ML abstention retains candidate and expectation",ICTMLFixtureParse(abstain,snapshot) && snapshot.prediction_status=="ABSTAIN" &&
      !snapshot.has_selected_target && snapshot.has_expected_net_r && snapshot.candidate_id!="-");
   abstain=ICTMLFixtureField(ICTMLFixtureField(ICTMLFixtureField(abstain,9,"-"),10,"-"),11,"0");
   abstain=ICTMLFixtureField(ICTMLFixtureField(ICTMLFixtureField(abstain,13,"NO_CANDIDATE"),15,"NA"),16,"NA");
   Check("ML abstention without candidate",ICTMLFixtureParse(abstain,snapshot) && snapshot.candidate_id=="-" && snapshot.direction==0);
   Check("ML expiry boundary rejects",!ICTMLParsePrediction(line,ICTMLFixtureModel(),"TEST","M15",(datetime)1700000000,
      (datetime)1700000900,snapshot) && snapshot.status=="STALE");
   Check("ML pin mismatch",!ICTMLParsePrediction(line,"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      "TEST","M15",(datetime)1700000000,(datetime)1700000050,snapshot) && snapshot.status=="MODEL_MISMATCH");
   Check("ML missing bars",!ICTMLParsePrediction(line,ICTMLFixtureModel(),"TEST","M15",0,(datetime)1700000050,snapshot) && snapshot.status=="MISSING_BARS");
   Check("ML invalid pin config",!ICTMLParsePrediction(line,"","TEST","M15",(datetime)1700000000,(datetime)1700000050,snapshot) && snapshot.status=="INVALID_CONFIG");
   Check("ML confirmation cannot be in the future despite generation skew tolerance",
      !ICTMLParsePrediction(ICTMLFixtureField(line,4,"1700000000"),ICTMLFixtureModel(),"TEST","M15",(datetime)1700000000,
      (datetime)1699999999,snapshot) && snapshot.status=="INVALID_TIME");
   ICTMLFixtureReject("ML wrong scope",ICTMLFixtureField(line,18,"LIVE"),"WRONG_SCOPE");
   ICTMLFixtureReject("ML execution flag rejected",ICTMLFixtureField(line,19,"1"),"WRONG_SCOPE");
   ICTMLFixtureReject("ML source verification required",ICTMLFixtureField(line,20,"UNVERIFIED"),"UNVERIFIED_SOURCE");
   ICTMLFixtureReject("ML timeframe mismatch",ICTMLFixtureField(line,3,"M5"),"TIMEFRAME_MISMATCH");
   ICTMLFixtureReject("ML symbol mismatch",ICTMLFixtureField(line,2,"OTHER"),"SYMBOL_MISMATCH");
   ICTMLFixtureReject("ML confirmation mismatch",ICTMLFixtureField(line,5,"1700000001"),"ASOF_MISMATCH");
   ICTMLFixtureReject("ML invalid numeric token",ICTMLFixtureField(line,15,"not-a-number"),"INVALID_NUMBER");
   ICTMLFixtureReject("ML numeric trailing junk",ICTMLFixtureField(line,15,"0.4suffix"),"INVALID_NUMBER");
   ICTMLFixtureReject("ML malformed exponent",ICTMLFixtureField(line,15,"1e+"),"INVALID_NUMBER");
   ICTMLFixtureReject("ML nonfinite numeric token",ICTMLFixtureField(line,15,"1e999"),"INVALID_NUMBER");
   ICTMLFixtureReject("ML probability outside range",ICTMLFixtureField(line,16,"1.01"),"INVALID_NUMBER");
   ICTMLFixtureReject("ML generation future",ICTMLFixtureField(line,4,"1700000056"),"INVALID_TIME");
   ICTMLFixtureReject("ML generation before confirmation",ICTMLFixtureField(line,4,"1699999999"),"INVALID_TIME");
   ICTMLFixtureReject("ML validity crosses next candle",ICTMLFixtureField(line,6,"1700000901"),"INVALID_TIME");
   ICTMLFixtureReject("ML training overlap",ICTMLFixtureField(line,8,"1699999990"),"INVALID_TRAINING_TIME");
   ICTMLFixtureReject("ML fit cutoff after confirmation",ICTMLFixtureField(line,7,"1700000001"),"INVALID_TRAINING_TIME");
   ICTMLFixtureReject("ML partial without terminator",StringSubstr(line,0,StringLen(line)-1),"PARTIAL");
   ICTMLFixtureReject("ML partial END marker",ICTMLFixtureField(line,21,"EN\n"),"INVALID_FILE");
   ICTMLFixtureReject("ML second record rejected",line+line,"INVALID_FILE");
   ICTMLFixtureReject("ML duplicate terminator rejected",line+"\n","INVALID_FILE");
   ICTMLFixtureReject("ML unknown family rejected",ICTMLFixtureField(line,10,"NATIVE_EA_SIGNAL"),"INVALID_IDENTITY");
   ICTMLFixtureReject("ML selected requires candidate",ICTMLFixtureField(line,9,"-"),"INVALID_IDENTITY");
   ICTMLFixtureReject("ML selected requires target",ICTMLFixtureField(line,14,"NA"),"INVALID_STATUS");
   ICTMLFixtureReject("ML selected requires expectation",ICTMLFixtureField(line,15,"NA"),"INVALID_STATUS");
   ICTMLFixtureReject("ML selected requires positive target",ICTMLFixtureField(line,14,"0"),"INVALID_STATUS");
   ICTMLFixtureReject("ML abstention cannot select target",ICTMLFixtureField(line,12,"ABSTAIN"),"INVALID_STATUS");
   ICTMLFixtureReject("ML zero training count",ICTMLFixtureField(line,17,"0"),"INVALID_NUMBER");
   Check("ML valid relative prediction file",ICTMLSafeFile("ICTML/prediction_TEST_M15.txt"));
   Check("ML reject traversal and absolute file paths",!ICTMLSafeFile("../prediction.txt") &&
      !ICTMLSafeFile("C:\\prediction.txt") && !ICTMLSafeFile("/prediction.txt") && !ICTMLSafeFile("ICTML//prediction.txt"));
   double number=0;
   Check("ML strict decimal grammar",ICTMLNumber("+.4e-2",number) && MathAbs(number-0.004)<0.0000001 &&
      !ICTMLNumber(".",number) && !ICTMLNumber("--1",number) && !ICTMLNumber(" 1",number));
   Check("ML advisory body labels separate uncalibrated forecast",ICTMLFixtureParse(line,snapshot) &&
      StringFind(ICTMLDashboardBody(snapshot),"ứng viên nghiên cứu độc lập")>=0 &&
      StringFind(ICTMLDashboardBody(snapshot),"chưa hiệu chỉnh xác suất")>=0);
  Check("ML chart label shows uncalibrated probability",ICTMLFixtureParse(line,snapshot) &&
    StringFind(ICTMLChartText(snapshot),"P(TP trước SL) 60.0%")>=0 &&
    StringFind(ICTMLChartText(snapshot),"CHƯA HIỆU CHỈNH")>=0);
  Check("ML chart label exposes unavailable state",!ICTMLFixtureParse("",snapshot) &&
    StringFind(ICTMLChartText(snapshot),"ML/DL | INVALID_FILE")==0);
  }

int OnInit()
  {
   RunICTMLPredictionFixtures();
   PrintFormat("ICTMLPredictionTests RESULT checks=%d failures=%d",checks,failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
  }
void OnTick() {}
