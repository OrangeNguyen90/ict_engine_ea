#ifndef ICT_REJECTION_BREAKER_FIXTURES_MQH
#define ICT_REJECTION_BREAKER_FIXTURES_MQH

void TestICTRejectionBreakerDetectors()
  {
   MqlRates bars[]; FlatFixture(bars,60);
   FixtureBar(bars[49],bars[49].time,100,120,98,100);
   FixtureBar(bars[50],bars[50].time,95,101,89,100);
   FixtureBar(bars[51],bars[51].time,100,102,98,100);
   FixtureBar(bars[52],bars[52].time,100,102,98,100);
   FixtureBar(bars[53],bars[53].time,100,130,99,129);
   SICTChartBlockSignal signal;
   Check("RB confirms only after swing rejection, displacement and MSS",
      ICTFindRejectionBlockFromRates(bars,60,0.50,0.60,1.20,5,300,signal) && signal.direction==1 &&
      signal.formed_at==bars[50].time && signal.confirmed_at==bars[54].time && signal.swept && signal.mss);
   FixtureBar(bars[53],bars[53].time,100,130,99,119);
   Check("long rejection wick without MSS is not confirmed RB",
      !ICTFindRejectionBlockFromRates(bars,60,0.50,0.60,1.20,5,300,signal));

   OBFixture(bars,2);
   SOrderBlock original; ZeroMemory(original);
   Check("breaker fixture starts with a confirmed bullish OB",
      SRMPFindOrderBlockFromRates(bars,54,SRMP_OB_HYBRID,0.1,3,original,1,false,48) &&
      original.state==SRMP_OB_CONFIRMED);
   if(original.state==SRMP_OB_CONFIRMED)
     {
      FixtureBar(bars[54],bars[54].time,100,101,original.lower-1.0,original.lower-0.1);
      for(int i=55;i<60;i++) FixtureBar(bars[i],bars[i].time,100,101,99,100);
     }
   Check("failed OB without post-failure sweep and MSS is not a breaker",
      !ICTFindBreakerBlockFromRates(bars,60,SRMP_OB_HYBRID,1.2,0.60,1.20,5,300,signal));
  }

#endif