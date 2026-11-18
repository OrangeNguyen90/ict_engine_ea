#ifndef ICT_SIGNAL_HISTORY_MQH
#define ICT_SIGNAL_HISTORY_MQH
#include "ICTSignalResult.mqh"
#include "ICTUnifiedRenderer.mqh"

// Records observations, not a second analysis algorithm. Reinitialization reads
// the original decisions; it never backfills old candles using today's account.
class CICTSignalHistory
  {
private:
   SICTSignalResult m_history[],m_latest;
   string m_path;
   bool m_ready;
   int m_rows,m_retention;
   datetime m_retry;
   bool WriteText(const int file,const SICTSignalResult &s)
     {
      return FileWrite(file,1,s.id,s.symbol,(int)s.frames.ltf,(int)s.frames.mtf,(int)s.frames.htf,(int)s.frames.mode,
         (int)s.frames.status,(int)s.state,(long)s.asof,(long)s.trigger_bar,(long)s.confirmation_time,
         (long)s.source_event_time,s.direction,s.score,(int)s.data_ready,(int)s.htf_pass,(int)s.mtf_pass,
         (int)s.ltf_pass,(int)s.smt_required,(int)s.smt_pass,(int)s.risk_pass,(int)s.confirmed,
         DoubleToString(s.entry,16),DoubleToString(s.stop,16),DoubleToString(s.tp1,16),DoubleToString(s.tp2,16),
         DoubleToString(s.rr,12),s.source_pool_id,s.target_pool_id,s.target2_pool_id,
         s.reason,s.htf_reason,s.mtf_reason,s.ltf_reason,s.smt_reason,DoubleToString(s.source_price,16),s.liquidity_event)>0;
     }
   bool ReadRecord(const int file,SICTSignalResult &s)
     {
      ZeroMemory(s);
      string fields[]; ArrayResize(fields,38);
      int n=0;
      while(!FileIsEnding(file))
        {
         string value=FileReadString(file);
         if(n<38) fields[n]=value;
         n++;
         if(FileIsLineEnding(file)) break;
        }
      if(n!=38 || fields[0]!="1") return false;
      s.id=fields[1]; s.symbol=fields[2];
      s.frames.ltf=(ENUM_TIMEFRAMES)StringToInteger(fields[3]); s.frames.mtf=(ENUM_TIMEFRAMES)StringToInteger(fields[4]);
      s.frames.htf=(ENUM_TIMEFRAMES)StringToInteger(fields[5]); s.frames.mode=(ENUM_ICT_MTF_MODE)StringToInteger(fields[6]);
      s.frames.status=(ENUM_ICT_MTF_STATUS)StringToInteger(fields[7]); s.state=(ENUM_ICT_SIGNAL_STATE)StringToInteger(fields[8]);
      s.asof=(datetime)StringToInteger(fields[9]); s.trigger_bar=(datetime)StringToInteger(fields[10]);
      s.confirmation_time=(datetime)StringToInteger(fields[11]); s.source_event_time=(datetime)StringToInteger(fields[12]);
      s.direction=(int)StringToInteger(fields[13]); s.score=(int)StringToInteger(fields[14]);
      s.data_ready=(bool)StringToInteger(fields[15]); s.htf_pass=(bool)StringToInteger(fields[16]);
      s.mtf_pass=(bool)StringToInteger(fields[17]); s.ltf_pass=(bool)StringToInteger(fields[18]);
      s.smt_required=(bool)StringToInteger(fields[19]); s.smt_pass=(bool)StringToInteger(fields[20]);
      s.risk_pass=(bool)StringToInteger(fields[21]); s.confirmed=(bool)StringToInteger(fields[22]);
      s.entry=StringToDouble(fields[23]); s.stop=StringToDouble(fields[24]); s.tp1=StringToDouble(fields[25]);
      s.tp2=StringToDouble(fields[26]); s.rr=StringToDouble(fields[27]); s.source_pool_id=fields[28];
      s.target_pool_id=fields[29]; s.target2_pool_id=fields[30]; s.reason=fields[31];
      s.htf_reason=fields[32]; s.mtf_reason=fields[33]; s.ltf_reason=fields[34]; s.smt_reason=fields[35];
      s.source_price=StringToDouble(fields[36]); s.liquidity_event=fields[37];
      return s.symbol!="" && s.asof>s.trigger_bar && s.trigger_bar>0 &&
         s.score>=0 && s.score<=100 && s.source_event_time<=s.asof &&
         (int)s.state>=0 && (int)s.state<=4 &&
         (!s.confirmed || (s.id!="" && s.confirmation_time==s.asof && ICTSignalPlanValid(s,2) &&
            s.frames.status==ICT_MTF_FULL && s.data_ready && s.htf_pass && s.mtf_pass && s.ltf_pass && s.risk_pass &&
            (!s.smt_required || s.smt_pass) && s.target_pool_id!="" &&
            s.state==(s.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED)));
     }
   bool Compact()
     {
      string pending=m_path+".pending";
      int file=FileOpen(pending,FILE_WRITE|FILE_CSV|FILE_UNICODE,'\t');
      if(file==INVALID_HANDLE) return false;
      bool ok=true,latest_written=false; int rows=0;
      for(int i=0;i<ArraySize(m_history) && ok;i++)
        {
         ok=WriteText(file,m_history[i]); rows++;
         if(m_history[i].asof==m_latest.asof) latest_written=true;
        }
      if(ok && m_latest.asof>0 && !latest_written) { ok=WriteText(file,m_latest); rows++; }
      ResetLastError(); FileFlush(file); if(GetLastError()!=0) ok=false; FileClose(file);
      if(ok) ok=FileMove(pending,0,m_path,FILE_REWRITE);
      if(!ok) { FileDelete(pending); return false; }
      m_rows=rows; return true;
     }
   // Replace only the most recent unconfirmed row. Compact() deliberately
   // keeps confirmed history only, so using it here would discard earlier
   // diagnostic observations whenever a signal is promoted.
   bool PromoteLatest(const SICTSignalResult &promoted)
     {
      int source_file=FileOpen(m_path,FILE_READ|FILE_CSV|FILE_UNICODE|FILE_SHARE_READ,'\t');
      if(source_file==INVALID_HANDLE) return false;
      string pending=m_path+".pending";
      int output=FileOpen(pending,FILE_WRITE|FILE_CSV|FILE_UNICODE,'\t');
      if(output==INVALID_HANDLE) { FileClose(source_file); return false; }
      bool ok=true,replaced=false; datetime last=0; int rows=0;
      while(ok && !FileIsEnding(source_file))
        {
         SICTSignalResult record;
         if(!ReadRecord(source_file,record) || record.asof<=last || record.asof>promoted.asof ||
            record.symbol!=promoted.symbol || record.frames.ltf!=promoted.frames.ltf ||
            record.frames.mtf!=promoted.frames.mtf || record.frames.htf!=promoted.frames.htf)
           { ok=false; break; }
         last=record.asof;
         if(record.asof==promoted.asof)
           {
            if(record.confirmed || replaced || record.trigger_bar!=promoted.trigger_bar ||
               record.frames.mode!=promoted.frames.mode || record.frames.status!=promoted.frames.status)
              { ok=false; break; }
            ok=WriteText(output,promoted); replaced=true;
           }
         else ok=WriteText(output,record);
         rows++;
        }
      FileClose(source_file);
      ResetLastError(); FileFlush(output); if(GetLastError()!=0) ok=false; FileClose(output);
      if(!replaced || last!=promoted.asof) ok=false;
      if(ok) ok=FileMove(pending,0,m_path,FILE_REWRITE);
      if(!ok) { FileDelete(pending); return false; }
      m_rows=rows; return true;
     }
public:
   CICTSignalHistory() { m_ready=false; m_rows=0; m_retention=60; m_retry=0; ZeroMemory(m_latest); }
   bool Init(const string symbol,const SICTTimeframes &frames,const int retention=60)
     {
      ArrayResize(m_history,0); ZeroMemory(m_latest);
      m_rows=0; m_retention=retention;
      datetime oldest=iTime(symbol,frames.ltf,retention);
      string identity=symbol+"|"+IntegerToString((int)frames.ltf)+"|"+IntegerToString((int)frames.mtf)+"|"+IntegerToString((int)frames.htf);
      m_path="ICT_signals_"+IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString(ChartID())+"_"+
         IntegerToString((long)ICTStableHash(identity))+".csv";
      m_ready=true;
      if(!FileIsExist(m_path)) return true;
      int file=FileOpen(m_path,FILE_READ|FILE_CSV|FILE_UNICODE|FILE_SHARE_READ,'\t');
      if(file==INVALID_HANDLE) { m_ready=false; return false; }
      while(!FileIsEnding(file))
        {
         SICTSignalResult s;
         if(!ReadRecord(file,s)) { m_ready=false; break; }
         if(s.symbol!=symbol || s.frames.ltf!=frames.ltf || s.frames.mtf!=frames.mtf || s.frames.htf!=frames.htf)
           { m_ready=false; break; }
         if(s.asof<=m_latest.asof) { m_ready=false; break; }
         m_rows++;
         if(s.asof>=m_latest.asof) m_latest=s;
         if(s.confirmed && (oldest<=0 || s.trigger_bar>=oldest))
           {
            if(!ICTMergeConfirmedSignal(s,m_history,1000)) { m_ready=false; break; }
           }
        }
      FileClose(file);
      if(m_ready && oldest>0 && m_rows>m_retention*2+100) m_ready=Compact();
      return m_ready;
     }
   void Prune(const datetime oldest_bar,const datetime asof)
     {
      for(int i=ArraySize(m_history)-1;i>=0;i--)
         if(m_history[i].trigger_bar<oldest_bar)
           { for(int j=i+1;j<ArraySize(m_history);j++) m_history[j-1]=m_history[j]; ArrayResize(m_history,ArraySize(m_history)-1); }
      if(m_ready && oldest_bar>0 && m_rows>m_retention*2+100) m_ready=Compact();
     }
   bool Observe(SICTSignalResult &s)
     {
      if(!m_ready)
        {
         if(TimeLocal()-m_retry<5) return false;
         m_retry=TimeLocal();
         if(!Init(s.symbol,s.frames,m_retention)) return false;
        }
      if(s.asof<=s.trigger_bar || s.trigger_bar<=0) return false;
      if(s.asof<m_latest.asof) return false; // Clock/history rollback cannot create an unjournaled decision.
      if(s.asof==m_latest.asof)
        {
         ENUM_ICT_SAME_BAR_ACTION action=ICTSignalSameBarAction(m_latest,s);
         if(action==ICT_BAR_KEEP_CONFIRMED)
           { ICTSignalReconcileCommittedLive(m_latest,s); return true; }
         if(action==ICT_BAR_REFRESH_UNCONFIRMED) { m_latest=s; return true; }
         if(action!=ICT_BAR_COMMIT_CONFIRMED) return false;
         // Retain the bar-close evidence time but make the actual live
         // observation explicit, including when delayed data/risk recovers.
         datetime observed=TimeTradeServer();
         if(observed<s.asof) return false;
         s.reason+=" | observed "+TimeToString(observed,TIME_DATE|TIME_SECONDS)+" broker time";
         if(!ICTMergeConfirmedSignal(s,m_history,1000)) return false;
           // Keep earlier diagnostic and confirmed rows, replacing only this
           // candle's unconfirmed observation before publishing its signal.
           if(!PromoteLatest(s)) { m_ready=false; return false; }
           m_latest=s;
         return true;
        }
      int file=FileOpen(m_path,FILE_READ|FILE_WRITE|FILE_CSV|FILE_UNICODE|FILE_SHARE_READ,'\t');
      if(file==INVALID_HANDLE) { m_ready=false; return false; }
      bool seek=FileSeek(file,0,SEEK_END); ResetLastError(); bool written=seek && WriteText(file,s); FileFlush(file);
      int error=GetLastError(); FileClose(file);
      if(!written || error!=0) { m_ready=false; return false; }
      m_latest=s;
      m_rows++;
      if(s.confirmed) ICTMergeConfirmedSignal(s,m_history,1000);
      return true;
     }
   void Render(const string prefix,const datetime oldest_bar,const datetime asof,const bool visible)
     {
      string keep[];
      for(int i=0;i<ArraySize(m_history) && visible;i++)
        {
         SICTSignalResult s=m_history[i]; if(!ICTSignalInsideWindow(s,oldest_bar,asof)) continue;
         string name=prefix+IntegerToString((long)ICTStableHash(s.id)),label=name+"t";
         color ink=(s.direction>0 ? clrLimeGreen : clrTomato);
         if(ObjectFind(0,name)<0)
           {
            ObjectCreate(0,name,OBJ_ARROW,0,s.trigger_bar,s.entry);
            ObjectSetInteger(0,name,OBJPROP_ARROWCODE,s.direction>0 ? 233 : 234);
            ObjectSetInteger(0,name,OBJPROP_COLOR,ink); ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
            ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
           }
         string tip=s.id+" | "+ICTSignalStateText(s.state)+" | candle "+TimeToString(s.trigger_bar,TIME_DATE|TIME_MINUTES)+
            " | confirmed "+TimeToString(s.confirmation_time,TIME_DATE|TIME_MINUTES)+" | "+s.reason+
            " | source "+s.source_pool_id+" | target "+s.target_pool_id;
         ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
         RMContextMarker(label,s.trigger_bar,s.entry,s.direction>0 ? "BUY" : "SELL",ink);
         ObjectSetString(0,label,OBJPROP_TOOLTIP,tip); ICTKeepObject(keep,name); ICTKeepObject(keep,label);
        }
      ICTReconcileObjects(prefix,keep);
     }
   void RenderPlan(const string prefix,const SICTSignalResult &s,const bool visible)
     {
      string keep[];
      if(visible && s.confirmed)
        {
         datetime edge=ICTVisualEdge(s.frames.ltf,s.asof,8);
         ICTFiniteLine(prefix+"target",s.trigger_bar,edge,s.tp1,clrLimeGreen,STYLE_SOLID);
         ObjectSetString(0,prefix+"target",OBJPROP_TOOLTIP,s.id+" | Target pool "+s.target_pool_id);
         ICTKeepObject(keep,prefix+"target");
         if(s.source_price>0 && s.source_event_time>0)
           {
            ICTFiniteLine(prefix+"source",s.source_event_time,s.asof,s.source_price,clrGold,STYLE_DASH);
            ObjectSetString(0,prefix+"source",OBJPROP_TOOLTIP,s.id+" | Source pool "+s.source_pool_id+" | "+s.liquidity_event);
            ICTKeepObject(keep,prefix+"source");
            string name=prefix+"event_to_entry";
            if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,s.source_event_time,s.source_price,s.trigger_bar,s.entry);
            ObjectMove(0,name,0,s.source_event_time,s.source_price); ObjectMove(0,name,1,s.trigger_bar,s.entry);
            ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,name,OBJPROP_COLOR,clrGold); ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
            ObjectSetString(0,name,OBJPROP_TOOLTIP,"Confirmed source event -> entry | "+s.id);
            ICTKeepObject(keep,name);
           }
         string bracket=prefix+"risk_bracket";
         if(ObjectFind(0,bracket)<0) ObjectCreate(0,bracket,OBJ_TREND,0,s.asof,s.stop,s.asof,s.tp1);
         ObjectMove(0,bracket,0,s.asof,s.stop); ObjectMove(0,bracket,1,s.asof,s.tp1);
         ObjectSetInteger(0,bracket,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,bracket,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,bracket,OBJPROP_COLOR,clrDodgerBlue);
         ObjectSetString(0,bracket,OBJPROP_TOOLTIP,s.id+" | SL -> Entry -> liquidity TP | net RR="+DoubleToString(s.rr,2)+" | advisory plan, not a forecast");
         ICTKeepObject(keep,bracket);
        }
      ICTReconcileObjects(prefix,keep);
     }
  };
#endif
