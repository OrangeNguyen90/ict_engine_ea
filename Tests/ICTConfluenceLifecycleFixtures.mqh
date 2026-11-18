#ifndef ICT_CONFLUENCE_LIFECYCLE_FIXTURES_MQH
#define ICT_CONFLUENCE_LIFECYCLE_FIXTURES_MQH

#include "../Include/ICTRangeEngine.mqh"

// Caller supplies Check(string,bool), as in ICTUnifiedCoreFixtures.mqh.
void TestICTConfluenceLifecycle()
  {
   SICTRangeSnapshot s; ZeroMemory(s);
   s.range.valid=true; s.range.id="R1"; s.as_of=2000; s.zone_count=2;
   s.zones[0].range_id="R1"; s.zones[1].range_id="R1";
   s.zones[0].membership=IR_INTERNAL; s.zones[1].membership=IR_INTERNAL;
   s.zones[0].type=IR_FVG; s.zones[1].type=IR_OB;
   s.zones[0].state=IR_FRESH; s.zones[1].state=IR_TOUCHED;
   s.zones[0].direction=1; s.zones[1].direction=1;
   s.zones[0].confirmed_at=1000; s.zones[1].confirmed_at=1500;
   s.zones[0].lower=100; s.zones[0].upper=105;
   s.zones[1].lower=103; s.zones[1].upper=108;
   ICTRangeUpdateZoneConfluence(s);
   Check("fresh/touched overlapping pair marks both zones",s.zones[0].confluence && s.zones[1].confluence);

   s.zones[0].state=IR_MITIGATED; ICTRangeUpdateZoneConfluence(s);
   Check("mitigated first zone clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[0].state=IR_FRESH; s.zones[1].state=IR_ZONE_INVALIDATED; ICTRangeUpdateZoneConfluence(s);
   Check("invalidated second zone clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].state=IR_FRESH; s.zones[1].range_id="R2"; ICTRangeUpdateZoneConfluence(s);
   Check("foreign range clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].range_id="R1"; s.zones[0].membership=IR_CROSSING; ICTRangeUpdateZoneConfluence(s);
   Check("non-internal first zone clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[0].membership=IR_INTERNAL; s.zones[1].membership=IR_OUTSIDE; ICTRangeUpdateZoneConfluence(s);
   Check("non-internal second zone clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].membership=IR_INTERNAL; s.zones[1].confirmed_at=2001; ICTRangeUpdateZoneConfluence(s);
   Check("future confirmation clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].confirmed_at=1500; s.zones[1].direction=-1; ICTRangeUpdateZoneConfluence(s);
   Check("opposite directions do not combine",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].direction=1; s.zones[1].lower=106; ICTRangeUpdateZoneConfluence(s);
   Check("separate zones do not combine",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].lower=103; s.zones[1].type=IR_FVG; ICTRangeUpdateZoneConfluence(s);
   Check("same type zones do not combine",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].type=IR_OB; s.zones[0].direction=-1; s.zones[1].direction=-1;
   ICTRangeUpdateZoneConfluence(s);
   Check("sell pair marks both zones",s.zones[0].confluence && s.zones[1].confluence);
   s.range.valid=false; ICTRangeUpdateZoneConfluence(s);
   Check("invalid owning range clears both",!s.zones[0].confluence && !s.zones[1].confluence);
  }
#endif
