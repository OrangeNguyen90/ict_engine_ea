#ifndef SRMP_ORDER_BLOCK_RENDERER_MQH
#define SRMP_ORDER_BLOCK_RENDERER_MQH

#include "DashboardComponents.mqh"
#include "OrderBlockDetector.mqh"

void SRMPClearOBObjects(const string prefix)
  {
   ObjectDelete(0,prefix+"zone");
   ObjectDelete(0,prefix+"mid");
   ObjectDelete(0,prefix+"upper");
   ObjectDelete(0,prefix+"lower");
   ObjectDelete(0,prefix+"label");
  }

void SRMPRenderOrderBlock(const string prefix,const SOrderBlock &block,
                          const datetime chart_edge,const bool show_inactive)
  {
   if(block.formation_time<=0 || block.upper<=block.lower ||
      (!show_inactive && block.state!=SRMP_OB_CONFIRMED))
     { SRMPClearOBObjects(prefix); return; }
   color ink=(block.state==SRMP_OB_CONFIRMED ?
              (block.direction>0 ? C'46,110,72' : C'139,58,67') :
              C'89,89,89');
   RMContextZone(prefix+"zone",block.formation_time,chart_edge,
                 block.lower,block.upper,ink);
   ObjectSetString(0,prefix+"zone",OBJPROP_TOOLTIP,StringFormat("%s OB | score %d | %s",
                   block.direction>0 ? "Bullish" : "Bearish",block.score,SRMPOBStateText(block.state)));
   RMContextLine(prefix+"mid",block.midpoint,ink,"OB midpoint 50 percent");
   RMContextLine(prefix+"upper",block.upper,ink,"OB upper");
   RMContextLine(prefix+"lower",block.lower,ink,"OB lower");
   RMContextMarker(prefix+"label",block.confirmation_time,block.upper,
                   StringFormat("%s OB %d %s",block.direction>0 ? "Bull" : "Bear",
                                block.score,SRMPOBStateText(block.state)),ink);
  }

#endif
