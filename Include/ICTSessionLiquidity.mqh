#ifndef ICT_SESSION_LIQUIDITY_MQH
#define ICT_SESSION_LIQUIDITY_MQH

#include "MarketStructure.mqh"

// All offset intervals use UTC [from_utc,to_utc), in minutes east of UTC.
// Supply separate historical schedules for the broker and the session's
// local timezone, including every DST transition. No offset is inferred from
// the current terminal clock. Contiguous intervals cover the whole session.
struct SICTSessionOffset
  {
   datetime from_utc,to_utc;
   int minutes_east;
  };

enum ENUM_ICT_SESSION_KIND
  {
   ICT_SESSION_ASIA=0,
   ICT_SESSION_LONDON=1,
   ICT_SESSION_NEW_YORK=2
  };

enum ENUM_ICT_SESSION_RESULT
  {
   ICT_SESSION_READY=0,
   ICT_SESSION_BAD_CONFIG,
   ICT_SESSION_BAD_SCHEDULE,
   ICT_SESSION_AMBIGUOUS_TIME,
   ICT_SESSION_NOT_CLOSED,
   ICT_SESSION_INCOMPLETE_DATA,
   ICT_SESSION_INVALID_BAR
  };

struct SICTSessionDefinition
  {
   ENUM_ICT_SESSION_KIND kind;
   int start_minute,end_minute; // Local wall clock; end <= start crosses midnight.
  };

struct SICTSessionLiquidity
  {
   ENUM_ICT_SESSION_RESULT status;
   ENUM_ICT_SESSION_KIND kind;
   datetime start_utc,end_utc,confirmed_utc;
   double high,low;
   int bar_count;
  };

bool ICTSessionOffsetsValid(const SICTSessionOffset &schedule[])
  {
   int n=ArraySize(schedule);
   if(n<1) return false;
   for(int i=0;i<n;i++)
     {
      if(schedule[i].from_utc<=0 || schedule[i].to_utc<=schedule[i].from_utc ||
         schedule[i].minutes_east < -840 || schedule[i].minutes_east > 840)
         return false;
      if(i>0 && schedule[i-1].to_utc!=schedule[i].from_utc) return false;
     }
   return true;
  }

int ICTSessionOffsetAt(const SICTSessionOffset &schedule[],const datetime utc)
  {
   for(int i=0;i<ArraySize(schedule);i++)
      if(utc>=schedule[i].from_utc && utc<schedule[i].to_utc) return i;
   return -1;
  }

// Wall times in a skipped DST hour have no solution; repeated times have two.
// Both are rejected, as is any time outside the supplied offset schedule.
bool ICTSessionWallToUTC(const SICTSessionOffset &schedule[],const datetime wall,datetime &utc)
  {
   int matches=0;
   utc=0;
   for(int i=0;i<ArraySize(schedule);i++)
     {
      datetime candidate=wall-schedule[i].minutes_east*60;
      if(candidate>=schedule[i].from_utc && candidate<schedule[i].to_utc)
        { matches++; utc=candidate; }
     }
   if(matches!=1) { utc=0; return false; }
   return true;
  }

// local_midnight is 00:00 of the session's start date represented as a
// timezone-neutral datetime. bars are broker-wall timestamps from a fixed
// intraday period (seconds), including all closed bars in the session.
// Ordering is irrelevant. A session is usable only at/after its UTC end;
// every slot must be present exactly once, with no straddling DST transition.
// Bars outside a conservative broker-wall envelope are ignored, including
// future suffixes beyond the supplied schedule. Bars inside the envelope
// must map uniquely. Prices are published only when status is READY.
bool ICTBuildSessionLiquidity(const SICTSessionDefinition &definition,
                              const datetime local_midnight,
                              const SICTSessionOffset &session_offsets[],
                              const SICTSessionOffset &broker_offsets[],
                              const MqlRates &bars[],const int period_seconds,
                              const datetime as_of_utc,SICTSessionLiquidity &result)
  {
   ZeroMemory(result);
   result.kind=definition.kind;
   result.status=ICT_SESSION_BAD_CONFIG;
   if((int)definition.kind<(int)ICT_SESSION_ASIA || (int)definition.kind>(int)ICT_SESSION_NEW_YORK ||
      definition.start_minute<0 || definition.start_minute>=1440 ||
      definition.end_minute<0 || definition.end_minute>=1440 ||
      definition.start_minute==definition.end_minute || local_midnight<=0 ||
      (long)local_midnight%86400!=0 || period_seconds<60 || period_seconds>86400 ||
      period_seconds%60!=0 || as_of_utc<=0) return false;
   result.status=ICT_SESSION_BAD_SCHEDULE;
   if(!ICTSessionOffsetsValid(session_offsets) || !ICTSessionOffsetsValid(broker_offsets)) return false;
   datetime start_wall=local_midnight+definition.start_minute*60;
   datetime end_wall=local_midnight+definition.end_minute*60;
   if(definition.end_minute<definition.start_minute) end_wall+=86400;
   result.status=ICT_SESSION_AMBIGUOUS_TIME;
   if(!ICTSessionWallToUTC(session_offsets,start_wall,result.start_utc) ||
      !ICTSessionWallToUTC(session_offsets,end_wall,result.end_utc)) return false;
   if(result.end_utc<=result.start_utc ||
      ICTSessionOffsetAt(session_offsets,result.start_utc)<0 ||
      ICTSessionOffsetAt(session_offsets,result.end_utc-1)<0 ||
      ICTSessionOffsetAt(broker_offsets,result.start_utc)<0 ||
      ICTSessionOffsetAt(broker_offsets,result.end_utc-1)<0) return false;
   result.status=ICT_SESSION_BAD_CONFIG;
   long duration=result.end_utc-result.start_utc;
   if(duration%period_seconds!=0 || duration/period_seconds>1440) return false;
   result.status=ICT_SESSION_NOT_CLOSED;
   if(as_of_utc<result.end_utc) return false;
   datetime first_wall=0,last_wall=0;
   for(int k=0;k<ArraySize(broker_offsets);k++)
     {
      datetime from=(datetime)MathMax((long)result.start_utc,(long)broker_offsets[k].from_utc);
      datetime to=(datetime)MathMin((long)result.end_utc,(long)broker_offsets[k].to_utc);
      if(from>=to) continue;
      datetime wall_from=from+broker_offsets[k].minutes_east*60;
      datetime wall_to=to+broker_offsets[k].minutes_east*60;
      if(first_wall==0 || wall_from<first_wall) first_wall=wall_from;
      if(last_wall==0 || wall_to>last_wall) last_wall=wall_to;
     }
   int expected=(int)(duration/period_seconds);
   bool seen[];
   ArrayResize(seen,expected);
   ArrayInitialize(seen,false);
   double high=0,low=0;
   int count=0;
   result.status=ICT_SESSION_INCOMPLETE_DATA;
   for(int i=0;i<ArraySize(bars);i++)
     {
      if(bars[i].time<first_wall || bars[i].time>=last_wall) continue;
      datetime utc=0;
      if(!ICTSessionWallToUTC(broker_offsets,bars[i].time,utc))
        { result.status=ICT_SESSION_AMBIGUOUS_TIME; return false; }
      if(utc<result.start_utc || utc>=result.end_utc) continue;
      long elapsed=utc-result.start_utc;
      if(elapsed%period_seconds!=0) return false;
      int slot=(int)(elapsed/period_seconds);
      if(seen[slot]) return false;
      int begin_offset=ICTSessionOffsetAt(broker_offsets,utc);
      int end_offset=ICTSessionOffsetAt(broker_offsets,utc+period_seconds-1);
      if(begin_offset<0 || end_offset!=begin_offset)
        { result.status=ICT_SESSION_AMBIGUOUS_TIME; return false; }
      if(!SRMPValidDetectorBar(bars[i]) || bars[i].low<=0)
        { result.status=ICT_SESSION_INVALID_BAR; return false; }
      if(count==0 || bars[i].high>high) high=bars[i].high;
      if(count==0 || bars[i].low<low) low=bars[i].low;
      seen[slot]=true;
      count++;
     }
   if(count!=expected) return false;
   result.high=high; result.low=low; result.bar_count=count;
   result.status=ICT_SESSION_READY;
   result.confirmed_utc=result.end_utc;
   return true;
  }

#endif
