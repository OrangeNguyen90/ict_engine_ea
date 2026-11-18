#ifndef ICT_SWEEP_SEQUENCE_MQH
#define ICT_SWEEP_SEQUENCE_MQH
#include "MarketStructure.mqh"

#define ICT_SWEEP_SEQUENCE_MAX 32
#define ICT_SWEEP_SNAPSHOT_MAX 64
enum ENUM_ICT_SWEEP_STATUS { ICT_SWEEP_CANDIDATE=0, ICT_SWEEP_CONFIRMED=1, ICT_SWEEP_INVALIDATED=2 };
enum ENUM_ICT_SWEEP_MODE { SWEEP_1_ALLOWED=0, SWEEP_2_PREFERRED=1, SWEEP_2_REQUIRED=2 };
struct SICTSweepRecord
  {
   string pool_id;
   int side,number; // side +1 BSL / -1 SSL
   ENUM_ICT_SWEEP_STATUS status;
   double level,extreme,depth;
   datetime event_time,confirmed_at;
  };
struct SICTSweepSequence
  {
   string pool_id;
   int side,count,bars_after_confirmation,candidate_age,outside_closes;
   double level;
   datetime available_at,last_bar;
   bool valid,armed,candidate;
   SICTSweepRecord events[ICT_SWEEP_SEQUENCE_MAX];
  };

void ICTSweepSequenceStart(SICTSweepSequence &s,const string pool_id,const int side,
                           const double level,const datetime available_at)
  {
   ZeroMemory(s);
   if(pool_id=="" || (side!=1 && side!=-1) || !MathIsValidNumber(level) ||
      level<=0 || available_at<=0) return;
   s.pool_id=pool_id; s.side=side; s.level=level; s.available_at=available_at;
   s.valid=true; s.armed=true;
  }

// Closed candles only. A pool must reject away on a later candle and satisfy
// the bar spacing before another excursion can become an independent event.
void ICTSweepSequenceStep(SICTSweepSequence &s,const MqlRates &bar,const int seconds,
                          const double penetration,const double rejection,
                          const int min_bars,const int validation_bars,
                          const int invalidation_closes,const datetime actual_close=0)
  {
   if(!s.valid || seconds<=0 || !SRMPValidDetectorBar(bar) || bar.time<s.available_at ||
      bar.time<=s.last_bar || !MathIsValidNumber(penetration) || penetration<0 ||
      !MathIsValidNumber(rejection) || rejection<0 || min_bars<1 || validation_bars<1 ||
      invalidation_closes<1) return;
   s.last_bar=bar.time;
   double extreme=(s.side>0 ? bar.high : bar.low);
   double excursion=(extreme-s.level)*s.side;
   double outside=(bar.close-s.level)*s.side;
   if(outside>penetration) s.outside_closes++; else s.outside_closes=0;
   if(s.outside_closes>=invalidation_closes)
     {
      if(s.candidate && s.count>0) s.events[s.count-1].status=ICT_SWEEP_INVALIDATED;
      s.valid=false; s.candidate=false; return;
     }
   if(!s.armed && !s.candidate)
     {
      s.bars_after_confirmation++;
      if(s.bars_after_confirmation>=min_bars && outside<=-rejection)
         s.armed=true;
      return; // Rearm and a new sweep cannot happen on the same candle.
     }
   if(s.armed && !s.candidate && excursion>penetration)
     {
      if(s.count>=ICT_SWEEP_SEQUENCE_MAX) { s.valid=false; return; }
      SICTSweepRecord e; ZeroMemory(e);
      e.pool_id=s.pool_id; e.side=s.side; e.number=s.count+1;
      e.level=s.level; e.extreme=extreme; e.depth=excursion;
      e.event_time=bar.time; e.status=ICT_SWEEP_CANDIDATE;
      s.events[s.count++]=e; s.candidate=true; s.armed=false; s.candidate_age=0;
     }
   if(!s.candidate) return;
   int n=s.count-1;
   if(excursion>s.events[n].depth)
     { s.events[n].depth=excursion; s.events[n].extreme=extreme; s.events[n].event_time=bar.time; }
   s.candidate_age++;
   if(outside<0)
     {
      s.events[n].status=ICT_SWEEP_CONFIRMED;
      s.events[n].confirmed_at=(actual_close>bar.time ? actual_close : bar.time+seconds);
      s.candidate=false; s.bars_after_confirmation=0; return;
     }
   if(s.candidate_age>=validation_bars)
     { s.events[n].status=ICT_SWEEP_INVALIDATED; s.candidate=false; s.valid=false; } // no silent reuse of an unresolved pool
  }
#endif
