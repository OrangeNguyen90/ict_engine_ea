#ifndef SRMP_ORDER_BLOCK_SCORING_MQH
#define SRMP_ORDER_BLOCK_SCORING_MQH

#include "OrderBlockDetector.mqh"

struct SOBScoreWeights
  {
   int sweep;
   int break_structure;
   int fvg;
   int displacement;
   int session;
   int premium_discount;
  };

void SRMPDefaultOBWeights(SOBScoreWeights &weights)
  {
   weights.sweep=20;
   weights.break_structure=25;
   weights.fvg=20;
   weights.displacement=15;
   weights.session=10;
   weights.premium_discount=10;
  }

bool SRMPScoreOrderBlock(SOrderBlock &block,const SOBScoreWeights &weights)
  {
   block.score=0;
   int total=weights.sweep+weights.break_structure+weights.fvg+
             weights.displacement+weights.session+weights.premium_discount;
   if(total!=100 || weights.sweep<0 || weights.break_structure<0 ||
      weights.fvg<0 || weights.displacement<0 || weights.session<0 ||
      weights.premium_discount<0) return false;
   if(block.state!=SRMP_OB_CONFIRMED) return true;
   block.score=(block.liquidity_sweep ? weights.sweep : 0)+
               (block.break_confirmed ? weights.break_structure : 0)+
               (block.fvg ? weights.fvg : 0)+
               (block.displacement ? weights.displacement : 0)+
               (block.session_match ? weights.session : 0)+
               (block.pd_match ? weights.premium_discount : 0);
   return true;
  }

#endif
