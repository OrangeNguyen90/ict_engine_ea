#ifndef ICT_SESSION_LIQUIDITY_FIXTURES_MQH
#define ICT_SESSION_LIQUIDITY_FIXTURES_MQH

#include "../Include/ICTSessionLiquidity.mqh"

// Caller supplies Check(string,bool), as in ICTUnifiedCoreFixtures.mqh.
void ICTSessionFixtureBar(MqlRates &bar,const datetime wall,const double high,const double low)
  {
   ZeroMemory(bar);
   bar.time=wall; bar.high=high; bar.low=low; bar.open=(high+low)/2; bar.close=bar.open;
  }

void TestICTSessionLiquidity()
  {
   SICTSessionOffset local[],broker[];
   ArrayResize(local,1); ArrayResize(broker,1);
   local[0].from_utc=D'2026.01.01'; local[0].to_utc=D'2027.01.01'; local[0].minutes_east=0;
   broker[0].from_utc=local[0].from_utc; broker[0].to_utc=local[0].to_utc; broker[0].minutes_east=120;
   SICTSessionDefinition d; d.kind=ICT_SESSION_ASIA; d.start_minute=22*60; d.end_minute=2*60;
   MqlRates bars[]; ArrayResize(bars,5);
   ICTSessionFixtureBar(bars[0],D'2026.06.02 00:00',101,90);
   ICTSessionFixtureBar(bars[1],D'2026.06.02 01:00',103,91);
   ICTSessionFixtureBar(bars[2],D'2026.06.02 02:00',102,88);
   ICTSessionFixtureBar(bars[3],D'2026.06.02 03:00',100,89);
   ICTSessionFixtureBar(bars[4],D'2026.06.02 04:00',999,1); // Future suffix, outside session.
   SICTSessionLiquidity result;
   Check("Asia crossing midnight, broker UTC+2 and closed bars",
      ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.02 02:00',result) &&
      result.status==ICT_SESSION_READY && result.high==103 && result.low==88 && result.bar_count==4 &&
      result.start_utc==D'2026.06.01 22:00' && result.confirmed_utc==D'2026.06.02 02:00');
   Check("session not confirmed one second before end",
      !ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.02 01:59:59',result) &&
      result.status==ICT_SESSION_NOT_CLOSED);
   bars[4].time=D'2028.06.02 04:00';
   Check("future suffix outside offset schedule cannot change confirmed result",
      ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.02 02:00',result) &&
      result.high==103 && result.low==88);
   bars[1].time=bars[0].time;
   Check("duplicate slot rejected",!ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.02 02:00',result) &&
      result.status==ICT_SESSION_INCOMPLETE_DATA);
   bars[1].time=D'2026.06.02 05:00';
   Check("missing slot rejected",!ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.02 02:00',result) &&
      result.status==ICT_SESSION_INCOMPLETE_DATA && result.high==0 && result.low==0 && result.bar_count==0);
   bars[1].time=D'2026.06.02 01:00'; bars[1].low=0;
   Check("invalid OHLC rejected",!ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.02 02:00',result) &&
      result.status==ICT_SESSION_INVALID_BAR);
   bars[1].low=91;
   bars[1].open=bars[1].high+1;
   Check("invalid candle open rejected",!ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.02 02:00',result) &&
      result.status==ICT_SESSION_INVALID_BAR);
   bars[1].open=(bars[1].high+bars[1].low)/2;
   Check("incompatible timeframe rejected",!ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,5400,D'2026.06.02 02:00',result) &&
      result.status==ICT_SESSION_BAD_CONFIG);
   broker[0].to_utc=D'2026.06.02 00:00';
   Check("broker offset coverage required",!ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.02 02:00',result));
   broker[0].to_utc=D'2027.01.01'; broker[0].minutes_east=0;
   local[0].minutes_east=60;
   d.kind=ICT_SESSION_LONDON; d.start_minute=8*60; d.end_minute=10*60;
   ArrayResize(bars,2);
   ICTSessionFixtureBar(bars[0],D'2026.06.01 07:00',104,90);
   ICTSessionFixtureBar(bars[1],D'2026.06.01 08:00',101,87);
   Check("London local daylight offset mapped independently from broker",
      ICTBuildSessionLiquidity(d,D'2026.06.01',local,broker,bars,3600,D'2026.06.01 09:00',result) &&
      result.kind==ICT_SESSION_LONDON && result.high==104 && result.low==87);

   // New York: US spring transition on 2026-03-08 at 07:00 UTC.
   ArrayResize(local,2);
   local[0].from_utc=D'2026.01.01'; local[0].to_utc=D'2026.03.08 07:00'; local[0].minutes_east=-300;
   local[1].from_utc=local[0].to_utc; local[1].to_utc=D'2027.01.01'; local[1].minutes_east=-240;
   d.kind=ICT_SESSION_NEW_YORK; d.start_minute=0; d.end_minute=4*60;
   ArrayResize(bars,3);
   ICTSessionFixtureBar(bars[0],D'2026.03.08 05:00',101,90);
   ICTSessionFixtureBar(bars[1],D'2026.03.08 06:00',105,91);
   ICTSessionFixtureBar(bars[2],D'2026.03.08 07:00',102,89);
   Check("spring DST changes session elapsed duration",
      ICTBuildSessionLiquidity(d,D'2026.03.08',local,broker,bars,3600,D'2026.03.08 08:00',result) &&
      result.start_utc==D'2026.03.08 05:00' && result.end_utc==D'2026.03.08 08:00' && result.high==105 && result.bar_count==3);
   d.start_minute=2*60+30;
   Check("spring nonexistent local boundary rejected",
      !ICTBuildSessionLiquidity(d,D'2026.03.08',local,broker,bars,1800,D'2026.03.08 09:00',result) &&
      result.status==ICT_SESSION_AMBIGUOUS_TIME);

   // New York: US autumn transition on 2026-11-01 at 06:00 UTC.
   local[0].to_utc=D'2026.11.01 06:00'; local[0].minutes_east=-240;
   local[1].from_utc=local[0].to_utc; local[1].minutes_east=-300;
   d.start_minute=0; d.end_minute=4*60;
   ArrayResize(bars,5);
   for(int i=0;i<5;i++) ICTSessionFixtureBar(bars[i],D'2026.11.01 04:00'+i*3600,100+i,90-i);
   Check("fall DST includes repeated hour once in UTC",
      ICTBuildSessionLiquidity(d,D'2026.11.01',local,broker,bars,3600,D'2026.11.01 09:00',result) &&
      result.bar_count==5 && result.low==86 && result.end_utc==D'2026.11.01 09:00');
   d.start_minute=90;
   Check("fall repeated local boundary rejected",
      !ICTBuildSessionLiquidity(d,D'2026.11.01',local,broker,bars,1800,D'2026.11.01 09:00',result) &&
      result.status==ICT_SESSION_AMBIGUOUS_TIME);
   d.start_minute=0; ArrayResize(broker,2);
   broker[0].from_utc=local[0].from_utc; broker[0].to_utc=local[0].to_utc; broker[0].minutes_east=local[0].minutes_east;
   broker[1].from_utc=local[1].from_utc; broker[1].to_utc=local[1].to_utc; broker[1].minutes_east=local[1].minutes_east;
   ICTSessionFixtureBar(bars[0],D'2026.11.01 01:00',101,90);
   Check("ambiguous broker timestamp rejected",
      !ICTBuildSessionLiquidity(d,D'2026.11.01',local,broker,bars,3600,D'2026.11.01 09:00',result) &&
      result.status==ICT_SESSION_AMBIGUOUS_TIME);
   local[1].from_utc++;
   Check("schedule gap rejected",!ICTBuildSessionLiquidity(d,D'2026.11.01',local,broker,bars,3600,D'2026.11.01 09:00',result) &&
      result.status==ICT_SESSION_BAD_SCHEDULE);
  }

#endif
