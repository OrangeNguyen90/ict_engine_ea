#ifndef ICT_UNIFIED_ANALYSIS_MQH
#define ICT_UNIFIED_ANALYSIS_MQH
#include "ICTDynamicSMT.mqh"
#include "ICTStrongOrderBlock.mqh"
#include "ICTBalancedPriceRange.mqh"
#include "ICTSignalResult.mqh"

#define ICT_UNIFIED_SCHEMA 3
#define ICT_SMART_OB_MAX 128
#define ICT_SMT_PAYLOAD_VERSION 2
#define ICT_SMT_PAYLOAD_MAGIC 1397576753
#define ICT_SMT_PAYLOAD_FIELDS 20
#define ICT_SMT_PAYLOAD_MAX_BYTES 4194304
enum ENUM_ICT_CONTEXT_STATE { ICT_CONTEXT_INSUFFICIENT=0, ICT_CONTEXT_NEUTRAL=1,
   ICT_CONTEXT_BULLISH=2, ICT_CONTEXT_BEARISH=3 };
enum ENUM_ICT_MTF_STRUCTURE { ICT_STRUCTURE_INSUFFICIENT=0, ICT_STRUCTURE_ALIGNED=1,
   ICT_STRUCTURE_COUNTER=2, ICT_STRUCTURE_TRANSITION=3, ICT_STRUCTURE_NEUTRAL=4 };
struct SICTTierSnapshot
  {
   ENUM_TIMEFRAMES timeframe;
   ENUM_ICT_CONTEXT_STATE status;
   SMarketStructure structure;
   datetime closed_at;
   string reason;
   bool fvg_ready,bpr_ready;
   MqlRates last_bar;
   bool displacement_up,displacement_down;
   SFairValueGap gap;
   SICTBalancedPriceRange bpr;
  };
struct SICTUnifiedConfig
  {
   SICTTimeframes frames;
   ENUM_TIMEFRAMES chart_tf;
   SICTDynamicSMTConfig smt;
   SICTStrongOBConfig ob;
   int structure_lookback,ob_lookback;
   bool enable_ob,ob_multi,ob_show_higher,enable_smt;
  };
struct SICTUnifiedSnapshot
  {
   int schema,revision,detection_bars,display_bars;
   string symbol,comparison1,comparison2,reason,comparator_reason;
   SICTTimeframes frames;
   ENUM_TIMEFRAMES chart_tf;
   SICTSignalResult signal;
   datetime asof,display_start;
   bool valid,capacity_ok;
   ENUM_ICT_MTF_STRUCTURE mtf_state;
   SICTTierSnapshot tiers[3];
   int layer_count,event_count,ob_count;
   SICTSMTLayer layers[4];
   SICTSMTEvent events[ICT_SMART_SMT_MAX];
   SICTStrongOrderBlock zones[ICT_SMART_OB_MAX];
  };
struct SICTCachedSeries
  {
   ENUM_TIMEFRAMES timeframe;
   MqlRates bars[];
   datetime last_open;
   bool ready;
  };
struct SICTSMTJournalCursor
  {
   string comparison;
   ENUM_TIMEFRAMES timeframe;
   datetime through;
  };

// Older writers advanced a slot even when no comparator had been resolved.
// Such a cursor owns no signal IDs. Normalize only this known legacy shape;
// named cursors, mapped timeframes and all saved event payloads stay strict.
bool ICTNormalizeSMTJournalCursor(const ENUM_TIMEFRAMES mapped_tf,const datetime saved,
                                  SICTSMTJournalCursor &cursor)
  {
   if(saved<=0 || cursor.through<0 || cursor.through>saved) return false;
   if(cursor.comparison=="")
     {
      if(cursor.timeframe==PERIOD_CURRENT && cursor.through!=0) return false;
      if(cursor.timeframe!=PERIOD_CURRENT && cursor.timeframe!=mapped_tf) return false;
      cursor.timeframe=PERIOD_CURRENT; cursor.through=0;
      return true;
     }
   return mapped_tf!=PERIOD_CURRENT && cursor.timeframe==mapped_tf;
  }

// Chart context is independent of the all-or-nothing execution snapshot.
// A persistence failure or missing peer must not hide a verified price tier.
bool ICTUnifiedTierAvailable(const SICTUnifiedSnapshot &s,const ENUM_TIMEFRAMES tf)
  {
   if(tf==PERIOD_CURRENT || s.asof<=0) return false;
   for(int i=0;i<3;i++)
      if(s.tiers[i].timeframe==tf && s.tiers[i].status!=ICT_CONTEXT_INSUFFICIENT &&
         s.tiers[i].closed_at>0 && s.tiers[i].closed_at<=s.asof) return true;
   return false;
  }
void ICTPackSMTPayload(const SICTSMTEvent &e,double &v[])
  {
   ArrayResize(v,ICT_SMT_PAYLOAD_FIELDS); SSMTDivergence s=e.signal;
   v[0]=s.state; v[1]=s.direction; v[2]=s.timeframe; v[3]=s.relation; v[4]=s.comparator_extreme;
   v[5]=s.correlation; v[6]=s.correlation_pairs; v[7]=(double)s.primary_pivot_time; v[8]=(double)s.primary_prior_time;
   v[9]=(double)s.comparison_pivot_time; v[10]=(double)s.comparison_prior_time; v[11]=(double)s.pivot_confirmation_time;
   v[12]=(double)s.confirmation_time; v[13]=s.primary_prior; v[14]=s.primary_recent;
   v[15]=s.comparison_prior; v[16]=s.comparison_recent; v[17]=e.life; v[18]=(double)e.changed_at; v[19]=e.seed_context;
  }
bool ICTUnpackSMTPayload(const string symbol,const string comparison,const string id,const double &v[],
                         const datetime asof,SICTSMTEvent &e)
  {
   ZeroMemory(e);
   if(ArraySize(v)!=ICT_SMT_PAYLOAD_FIELDS || comparison=="" || comparison==symbol || id=="") return false;
   for(int i=0;i<ArraySize(v);i++)
     {
      if(!MathIsValidNumber(v[i])) return false;
      if(i!=5 && (i<13 || i>16) && (v[i]< -2147483648.0 || v[i]>9007199254740991.0 || (double)(long)v[i]!=v[i])) return false;
     }
   if((v[0]!=SRMP_SMT_BULLISH && v[0]!=SRMP_SMT_BEARISH) || (v[1]!=1 && v[1]!=-1) ||
      (v[3]!=1 && v[3]!=-1) || (v[4]!=0 && v[4]!=1) || (v[19]!=0 && v[19]!=1) ||
      v[2]<=0 || v[2]>49153 || v[6]<0 || v[6]>200 || MathAbs(v[5])>1.000001 ||
      v[17]<ICT_SMT_CONFIRMED || v[17]>ICT_SMT_EXPIRED) return false;
   SSMTDivergence s; ZeroMemory(s); s.comparison=comparison; s.event_id=id;
   s.state=(ENUM_SRMP_SMT_STATE)(int)v[0]; s.direction=(int)v[1]; s.timeframe=(ENUM_TIMEFRAMES)(int)v[2];
   s.relation=(int)v[3]; s.comparator_extreme=(bool)v[4]; s.correlation=v[5]; s.correlation_pairs=(int)v[6];
   s.primary_pivot_time=(datetime)v[7]; s.primary_prior_time=(datetime)v[8]; s.comparison_pivot_time=(datetime)v[9];
   s.comparison_prior_time=(datetime)v[10]; s.pivot_confirmation_time=(datetime)v[11]; s.confirmation_time=(datetime)v[12];
   s.primary_prior=v[13]; s.primary_recent=v[14]; s.comparison_prior=v[15]; s.comparison_recent=v[16];
   e.signal=s; e.life=(ENUM_ICT_SMT_LIFE)(int)v[17]; e.changed_at=(datetime)v[18]; e.seed_context=(bool)v[19];
   string expected=symbol+"|"+comparison+"|"+IntegerToString((int)s.timeframe)+"|"+IntegerToString(s.direction)+"|"+
      IntegerToString(s.relation)+"|"+IntegerToString((long)s.primary_prior_time)+"|"+IntegerToString((long)s.primary_pivot_time)+"|"+
      IntegerToString((long)s.comparison_prior_time)+"|"+IntegerToString((long)s.comparison_pivot_time);
   return id==expected && s.timeframe!=PERIOD_CURRENT && PeriodSeconds(s.timeframe)>0 &&
      s.state==(s.direction>0 ? SRMP_SMT_BULLISH : SRMP_SMT_BEARISH) &&
      s.primary_prior_time>0 && s.primary_prior_time<s.primary_pivot_time && s.comparison_prior_time>0 &&
      s.comparison_prior_time<s.comparison_pivot_time && s.primary_prior>0 && s.primary_recent>0 && s.comparison_prior>0 && s.comparison_recent>0 &&
      s.pivot_confirmation_time>=ICTBarClose(s.timeframe,s.primary_pivot_time) &&
      s.pivot_confirmation_time>=ICTBarClose(s.timeframe,s.comparison_pivot_time) &&
      s.confirmation_time>=s.pivot_confirmation_time && s.confirmation_time<=asof &&
      e.changed_at>=s.confirmation_time && e.changed_at<=asof;
  }

bool ICTValidUnifiedConfig(const SICTUnifiedConfig &c)
  {
   return c.frames.status!=ICT_MTF_INVALID && c.frames.ltf!=PERIOD_CURRENT &&
      c.chart_tf!=PERIOD_CURRENT && PeriodSeconds(c.chart_tf)>0 &&
      c.structure_lookback>=40 && c.structure_lookback<=1000 && c.ob_lookback>=40 && c.ob_lookback<=1000 &&
      ICTValidDynamicSMTConfig(c.smt) && ICTValidStrongOBConfig(c.ob);
  }

string ICTUnifiedSignature(const string symbol,const SICTUnifiedConfig &c)
  {
   string signature=symbol+"|"+c.smt.manual1+"|"+c.smt.manual2+"|"+c.smt.pair_map;
   int values[]={(int)c.frames.ltf,(int)c.frames.mtf,(int)c.frames.htf,(int)c.frames.mode,(int)c.frames.status,
      (int)c.smt.mode,(int)c.smt.manual_tf,(int)c.smt.slot1,(int)c.smt.slot2,(int)c.smt.relation,(int)c.smt.relation1,(int)c.smt.relation2,
      c.smt.display_bars,c.smt.detection_bars,c.smt.left,c.smt.right,c.smt.max_gap,c.smt.correlation_window,
      c.structure_lookback,c.ob_lookback,(int)c.enable_ob,(int)c.enable_smt,(int)c.ob_multi,(int)c.ob_show_higher,
      c.ob.max_group,c.ob.confirmation_bars,c.ob.left,c.ob.right,c.ob.expiry_bars,(int)c.ob.bounds,
      (int)c.ob.require_fvg,(int)c.ob.invalidate_on_close,(int)c.ob.allow_continuation,
      c.ob.weight_sweep,c.ob.weight_displacement,c.ob.weight_structure,c.ob.weight_fvg,c.ob.weight_bias,c.ob.weight_pd,c.ob.weight_freshness,
      c.ob.strong_threshold,c.ob.moderate_threshold,c.ob.touch_penalty};
   for(int i=0;i<ArraySize(values);i++) signature+="|"+IntegerToString(values[i]);
   if(c.chart_tf!=c.frames.ltf) signature+="|chart="+IntegerToString((int)c.chart_tf);
   double thresholds[]={c.smt.correlation_threshold,c.smt.tolerance_ticks,c.ob.displacement_atr,c.ob.body_ratio,
      c.ob.max_overlap,c.ob.fvg_atr,c.ob.tolerance_ticks,c.ob.mitigation_fraction};
   for(int i=0;i<ArraySize(thresholds);i++) signature+="|"+DoubleToString(thresholds[i],16);
   return signature;
  }
bool ICTUnifiedSMTAligned(const SICTUnifiedSnapshot &s,const int direction)
  {
   bool same=false,opposite=false;
   if(!s.valid || (direction!=1 && direction!=-1)) return false;
   for(int layer=0;layer<s.layer_count;layer++)
      for(int comp=0;comp<2;comp++)
        {
         SICTSMTPeerSnapshot peer=s.layers[layer].peers[comp];
         string configured=(comp==0 ? s.comparison1 : s.comparison2);
         if(peer.comparison=="" || peer.comparison!=configured || !peer.ready || !peer.relation_known ||
            peer.last_close!=s.layers[layer].last_close || peer.last_close>s.asof) continue;
         if(peer.conflict) opposite=true;
         int bias=(peer.state==ICT_SMT_PEER_BULLISH ? 1 : peer.state==ICT_SMT_PEER_BEARISH ? -1 : 0);
         if(bias==direction) same=true;
         if(bias==-direction) opposite=true;
        }
   return same && !opposite;
  }
int ICTNearestActiveOB(const SICTUnifiedSnapshot &s,const double price,const int direction=0)
  {
   int best=-1; double distance=DBL_MAX;
   for(int i=0;i<s.ob_count;i++)
     {
      if(!ICTOBActive(s.zones[i]) || !s.zones[i].hard_gates ||
         (direction!=0 && s.zones[i].ob.direction!=direction)) continue;
      double d=(price<s.zones[i].ob.lower ? s.zones[i].ob.lower-price :
                price>s.zones[i].ob.upper ? price-s.zones[i].ob.upper : 0);
       if(s.zones[i].ob.confirmation_time>s.asof) continue;
       if(best<0 || d<distance || (d==distance && s.zones[i].current_context_score>s.zones[best].current_context_score))
        { best=i; distance=d; }
     }
   return best;
  }

// One producer implementation, shared by EA and standalone indicator. History
// is fetched only after a source TF closes (or a bounded retry for missing data).
class CICTUnifiedAnalysis
  {
private:
   SICTUnifiedSnapshot m_state;
   SICTCachedSeries m_series[4];
   string m_signature,m_journal,m_log_keys[];
   datetime m_last_attempt,m_smt_closes[4],m_ob_closes[3];
   bool m_smt_ok[4],m_ob_ok[3],m_history_ok;
   string m_smt_journal;
   bool m_smt_loaded,m_smt_dirty,m_smt_io_ok;
   bool m_smt_disk_present;
   uint m_smt_disk_hash;
   SICTSMTJournalCursor m_smt_cursors[8];

   string SMTJournalIdentity()
     {
      return m_signature+"|"+AccountInfoString(ACCOUNT_SERVER)+"|"+IntegerToString((long)MQLInfoInteger(MQL_TESTER));
     }

   bool SMTPayloadTextWrite(const int f,const string value)
     {
      int length=StringLen(value);
      return length<=4096 && FileWriteInteger(f,length)==4 && (length==0 || FileWriteString(f,value,length)==(uint)(length*2));
     }
   string SMTPayloadTextRead(const int f,const ulong end,bool &ok)
     {
      if(!ok || FileTell(f)+4>end) { ok=false; return ""; }
      int length=FileReadInteger(f);
      if(length<0 || length>4096 || FileTell(f)+(ulong)(length*2)>end) { ok=false; return ""; }
      string value=(length>0 ? FileReadString(f,length) : ""); if(StringLen(value)!=length) ok=false; return value;
     }
   uint SMTPayloadHash(const uchar &bytes[])
     {
      uint hash=2166136261;
      for(int i=0;i<ArraySize(bytes);i++) hash=(hash^(uint)bytes[i])*16777619;
      return hash;
     }
   bool SMTPayloadDigest(const string path,uint &digest)
     {
      int f=FileOpen(path,FILE_READ|FILE_BIN|FILE_SHARE_READ);
      if(f==INVALID_HANDLE) return false;
      ulong size=FileSize(f); bool ok=size>=24 && size<=ICT_SMT_PAYLOAD_MAX_BYTES; uchar bytes[];
      if(ok) { ArrayResize(bytes,(int)size-4); ok=FileReadArray(f,bytes,0,ArraySize(bytes))==(uint)ArraySize(bytes); }
      if(ok) { digest=(uint)FileReadInteger(f); ok=digest==SMTPayloadHash(bytes); }
      FileClose(f); return ok;
     }
   datetime SMTRetainFrom(const ENUM_TIMEFRAMES tf,const SICTUnifiedConfig &c)
     {
      datetime start=m_state.display_start;
      int shift=iBarShift(m_state.symbol,tf,m_state.asof-1,false);
      if(shift<0) return 0;
      datetime opened=iTime(m_state.symbol,tf,shift);
      if(ICTBarClose(tf,opened)>m_state.asof) shift++;
      datetime detection=iTime(m_state.symbol,tf,shift+c.smt.detection_bars-1);
      if(start<=0 || detection<=0) return 0; // Insufficient timestamps cannot authorize deletion.
      return (datetime)MathMin(start,detection);
     }
   void PruneSMTHistory(const SICTUnifiedConfig &c)
     {
      for(int i=m_state.event_count-1;i>=0;i--)
        {
         datetime oldest=SMTRetainFrom(m_state.events[i].signal.timeframe,c);
         if(oldest<=0 || m_state.events[i].signal.confirmation_time>=oldest) continue;
         for(int j=i+1;j<m_state.event_count;j++) m_state.events[j-1]=m_state.events[j];
         m_state.event_count--; m_smt_dirty=true;
        }
     }
   bool LoadSMTHistory(const SICTUnifiedConfig &c)
     {
      if(m_smt_loaded) return m_smt_io_ok;
      m_smt_loaded=true;
      // Intentionally new format. The legacy key-only CSV cannot recover a
      // confirmation payload and is never treated as a payload journal.
      string identity=SMTJournalIdentity();
      // Logical settings identity survives a terminal restart/new ChartID.
      m_smt_journal="ICT_smt_payload_v1_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+
         IntegerToString((long)ICTStableHash(identity))+".bin";
      if(!FileIsExist(m_smt_journal)) { m_smt_dirty=true; return true; }
      int f=FileOpen(m_smt_journal,FILE_READ|FILE_BIN|FILE_UNICODE|FILE_SHARE_READ);
      if(f==INVALID_HANDLE) return false;
      ulong size=FileSize(f); bool ok=size>=24 && size<=ICT_SMT_PAYLOAD_MAX_BYTES;
      uchar bytes[];
      if(ok) { ArrayResize(bytes,(int)size-4); ok=FileReadArray(f,bytes,0,ArraySize(bytes))==(uint)ArraySize(bytes); }
      uint digest=0;
      if(ok) { digest=(uint)FileReadInteger(f); ok=SMTPayloadHash(bytes)==digest; }
      if(!ok) { FileClose(f); return false; }
      ulong end=size-4;
      if(!FileSeek(f,0,SEEK_SET)) { FileClose(f); return false; }
      int magic=FileReadInteger(f),version=FileReadInteger(f),fields=FileReadInteger(f),count=FileReadInteger(f);
      if(magic!=ICT_SMT_PAYLOAD_MAGIC || (version!=1 && version!=ICT_SMT_PAYLOAD_VERSION) || fields!=ICT_SMT_PAYLOAD_FIELDS || count<0 || count>ICT_SMART_SMT_MAX) ok=false;
      string signature=SMTPayloadTextRead(f,end,ok); if(signature!=identity) ok=false;
      double saved=FileReadDouble(f);
      if(!MathIsValidNumber(saved) || saved<=0 || saved>(double)m_state.asof || (double)(datetime)saved!=saved) ok=false;
      SICTSMTJournalCursor cursors[8]; ENUM_TIMEFRAMES frames[];
      ICTSMTTimeframes(c.frames,c.smt.mode,c.smt.manual_tf,frames,c.chart_tf);
      int stored_cursors=(version==1 ? 6 : 8);
      bool migrated=(version==1);
      for(int i=0;i<stored_cursors && ok;i++)
        {
         cursors[i].comparison=SMTPayloadTextRead(f,end,ok);
         double tf=FileReadDouble(f),through=FileReadDouble(f);
         if(!MathIsValidNumber(tf) || !MathIsValidNumber(through) || tf!=(double)(int)tf || through!=(double)(datetime)through || through<0 || through>saved) ok=false;
         cursors[i].timeframe=(ENUM_TIMEFRAMES)(int)tf; cursors[i].through=(datetime)through;
         ENUM_TIMEFRAMES mapped=(i/2<ArraySize(frames) ? frames[i/2] : PERIOD_CURRENT);
         if(!ICTNormalizeSMTJournalCursor(mapped,(datetime)saved,cursors[i])) ok=false;
         if(cursors[i].comparison=="" && (tf!=0 || through!=0)) migrated=true;
        }
      for(int i=stored_cursors;i<8;i++) ZeroMemory(cursors[i]);
      SICTSMTEvent restored[]; if(ok) ArrayResize(restored,count);
      for(int i=0;i<count && ok;i++)
        {
         string comparison=SMTPayloadTextRead(f,end,ok),id=SMTPayloadTextRead(f,end,ok); double values[]; ArrayResize(values,ICT_SMT_PAYLOAD_FIELDS);
         if(!ok || FileTell(f)+(ulong)(ICT_SMT_PAYLOAD_FIELDS*8)>end || FileReadArray(f,values,0,ICT_SMT_PAYLOAD_FIELDS)!=(uint)ICT_SMT_PAYLOAD_FIELDS ||
            !ICTUnpackSMTPayload(m_state.symbol,comparison,id,values,(datetime)saved,restored[i])) { ok=false; break; }
         bool mapped=false; for(int j=0;j<ArraySize(frames);j++) if(restored[i].signal.timeframe==frames[j]) mapped=true;
         if(!mapped) ok=false;
         for(int j=0;j<i;j++) if(restored[j].signal.event_id==id) ok=false;
        }
      if(FileTell(f)!=end) ok=false; FileClose(f);
      if(!ok) return false; // Restore is all-or-nothing; never salvage a corrupt prefix.
      for(int i=0;i<8;i++) m_smt_cursors[i]=cursors[i];
      m_smt_disk_present=true; m_smt_disk_hash=digest;
      m_state.event_count=count; for(int i=0;i<count;i++) m_state.events[i]=restored[i];
      if(migrated) m_smt_dirty=true; // Rewrite verified legacy cursors/payload atomically on the next save.
      PruneSMTHistory(c); return true;
     }
   bool SaveSMTHistory(const SICTUnifiedConfig &c)
     {
      if(!m_smt_io_ok || !m_smt_loaded) return false;
      if(!m_smt_dirty) return true;
      ENUM_TIMEFRAMES frames[];
      ICTSMTTimeframes(c.frames,c.smt.mode,c.smt.manual_tf,frames,c.chart_tf);
      for(int i=0;i<8;i++)
        {
         ENUM_TIMEFRAMES mapped=(i/2<ArraySize(frames) ? frames[i/2] : PERIOD_CURRENT);
         if(!ICTNormalizeSMTJournalCursor(mapped,m_state.asof,m_smt_cursors[i])) return false;
        }
      string pending=m_smt_journal+".pending_"+IntegerToString((long)GetMicrosecondCount());
      int f=FileOpen(pending,FILE_WRITE|FILE_BIN|FILE_UNICODE);
      if(f==INVALID_HANDLE) return false;
      bool ok=FileWriteInteger(f,ICT_SMT_PAYLOAD_MAGIC)==4 && FileWriteInteger(f,ICT_SMT_PAYLOAD_VERSION)==4 &&
         FileWriteInteger(f,ICT_SMT_PAYLOAD_FIELDS)==4 && FileWriteInteger(f,m_state.event_count)==4 &&
         SMTPayloadTextWrite(f,SMTJournalIdentity()) && FileWriteDouble(f,(double)m_state.asof)==8;
      for(int i=0;i<8 && ok;i++) ok=SMTPayloadTextWrite(f,m_smt_cursors[i].comparison) &&
         FileWriteDouble(f,(double)m_smt_cursors[i].timeframe)==8 && FileWriteDouble(f,(double)m_smt_cursors[i].through)==8;
      for(int i=0;i<m_state.event_count && ok;i++)
        {
         SICTSMTEvent e=m_state.events[i]; double values[]; ICTPackSMTPayload(e,values);
         SICTSMTEvent checked;
         ok=ICTUnpackSMTPayload(m_state.symbol,e.signal.comparison,e.signal.event_id,values,m_state.asof,checked) &&
            SMTPayloadTextWrite(f,e.signal.comparison) && SMTPayloadTextWrite(f,e.signal.event_id) &&
            FileWriteArray(f,values,0,ArraySize(values))==(uint)ArraySize(values);
        }
      ResetLastError(); FileFlush(f); if(GetLastError()!=0) ok=false; FileClose(f);
      if(!ok) { FileDelete(pending); return false; }
      f=FileOpen(pending,FILE_READ|FILE_WRITE|FILE_BIN);
      if(f==INVALID_HANDLE) { FileDelete(pending); return false; }
      ulong size=FileSize(f); uchar bytes[];
      ok=size>=24 && size+4<=ICT_SMT_PAYLOAD_MAX_BYTES;
      if(ok) { ArrayResize(bytes,(int)size); ok=FileReadArray(f,bytes,0,ArraySize(bytes))==(uint)ArraySize(bytes); }
      uint digest=0;
      if(ok) { digest=SMTPayloadHash(bytes); ok=FileWriteInteger(f,(int)digest)==4; }
      ResetLastError(); FileFlush(f); if(GetLastError()!=0) ok=false; FileClose(f);
      if(!ok) { FileDelete(pending); return false; }
      int guard=FileOpen(m_smt_journal+".lock",FILE_READ|FILE_WRITE|FILE_BIN);
      if(guard==INVALID_HANDLE) { FileDelete(pending); return false; }
      uint current=0;
      bool unchanged=(m_smt_disk_present ? FileIsExist(m_smt_journal) && SMTPayloadDigest(m_smt_journal,current) && current==m_smt_disk_hash : !FileIsExist(m_smt_journal));
      bool committed=unchanged && FileMove(pending,0,m_smt_journal,FILE_REWRITE); FileClose(guard);
      if(!committed) { FileDelete(pending); return false; }
      m_smt_disk_present=true; m_smt_disk_hash=digest;
      m_smt_dirty=false; return true;
     }

   bool Journal(const string key,const string kind,const ENUM_TIMEFRAMES tf,const int direction,
                 const datetime formation,const datetime confirmation,const int state,
                 const datetime changed,const double lower,const double upper,const int score)
     {
      for(int i=0;i<ArraySize(m_log_keys);i++) if(m_log_keys[i]==key) return true;
      int f=FileOpen(m_journal,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(f==INVALID_HANDLE) { m_history_ok=false; return false; }
      FileSeek(f,0,SEEK_END);
      bool ok=FileWrite(f,key,kind,m_state.symbol,(int)tf,direction,(long)formation,(long)confirmation,state,
                         (long)changed,lower,upper,score)>0;
      FileFlush(f); FileClose(f);
      if(ok) { int n=ArraySize(m_log_keys); ArrayResize(m_log_keys,n+1); m_log_keys[n]=key; }
      else m_history_ok=false;
      return ok;
     }
   void OpenJournal()
     {
      ArrayResize(m_log_keys,0); m_history_ok=true;
      m_journal="ICT_unified_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+
         IntegerToString(ChartID())+"_"+IntegerToString((long)ICTStableHash(m_signature))+".csv";
      if(!FileIsExist(m_journal)) return;
      int f=FileOpen(m_journal,FILE_READ|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(f==INVALID_HANDLE) { m_history_ok=false; return; }
      while(!FileIsEnding(f))
        {
         string key=FileReadString(f);
         while(!FileIsEnding(f) && !FileIsLineEnding(f)) FileReadString(f);
         if(key!="") { int n=ArraySize(m_log_keys); ArrayResize(m_log_keys,n+1); m_log_keys[n]=key; }
        }
      FileClose(f);
     }
   int Series(const string symbol,const ENUM_TIMEFRAMES tf,const datetime asof,const int needed)
     {
      if(tf==PERIOD_CURRENT) return -1;
      int slot=-1;
      for(int i=0;i<4;i++) if(m_series[i].timeframe==tf) { slot=i; break; }
      if(slot<0) for(int i=0;i<4;i++) if(m_series[i].timeframe==PERIOD_CURRENT) { slot=i; m_series[i].timeframe=tf; break; }
      if(slot<0) return -1;
      int shift=iBarShift(symbol,tf,asof-1,false);
      datetime opened=(shift>=0 ? iTime(symbol,tf,shift) : 0);
      if(opened>0 && ICTBarClose(tf,opened)>asof) opened=iTime(symbol,tf,shift+1);
      if(opened>0 && m_series[slot].ready && opened==m_series[slot].last_open && ArraySize(m_series[slot].bars)>=needed) return slot;
      MqlRates fetched[];
       int fetch_needed=(int)MathMax(needed,ArraySize(m_series[slot].bars));
       // Request the missing series even when iBarShift has no local index yet.
       // Keep the full closed-bar requirement; never pad or invent history.
       if(!ICTCopyClosedAsOf(symbol,tf,asof,fetch_needed,fetched)) return -1;
       ArrayResize(m_series[slot].bars,ArraySize(fetched));
       if(ArrayCopy(m_series[slot].bars,fetched)!=ArraySize(fetched)) { m_series[slot].ready=false; return -1; }
       m_series[slot].ready=true;
      m_series[slot].last_open=fetched[ArraySize(fetched)-1].time; return slot;
     }
   void MergeSMT(const SICTSMTEvent &e,const datetime seen_through,const datetime retain_from)
     {
      for(int i=0;i<m_state.event_count;i++) if(m_state.events[i].signal.event_id==e.signal.event_id) return;
       // A restored ID always wins, including its original seed flag. Unknown
       // first-prefix context and already processed history cannot be backfilled
       // with a new first-qualification time after a sliding-window restart.
       if(e.seed_context || e.signal.confirmation_time<=seen_through ||
          (retain_from>0 && e.signal.confirmation_time<retain_from)) return;
      if(m_state.event_count>=ICT_SMART_SMT_MAX)
        { m_state.capacity_ok=false; m_state.reason="SMT event capacity reached; no candidate until history is reviewed"; return; }
      m_state.events[m_state.event_count++]=e;
       m_smt_dirty=true;
      Journal(e.signal.event_id+"|1|"+IntegerToString((long)e.signal.confirmation_time),"SMT",e.signal.timeframe,
         e.signal.direction,e.signal.primary_pivot_time,e.signal.confirmation_time,1,e.signal.confirmation_time,
         e.signal.primary_prior,e.signal.primary_recent,0);
     }
   void MergeOB(const SICTStrongOrderBlock &z)
     {
      for(int i=0;i<m_state.ob_count;i++) if(m_state.zones[i].id==z.id) return;
      if(m_state.ob_count>=ICT_SMART_OB_MAX)
        { m_state.capacity_ok=false; m_state.reason="OB capacity reached; no candidate until history is reviewed"; return; }
      m_state.zones[m_state.ob_count++]=z;
      Journal(z.id+"|CONFIRM", "OB",z.timeframe,z.ob.direction,z.ob.formation_time,z.ob.confirmation_time,1,
         z.ob.confirmation_time,z.ob.lower,z.ob.upper,z.confirmation_score);
     }
   void PruneJournaled(const datetime oldest)
     {
      if(!m_history_ok) return;
      for(int i=m_state.ob_count-1;i>=0;i--)
         if(!ICTOBActive(m_state.zones[i]) && m_state.zones[i].ob.state_time<oldest)
           { for(int j=i+1;j<m_state.ob_count;j++) m_state.zones[j-1]=m_state.zones[j]; m_state.ob_count--; }
     }
public:
   CICTUnifiedAnalysis() { Reset(); }
   void Reset()
     {
      ZeroMemory(m_state); m_state.schema=ICT_UNIFIED_SCHEMA;
      m_signature=""; m_last_attempt=0; m_history_ok=true;
       m_smt_journal=""; m_smt_loaded=false; m_smt_dirty=false; m_smt_io_ok=true;
       m_smt_disk_present=false; m_smt_disk_hash=0;
       for(int i=0;i<8;i++) ZeroMemory(m_smt_cursors[i]);
      ArrayResize(m_log_keys,0);
      for(int i=0;i<4;i++) { m_series[i].timeframe=PERIOD_CURRENT; m_series[i].ready=false; m_series[i].last_open=0; ArrayResize(m_series[i].bars,0); }
      for(int i=0;i<4;i++) { m_smt_closes[i]=0; m_smt_ok[i]=false; }
      for(int i=0;i<3;i++) { m_ob_closes[i]=0; m_ob_ok[i]=false; }
     }
   void Snapshot(SICTUnifiedSnapshot &out) { out=m_state; }
   bool Update(const string symbol,const SICTUnifiedConfig &c)
     {
      if(!ICTValidUnifiedConfig(c)) { m_state.valid=false; m_state.reason="Invalid unified settings"; return false; }
      string signature=ICTUnifiedSignature(symbol,c);
      if(signature!=m_signature) { Reset(); m_signature=signature; m_state.symbol=symbol; OpenJournal(); }
      m_state.frames=c.frames; m_state.chart_tf=c.chart_tf;
      m_state.tiers[0].timeframe=c.frames.ltf;
      m_state.tiers[1].timeframe=c.frames.mtf;
      m_state.tiers[2].timeframe=c.frames.htf;
      datetime asof=ICTBarClose(c.frames.ltf,iTime(symbol,c.frames.ltf,1));
      if(asof<=0 || asof>TimeCurrent()) { m_state.valid=false; m_state.reason="INSUFFICIENT_DATA: no closed chart candle"; return false; }
       if(m_state.asof>asof) { Reset(); m_signature=signature; m_state.symbol=symbol; OpenJournal(); }
       string comparison1,comparison2,comparator_reason;
       ICTResolveSMTComparators(symbol,c.smt,comparison1,comparison2,comparator_reason);
       bool comparators_changed=comparison1!=m_state.comparison1 || comparison2!=m_state.comparison2;
       bool retry_pending=false;
       for(int layer=0;layer<m_state.layer_count;layer++) if(!m_smt_ok[layer]) retry_pending=true;
       if(m_state.asof==asof && !comparators_changed && ((m_state.valid && !retry_pending) || TimeLocal()-m_last_attempt<5)) return m_state.valid;
      m_last_attempt=TimeLocal(); m_state.asof=asof; m_state.frames=c.frames; m_state.chart_tf=c.chart_tf; m_state.valid=true; m_state.revision++;
       ZeroMemory(m_state.signal); // The decision adapter/EA fills the single committed result.
      m_state.detection_bars=c.smt.detection_bars; m_state.display_bars=c.smt.display_bars;
      m_state.capacity_ok=true; m_state.reason="Closed as-of shared snapshot";
       int chart_shift=iBarShift(symbol,c.chart_tf,asof-1,false);
       if(chart_shift>=0 && ICTBarClose(c.chart_tf,iTime(symbol,c.chart_tf,chart_shift))>asof) chart_shift++;
       datetime start=(chart_shift>=0 ? ICTBarClose(c.chart_tf,iTime(symbol,c.chart_tf,chart_shift+c.smt.display_bars-1)) : 0);
      m_state.display_start=start;
      if(start<=0) { m_state.valid=false; m_state.reason="INSUFFICIENT_DATA: chart display window history missing"; }
       m_state.comparison1=comparison1; m_state.comparison2=comparison2; m_state.comparator_reason=comparator_reason;
      int needed=c.structure_lookback;
      ENUM_TIMEFRAMES tier_tf[3]; tier_tf[0]=c.frames.ltf; tier_tf[1]=c.frames.mtf; tier_tf[2]=c.frames.htf;
      int indexes[3];
      for(int i=0;i<3;i++)
        {
         ZeroMemory(m_state.tiers[i]); m_state.tiers[i].timeframe=tier_tf[i]; indexes[i]=-1;
         if(tier_tf[i]==PERIOD_CURRENT) { m_state.tiers[i].reason="N/A: reduced-tier mapping"; continue; }
         int slot=Series(symbol,tier_tf[i],asof,needed); indexes[i]=slot;
         MqlRates context[];
         if(slot>=0) ArrayCopy(context,m_series[slot].bars,0,ArraySize(m_series[slot].bars)-needed,needed);
         if(slot<0)
           {
            m_state.valid=false;
            m_state.tiers[i].reason="INSUFFICIENT_DATA: waiting for closed history ("+IntegerToString(needed)+" bars)";
            continue;
           }
         if(!SRMPAnalyzeStructureFromRates(context,ArraySize(context),c.ob.left,c.ob.right,m_state.tiers[i].structure))
           { m_state.valid=false; m_state.tiers[i].reason="INSUFFICIENT_DATA: confirmed swings missing"; continue; }
         SMarketStructure structure=m_state.tiers[i].structure;
         m_state.tiers[i].closed_at=ICTBarClose(tier_tf[i],structure.latest_closed_bar);
         m_state.tiers[i].status=(structure.bias>0 ? ICT_CONTEXT_BULLISH : structure.bias<0 ? ICT_CONTEXT_BEARISH : ICT_CONTEXT_NEUTRAL);
         m_state.tiers[i].reason="Confirmed swings; close "+TimeToString(m_state.tiers[i].closed_at,TIME_DATE|TIME_MINUTES);
         double tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
         double atr=ICTPriorATR(context,ArraySize(context));
          m_state.tiers[i].last_bar=context[ArraySize(context)-1];
          MqlRates last=m_state.tiers[i].last_bar;
          double range=last.high-last.low,body=last.close-last.open;
          bool displaced=atr>0 && range>0 && MathAbs(body)>=atr*c.ob.displacement_atr && MathAbs(body)/range>=c.ob.body_ratio;
          m_state.tiers[i].displacement_up=displaced && body>0;
          m_state.tiers[i].displacement_down=displaced && body<0;
         if(tick_size>0)
           {
            m_state.tiers[i].fvg_ready=SRMPFindFVGFromRates(context,ArraySize(context),MathMax(tick_size,c.ob.fvg_atr*atr),m_state.tiers[i].gap);
            m_state.tiers[i].bpr_ready=ICTFindBPRFromRates(symbol,tier_tf[i],context,ArraySize(context),tick_size,tick_size,m_state.tiers[i].bpr) &&
                                        m_state.tiers[i].bpr.state==ICT_BPR_CONFIRMED;
           }
        }
      int upper=(c.frames.htf!=PERIOD_CURRENT ? 2 : c.frames.mtf!=PERIOD_CURRENT ? 1 : 0);
      int bias=m_state.tiers[upper].structure.bias;
      int intermediate=(upper==2 ? 1 : 0);
      SMarketStructure ms=m_state.tiers[intermediate].structure;
      m_state.mtf_state=(!m_state.valid ? ICT_STRUCTURE_INSUFFICIENT : ms.bias==0 ?
         (ms.bos_direction!=0 ? ICT_STRUCTURE_TRANSITION : ICT_STRUCTURE_NEUTRAL) :
         (bias!=0 && ms.bias==bias ? ICT_STRUCTURE_ALIGNED : ICT_STRUCTURE_COUNTER));
       // Restore SMT only after collecting independent market context. A
       // damaged journal must block decisions without blanking valid tiers.
       string smt_history_reason="";
       bool smt_history_ready=c.enable_smt;
       if(c.enable_smt && (!m_smt_io_ok || !LoadSMTHistory(c)))
         {
          m_smt_io_ok=false; m_state.valid=false; smt_history_ready=false;
          smt_history_reason="SMT payload journal corrupt/unavailable: frozen confirmation history cannot be restored";
         }
       if(smt_history_ready) PruneSMTHistory(c);
      double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      if(tick<=0) { m_state.valid=false; m_state.reason="INSUFFICIENT_DATA: symbol tick size missing"; return false; }
      ENUM_TIMEFRAMES smt_frames[]; m_state.layer_count=(smt_history_ready ? ICTSMTTimeframes(c.frames,c.smt.mode,c.smt.manual_tf,smt_frames,c.chart_tf) : 0);
      for(int layer=0;layer<m_state.layer_count;layer++)
        {
         ENUM_TIMEFRAMES tf=smt_frames[layer];
          bool automatic_relation=ICTSMTPeerRelation(c.smt,0)==SMT_AUTO || ICTSMTPeerRelation(c.smt,1)==SMT_AUTO;
          int smt_needed=c.smt.detection_bars+(automatic_relation ? c.smt.correlation_window*2 : 61)+c.smt.left+c.smt.right+10;
         int slot=Series(symbol,tf,asof,smt_needed);
         m_state.layers[layer].timeframe=tf;
          if(slot<0)
            {
             m_smt_ok[layer]=false; m_state.layers[layer].ready=false; m_state.layers[layer].relation_known=false;
             m_state.layers[layer].reason="INSUFFICIENT_DATA";
             ICTResetSMTPeer(m_state.comparison1,"INSUFFICIENT_DATA: primary history",m_state.layers[layer].peers[0]);
             ICTResetSMTPeer(m_state.comparison2,"INSUFFICIENT_DATA: primary history",m_state.layers[layer].peers[1]);
             continue;
            }
          // A tier cache may hold a longer OB window. Replay always receives the
          // same bounded SMT prefix, independently of cache/consumer call order.
          MqlRates primary[];
          ArrayCopy(primary,m_series[slot].bars,0,ArraySize(m_series[slot].bars)-smt_needed,smt_needed);
          int an=ArraySize(primary); datetime closed=ICTBarClose(tf,primary[an-1].time);
         m_state.layers[layer].last_close=closed;
          m_state.layers[layer].window_start=primary[(int)MathMax(0,an-c.smt.detection_bars)].time;
          bool all_ready=true,any_ready=false,known=false,configured=false;
          for(int comp=0;comp<2;comp++)
           {
             string other=(comp==0 ? m_state.comparison1 : m_state.comparison2);
             bool enabled=(comp==0 ? c.smt.slot1!=SMT_SLOT_DISABLED : c.smt.slot2!=SMT_SLOT_DISABLED);
             if(!enabled || other=="")
              {
                ICTResetSMTPeer(other,enabled ? "N/A: comparator unavailable" : "DISABLED",m_state.layers[layer].peers[comp]);
                if(enabled) all_ready=false;
                continue;
               }
             configured=true;
             SICTSMTPeerSnapshot peer=m_state.layers[layer].peers[comp];
             if(peer.comparison!=other || !peer.ready || peer.last_close!=closed)
               {
                ICTResetSMTPeer(other,"INSUFFICIENT_DATA: comparator history",peer);
               MqlRates comparison[];
                if(!ICTCopyClosedAsOf(other,tf,closed,smt_needed,comparison))
                  { m_state.layers[layer].peers[comp]=peer; all_ready=false; continue; }
               double other_tick=SymbolInfoDouble(other,SYMBOL_TRADE_TICK_SIZE);
                int bn=ArraySize(comparison);
                if(other_tick<=0 || bn<60 || comparison[bn-1].time!=primary[an-1].time)
                  {
                   peer.reason=other_tick<=0 ? "INSUFFICIENT_DATA: comparator tick size" : "INSUFFICIENT_DATA: timestamps not aligned";
                   m_state.layers[layer].peers[comp]=peer; all_ready=false; continue;
                  }
                SICTDynamicSMTConfig peer_config=c.smt; peer_config.relation=ICTSMTPeerRelation(c.smt,comp);
                 int cursor=layer*2+comp;
                 if(m_smt_cursors[cursor].comparison!=other || m_smt_cursors[cursor].timeframe!=tf)
                   {
                    m_smt_cursors[cursor].comparison=other; m_smt_cursors[cursor].timeframe=tf;
                    m_smt_cursors[cursor].through=0; m_smt_dirty=true;
                   }
               SICTSMTEvent found[]; bool related=false;
                ICTReplaySMT(symbol,other,tf,primary,an,comparison,bn,tick,other_tick,peer_config,found,related);
                 datetime retained=SMTRetainFrom(tf,c);
                 for(int e=0;e<ArraySize(found);e++) MergeSMT(found[e],m_smt_cursors[cursor].through,retained);
                 if(m_state.capacity_ok && m_smt_cursors[cursor].through!=closed)
                   { m_smt_cursors[cursor].through=closed; m_smt_dirty=true; }
                double rho=0; int pairs=0;
                peer.relation=ICTSMTRelationFromRates(primary,an,comparison,bn,peer_config,rho,pairs);
                peer.ready=true; peer.last_close=closed; peer.relation_known=peer.relation!=0;
                peer.reason=peer.relation_known ? "CONFIRMED PIVOT REPLAY" : "RELATION_UNKNOWN";
              }
             m_state.layers[layer].peers[comp]=peer;
             any_ready=any_ready || peer.ready; known=known || peer.relation_known;
           }
          m_smt_closes[layer]=closed; m_smt_ok[layer]=all_ready;
          m_state.layers[layer].ready=any_ready; m_state.layers[layer].relation_known=known;
          m_state.layers[layer].reason=(!configured ? "NO COMPARATOR" : !all_ready ? "PARTIAL: unavailable peer; available peer retained" :
             !known ? "RELATION_UNKNOWN" : "CONFIRMED PIVOT REPLAY");
         for(int e=0;e<m_state.event_count;e++)
           {
            if(m_state.events[e].signal.timeframe!=tf) continue;
             ENUM_ICT_SMT_LIFE previous_life=m_state.events[e].life;
            for(int k=0;k<an;k++)
              {
                datetime expired=(k>=c.smt.detection_bars ? primary[k-c.smt.detection_bars+1].time : 0);
                ICTAdvanceSMT(primary[k],ICTBarClose(tf,primary[k].time),tick*c.smt.tolerance_ticks,expired,m_state.events[e]);
              }
             if(m_state.events[e].life!=previous_life) m_smt_dirty=true;
            SICTSMTEvent event=m_state.events[e];
            Journal(event.signal.event_id+"|"+IntegerToString((int)event.life)+"|"+IntegerToString((long)event.changed_at),"SMT",tf,event.signal.direction,
               event.signal.primary_pivot_time,event.signal.confirmation_time,(int)event.life,event.changed_at,event.signal.primary_prior,event.signal.primary_recent,0);
           }
          for(int comp=0;comp<2;comp++)
             ICTSummarizeSMTPeer(m_state.events,m_state.event_count,tf,asof,m_state.layers[layer].window_start,m_state.layers[layer].peers[comp]);
        }
      for(int tier=0;tier<3;tier++)
        {
         if(!c.enable_ob || indexes[tier]<0 || (tier>0 && !c.ob_multi) || (tier==2 && !c.ob_show_higher)) continue;
         ENUM_TIMEFRAMES tf=tier_tf[tier];
          int ob_needed=c.ob_lookback+c.ob.max_group+c.ob.left+c.ob.right+35;
          int extended=Series(symbol,tf,asof,ob_needed);
         int slot=(extended>=0 ? extended : indexes[tier]);
          MqlRates ob_rates[]; int available=ArraySize(m_series[slot].bars);
          int n=(int)MathMin(ob_needed,available);
          ArrayCopy(ob_rates,m_series[slot].bars,0,available-n,n);
          datetime closed=ICTBarClose(tf,ob_rates[n-1].time);
         int hs=(tier<upper ? indexes[upper] : -1);
         MqlRates higher[]; if(hs>=0) ArrayCopy(higher,m_series[hs].bars);
         if(m_ob_closes[tier]!=closed || !m_ob_ok[tier])
           {
             datetime earliest=ob_rates[(int)MathMax(0,n-c.ob_lookback)].time;
            for(int e=30;e<n;e++)
              {
               SICTStrongOrderBlock zone;
                if(ICTStrongOBAt(symbol,tf,ob_rates,n,e,tick,c.ob,higher,ArraySize(higher),
                    hs>=0 ? tier_tf[upper] : PERIOD_CURRENT,zone,false) && zone.ob.formation_time>=earliest) MergeOB(zone);
              }
            m_ob_closes[tier]=closed; m_ob_ok[tier]=true;
           }
         for(int z=0;z<m_state.ob_count;z++)
           {
            if(m_state.zones[z].timeframe!=tf) continue;
             for(int k=0;k<n;k++) ICTAdvanceStrongOB(ob_rates[k],ICTBarClose(tf,ob_rates[k].time),c.ob,tick*c.ob.tolerance_ticks,m_state.zones[z]);
            SICTStrongOrderBlock zone=m_state.zones[z];
            Journal(zone.id+"|"+IntegerToString((int)zone.life)+"|"+IntegerToString((long)zone.ob.state_time),"OB",tf,zone.ob.direction,
               zone.ob.formation_time,zone.ob.confirmation_time,(int)zone.life,zone.ob.state_time,zone.ob.lower,zone.ob.upper,zone.confirmation_score);
           }
        }
      for(int layer=0;layer<m_state.layer_count;layer++)
        {
         m_state.layers[layer].detected=0; m_state.layers[layer].displayed=0; m_state.layers[layer].bullish=0; m_state.layers[layer].bearish=0;
         for(int e=0;e<m_state.event_count;e++)
           {
            SICTSMTEvent event=m_state.events[e];
            if(event.signal.timeframe!=m_state.layers[layer].timeframe || event.seed_context) continue;
            if(event.signal.confirmation_time>=m_state.layers[layer].window_start && event.signal.confirmation_time<=asof) m_state.layers[layer].detected++;
            if(ICTSMTInsideDisplayWindow(event.signal.confirmation_time,start,asof)) m_state.layers[layer].displayed++;
             bool usable=false;
             for(int comp=0;comp<2;comp++)
                if(ICTSMTPeerEventUsable(event,m_state.layers[layer].timeframe,asof,m_state.layers[layer].window_start,m_state.layers[layer].peers[comp])) usable=true;
             if(!usable) continue;
            if(event.signal.direction>0) m_state.layers[layer].bullish++; else m_state.layers[layer].bearish++;
           }
        }
      datetime oldest=start;
      for(int i=0;i<m_state.layer_count;i++) if(m_state.layers[i].window_start>0) oldest=(datetime)MathMin(oldest,m_state.layers[i].window_start);
      PruneJournaled(oldest);
       if(smt_history_ready) PruneSMTHistory(c);
       if(smt_history_ready && m_state.capacity_ok && !SaveSMTHistory(c))
         {
          m_smt_io_ok=false;
          smt_history_reason="SMT payload journal commit failed: uncommitted history is unavailable";
         }
       if(smt_history_reason!="")
         { m_state.valid=false; m_state.reason=smt_history_reason; return false; }
      if(!m_state.capacity_ok || !m_history_ok) { m_state.valid=false; if(!m_history_ok) m_state.reason="Event journal unavailable; history retention cannot be guaranteed"; }
      else if(!m_state.valid) m_state.reason="INSUFFICIENT_DATA: one or more mapped tiers lack closed confirmed history";
      else if(c.frames.status!=ICT_MTF_FULL) m_state.reason=(c.frames.status==ICT_MTF_TWO_TIER ? "TWO TIER CONTEXT: no HTF; MTF is upper context" : "ONE TIER CONTEXT: advisory entry disabled");
      return m_state.valid;
     }
  };
#endif
