#ifndef SRMP_EMERGENCY_CONTROLLER_MQH
#define SRMP_EMERGENCY_CONTROLLER_MQH

#include <Trade/Trade.mqh>

struct SRetryRecord
  {
   ulong    ticket;
   int      attempts;
   datetime next_allowed;
  };

SRetryRecord g_order_retries[];
SRetryRecord g_position_retries[];

int SRMPFindRetry(SRetryRecord &records[],const ulong ticket)
  {
   for(int i=0;i<ArraySize(records);i++)
      if(records[i].ticket==ticket) return i;
   return -1;
  }

bool SRMPCanAttempt(SRetryRecord &records[],const ulong ticket,
                    const int max_attempts,bool &exhausted)
  {
   exhausted=false;
   int index=SRMPFindRetry(records,ticket);
   if(index<0) return true;
   if(records[index].attempts>=max_attempts)
     { exhausted=true; return false; }
   return TimeLocal()>=records[index].next_allowed;
  }

void SRMPRecordAttempt(SRetryRecord &records[],const ulong ticket,
                       const int retry_delay_seconds)
  {
   int index=SRMPFindRetry(records,ticket);
   if(index<0)
     {
      index=ArraySize(records);
      ArrayResize(records,index+1);
      records[index].ticket=ticket;
      records[index].attempts=0;
     }
   records[index].attempts++;
   int multiplier=(int)MathPow(2.0,(double)MathMin(records[index].attempts-1,5));
   records[index].next_allowed=TimeLocal()+retry_delay_seconds*multiplier;
  }

// Returns true only when no account-wide pending order or position remains.
// One controller invokes this function, with a persistent emergency latch.
bool SRMPProcessEmergency(CTrade &trade,const int max_attempts,
                          const int retry_delay_seconds,
                          const int deviation_points,bool &exhausted,
                          bool &had_failure)
  {
   exhausted=false;
   had_failure=false;
   if(TerminalInfoInteger(TERMINAL_CONNECTED)==0 ||
      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)==0 ||
      AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)==0)
      return false;

   // Pending orders are canceled first so they cannot create fresh exposure.
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket)) continue;
      bool item_exhausted=false;
      if(!SRMPCanAttempt(g_order_retries,ticket,max_attempts,item_exhausted))
        { if(item_exhausted) exhausted=true; continue; }
      ResetLastError();
      bool requested=trade.OrderDelete(ticket);
      uint retcode=trade.ResultRetcode();
      int request_error=GetLastError();
      bool still_open=OrderSelect(ticket);
      PrintFormat("EMERGENCY cancel order #%I64u sent=%d retcode=%u (%s) remains=%d error=%d",
                  ticket,(int)requested,retcode,trade.ResultRetcodeDescription(),
                  (int)still_open,request_error);
      if(still_open)
        {
         had_failure=true;
         SRMPRecordAttempt(g_order_retries,ticket,retry_delay_seconds);
        }
     }

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      bool item_exhausted=false;
      if(!SRMPCanAttempt(g_position_retries,ticket,max_attempts,item_exhausted))
        { if(item_exhausted) exhausted=true; continue; }
      string symbol=PositionGetString(POSITION_SYMBOL);
      trade.SetTypeFillingBySymbol(symbol);
      ResetLastError();
      bool requested=trade.PositionClose(ticket,(ulong)deviation_points);
      uint retcode=trade.ResultRetcode();
      int request_error=GetLastError();
      bool still_open=PositionSelectByTicket(ticket);
      PrintFormat("EMERGENCY close position #%I64u %s sent=%d retcode=%u (%s) remains=%d error=%d",
                  ticket,symbol,(int)requested,retcode,trade.ResultRetcodeDescription(),
                  (int)still_open,request_error);
      if(still_open)
        {
         had_failure=true;
         SRMPRecordAttempt(g_position_retries,ticket,retry_delay_seconds);
        }
     }

   return OrdersTotal()==0 && PositionsTotal()==0;
  }

#endif
