#ifndef ICT_ALERT_MANAGER_MQH
#define ICT_ALERT_MANAGER_MQH
#include "ICTDecisionRenderer.mqh"
#include "ICTSignalResult.mqh"

class CICTAlertManager
  {
private:
   string m_observed;
   string m_sent;
   string m_confirmed_sent;
   datetime m_last;
   bool m_initialized;
public:
   CICTAlertManager() { m_observed=""; m_sent=""; m_confirmed_sent=""; m_last=0; m_initialized=false; }
   void UpdateSignal(const SICTSignalResult &s,const bool popup,const bool push,const bool sound,
                     const bool log,const string sound_file,const int cooldown,const bool initial)
     {
      string key=(s.confirmed ? s.id : s.symbol+"|"+IntegerToString((int)s.frames.ltf)+"|"+IntegerToString((long)s.asof));
      if(!m_initialized)
        { m_initialized=true; if(!initial) { m_observed=key; m_sent=key; if(s.confirmed) m_confirmed_sent=s.id; return; } }
      if(key==m_observed && key==m_sent) return;
      bool changed=key!=m_observed;
      m_observed=key;
      if(log && changed)
         Print("ICT_SIGNAL id=",s.id," state=",ICTSignalStateText(s.state)," asof=",TimeToString(s.asof,TIME_DATE|TIME_SECONDS),
            " HTF=",s.htf_pass," MTF=",s.mtf_pass," LTF=",s.ltf_pass," SMT=",s.smt_pass,
            " RISK=",s.risk_pass," RR=",DoubleToString(s.rr,2)," source=",s.source_pool_id,
            " target=",s.target_pool_id," reason=",s.reason);
      if(!s.confirmed) { m_sent=key; return; }
      if(s.id==m_confirmed_sent || key==m_sent || TimeLocal()-m_last<cooldown) return;
      m_sent=key; m_confirmed_sent=s.id; m_last=TimeLocal();
      string payload=s.symbol+" "+ICTSignalStateText(s.state)+" | ID="+s.id+
         " | confirmed "+TimeToString(s.confirmation_time,TIME_DATE|TIME_SECONDS)+
         " | Entry="+ICTPriceLabel(s.entry)+" SL="+ICTPriceLabel(s.stop)+" TP="+ICTPriceLabel(s.tp1)+
         " RR="+DoubleToString(s.rr,2)+" | "+s.reason;
      if(popup) Alert(payload);
      if(sound && !PlaySound(sound_file) && log) Print("ICT alert sound failed: ",GetLastError());
      if(push)
        {
         string compact=s.symbol+" "+ICTSignalStateText(s.state)+" ID="+s.id+" "+TimeToString(s.confirmation_time,TIME_DATE|TIME_MINUTES);
         if(StringLen(compact)>255) compact=StringSubstr(compact,0,252)+"...";
         if(!SendNotification(compact) && log) Print("ICT push failed: ",GetLastError());
        }
     }
   void Update(const SICTDecision &d,const bool popup,const bool push,const bool sound,
               const bool log,const string sound_file,const int cooldown,const bool initial)
     {
      // Deliberately exclude bar timestamp, prices, balances and fluctuating scores.
      string key=StringFormat("%d|%d|%d|%I64d|%I64d|%I64d|%u|%u|%d|%s",
         (int)d.state,(int)d.priority,d.direction,(long)d.sweep_time,(long)d.mss_time,
         (long)d.fvg_time,d.buy_confirmed,d.sell_confirmed,(int)d.data_quality_ok,d.reason);
      if(!m_initialized)
        { m_initialized=true; m_observed=key; if(!initial) { m_sent=key; return; } }
      m_observed=key;
      if(key==m_sent || TimeLocal()-m_last<cooldown) return;
      m_sent=key; m_last=TimeLocal();
      if(!popup && !push && !sound && !log) return;
      bool ready=d.state==ICT_ENTRY_READY && d.hard_filters_passed && d.risk.valid;
      string levels=ready ? "Entry="+ICTPriceLabel(d.entry)+" SL="+ICTPriceLabel(d.stop)+" TP="+ICTPriceLabel(d.target)+StringFormat(" RR=%.2f Risk=%.2f %s",d.risk.rr,d.risk.risk_money,AccountInfoString(ACCOUNT_CURRENCY)) : "Entry/SL/TP/RR/money unavailable";
      string payload=_Symbol+" | "+ICTPriorityLabel(d)+" | "+ICTStateText(d.state)+
         StringFormat(" | BUY=%d SELL=%d | Bias=",d.buy_score,d.sell_score)+ICTBiasLabel(d.higher_bias)+
         " | "+levels+" | Required="+ICTEvidenceLabel(d.required)+" | Confirmed="+ICTEvidenceLabel(d.confirmed)+
         " | Missing="+ICTEvidenceLabel(d.missing)+" | Quality="+d.data_quality+" | "+d.reason+
         " | Bar="+ICTTimeLabel(d.as_of)+" | Advisory only";
      if(log) Print(payload);
      if(popup) Alert(payload);
      if(sound && !PlaySound(sound_file) && log) Print("ICT alert sound failed: ",GetLastError());
      // MT5 push limit is 255 characters; one concise notification per event.
      if(push)
        {
         string compact=_Symbol+" "+ICTStateText(d.state)+StringFormat(" B%d/S%d ",d.buy_score,d.sell_score)+levels+" "+ICTTimeLabel(d.as_of)+" "+d.reason;
         if(StringLen(compact)>255) compact=StringSubstr(compact,0,252)+"...";
         if(!SendNotification(compact) && log) Print("ICT push failed: ",GetLastError());
        }
     }
  };
#endif
