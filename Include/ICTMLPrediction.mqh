#ifndef ICT_ML_PREDICTION_MQH
#define ICT_ML_PREDICTION_MQH

// Independent research telemetry only. This module neither reads nor writes
// native decisions, signal bridges, positions, account permissions or orders.
struct SICTMLPrediction
  {
   bool valid;
   string status,reason,model_id,symbol,timeframe,candidate_id,family,prediction_status;
   datetime generated_utc,asof_utc,expires_utc,fit_cutoff_utc,train_end_utc;
   int direction,train_n;
   bool has_selected_target,has_expected_net_r,has_p_tp;
   double selected_target_r,expected_net_r,p_tp;
  };

bool ICTMLReject(SICTMLPrediction &out,const string status,const string reason)
  {
   ZeroMemory(out); out.status=status; out.reason=reason; return false;
  }

bool ICTMLHex(const string value,const int length)
  {
   if(StringLen(value)!=length) return false;
   for(int i=0;i<length;i++)
     {
      int c=(int)StringGetCharacter(value,i);
      if(!((c>='0' && c<='9') || (c>='a' && c<='f') || (c>='A' && c<='F'))) return false;
     }
   return true;
  }

int ICTMLPeriodSeconds(const string timeframe)
  {
   if(timeframe=="M1") return 60;
   if(timeframe=="M5") return 300;
   if(timeframe=="M15") return 900;
   if(timeframe=="H1") return 3600;
   if(timeframe=="H4") return 14400;
   if(timeframe=="D1") return 86400;
   return 0;
  }

string ICTMLTimeframe(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe==PERIOD_M1) return "M1";
   if(timeframe==PERIOD_M5) return "M5";
   if(timeframe==PERIOD_M15) return "M15";
   if(timeframe==PERIOD_H1) return "H1";
   if(timeframe==PERIOD_H4) return "H4";
   if(timeframe==PERIOD_D1) return "D1";
   return "";
  }

bool ICTMLUnsigned(const string token,long &value)
  {
   value=0;
   int length=StringLen(token);
   if(length<1 || length>10) return false;
   for(int i=0;i<length;i++)
     {
      int c=(int)StringGetCharacter(token,i);
      if(c<'0' || c>'9') return false;
      value=value*10+c-'0';
     }
   return value>0;
  }

// StringToDouble accepts malformed strings as zero. Validate the entire
// decimal/scientific token before conversion, including exponent digits.
bool ICTMLNumber(const string token,double &value)
  {
   value=0;
   int length=StringLen(token),i=0,digits=0;
   if(length<1 || length>64) return false;
   int first=(int)StringGetCharacter(token,0);
   if(first=='+' || first=='-') i++;
   while(i<length)
     {
      int c=(int)StringGetCharacter(token,i);
      if(c<'0' || c>'9') break;
      digits++; i++;
     }
   if(i<length && StringGetCharacter(token,i)=='.')
     {
      i++;
      while(i<length)
        {
         int c=(int)StringGetCharacter(token,i);
         if(c<'0' || c>'9') break;
         digits++; i++;
        }
     }
   if(digits==0) return false;
   if(i<length && (StringGetCharacter(token,i)=='e' || StringGetCharacter(token,i)=='E'))
     {
      i++;
      if(i<length && (StringGetCharacter(token,i)=='+' || StringGetCharacter(token,i)=='-')) i++;
      int exponent_digits=0;
      while(i<length)
        {
         int c=(int)StringGetCharacter(token,i);
         if(c<'0' || c>'9') break;
         exponent_digits++; i++;
        }
      if(exponent_digits==0) return false;
     }
   if(i!=length) return false;
   value=StringToDouble(token);
   return MathIsValidNumber(value);
  }

bool ICTMLOptionalNumber(const string token,bool &present,double &value)
  {
   present=token!="NA"; value=0;
   return !present || ICTMLNumber(token,value);
  }

bool ICTMLToken(const string token)
  {
   int length=StringLen(token);
   if(length<1 || length>128) return false;
   for(int i=0;i<length;i++)
     {
      int c=(int)StringGetCharacter(token,i);
      if(!((c>='A' && c<='Z') || (c>='0' && c<='9') || c=='_')) return false;
     }
   return true;
  }

bool ICTMLSafeFile(const string name)
  {
   int length=StringLen(name);
   if(length<1 || length>200 || StringFind(name,"..")>=0) return false;
   if(StringGetCharacter(name,0)=='/' || StringGetCharacter(name,0)=='\\') return false;
   string component="";
   for(int i=0;i<length;i++)
     {
      int c=(int)StringGetCharacter(name,i);
      if(c=='/' || c=='\\')
        {
         if(component=="" || component=="." || StringGetCharacter(component,StringLen(component)-1)=='.') return false;
         component=""; continue;
        }
      if(!((c>='A' && c<='Z') || (c>='a' && c<='z') || (c>='0' && c<='9') || c=='_' || c=='-' || c=='.')) return false;
      component+=StringSubstr(name,i,1);
     }
   return component!="" && component!="." && StringGetCharacter(component,StringLen(component)-1)!='.';
  }

// Pure protocol validator: all clock and chart expectations are supplied.
// A transport validity result is not a model performance approval.
bool ICTMLParsePrediction(const string line,const string expected_model_id,
                          const string expected_symbol,const string expected_timeframe,
                          const datetime expected_asof_utc,const datetime now_utc,
                          SICTMLPrediction &out)
  {
   ZeroMemory(out);
   if(!ICTMLHex(expected_model_id,64)) return ICTMLReject(out,"INVALID_CONFIG","Model ID pin must contain exactly 64 hex characters");
   int period=ICTMLPeriodSeconds(expected_timeframe);
   if(period<=0) return ICTMLReject(out,"INVALID_CONFIG","Unsupported prediction timeframe");
   if(expected_asof_utc<=0) return ICTMLReject(out,"MISSING_BARS","Latest closed prediction candle is unavailable");
   if(now_utc<=0) return ICTMLReject(out,"INVALID_CLOCK","UTC clock is unavailable");
   int length=StringLen(line);
   if(length<1 || length>8192) return ICTMLReject(out,"INVALID_FILE","Prediction file is empty or exceeds 8192 bytes");
   string content=line;
   if(length>=2 && StringSubstr(content,length-2)=="\r\n") content=StringSubstr(content,0,length-2);
   else if(StringGetCharacter(content,length-1)=='\n' || StringGetCharacter(content,length-1)=='\r') content=StringSubstr(content,0,length-1);
   else return ICTMLReject(out,"PARTIAL","Prediction record requires its final newline terminator");
   for(int i=0;i<StringLen(content);i++)
     {
      int c=(int)StringGetCharacter(content,i);
      if(c<32 || c>126) return ICTMLReject(out,"INVALID_FILE","Expected exactly one ASCII prediction record");
     }
   string fields[];
   if(StringSplit(content,';',fields)!=22 || fields[0]!="ICTML1" || fields[21]!="END")
      return ICTMLReject(out,"INVALID_FILE","Prediction schema, field count or END marker is invalid");
   if(fields[18]!="RESEARCH_ADVISORY" || fields[19]!="0") return ICTMLReject(out,"WRONG_SCOPE","Prediction must be advisory with execution forbidden");
   if(fields[20]!="VERIFIED") return ICTMLReject(out,"UNVERIFIED_SOURCE","Verified source marker is required");
   if(!ICTMLHex(fields[1],64) || fields[1]!=expected_model_id) return ICTMLReject(out,"MODEL_MISMATCH","Prediction model does not match pinned model ID");
   if(StringLen(fields[2])<1 || StringLen(fields[2])>40 || fields[2]!=expected_symbol)
      return ICTMLReject(out,"SYMBOL_MISMATCH","Prediction symbol does not match chart symbol");
   for(int i=0;i<StringLen(fields[2]);i++)
      if(StringGetCharacter(fields[2],i)<=32) return ICTMLReject(out,"INVALID_FILE","Prediction symbol must be a nonwhitespace ASCII token");
   if(fields[3]!=expected_timeframe || ICTMLPeriodSeconds(fields[3])<=0) return ICTMLReject(out,"TIMEFRAME_MISMATCH","Prediction timeframe does not match configured timeframe");
   long generated=0,asof=0,expires=0,fit_cutoff=0,train_end=0,train_n=0;
   if(!ICTMLUnsigned(fields[4],generated) || !ICTMLUnsigned(fields[5],asof) || !ICTMLUnsigned(fields[6],expires) ||
      !ICTMLUnsigned(fields[7],fit_cutoff) || !ICTMLUnsigned(fields[8],train_end) ||
      !ICTMLUnsigned(fields[17],train_n) || train_n>2147483647)
      return ICTMLReject(out,"INVALID_NUMBER","Prediction timestamps and training count must be positive integers");
   if(asof!=(long)expected_asof_utc) return ICTMLReject(out,"ASOF_MISMATCH","Prediction is not for the latest closed configured candle");
   if(asof>(long)now_utc) return ICTMLReject(out,"INVALID_TIME","Prediction confirmation has not closed on the UTC clock");
   if(generated>(long)now_utc+5 || generated<asof) return ICTMLReject(out,"INVALID_TIME","Prediction generation timestamp is future-dated or before confirmation");
   if(expires<=asof || expires>asof+period || generated>=expires) return ICTMLReject(out,"INVALID_TIME","Prediction validity must end within the next candle");
   if((long)now_utc>=expires) return ICTMLReject(out,"STALE","Prediction has expired");
   if(train_end>=fit_cutoff || fit_cutoff>asof) return ICTMLReject(out,"INVALID_TRAINING_TIME","Training labels must finish before the frozen cutoff and prediction confirmation");
   bool candidate=fields[9]!="-";
   bool known_family=fields[10]=="SWEEP_RECLAIM" || fields[10]=="FVG_FIRST_RETEST" || fields[10]=="BREAK_RETEST";
   int direction=(fields[11]=="1" ? 1 : fields[11]=="-1" ? -1 : 0);
   if((fields[11]!="1" && fields[11]!="-1" && fields[11]!="0") ||
      (candidate && (!ICTMLHex(fields[9],24) || !known_family || direction==0)) ||
      (!candidate && (fields[10]!="-" || direction!=0)))
      return ICTMLReject(out,"INVALID_IDENTITY","Candidate ID, family and direction are inconsistent");
   if(fields[12]!="SELECTED" && fields[12]!="ABSTAIN") return ICTMLReject(out,"INVALID_STATUS","Prediction status must be SELECTED or ABSTAIN");
   if(!ICTMLToken(fields[13])) return ICTMLReject(out,"INVALID_STATUS","Prediction reason must be an uppercase token");
   bool has_target=false,has_expected=false,has_probability=false;
   double target=0,expected=0,probability=0;
   if(!ICTMLOptionalNumber(fields[14],has_target,target) || !ICTMLOptionalNumber(fields[15],has_expected,expected) ||
      !ICTMLOptionalNumber(fields[16],has_probability,probability) ||
      (has_probability && (probability<0 || probability>1)))
      return ICTMLReject(out,"INVALID_NUMBER","Prediction numeric fields must be finite decimals or NA; probability must be in [0,1]");
   if((fields[12]=="SELECTED" && (!candidate || !has_target || target<=0 || !has_expected)) ||
      (fields[12]=="ABSTAIN" && has_target))
      return ICTMLReject(out,"INVALID_STATUS","Selected predictions require a positive target and expectation; abstentions have no selected target");
   out.valid=true; out.status="READY"; out.reason=fields[13]; out.model_id=fields[1]; out.symbol=fields[2]; out.timeframe=fields[3];
   out.generated_utc=(datetime)generated; out.asof_utc=(datetime)asof; out.expires_utc=(datetime)expires;
   out.fit_cutoff_utc=(datetime)fit_cutoff; out.train_end_utc=(datetime)train_end;
   out.candidate_id=fields[9]; out.family=fields[10]; out.direction=direction; out.prediction_status=fields[12]; out.train_n=(int)train_n;
   out.has_selected_target=has_target; out.has_expected_net_r=has_expected; out.has_p_tp=has_probability;
   out.selected_target_r=target; out.expected_net_r=expected; out.p_tp=probability;
   return true;
  }

bool ICTMLReadPrediction(const string relative_file,const bool common_scope,const string expected_model_id,
                         const string expected_symbol,const string expected_timeframe,
                         const datetime expected_asof_utc,const datetime now_utc,SICTMLPrediction &out)
  {
   if(!ICTMLSafeFile(relative_file)) return ICTMLReject(out,"INVALID_CONFIG","Prediction file must be a safe relative path under MQL5/Files");
   int flags=FILE_READ|FILE_BIN|FILE_SHARE_READ;
   if(common_scope) flags|=FILE_COMMON;
   int handle=FileOpen(relative_file,flags);
   if(handle==INVALID_HANDLE) return ICTMLReject(out,"MISSING","Prediction file is absent or temporarily unavailable");
   ulong length=FileSize(handle);
   if(length<1 || length>8192) { FileClose(handle); return ICTMLReject(out,"INVALID_FILE","Prediction file is empty or exceeds 8192 bytes"); }
   uchar bytes[];
   ArrayResize(bytes,(int)length);
   uint read=FileReadArray(handle,bytes,0,(int)length);
   FileClose(handle);
   if(read!=(uint)length) return ICTMLReject(out,"INVALID_FILE","Prediction file was not read completely");
   for(int i=0;i<(int)length;i++)
      if((bytes[i]<32 && bytes[i]!=10 && bytes[i]!=13) || bytes[i]>126)
         return ICTMLReject(out,"INVALID_FILE","Prediction file must contain ASCII text without control characters");
   string line=CharArrayToString(bytes,0,(int)length,CP_UTF8);
   return ICTMLParsePrediction(line,expected_model_id,expected_symbol,expected_timeframe,expected_asof_utc,now_utc,out);
  }

string ICTMLDashboardBody(const SICTMLPrediction &prediction)
  {
   string body="[ML/DL tham khảo - ứng viên nghiên cứu độc lập]\n";
   if(!prediction.valid) return body+prediction.status+": "+prediction.reason+"\n";
   body+=prediction.prediction_status+" | "+prediction.timeframe+" | "+prediction.reason+"\n";
   if(prediction.candidate_id!="-")
      body+=prediction.family+" "+(prediction.direction>0 ? "BUY" : "SELL")+" | ID "+prediction.candidate_id+"\n";
   body+="Target "+(prediction.has_selected_target ? DoubleToString(prediction.selected_target_r,2)+"R" : "--")+
      " | R ròng kỳ vọng "+(prediction.has_expected_net_r ? DoubleToString(prediction.expected_net_r,3) : "--")+"\n";
   body+="P(TP trước SL trong horizon): "+(prediction.has_p_tp ? DoubleToString(prediction.p_tp*100,1)+"%" : "chưa có")+
      " (chưa hiệu chỉnh xác suất)\n";
   body+="Xác nhận UTC "+TimeToString(prediction.asof_utc,TIME_DATE|TIME_SECONDS)+" | hết hạn UTC "+
      TimeToString(prediction.expires_utc,TIME_DATE|TIME_SECONDS)+"\n";
   body+="Train "+IntegerToString(prediction.train_n)+" | model "+StringSubstr(prediction.model_id,0,12)+"\n";
   body+="Dự báo riêng từ nghiên cứu; không thay tín hiệu, SL/TP hoặc điều kiện rủi ro của EA.\n";
   return body;
  }

string ICTMLChartText(const SICTMLPrediction &prediction)
  {
   if(!prediction.valid) return "ML/DL | "+prediction.status;
  string direction=(prediction.direction>0 ? "BUY" : prediction.direction<0 ? "SELL" : "KHÔNG CÓ HƯỚNG");
   string probability=(prediction.has_p_tp ? DoubleToString(prediction.p_tp*100,1)+"%" : "N/A");
   return "ML/DL RESEARCH | "+prediction.timeframe+" | "+prediction.prediction_status+" "+direction+
    " | P(TP trước SL) "+probability+" | CHƯA HIỆU CHỈNH";
  }
#endif
