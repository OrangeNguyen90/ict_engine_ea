#ifndef SRMP_ORDER_BLOCK_VALIDATOR_MQH
#define SRMP_ORDER_BLOCK_VALIDATOR_MQH

#include "OrderBlockDetector.mqh"

void SRMPValidateOrderBlock(const string symbol,const ENUM_TIMEFRAMES timeframe,
                            const ENUM_SRMP_OB_MITIGATION mitigation,
                            const ENUM_SRMP_OB_INVALIDATION invalidation,
                            const int expiry_bars,SOrderBlock &block)
  {
   if(block.state!=SRMP_OB_CONFIRMED || expiry_bars<1) return;
   MqlRates later[];
   ArraySetAsSeries(later,false);
   datetime last_closed=iTime(symbol,timeframe,1);
   int confirmation_shift=iBarShift(symbol,timeframe,block.confirmation_time,true);
   if(last_closed<=0 || confirmation_shift<1)
     { block.state=SRMP_OB_NONE; return; }
   if(last_closed==block.confirmation_time) return;
   int count=CopyRates(symbol,timeframe,block.confirmation_time+1,last_closed,later);
   if(count<=0 || count!=confirmation_shift-1)
     { block.state=SRMP_OB_NONE; return; }
   SRMPValidateOrderBlockFromRates(later,count,mitigation,invalidation,expiry_bars,block);
  }

#endif
