#ifndef ICT_UNIFIED_BRIDGE_MQH
#define ICT_UNIFIED_BRIDGE_MQH
#include "ICTUnifiedAnalysis.mqh"
#include "AdviceBridge.mqh"

// Account/chart scoped, schema checked and seqlocked. No trade instructions
// are consumed here: Risk Manager still reads the established decision bridge.
#define ICT_U_NUMBERS_MAX 32768
#define ICT_U_STRINGS_MAX 4096
#define U_P(x) v[n++]=(double)(x)
#define U_T(x) t[k++]=(x)
double ICTUTake(const double &v[],int &n,bool &ok)
  { if(n>=ArraySize(v)) { ok=false; return 0; } return v[n++]; }
int ICTUEnumTake(const double &v[],int &n,bool &ok)
  {
   double value=ICTUTake(v,n,ok);
   if(!MathIsValidNumber(value) || value< -2147483648.0 || value>2147483647.0) { ok=false; return 0; }
   int result=(int)value; if((double)result!=value) ok=false; return result;
  }
string ICTUText(const string &v[],int &n,bool &ok)
  { if(n>=ArraySize(v)) { ok=false; return ""; } return v[n++]; }
#define U_G(type) (type)ICTUTake(v,n,ok)
#define U_E(type) (type)ICTUEnumTake(v,n,ok)
#define U_S ICTUText(t,k,ok)
void ICTUPackStructure(const SMarketStructure &s,double &v[],int &n)
  {
   U_P(s.bias); U_P(s.bos_direction); U_P(s.mss); U_P(s.recent_high); U_P(s.prior_high); U_P(s.recent_low); U_P(s.prior_low);
   U_P(s.recent_high_time); U_P(s.prior_high_time); U_P(s.recent_low_time); U_P(s.prior_low_time);
   U_P(s.recent_high_confirmed_time); U_P(s.prior_high_confirmed_time); U_P(s.recent_low_confirmed_time); U_P(s.prior_low_confirmed_time);
   U_P(s.bos_time); U_P(s.bos_level); U_P(s.latest_closed_bar);
  }
void ICTUUnpackStructure(SMarketStructure &s,const double &v[],int &n,bool &ok)
  {
   s.bias=U_G(int); s.bos_direction=U_G(int); s.mss=U_G(bool);
   s.recent_high=U_G(double); s.prior_high=U_G(double); s.recent_low=U_G(double); s.prior_low=U_G(double);
   s.recent_high_time=U_G(datetime); s.prior_high_time=U_G(datetime); s.recent_low_time=U_G(datetime); s.prior_low_time=U_G(datetime);
   s.recent_high_confirmed_time=U_G(datetime); s.prior_high_confirmed_time=U_G(datetime);
   s.recent_low_confirmed_time=U_G(datetime); s.prior_low_confirmed_time=U_G(datetime);
   s.bos_time=U_G(datetime); s.bos_level=U_G(double); s.latest_closed_bar=U_G(datetime);
  }
bool ICTUValidFrame(const ENUM_TIMEFRAMES tf,const bool allow_current=true)
  {
   if(tf==PERIOD_CURRENT) return allow_current;
   ENUM_TIMEFRAMES frames[]={PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,PERIOD_M10,PERIOD_M12,PERIOD_M15,
      PERIOD_M20,PERIOD_M30,PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
   for(int i=0;i<ArraySize(frames);i++) if(tf==frames[i]) return true;
   return false;
  }
bool ICTUValidFrames(const SICTTimeframes &f)
  {
   if(!ICTUValidFrame(f.ltf,false) || !ICTUValidFrame(f.mtf) || !ICTUValidFrame(f.htf) ||
      (f.mode!=ICT_MTF_AUTO && f.mode!=ICT_MTF_MANUAL)) return false;
   if(f.status==ICT_MTF_FULL) return f.mtf!=PERIOD_CURRENT && f.htf!=PERIOD_CURRENT &&
      PeriodSeconds(f.ltf)<PeriodSeconds(f.mtf) && PeriodSeconds(f.mtf)<PeriodSeconds(f.htf);
   if(f.status==ICT_MTF_TWO_TIER) return f.mtf!=PERIOD_CURRENT && f.htf==PERIOD_CURRENT && PeriodSeconds(f.ltf)<PeriodSeconds(f.mtf);
   return f.status==ICT_MTF_ONE_TIER && f.mtf==PERIOD_CURRENT && f.htf==PERIOD_CURRENT;
  }
void ICTUPackSignal(const SICTSignalResult &a,double &v[],int &n,string &t[],int &k)
  {
   U_T(a.id); U_T(a.symbol); U_T(a.reason); U_T(a.htf_reason); U_T(a.mtf_reason); U_T(a.ltf_reason); U_T(a.smt_reason);
   U_T(a.source_pool_id); U_T(a.target_pool_id); U_T(a.target2_pool_id); U_T(a.liquidity_event);
   U_P(a.frames.ltf); U_P(a.frames.mtf); U_P(a.frames.htf); U_P(a.frames.mode); U_P(a.frames.status);
   U_P(a.state); U_P(a.asof); U_P(a.trigger_bar); U_P(a.confirmation_time); U_P(a.source_event_time); U_P(a.direction); U_P(a.score);
   U_P(a.data_ready); U_P(a.htf_pass); U_P(a.mtf_pass); U_P(a.ltf_pass); U_P(a.smt_required); U_P(a.smt_pass); U_P(a.risk_pass); U_P(a.confirmed);
   U_P(a.entry); U_P(a.stop); U_P(a.tp1); U_P(a.tp2); U_P(a.rr); U_P(a.source_price);
  }
void ICTUUnpackSignal(SICTSignalResult &a,const double &v[],int &n,const string &t[],int &k,bool &ok)
  {
   a.id=U_S; a.symbol=U_S; a.reason=U_S; a.htf_reason=U_S; a.mtf_reason=U_S; a.ltf_reason=U_S; a.smt_reason=U_S;
   a.source_pool_id=U_S; a.target_pool_id=U_S; a.target2_pool_id=U_S; a.liquidity_event=U_S;
   a.frames.ltf=U_E(ENUM_TIMEFRAMES); a.frames.mtf=U_E(ENUM_TIMEFRAMES); a.frames.htf=U_E(ENUM_TIMEFRAMES);
   a.frames.mode=U_E(ENUM_ICT_MTF_MODE); a.frames.status=U_E(ENUM_ICT_MTF_STATUS);
   a.state=U_E(ENUM_ICT_SIGNAL_STATE); a.asof=U_G(datetime); a.trigger_bar=U_G(datetime); a.confirmation_time=U_G(datetime);
   a.source_event_time=U_G(datetime); a.direction=U_G(int); a.score=U_G(int);
   a.data_ready=U_G(bool); a.htf_pass=U_G(bool); a.mtf_pass=U_G(bool); a.ltf_pass=U_G(bool);
   a.smt_required=U_G(bool); a.smt_pass=U_G(bool); a.risk_pass=U_G(bool); a.confirmed=U_G(bool);
   a.entry=U_G(double); a.stop=U_G(double); a.tp1=U_G(double); a.tp2=U_G(double); a.rr=U_G(double); a.source_price=U_G(double);
  }
bool ICTUnifiedPack(const SICTUnifiedSnapshot &s,double &v[],string &t[])
  {
   if(s.event_count<0 || s.event_count>ICT_SMART_SMT_MAX || s.ob_count<0 || s.ob_count>ICT_SMART_OB_MAX || s.layer_count<0 || s.layer_count>4) return false;
   ArrayResize(v,ICT_U_NUMBERS_MAX); ArrayResize(t,ICT_U_STRINGS_MAX); int n=0,k=0;
   U_T(s.symbol); U_T(s.comparison1); U_T(s.comparison2); U_T(s.reason); U_T(s.comparator_reason);
   U_P(s.schema); U_P(s.revision); U_P(s.detection_bars); U_P(s.display_bars);
   U_P(s.frames.ltf); U_P(s.frames.mtf); U_P(s.frames.htf); U_P(s.frames.mode); U_P(s.frames.status); U_P(s.chart_tf);
   U_P(s.asof); U_P(s.display_start); U_P(s.valid); U_P(s.capacity_ok); U_P(s.mtf_state);
   U_P(s.layer_count); U_P(s.event_count); U_P(s.ob_count);
   ICTUPackSignal(s.signal,v,n,t,k);
   for(int i=0;i<3;i++)
     {
      U_P(s.tiers[i].timeframe); U_P(s.tiers[i].status); U_P(s.tiers[i].closed_at); U_T(s.tiers[i].reason); ICTUPackStructure(s.tiers[i].structure,v,n);
       MqlRates last=s.tiers[i].last_bar;
       U_P(last.time); U_P(last.open); U_P(last.high); U_P(last.low); U_P(last.close);
       U_P(s.tiers[i].displacement_up); U_P(s.tiers[i].displacement_down);
      U_P(s.tiers[i].fvg_ready); U_P(s.tiers[i].bpr_ready);
      SFairValueGap g=s.tiers[i].gap;
      U_P(g.direction); U_P(g.lower); U_P(g.upper); U_P(g.mitigated); U_P(g.formed_time); U_P(g.status);
      U_P(g.first_touch_time); U_P(g.fully_filled_time); U_P(g.invalidated_time); U_P(g.inversion_evidence); U_P(g.inversion_direction); U_P(g.inversion_time);
      SICTBalancedPriceRange b=s.tiers[i].bpr; U_T(b.id); U_P(b.timeframe); U_P(b.state); U_P(b.direction); U_P(b.lower); U_P(b.upper);
      U_P(b.invalidation); U_P(b.first_fvg_time); U_P(b.second_fvg_time); U_P(b.confirmed_at); U_P(b.invalidated_at);
     }
   for(int i=0;i<s.layer_count;i++)
     {
      SICTSMTLayer l=s.layers[i]; U_P(l.timeframe); U_P(l.ready); U_P(l.relation_known); U_P(l.detected); U_P(l.displayed);
      U_P(l.bullish); U_P(l.bearish); U_P(l.last_close); U_P(l.window_start); U_T(l.reason);
       for(int comp=0;comp<2;comp++)
         {
          SICTSMTPeerSnapshot p=l.peers[comp]; U_T(p.comparison); U_T(p.event_id); U_T(p.reason);
          U_P(p.ready); U_P(p.relation_known); U_P(p.conflict); U_P(p.relation); U_P(p.state); U_P(p.last_close);
          U_P(p.primary_pivot_time); U_P(p.comparison_pivot_time); U_P(p.pivot_confirmation_time); U_P(p.confirmation_time);
          U_P(p.primary_pivot); U_P(p.comparison_pivot);
         }
     }
   for(int i=0;i<s.event_count;i++)
     {
      SICTSMTEvent e=s.events[i]; SSMTDivergence a=e.signal;
      U_T(a.comparison); U_T(a.event_id); U_P(a.state); U_P(a.direction); U_P(a.timeframe); U_P(a.relation); U_P(a.comparator_extreme);
      U_P(a.correlation); U_P(a.correlation_pairs); U_P(a.primary_pivot_time); U_P(a.primary_prior_time); U_P(a.comparison_pivot_time);
      U_P(a.comparison_prior_time); U_P(a.pivot_confirmation_time); U_P(a.confirmation_time);
      U_P(a.primary_prior); U_P(a.primary_recent); U_P(a.comparison_prior); U_P(a.comparison_recent);
      U_P(e.life); U_P(e.changed_at); U_P(e.seed_context);
     }
   for(int i=0;i<s.ob_count;i++)
     {
      SICTStrongOrderBlock z=s.zones[i]; SOrderBlock b=z.ob;
      U_T(z.id); U_T(z.gate_reason); U_T(z.invalidation_reason);
      U_P(b.direction); U_P(b.state); U_P(b.formation_time); U_P(b.confirmation_time); U_P(b.state_time); U_P(b.upper); U_P(b.lower); U_P(b.midpoint);
      U_P(b.displacement); U_P(b.break_confirmed); U_P(b.liquidity_sweep); U_P(b.fvg); U_P(b.pd_match); U_P(b.session_match); U_P(b.score);
       U_P(z.timeframe); U_P(z.grade); U_P(z.confirmation_grade); U_P(z.life); U_P(z.candles); U_P(z.confirmation_score); U_P(z.current_context_score); U_P(z.touch_count); U_P(z.age); U_P(z.sweep_count);
      U_P(z.sweep_points); U_P(z.displacement_points); U_P(z.structure_points); U_P(z.fvg_points); U_P(z.bias_points); U_P(z.pd_points); U_P(z.freshness_points);
      U_P(z.hard_gates); U_P(z.continuation); U_P(z.in_contact); U_P(z.departed); U_P(z.group_end); U_P(z.processed_at);
      U_P(z.open_reference); U_P(z.mitigation_depth); U_P(z.invalidation);
     }
   ArrayResize(v,n); ArrayResize(t,k); return true;
  }
bool ICTUnifiedUnpack(const double &v[],const string &t[],SICTUnifiedSnapshot &s)
  {
   ZeroMemory(s); int n=0,k=0; bool ok=true;
   if(ArraySize(v)>ICT_U_NUMBERS_MAX || ArraySize(t)>ICT_U_STRINGS_MAX) return false;
   for(int i=0;i<ArraySize(v);i++) if(!MathIsValidNumber(v[i])) return false;
   s.symbol=U_S; s.comparison1=U_S; s.comparison2=U_S; s.reason=U_S; s.comparator_reason=U_S;
   s.schema=U_G(int); s.revision=U_G(int); s.detection_bars=U_G(int); s.display_bars=U_G(int);
   s.frames.ltf=U_E(ENUM_TIMEFRAMES); s.frames.mtf=U_E(ENUM_TIMEFRAMES); s.frames.htf=U_E(ENUM_TIMEFRAMES);
   s.frames.mode=U_E(ENUM_ICT_MTF_MODE); s.frames.status=U_E(ENUM_ICT_MTF_STATUS); s.chart_tf=U_E(ENUM_TIMEFRAMES);
   s.asof=U_G(datetime); s.display_start=U_G(datetime); s.valid=U_G(bool); s.capacity_ok=U_G(bool); s.mtf_state=U_G(ENUM_ICT_MTF_STRUCTURE);
   s.layer_count=U_G(int); s.event_count=U_G(int); s.ob_count=U_G(int);
   if(!ok || s.schema!=ICT_UNIFIED_SCHEMA || s.symbol=="" || s.asof<=0 || s.layer_count<0 || s.layer_count>4 ||
       s.event_count<0 || s.event_count>ICT_SMART_SMT_MAX || s.ob_count<0 || s.ob_count>ICT_SMART_OB_MAX ||
       !ICTUValidFrames(s.frames) || !ICTUValidFrame(s.chart_tf,false)) return false;
   ICTUUnpackSignal(s.signal,v,n,t,k,ok);
   SICTSignalResult signal=s.signal;
   if((int)signal.state<0 || (int)signal.state>4 || signal.score<0 || signal.score>100 || signal.direction< -1 || signal.direction>1) ok=false;
   if(signal.symbol!="" || signal.asof!=0 || signal.confirmed)
     {
      if(signal.symbol!=s.symbol || signal.asof!=s.asof || !ICTUValidFrames(signal.frames) ||
         signal.frames.ltf!=s.frames.ltf || signal.frames.mtf!=s.frames.mtf || signal.frames.htf!=s.frames.htf ||
         signal.frames.status!=s.frames.status ||
         signal.trigger_bar>signal.asof || signal.confirmation_time>signal.asof || signal.source_event_time>signal.asof) ok=false;
      if(signal.confirmed && (signal.id=="" || !signal.data_ready || !signal.htf_pass || !signal.mtf_pass || !signal.ltf_pass ||
         !signal.risk_pass || (signal.smt_required && !signal.smt_pass) || signal.frames.status!=ICT_MTF_FULL ||
         signal.confirmation_time!=signal.asof || signal.trigger_bar<=0 || signal.trigger_bar>=signal.confirmation_time ||
         signal.target_pool_id=="" || !ICTSignalPlanValid(signal,2) ||
         signal.state!=(signal.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED))) ok=false;
      if(!signal.confirmed && (signal.state==ICT_SIGNAL_BUY_CONFIRMED || signal.state==ICT_SIGNAL_SELL_CONFIRMED)) ok=false;
     }
   else if(signal.frames.ltf!=PERIOD_CURRENT || signal.frames.mtf!=PERIOD_CURRENT || signal.frames.htf!=PERIOD_CURRENT ||
      signal.frames.mode!=ICT_MTF_AUTO || signal.frames.status!=ICT_MTF_INVALID || signal.state!=ICT_SIGNAL_NO_TRADE) ok=false;
   for(int i=0;i<3;i++)
     { s.tiers[i].timeframe=U_G(ENUM_TIMEFRAMES); s.tiers[i].status=U_G(ENUM_ICT_CONTEXT_STATE);
       s.tiers[i].closed_at=U_G(datetime); s.tiers[i].reason=U_S; ICTUUnpackStructure(s.tiers[i].structure,v,n,ok);
        s.tiers[i].last_bar.time=U_G(datetime); s.tiers[i].last_bar.open=U_G(double); s.tiers[i].last_bar.high=U_G(double);
        s.tiers[i].last_bar.low=U_G(double); s.tiers[i].last_bar.close=U_G(double);
        s.tiers[i].displacement_up=U_G(bool); s.tiers[i].displacement_down=U_G(bool);
        ENUM_TIMEFRAMES expected=(i==0 ? s.frames.ltf : i==1 ? s.frames.mtf : s.frames.htf);
        if(s.tiers[i].timeframe!=expected || s.tiers[i].closed_at>s.asof || (int)s.tiers[i].status<0 || (int)s.tiers[i].status>3 ||
           (s.tiers[i].displacement_up && s.tiers[i].displacement_down)) ok=false;
        if(s.tiers[i].last_bar.time>0 && (!SRMPValidDetectorBar(s.tiers[i].last_bar) ||
           ICTBarClose(expected,s.tiers[i].last_bar.time)!=s.tiers[i].closed_at)) ok=false;
        if(s.valid && expected!=PERIOD_CURRENT && s.tiers[i].status!=ICT_CONTEXT_INSUFFICIENT && s.tiers[i].last_bar.time<=0) ok=false;
       s.tiers[i].fvg_ready=U_G(bool); s.tiers[i].bpr_ready=U_G(bool);
       s.tiers[i].gap.direction=U_G(int); s.tiers[i].gap.lower=U_G(double); s.tiers[i].gap.upper=U_G(double);
       s.tiers[i].gap.mitigated=U_G(bool); s.tiers[i].gap.formed_time=U_G(datetime); s.tiers[i].gap.status=U_G(ENUM_SRMP_FVG_STATUS);
       s.tiers[i].gap.first_touch_time=U_G(datetime); s.tiers[i].gap.fully_filled_time=U_G(datetime); s.tiers[i].gap.invalidated_time=U_G(datetime);
       s.tiers[i].gap.inversion_evidence=U_G(bool); s.tiers[i].gap.inversion_direction=U_G(int); s.tiers[i].gap.inversion_time=U_G(datetime);
       s.tiers[i].bpr.id=U_S; s.tiers[i].bpr.timeframe=U_G(ENUM_TIMEFRAMES); s.tiers[i].bpr.state=U_G(ENUM_ICT_BPR_STATE);
       s.tiers[i].bpr.direction=U_G(int); s.tiers[i].bpr.lower=U_G(double); s.tiers[i].bpr.upper=U_G(double); s.tiers[i].bpr.invalidation=U_G(double);
       s.tiers[i].bpr.first_fvg_time=U_G(datetime); s.tiers[i].bpr.second_fvg_time=U_G(datetime); s.tiers[i].bpr.confirmed_at=U_G(datetime); s.tiers[i].bpr.invalidated_at=U_G(datetime);
       if(s.tiers[i].bpr_ready && (s.tiers[i].bpr.upper<=s.tiers[i].bpr.lower || s.tiers[i].bpr.confirmed_at>s.asof)) ok=false;
     }
   for(int i=0;i<s.layer_count;i++)
     {
      s.layers[i].timeframe=U_G(ENUM_TIMEFRAMES); s.layers[i].ready=U_G(bool); s.layers[i].relation_known=U_G(bool);
      s.layers[i].detected=U_G(int); s.layers[i].displayed=U_G(int); s.layers[i].bullish=U_G(int); s.layers[i].bearish=U_G(int);
      s.layers[i].last_close=U_G(datetime); s.layers[i].window_start=U_G(datetime); s.layers[i].reason=U_S;
      if(s.layers[i].last_close>s.asof) ok=false;
       if(!ICTUValidFrame(s.layers[i].timeframe,false)) ok=false;
       for(int comp=0;comp<2;comp++)
         {
          SICTSMTPeerSnapshot p; ZeroMemory(p); p.comparison=U_S; p.event_id=U_S; p.reason=U_S;
          p.ready=U_G(bool); p.relation_known=U_G(bool); p.conflict=U_G(bool); p.relation=U_G(int);
          p.state=U_G(ENUM_ICT_SMT_PEER_STATE); p.last_close=U_G(datetime); p.primary_pivot_time=U_G(datetime);
          p.comparison_pivot_time=U_G(datetime); p.pivot_confirmation_time=U_G(datetime); p.confirmation_time=U_G(datetime);
          p.primary_pivot=U_G(double); p.comparison_pivot=U_G(double);
          string configured=(comp==0 ? s.comparison1 : s.comparison2);
          if(p.comparison!=configured || (int)p.state<0 || (int)p.state>3 || p.relation< -1 || p.relation>1 ||
             p.last_close>s.asof || p.confirmation_time>s.asof || p.pivot_confirmation_time>p.confirmation_time ||
             (p.ready && (p.comparison=="" || p.last_close<=0 || p.last_close!=s.layers[i].last_close)) ||
             (p.relation_known && (!p.ready || p.relation==0)) ||
             (p.state!=ICT_SMT_PEER_NA && (!p.ready || !p.relation_known)) ||
             (p.conflict && p.state!=ICT_SMT_PEER_NONE)) ok=false;
          s.layers[i].peers[comp]=p;
         }
     }
   for(int i=0;i<s.event_count;i++)
     {
      SSMTDivergence a; ZeroMemory(a); a.comparison=U_S; a.event_id=U_S;
      a.state=U_G(ENUM_SRMP_SMT_STATE); a.direction=U_G(int); a.timeframe=U_G(ENUM_TIMEFRAMES); a.relation=U_G(int); a.comparator_extreme=U_G(bool);
      a.correlation=U_G(double); a.correlation_pairs=U_G(int); a.primary_pivot_time=U_G(datetime); a.primary_prior_time=U_G(datetime);
      a.comparison_pivot_time=U_G(datetime); a.comparison_prior_time=U_G(datetime); a.pivot_confirmation_time=U_G(datetime); a.confirmation_time=U_G(datetime);
      a.primary_prior=U_G(double); a.primary_recent=U_G(double); a.comparison_prior=U_G(double); a.comparison_recent=U_G(double);
      s.events[i].signal=a; s.events[i].life=U_G(ENUM_ICT_SMT_LIFE); s.events[i].changed_at=U_G(datetime); s.events[i].seed_context=U_G(bool);
      if(a.event_id=="" || a.comparison=="" || (a.direction!=1 && a.direction!=-1) || (a.relation!=1 && a.relation!=-1) ||
         a.confirmation_time>s.asof || a.confirmation_time<a.pivot_confirmation_time || a.primary_prior_time>=a.primary_pivot_time ||
         a.primary_prior<=0 || a.primary_recent<=0 || (int)s.events[i].life<0 || (int)s.events[i].life>3 || s.events[i].changed_at>s.asof) ok=false;
     }
   for(int i=0;i<s.ob_count;i++)
     {
      SICTStrongOrderBlock z; ZeroMemory(z); z.id=U_S; z.gate_reason=U_S; z.invalidation_reason=U_S;
      z.ob.direction=U_G(int); z.ob.state=U_G(ENUM_SRMP_OB_STATE); z.ob.formation_time=U_G(datetime); z.ob.confirmation_time=U_G(datetime);
      z.ob.state_time=U_G(datetime); z.ob.upper=U_G(double); z.ob.lower=U_G(double); z.ob.midpoint=U_G(double);
      z.ob.displacement=U_G(bool); z.ob.break_confirmed=U_G(bool); z.ob.liquidity_sweep=U_G(bool); z.ob.fvg=U_G(bool);
      z.ob.pd_match=U_G(bool); z.ob.session_match=U_G(bool); z.ob.score=U_G(int);
       z.timeframe=U_G(ENUM_TIMEFRAMES); z.grade=U_G(ENUM_ICT_OB_GRADE); z.confirmation_grade=U_G(ENUM_ICT_OB_GRADE); z.life=U_G(ENUM_ICT_OB_LIFE);
      z.candles=U_G(int); z.confirmation_score=U_G(int); z.current_context_score=U_G(int); z.touch_count=U_G(int); z.age=U_G(int); z.sweep_count=U_G(int);
      z.sweep_points=U_G(int); z.displacement_points=U_G(int); z.structure_points=U_G(int); z.fvg_points=U_G(int); z.bias_points=U_G(int); z.pd_points=U_G(int); z.freshness_points=U_G(int);
      z.hard_gates=U_G(bool); z.continuation=U_G(bool); z.in_contact=U_G(bool); z.departed=U_G(bool);
      z.group_end=U_G(datetime); z.processed_at=U_G(datetime); z.open_reference=U_G(double); z.mitigation_depth=U_G(double); z.invalidation=U_G(double);
      if(z.id=="" || (z.ob.direction!=1 && z.ob.direction!=-1) || z.ob.lower<=0 || z.ob.upper<=z.ob.lower ||
         z.ob.confirmation_time>s.asof || z.ob.confirmation_time<=z.ob.formation_time || z.processed_at>s.asof ||
          z.confirmation_score<0 || z.confirmation_score>100 || z.current_context_score<0 || z.current_context_score>z.confirmation_score ||
          z.touch_count<0 || z.mitigation_depth<0 || z.mitigation_depth>1 || !ICTUValidFrame(z.timeframe,false) ||
          (int)z.life<0 || (int)z.life>7 || (int)z.grade<0 || (int)z.grade>2 || (int)z.confirmation_grade<0 || (int)z.confirmation_grade>2) ok=false;
      s.zones[i]=z;
     }
   return ok && n==ArraySize(v) && k==ArraySize(t);
  }
#undef U_P
#undef U_T
#undef U_G
#undef U_E
#undef U_S

string ICTUnifiedFile(const string symbol) { return SRMPAdviceKey(symbol,"UNIFIED")+".bin"; }
bool ICTPublishUnified(const string symbol,const SICTUnifiedSnapshot &s)
  {
   string key=SRMPAdviceKey(symbol,"USEQ"),stamp=SRMPAdviceKey(symbol,"UTS");
    // The EA can fill signal after analysis without changing its revision. A
    // revision-only shortcut would publish stale decisions after a reset/retry.
   double values[]; string texts[]; if(!ICTUnifiedPack(s,values,texts)) return false;
   double seq=GlobalVariableCheck(key) ? GlobalVariableGet(key) : 0;
   if((long)seq%2!=0) seq++;
   GlobalVariableSet(stamp,0); GlobalVariableSet(key,seq+1);
   int f=FileOpen(ICTUnifiedFile(symbol),FILE_WRITE|FILE_BIN|FILE_UNICODE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(f==INVALID_HANDLE) return false;
   bool ok=FileWriteInteger(f,ICT_UNIFIED_SCHEMA)==4 && FileWriteInteger(f,ArraySize(values))==4 && FileWriteInteger(f,ArraySize(texts))==4 &&
      FileWriteArray(f,values,0,ArraySize(values))==(uint)ArraySize(values);
   for(int i=0;i<ArraySize(texts) && ok;i++)
     { int size=StringLen(texts[i]); ok=size<=1024 && FileWriteInteger(f,size)==4; if(size>0) ok=ok && FileWriteString(f,texts[i],size)==(uint)(size*2); }
   FileFlush(f); FileClose(f);
   if(!ok) return false;
    GlobalVariableSet(key,seq+2); GlobalVariableSet(stamp,(double)TimeLocal()); return true;
  }
bool ICTReadUnified(const string symbol,SICTUnifiedSnapshot &s,const int max_age=15,
                    const ENUM_TIMEFRAMES expected_ltf=PERIOD_CURRENT)
  {
   ZeroMemory(s);
   string key=SRMPAdviceKey(symbol,"USEQ"),stamp=SRMPAdviceKey(symbol,"UTS");
   if(!GlobalVariableCheck(stamp) || !GlobalVariableCheck(key)) return false;
   double age=(double)TimeLocal()-GlobalVariableGet(stamp),before=GlobalVariableGet(key);
   if(age<0 || age>max_age || before<=0 || (long)before%2!=0) return false;
   int f=FileOpen(ICTUnifiedFile(symbol),FILE_READ|FILE_BIN|FILE_UNICODE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(f==INVALID_HANDLE) return false;
   int schema=FileReadInteger(f),numbers=FileReadInteger(f),strings=FileReadInteger(f);
   if(schema!=ICT_UNIFIED_SCHEMA || numbers<1 || numbers>ICT_U_NUMBERS_MAX || strings<1 || strings>ICT_U_STRINGS_MAX)
     { FileClose(f); return false; }
   double values[]; string texts[]; ArrayResize(values,numbers); ArrayResize(texts,strings);
   bool ok=FileReadArray(f,values,0,numbers)==(uint)numbers;
   for(int i=0;i<strings && ok;i++)
     { int length=FileReadInteger(f); if(length<0 || length>1024) { ok=false; break; }
       texts[i]=(length>0 ? FileReadString(f,length) : ""); if(StringLen(texts[i])!=length) ok=false; }
   FileClose(f); double after=GlobalVariableGet(key);
   ENUM_TIMEFRAMES expected=(expected_ltf==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : expected_ltf);
   if(!ok || before!=after || !ICTUnifiedUnpack(values,texts,s) || s.symbol!=symbol ||
      s.frames.ltf!=expected || s.chart_tf!=(ENUM_TIMEFRAMES)_Period)
     { ZeroMemory(s); return false; }
   return true;
  }
#endif
