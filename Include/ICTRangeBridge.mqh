#ifndef ICT_RANGE_BRIDGE_MQH
#define ICT_RANGE_BRIDGE_MQH
#include "ICTRangeTypes.mqh"
#include "AdviceBridge.mqh"

// Binary payload, bounded strings and a chart/account seqlock. No risk or
// detector calls here: the indicator displays the exact producer snapshot.
#define ICT_IR_NUMBERS_MAX 8192
#define ICT_IR_STRINGS_MAX 1024
void IRPush(double &v[],int &n,const double x) { v[n++]=x; }
double IRTake(const double &v[],int &n,bool &ok)
  { if(n>=ArraySize(v)) { ok=false; return 0; } return v[n++]; }
string IRString(const string &v[],int &n,bool &ok)
  { if(n>=ArraySize(v)) { ok=false; return ""; } return v[n++]; }

#define IR_P(x) IRPush(v,n,(double)(x))
#define IR_T(x) t[k++]=(x)
#define IR_G(type) (type)IRTake(v,n,ok)
#define IR_S IRString(t,k,ok)

void IRPackZone(const SICTRangeZone &z,double &v[],int &n,string &t[],int &k)
  {
   IR_T(z.id); IR_T(z.range_id);
   IR_P(z.type); IR_P(z.state); IR_P(z.membership); IR_P(z.timeframe);
   IR_P(z.direction); IR_P(z.quality); IR_P(z.upper); IR_P(z.lower); IR_P(z.midpoint);
   IR_P(z.invalidation); IR_P(z.formed_at); IR_P(z.confirmed_at);
   IR_P(z.displacement); IR_P(z.structure_match); IR_P(z.confluence);
  }
void IRUnpackZone(SICTRangeZone &z,const double &v[],int &n,const string &t[],int &k,bool &ok)
  {
   z.id=IR_S; z.range_id=IR_S;
   z.type=IR_G(ENUM_IR_ZONE_TYPE); z.state=IR_G(ENUM_IR_ZONE_STATE);
   z.membership=IR_G(ENUM_IR_MEMBERSHIP); z.timeframe=IR_G(ENUM_TIMEFRAMES);
   z.direction=IR_G(int); z.quality=IR_G(int); z.upper=IR_G(double); z.lower=IR_G(double);
   z.midpoint=IR_G(double); z.invalidation=IR_G(double); z.formed_at=IR_G(datetime);
   z.confirmed_at=IR_G(datetime); z.displacement=IR_G(bool); z.structure_match=IR_G(bool); z.confluence=IR_G(bool);
  }

void ICTRangePack(const SICTRangeSnapshot &s,double &v[],string &t[])
  {
   ArrayResize(v,0); ArrayResize(t,0);
   if(s.level_count<0 || s.level_count>ICT_RANGE_LEVELS || s.zone_count<0 || s.zone_count>ICT_RANGE_ZONES ||
      s.liquidity_event_count<0 || s.liquidity_event_count>ICT_RANGE_LIQUIDITY_EVENTS ||
      s.sweep_event_count<0 || s.sweep_event_count>ICT_SWEEP_SNAPSHOT_MAX) return;
   ArrayResize(v,ICT_IR_NUMBERS_MAX); ArrayResize(t,ICT_IR_STRINGS_MAX); int n=0,k=0;
   IR_T(s.symbol); IR_T(s.signal_id); IR_T(s.reason); IR_T(s.target_reason); IR_T(s.range.id);
   IR_T(s.source_pool_id); IR_T(s.target1_pool_id); IR_T(s.target2_pool_id);
   IR_T(s.source_reason);
   IR_P(s.schema); IR_P(s.reason_code); IR_P(s.range.version); IR_P(s.range.high); IR_P(s.range.low);
   IR_P(s.range.midpoint); IR_P(s.range.width); IR_P(s.range.direction); IR_P(s.range.bias);
   IR_P(s.range.timeframe); IR_P(s.range.high_time); IR_P(s.range.low_time);
   IR_P(s.range.confirmed_at); IR_P(s.range.retired_at); IR_P(s.range.valid);
   IR_P(s.mtf); IR_P(s.ltf); IR_P(s.as_of); IR_P(s.phase_at); IR_P(s.sweep_at);
   IR_P(s.structure_at); IR_P(s.reaction_at); IR_P(s.last_mtf_event); IR_P(s.phase); IR_P(s.scenario);
   IR_P(s.direction); IR_P(s.htf_bias); IR_P(s.valid); IR_P(s.technical_ready);
   IR_P(s.displacement); IR_P(s.structure_confirmed); IR_P(s.sweep_extreme); IR_P(s.sweep_level);
   IR_P(s.invalidation); IR_P(s.entry); IR_P(s.stop); IR_P(s.tp1); IR_P(s.tp2); IR_P(s.target_distance); IR_P(s.last_close);
   IR_P(s.target1_index); IR_P(s.target2_index); IR_P(s.level_count); IR_P(s.zone_count);
   IR_P(s.proposed_action); IR_P(s.score); IR_P(s.risk_money); IR_P(s.volume); IR_P(s.rr);
   IR_P(s.source_pool_tf); IR_P(s.target1_pool_tf); IR_P(s.target2_pool_tf);
   IR_P(s.source_event); IR_P(s.source_event_at); IR_P(s.liquidity_display_start);
   IRPackZone(s.active_zone,v,n,t,k);
   for(int i=0;i<s.level_count && i<ICT_RANGE_LEVELS;i++)
     {
      SICTRangeLevel l=s.levels[i]; IR_T(l.id); IR_T(l.range_id); IR_T(l.name);
      IR_P(l.price); IR_P(l.side); IR_P(l.membership); IR_P(l.state); IR_P(l.available_at);
      IR_P(l.event_at); IR_P(l.last_bar); IR_P(l.outside_closes); IR_P(l.candidate);
      IR_P(l.timeframe); IR_P(l.last_event); IR_P(l.event_bar_time); IR_P(l.event_wick_time); IR_P(l.event_wick); IR_P(l.event_close);
      IR_P(l.candidate_wick_time); IR_P(l.breakout_at); IR_P(l.candidate_wick);
      IR_P(l.candidate_displacement); IR_P(l.retest_pending); IR_P(l.sweep_armed);
      IR_P(l.breakout_age); IR_P(l.sweep_count); IR_P(l.sweep_wait_bars);
     }
   IR_P(s.liquidity_event_count);
   for(int i=0;i<s.liquidity_event_count;i++)
     {
      SICTRangeLiquidityEvent e=s.liquidity_events[i]; IR_T(e.id); IR_T(e.pool_id); IR_T(e.range_id); IR_T(e.pool_name);
      IR_P(e.type); IR_P(e.membership); IR_P(e.source_tf); IR_P(e.event_tf); IR_P(e.side); IR_P(e.sweep_number);
      IR_P(e.bar_time); IR_P(e.wick_time); IR_P(e.confirmed_at); IR_P(e.level); IR_P(e.wick); IR_P(e.close);
     }
   for(int i=0;i<s.zone_count && i<ICT_RANGE_ZONES;i++) IRPackZone(s.zones[i],v,n,t,k);
   int sweep_count=(int)MathMax(0,MathMin(s.sweep_event_count,ICT_SWEEP_SNAPSHOT_MAX));
   IR_P(sweep_count);
   for(int i=0;i<sweep_count;i++)
     {
      SICTSweepRecord e=s.sweep_events[i]; IR_T(e.pool_id);
      IR_P(e.side); IR_P(e.number); IR_P(e.status); IR_P(e.level); IR_P(e.extreme);
      IR_P(e.depth); IR_P(e.event_time); IR_P(e.confirmed_at);
     }
   ArrayResize(v,n); ArrayResize(t,k);
  }

bool ICTRangeUnpack(const double &v[],const string &t[],SICTRangeSnapshot &s)
  {
   ZeroMemory(s); int n=0,k=0; bool ok=true;
   if(ArraySize(v)>ICT_IR_NUMBERS_MAX || ArraySize(t)>ICT_IR_STRINGS_MAX) return false;
   for(int i=0;i<ArraySize(v);i++) if(!MathIsValidNumber(v[i])) return false;
   s.symbol=IR_S; s.signal_id=IR_S; s.reason=IR_S; s.target_reason=IR_S; s.range.id=IR_S;
   s.source_pool_id=IR_S; s.target1_pool_id=IR_S; s.target2_pool_id=IR_S;
   s.source_reason=IR_S;
   s.schema=IR_G(int); s.reason_code=IR_G(ENUM_IR_REASON); s.range.version=IR_G(int);
   s.range.high=IR_G(double); s.range.low=IR_G(double); s.range.midpoint=IR_G(double);
   s.range.width=IR_G(double); s.range.direction=IR_G(int); s.range.bias=IR_G(int);
   s.range.timeframe=IR_G(ENUM_TIMEFRAMES); s.range.high_time=IR_G(datetime); s.range.low_time=IR_G(datetime);
   s.range.confirmed_at=IR_G(datetime); s.range.retired_at=IR_G(datetime); s.range.valid=IR_G(bool);
   s.mtf=IR_G(ENUM_TIMEFRAMES); s.ltf=IR_G(ENUM_TIMEFRAMES); s.as_of=IR_G(datetime);
   s.phase_at=IR_G(datetime); s.sweep_at=IR_G(datetime); s.structure_at=IR_G(datetime);
   s.reaction_at=IR_G(datetime); s.last_mtf_event=IR_G(datetime); s.phase=IR_G(ENUM_IR_PHASE);
   s.scenario=IR_G(ENUM_IR_SCENARIO); s.direction=IR_G(int); s.htf_bias=IR_G(int);
   s.valid=IR_G(bool); s.technical_ready=IR_G(bool); s.displacement=IR_G(bool); s.structure_confirmed=IR_G(bool);
   s.sweep_extreme=IR_G(double); s.sweep_level=IR_G(double); s.invalidation=IR_G(double);
   s.entry=IR_G(double); s.stop=IR_G(double); s.tp1=IR_G(double); s.tp2=IR_G(double);
   s.target_distance=IR_G(double); s.last_close=IR_G(double); s.target1_index=IR_G(int); s.target2_index=IR_G(int);
   s.level_count=IR_G(int); s.zone_count=IR_G(int); s.proposed_action=IR_G(int); s.score=IR_G(int);
   s.risk_money=IR_G(double); s.volume=IR_G(double); s.rr=IR_G(double);
   s.source_pool_tf=IR_G(ENUM_TIMEFRAMES); s.target1_pool_tf=IR_G(ENUM_TIMEFRAMES); s.target2_pool_tf=IR_G(ENUM_TIMEFRAMES);
   s.source_event=IR_G(ENUM_IR_LEVEL_EVENT); s.source_event_at=IR_G(datetime); s.liquidity_display_start=IR_G(datetime);
   if(!ok || s.schema!=ICT_RANGE_SCHEMA || s.level_count<0 || s.level_count>ICT_RANGE_LEVELS ||
      s.zone_count<0 || s.zone_count>ICT_RANGE_ZONES || (int)s.phase<0 || (int)s.phase>9 ||
      s.proposed_action<-1 || s.proposed_action>1 || s.score<0 || s.score>100 ||
      (int)s.source_event<0 || (int)s.source_event>4 || s.source_event_at>s.as_of ||
      s.liquidity_display_start>s.as_of) return false;
   if(s.source_pool_id!="" && (s.source_event==IR_EVENT_NONE || s.source_event_at<=0 ||
      s.source_pool_tf==PERIOD_CURRENT || PeriodSeconds(s.source_pool_tf)<=0)) return false;
   if((s.target1_pool_id!="" && (s.tp1<=0 || s.target1_pool_tf==PERIOD_CURRENT || PeriodSeconds(s.target1_pool_tf)<=0)) ||
      (s.target2_pool_id!="" && (s.tp2<=0 || s.target2_pool_tf==PERIOD_CURRENT || PeriodSeconds(s.target2_pool_tf)<=0))) return false;
   IRUnpackZone(s.active_zone,v,n,t,k,ok);
   for(int i=0;i<s.level_count;i++)
     {
      s.levels[i].id=IR_S; s.levels[i].range_id=IR_S; s.levels[i].name=IR_S;
      s.levels[i].price=IR_G(double); s.levels[i].side=IR_G(int);
      s.levels[i].membership=IR_G(ENUM_IR_MEMBERSHIP); s.levels[i].state=IR_G(ENUM_IR_LEVEL_STATE);
      s.levels[i].available_at=IR_G(datetime); s.levels[i].event_at=IR_G(datetime);
      s.levels[i].last_bar=IR_G(datetime); s.levels[i].outside_closes=IR_G(int); s.levels[i].candidate=IR_G(bool);
      s.levels[i].timeframe=IR_G(ENUM_TIMEFRAMES); s.levels[i].last_event=IR_G(ENUM_IR_LEVEL_EVENT);
      s.levels[i].event_bar_time=IR_G(datetime); s.levels[i].event_wick_time=IR_G(datetime);
      s.levels[i].event_wick=IR_G(double); s.levels[i].event_close=IR_G(double);
      s.levels[i].candidate_wick_time=IR_G(datetime); s.levels[i].breakout_at=IR_G(datetime); s.levels[i].candidate_wick=IR_G(double);
      s.levels[i].candidate_displacement=IR_G(bool); s.levels[i].retest_pending=IR_G(bool); s.levels[i].sweep_armed=IR_G(bool);
      s.levels[i].breakout_age=IR_G(int); s.levels[i].sweep_count=IR_G(int); s.levels[i].sweep_wait_bars=IR_G(int);
      if(s.levels[i].range_id!=s.range.id || s.levels[i].price<=0 ||
         (s.levels[i].side!=1 && s.levels[i].side!=-1) ||
         (int)s.levels[i].membership<0 || (int)s.levels[i].membership>3 ||
         (int)s.levels[i].state<0 || (int)s.levels[i].state>5 ||
          s.levels[i].available_at>s.as_of || (int)s.levels[i].last_event<0 || (int)s.levels[i].last_event>4 ||
          s.levels[i].timeframe==PERIOD_CURRENT || PeriodSeconds(s.levels[i].timeframe)<=0 ||
          s.levels[i].last_bar>s.as_of || s.levels[i].breakout_at>s.as_of || s.levels[i].candidate_wick_time>s.as_of ||
          s.levels[i].outside_closes<0 || s.levels[i].breakout_age<0 || s.levels[i].sweep_count<0 || s.levels[i].sweep_wait_bars<0) ok=false;
      if(s.levels[i].last_event!=IR_EVENT_NONE &&
         (s.levels[i].event_at<=s.levels[i].event_bar_time || s.levels[i].event_at>s.as_of ||
          s.levels[i].event_bar_time<=0 || s.levels[i].event_wick_time<=0 ||
          s.levels[i].event_wick_time>s.levels[i].event_bar_time || s.levels[i].event_wick<=0 || s.levels[i].event_close<=0)) ok=false;
     }
   s.liquidity_event_count=IR_G(int);
   if(!ok || s.liquidity_event_count<0 || s.liquidity_event_count>ICT_RANGE_LIQUIDITY_EVENTS) return false;
   for(int i=0;i<s.liquidity_event_count;i++)
     {
      SICTRangeLiquidityEvent e; ZeroMemory(e); e.id=IR_S; e.pool_id=IR_S; e.range_id=IR_S; e.pool_name=IR_S;
      e.type=IR_G(ENUM_IR_LEVEL_EVENT); e.membership=IR_G(ENUM_IR_MEMBERSHIP);
      e.source_tf=IR_G(ENUM_TIMEFRAMES); e.event_tf=IR_G(ENUM_TIMEFRAMES); e.side=IR_G(int); e.sweep_number=IR_G(int);
      e.bar_time=IR_G(datetime); e.wick_time=IR_G(datetime); e.confirmed_at=IR_G(datetime);
      e.level=IR_G(double); e.wick=IR_G(double); e.close=IR_G(double);
      if(e.pool_id=="" || e.range_id=="" || e.id!=e.pool_id+"|"+IntegerToString((int)e.type)+"|"+IntegerToString((long)e.confirmed_at) ||
         (int)e.type<1 || (int)e.type>4 ||
         (int)e.membership<0 || (int)e.membership>3 || (e.side!=1 && e.side!=-1) || e.sweep_number<0 ||
         e.source_tf==PERIOD_CURRENT || PeriodSeconds(e.source_tf)<=0 || e.event_tf==PERIOD_CURRENT || PeriodSeconds(e.event_tf)<=0 ||
         e.bar_time<=0 || e.wick_time<=0 || e.wick_time>e.bar_time || e.confirmed_at<=e.bar_time ||
         e.confirmed_at>s.as_of || e.level<=0 || e.wick<=0 || e.close<=0) ok=false;
      s.liquidity_events[i]=e;
     }
   for(int i=0;i<s.zone_count;i++)
     {
      IRUnpackZone(s.zones[i],v,n,t,k,ok);
      if(s.zones[i].range_id!=s.range.id || s.zones[i].upper<=s.zones[i].lower ||
         s.zones[i].lower<=0 || s.zones[i].confirmed_at>s.as_of ||
         (int)s.zones[i].type<0 || (int)s.zones[i].type>2 ||
         (int)s.zones[i].state<0 || (int)s.zones[i].state>3 ||
         (int)s.zones[i].membership<0 || (int)s.zones[i].membership>3) ok=false;
     }
   s.sweep_event_count=IR_G(int);
   if(!ok || s.sweep_event_count<0 || s.sweep_event_count>ICT_SWEEP_SNAPSHOT_MAX) return false;
   for(int i=0;i<s.sweep_event_count;i++)
     {
      s.sweep_events[i].pool_id=IR_S; s.sweep_events[i].side=IR_G(int);
      s.sweep_events[i].number=IR_G(int); s.sweep_events[i].status=IR_G(ENUM_ICT_SWEEP_STATUS);
      s.sweep_events[i].level=IR_G(double); s.sweep_events[i].extreme=IR_G(double);
      s.sweep_events[i].depth=IR_G(double); s.sweep_events[i].event_time=IR_G(datetime);
      s.sweep_events[i].confirmed_at=IR_G(datetime);
      if(s.sweep_events[i].pool_id=="" || (s.sweep_events[i].side!=1 && s.sweep_events[i].side!=-1) ||
         s.sweep_events[i].number<1 || s.sweep_events[i].number>ICT_SWEEP_SEQUENCE_MAX ||
         (int)s.sweep_events[i].status<0 || (int)s.sweep_events[i].status>2 ||
         s.sweep_events[i].level<=0 || s.sweep_events[i].depth<=0 ||
         s.sweep_events[i].event_time<=0 || s.sweep_events[i].event_time>s.as_of ||
         (s.sweep_events[i].status==ICT_SWEEP_CONFIRMED &&
          (s.sweep_events[i].confirmed_at<=s.sweep_events[i].event_time || s.sweep_events[i].confirmed_at>s.as_of))) ok=false;
     }
   return ok && n==ArraySize(v) && k==ArraySize(t) &&
      (!s.valid || (s.range.valid && s.range.high>s.range.low && s.range.low>0 && s.range.confirmed_at<=s.as_of));
  }
#undef IR_P
#undef IR_T
#undef IR_G
#undef IR_S

string ICTRangeSnapshotFile(const string symbol) { return SRMPAdviceKey(symbol,"IRL_ERL")+".bin"; }

bool ICTPublishRange(const string symbol,const SICTRangeSnapshot &s)
  {
   double sequence=GlobalVariableGet(SRMPAdviceKey(symbol,"IRSEQ"));
   sequence=MathFloor(sequence/2)*2+2;
   if(!GlobalVariableSet(SRMPAdviceKey(symbol,"IRSEQ"),sequence-1)) return false;
   double values[]; string strings[]; ICTRangePack(s,values,strings);
   if(ArraySize(values)==0 || ArraySize(strings)==0) return false;
   ResetLastError();
   int f=FileOpen(ICTRangeSnapshotFile(symbol),FILE_WRITE|FILE_BIN|FILE_UNICODE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(f==INVALID_HANDLE) { Print("IRL/ERL snapshot write failed ",GetLastError()); return false; }
   bool ok=FileWriteInteger(f,ICT_RANGE_SCHEMA,INT_VALUE)==4 &&
      FileWriteInteger(f,ArraySize(values),INT_VALUE)==4 && FileWriteInteger(f,ArraySize(strings),INT_VALUE)==4;
   if(FileWriteArray(f,values)!=(uint)ArraySize(values)) ok=false;
   for(int i=0;i<ArraySize(strings);i++)
     {
      int length=StringLen(strings[i]);
      if(length>512 || FileWriteInteger(f,length,INT_VALUE)!=4) { ok=false; break; }
      if(length>0 && FileWriteString(f,strings[i],length)!=(uint)(length*2)) ok=false;
     }
   FileFlush(f); if(GetLastError()!=0) ok=false; FileClose(f);
   if(!ok) { Print("IRL/ERL snapshot incomplete; publication withheld"); return false; }
   if(!GlobalVariableSet(SRMPAdviceKey(symbol,"IRTS"),(double)TimeLocal())) return false;
   return GlobalVariableSet(SRMPAdviceKey(symbol,"IRSEQ"),sequence)>0;
  }

bool ICTReadRange(const string symbol,SICTRangeSnapshot &s,const int max_age=15,
                  const ENUM_TIMEFRAMES expected_ltf=PERIOD_CURRENT)
  {
   ZeroMemory(s);
   double before=GlobalVariableGet(SRMPAdviceKey(symbol,"IRSEQ"));
   datetime stamp=(datetime)GlobalVariableGet(SRMPAdviceKey(symbol,"IRTS"));
   if(before<=0 || MathMod(before,2)!=0 || stamp<=0 || stamp>TimeLocal() || TimeLocal()-stamp>max_age) return false;
   ResetLastError();
   int f=FileOpen(ICTRangeSnapshotFile(symbol),FILE_READ|FILE_BIN|FILE_UNICODE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(f==INVALID_HANDLE) return false;
   int schema=FileReadInteger(f,INT_VALUE),numbers=FileReadInteger(f,INT_VALUE),texts=FileReadInteger(f,INT_VALUE);
   if(schema!=ICT_RANGE_SCHEMA || numbers<1 || numbers>ICT_IR_NUMBERS_MAX || texts<1 || texts>ICT_IR_STRINGS_MAX)
     { FileClose(f); return false; }
   double values[]; string strings[]; ArrayResize(values,numbers); ArrayResize(strings,texts);
   bool ok=FileReadArray(f,values,0,numbers)==(uint)numbers;
   for(int i=0;i<texts && ok;i++)
     {
      if(FileIsEnding(f)) { ok=false; break; }
      int length=FileReadInteger(f,INT_VALUE);
      if(length<0 || length>512 || FileTell(f)+(ulong)(length*2)>FileSize(f)) { ok=false; break; }
      strings[i]=(length>0 ? FileReadString(f,length) : "");
      if(StringLen(strings[i])!=length) ok=false;
     }
   if(GetLastError()!=0) ok=false;
   FileClose(f);
   double after=GlobalVariableGet(SRMPAdviceKey(symbol,"IRSEQ"));
   ENUM_TIMEFRAMES expected=(expected_ltf==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : expected_ltf);
   if(!ok || before!=after || !ICTRangeUnpack(values,strings,s) || s.symbol!=symbol || s.ltf!=expected)
     { ZeroMemory(s); return false; }
   return true;
  }
#endif
