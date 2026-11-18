#ifndef ICT_DYNAMIC_SMT_MQH
#define ICT_DYNAMIC_SMT_MQH
#include "SMTDivergenceDetector.mqh"
#include "ICTTimeframeMapper.mqh"

#define ICT_SMART_SMT_MAX 512
enum ENUM_ICT_SMT_MODE { AUTO_LTF=0, AUTO_MTF=1, AUTO_HTF=2, AUTO_ALL=3, SMT_MANUAL=4 };
enum ENUM_ICT_SMT_SLOT { SMT_SLOT_AUTO=0, SMT_SLOT_MANUAL=1, SMT_SLOT_DISABLED=2 };
enum ENUM_ICT_SMT_LIFE { ICT_SMT_PENDING=0, ICT_SMT_CONFIRMED=1, ICT_SMT_INVALIDATED=2, ICT_SMT_EXPIRED=3 };
enum ENUM_ICT_SMT_PEER_STATE { ICT_SMT_PEER_NA=0, ICT_SMT_PEER_NONE=1,
   ICT_SMT_PEER_BULLISH=2, ICT_SMT_PEER_BEARISH=3 };
struct SICTDynamicSMTConfig
  {
   ENUM_ICT_SMT_MODE mode;
   ENUM_TIMEFRAMES manual_tf;
   ENUM_SMT_CORRELATION relation;
   ENUM_SMT_CORRELATION relation1,relation2; // AUTO inherits the legacy relation setting.
   ENUM_ICT_SMT_SLOT slot1,slot2;
   string manual1,manual2,pair_map;
   int display_bars,detection_bars,left,right,max_gap,correlation_window;
   double correlation_threshold,tolerance_ticks;
   bool show_ltf,show_mtf,show_htf;
  };
struct SICTSMTEvent
  {
   SSMTDivergence signal;
   ENUM_ICT_SMT_LIFE life;
   datetime changed_at;
   bool seed_context;
  };
struct SICTSMTPeerSnapshot
  {
   string comparison,event_id,reason;
   bool ready,relation_known,conflict;
   int relation;
   ENUM_ICT_SMT_PEER_STATE state;
   datetime last_close,primary_pivot_time,comparison_pivot_time,pivot_confirmation_time,confirmation_time;
   double primary_pivot,comparison_pivot;
  };
struct SICTSMTLayer
  {
   ENUM_TIMEFRAMES timeframe;
   bool ready,relation_known;
   int detected,displayed,bullish,bearish;
   datetime last_close,window_start;
   string reason;
   SICTSMTPeerSnapshot peers[2];
  };
void ICTDefaultDynamicSMTConfig(SICTDynamicSMTConfig &c)
  {
   ZeroMemory(c); c.mode=AUTO_ALL; c.manual_tf=PERIOD_H1; c.relation=SMT_AUTO;
   c.slot1=SMT_SLOT_AUTO; c.slot2=SMT_SLOT_AUTO; c.display_bars=60; c.detection_bars=60;
   c.left=2; c.right=2; c.max_gap=3; c.correlation_window=60; c.correlation_threshold=0.60;
   c.tolerance_ticks=1; c.show_ltf=true; c.show_mtf=true; c.show_htf=true;
   c.pair_map="EURUSD:GBPUSD,DXY;GBPUSD:EURUSD,DXY;XAUUSD:XAGUSD,DXY;XAGUSD:XAUUSD,DXY;ES:NQ,YM;NQ:ES,YM";
  }
bool ICTValidDynamicSMTConfig(const SICTDynamicSMTConfig &c)
  {
   return (int)c.mode>=0 && (int)c.mode<=4 && c.manual_tf!=PERIOD_CURRENT && PeriodSeconds(c.manual_tf)>0 &&
      (int)c.slot1>=0 && (int)c.slot1<=2 && (int)c.slot2>=0 && (int)c.slot2<=2 &&
      (c.relation==SMT_AUTO || c.relation==SMT_POSITIVE || c.relation==SMT_NEGATIVE) &&
       (c.relation1==SMT_AUTO || c.relation1==SMT_POSITIVE || c.relation1==SMT_NEGATIVE) &&
       (c.relation2==SMT_AUTO || c.relation2==SMT_POSITIVE || c.relation2==SMT_NEGATIVE) &&
      c.display_bars>=10 && c.display_bars<=500 && c.detection_bars>=60 && c.detection_bars<=500 &&
      c.left>=1 && c.left<=10 && c.right>=1 && c.right<=10 && c.max_gap>=0 && c.max_gap<=20 &&
      c.correlation_window>=60 && c.correlation_window<=200 && MathIsValidNumber(c.correlation_threshold) &&
      c.correlation_threshold>0 && c.correlation_threshold<=1 && MathIsValidNumber(c.tolerance_ticks) && c.tolerance_ticks>=0;
  }
int ICTSMTTimeframes(const SICTTimeframes &map,const ENUM_ICT_SMT_MODE mode,
                     const ENUM_TIMEFRAMES manual,ENUM_TIMEFRAMES &frames[],
                     const ENUM_TIMEFRAMES chart_tf=PERIOD_CURRENT)
  {
   ArrayResize(frames,0);
   ENUM_TIMEFRAMES requested[3]; int n=0;
   if(mode==AUTO_ALL) { requested[0]=map.ltf; requested[1]=map.mtf; requested[2]=map.htf; n=3; }
   else { requested[0]=(mode==AUTO_LTF ? map.ltf : mode==AUTO_MTF ? map.mtf : mode==AUTO_HTF ? map.htf : manual); n=1; }
   for(int i=0;i<n;i++)
     {
      if(requested[i]==PERIOD_CURRENT) continue;
      bool duplicate=false; for(int j=0;j<ArraySize(frames);j++) if(frames[j]==requested[i]) duplicate=true;
      if(!duplicate) { int size=ArraySize(frames); ArrayResize(frames,size+1); frames[size]=requested[i]; }
     }
   // The current chart is a distinct AUTO source when an LTF override differs.
   // MANUAL is the only mode that pins SMT to a single unrelated timeframe.
   if(mode!=SMT_MANUAL && chart_tf!=PERIOD_CURRENT && PeriodSeconds(chart_tf)>0)
     {
      bool present=false; for(int i=0;i<ArraySize(frames);i++) if(frames[i]==chart_tf) present=true;
      if(!present) { int size=ArraySize(frames); ArrayResize(frames,size+1); frames[size]=chart_tf; }
     }
   return ArraySize(frames);
  }
bool ICTSMTInsideDisplayWindow(const datetime confirmation,const datetime start,const datetime asof)
  { return start>0 && confirmation>=start && confirmation<=asof; }

ENUM_SMT_CORRELATION ICTSMTPeerRelation(const SICTDynamicSMTConfig &c,const int peer)
  {
   ENUM_SMT_CORRELATION selected=(peer==0 ? c.relation1 : c.relation2);
   return selected==SMT_AUTO ? c.relation : selected;
  }
string ICTSMTPeerStateText(const ENUM_ICT_SMT_PEER_STATE state)
  {
   if(state==ICT_SMT_PEER_BULLISH) return "BULLISH";
   if(state==ICT_SMT_PEER_BEARISH) return "BEARISH";
   return state==ICT_SMT_PEER_NONE ? "NONE" : "N/A";
  }
void ICTResetSMTPeer(const string comparison,const string reason,SICTSMTPeerSnapshot &peer)
  {
   ZeroMemory(peer); peer.comparison=comparison; peer.state=ICT_SMT_PEER_NA; peer.reason=reason;
  }
// Pure prefix qualification, shared by replay and the current per-peer status.
int ICTSMTRelationFromRates(const MqlRates &a[],const int an,const MqlRates &b[],const int bn,
                            const SICTDynamicSMTConfig &c,double &rho,int &pairs)
  {
   rho=0; pairs=0;
   if(an<60 || bn<60 || !SRMPValidDetectorRates(a,an) || !SRMPValidDetectorRates(b,bn) ||
      a[an-1].time!=b[bn-1].time) return 0;
   bool measured=SRMPAlignedCorrelationFromRates(a,an,b,bn,c.correlation_window,0,rho,pairs);
   if(c.relation!=SMT_AUTO) return (int)c.relation;
   double old_rho=0; int old_pairs=0;
   bool stable=measured && SRMPAlignedCorrelationFromRates(a,an,b,bn,c.correlation_window,c.correlation_window,old_rho,old_pairs) &&
      MathAbs(rho)>=c.correlation_threshold && MathAbs(old_rho)>=c.correlation_threshold && rho*old_rho>0;
   return stable ? (rho>0 ? 1 : -1) : 0;
  }
bool ICTSMTPeerEventUsable(const SICTSMTEvent &event,const ENUM_TIMEFRAMES tf,
                           const datetime asof,const datetime window_start,const SICTSMTPeerSnapshot &peer)
  {
   return peer.ready && peer.relation_known && peer.comparison!="" && peer.last_close>0 && peer.last_close<=asof &&
      event.signal.comparison==peer.comparison && event.signal.timeframe==tf && event.signal.relation==peer.relation &&
      event.life==ICT_SMT_CONFIRMED && !event.seed_context && event.signal.confirmation_time>0 &&
      event.signal.confirmation_time>=window_start && event.signal.confirmation_time<=asof;
  }
// Historical metadata survives invalidation. Only live, currently qualified
// evidence contributes to the state used by decisions.
void ICTSummarizeSMTPeer(const SICTSMTEvent &events[],const int count,const ENUM_TIMEFRAMES tf,
                         const datetime asof,const datetime window_start,SICTSMTPeerSnapshot &peer)
  {
   peer.event_id=""; peer.primary_pivot_time=0; peer.comparison_pivot_time=0;
   peer.pivot_confirmation_time=0; peer.confirmation_time=0; peer.primary_pivot=0; peer.comparison_pivot=0;
   peer.conflict=false; bool bull=false,bear=false;
   for(int i=0;i<count && i<ArraySize(events);i++)
     {
      SICTSMTEvent event=events[i];
      if(event.signal.comparison!=peer.comparison || event.signal.timeframe!=tf || event.seed_context ||
         event.signal.confirmation_time>asof) continue;
      if(event.signal.confirmation_time>peer.confirmation_time)
        {
         peer.event_id=event.signal.event_id; peer.confirmation_time=event.signal.confirmation_time;
         peer.primary_pivot_time=event.signal.primary_pivot_time; peer.comparison_pivot_time=event.signal.comparison_pivot_time;
         peer.pivot_confirmation_time=event.signal.pivot_confirmation_time;
         peer.primary_pivot=event.signal.primary_recent; peer.comparison_pivot=event.signal.comparison_recent;
        }
      if(!ICTSMTPeerEventUsable(event,tf,asof,window_start,peer)) continue;
      if(event.signal.direction>0) bull=true; else if(event.signal.direction<0) bear=true;
     }
   if(!peer.ready || !peer.relation_known) { peer.state=ICT_SMT_PEER_NA; return; }
   peer.conflict=bull && bear;
   peer.state=(peer.conflict ? ICT_SMT_PEER_NONE : bull ? ICT_SMT_PEER_BULLISH : bear ? ICT_SMT_PEER_BEARISH : ICT_SMT_PEER_NONE);
   peer.reason=peer.conflict ? "SMT_CONFLICT: both live directions" : bull || bear ? "CONFIRMED PIVOT" : "NONE: no active divergence";
  }

string ICTResolveBrokerSymbol(const string primary,const string primary_base,const string comparison_base)
  {
   if(comparison_base=="" || comparison_base==primary) return "";
   int at=StringFind(primary,primary_base);
   string same=(at>=0 ? StringSubstr(primary,0,at)+comparison_base+StringSubstr(primary,at+StringLen(primary_base)) : comparison_base);
   bool custom=false;
   if(same!=primary && SymbolExist(same,custom) && SymbolSelect(same,true)) return same;
   if(comparison_base!=primary && SymbolExist(comparison_base,custom) && SymbolSelect(comparison_base,true)) return comparison_base;
   // No substring guessing for futures contracts: the exact configured broker
   // symbol or the same known prefix/suffix must actually exist.
   return "";
  }
void ICTResolveSMTComparators(const string primary,const SICTDynamicSMTConfig &c,string &one,string &two,string &reason)
  {
   one=""; two=""; reason="";
   string suggestions[2],base=""; string rows[];
   int n=StringSplit(c.pair_map,';',rows);
   for(int i=0;i<n;i++)
     {
      string pair[]; if(StringSplit(rows[i],':',pair)!=2 || pair[0]=="" || StringFind(primary,pair[0])<0) continue;
      string targets[]; int k=StringSplit(pair[1],',',targets); base=pair[0];
      if(k>0) suggestions[0]=targets[0]; if(k>1) suggestions[1]=targets[1]; break;
     }
   ENUM_ICT_SMT_SLOT modes[2]; modes[0]=c.slot1; modes[1]=c.slot2;
   string manual[2]; manual[0]=c.manual1; manual[1]=c.manual2;
   string resolved[2];
   for(int i=0;i<2;i++)
     {
      if(modes[i]==SMT_SLOT_DISABLED) continue;
      if(manual[i]!="") resolved[i]=manual[i];
      else if(modes[i]==SMT_SLOT_AUTO && base!="") resolved[i]=ICTResolveBrokerSymbol(primary,base,suggestions[i]);
      if(resolved[i]!="" && !SRMPValidateComparisonSymbol(primary,resolved[i])) resolved[i]="";
      if(resolved[i]=="" && (modes[i]==SMT_SLOT_AUTO || manual[i]!=""))
         reason+="SMT"+IntegerToString(i+1)+": configured comparator unavailable; ";
     }
   if(resolved[0]!="" && resolved[0]==resolved[1]) { resolved[1]=""; reason+="Duplicate comparator slot disabled; "; }
   one=resolved[0]; two=resolved[1];
  }

// The history replay qualifies relation at EACH closed prefix. Confirmation is
// committed on the first qualifying prefix and keyed by both pairs of pivots.
// The first prefix is context-only because earlier evidence may be truncated.
int ICTReplaySMT(const string primary,const string comparison,const ENUM_TIMEFRAMES tf,
                  const MqlRates &a[],const int an,const MqlRates &b[],const int bn,
                  const double primary_tick,const double comparison_tick,const SICTDynamicSMTConfig &c,
                  SICTSMTEvent &events[],bool &relation_known)
  {
   ArrayResize(events,0); relation_known=false;
   if(an<60 || bn<60 || !SRMPValidDetectorRates(a,an) || !SRMPValidDetectorRates(b,bn) ||
      primary_tick<=0 || comparison_tick<=0) return 0;
   int warmup=(c.relation==SMT_AUTO ? c.correlation_window*2+1 : 61);
   string seen[];
   for(int n=warmup;n<=an;n++)
     {
      datetime asof=ICTBarClose(tf,a[n-1].time);
      int m=ICTClosedPrefix(b,bn,tf,asof); if(m<60 || b[m-1].time!=a[n-1].time) continue;
       double rho=0; int pairs=0;
       int relation=ICTSMTRelationFromRates(a,n,b,m,c,rho,pairs);
      if(n==an) relation_known=relation!=0;
      if(relation==0) continue;
      for(int dir=-1;dir<=1;dir+=2)
        {
         SSMTDivergence s;
         if(!SRMPFindSMTPairFromRates(primary,comparison,tf,a,n,b,m,c.left,c.right,c.max_gap,relation,
                primary_tick*c.tolerance_ticks,comparison_tick*c.tolerance_ticks,dir,s)) continue;
         bool duplicate=false; for(int i=0;i<ArraySize(seen);i++) if(seen[i]==s.event_id) { duplicate=true; break; }
         if(duplicate) continue;
         int used=ArraySize(seen); ArrayResize(seen,used+1); seen[used]=s.event_id;
         s.correlation=rho; s.correlation_pairs=pairs;
         SICTSMTEvent e; ZeroMemory(e); e.signal=s; e.life=ICT_SMT_CONFIRMED; e.changed_at=s.confirmation_time;
         e.seed_context=n==warmup;
         int size=ArraySize(events); ArrayResize(events,size+1); events[size]=e;
        }
     }
   return ArraySize(events);
  }

void ICTAdvanceSMT(const MqlRates &bar,const datetime closed,const double tolerance,
                    const datetime expiry_start,SICTSMTEvent &event)
  {
   if(event.life!=ICT_SMT_CONFIRMED || closed<=event.signal.confirmation_time) return;
   bool invalid=(event.signal.direction>0 ? bar.close<event.signal.primary_recent-tolerance :
                                         bar.close>event.signal.primary_recent+tolerance);
   if(invalid) { event.life=ICT_SMT_INVALIDATED; event.changed_at=closed; }
   else if(event.signal.confirmation_time<expiry_start) { event.life=ICT_SMT_EXPIRED; event.changed_at=closed; }
  }
#endif
