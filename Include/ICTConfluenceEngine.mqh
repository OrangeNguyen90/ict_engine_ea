#ifndef SRMP_ICT_CONFLUENCE_ENGINE_MQH
#define SRMP_ICT_CONFLUENCE_ENGINE_MQH

#include "OrderBlockDetector.mqh"
#include "OrderBlockValidator.mqh"
#include "OrderBlockScoring.mqh"
#include "SMTDivergenceDetector.mqh"

enum ENUM_SRMP_ICT_RECOMMENDATION
  {
   SRMP_ICT_NO_TRADE=0, SRMP_ICT_WAIT_CONFIRMATION=1,
   SRMP_ICT_WAIT_RETRACE=2, SRMP_ICT_BULLISH_SETUP=3,
   SRMP_ICT_BEARISH_SETUP=4, SRMP_ICT_INVALIDATED=5
  };

struct SICTSettings
  {
   bool enable_ob;
   ENUM_TIMEFRAMES ob_timeframe;
   int ob_lookback;
   ENUM_SRMP_OB_BOUNDS ob_bounds;
   double displacement_factor;
   int confirmation_bars;
   ENUM_SRMP_OB_MITIGATION mitigation;
   ENUM_SRMP_OB_INVALIDATION invalidation;
   int expiry_bars;
   SOBScoreWeights weights;
   bool enable_smt;
   string comparison1;
   string comparison2;
   ENUM_TIMEFRAMES smt_timeframe;
   int smt_lookback;
   int pivot_left;
   int pivot_right;
   ENUM_SMT_CORRELATION correlation1;
   ENUM_SMT_CORRELATION correlation2;
   int correlation_window;
   int min_pairs;
   double correlation_threshold;
   int max_gap_bars;
  };

struct SICTSnapshot
  {
   SOrderBlock ob;
   SSMTDivergence smt1;
   SSMTDivergence smt2;
   bool ob_available;
   bool smt1_available;
   bool smt2_available;
   int score;
   ENUM_SRMP_ICT_RECOMMENDATION recommendation;
   datetime analyzed_bar;
  };

void SRMPDefaultICTSettings(SICTSettings &settings)
  {
   settings.enable_ob=true;
   settings.ob_timeframe=PERIOD_M15;
   settings.ob_lookback=120;
   settings.ob_bounds=SRMP_OB_HYBRID;
   settings.displacement_factor=1.2;
   settings.confirmation_bars=3;
   settings.mitigation=SRMP_OB_TOUCH;
   settings.invalidation=SRMP_OB_CLOSE;
   settings.expiry_bars=40;
   SRMPDefaultOBWeights(settings.weights);
   settings.enable_smt=true;
   settings.comparison1="";
   settings.comparison2="";
   settings.smt_timeframe=PERIOD_H1;
   settings.smt_lookback=80;
   settings.pivot_left=3;
   settings.pivot_right=3;
   settings.correlation1=SMT_AUTO;
   settings.correlation2=SMT_AUTO;
   settings.correlation_window=100;
   settings.min_pairs=60;
   settings.correlation_threshold=0.60;
   settings.max_gap_bars=3;
  }

bool SRMPValidICTSettings(const SICTSettings &settings)
  {
   int total=settings.weights.sweep+settings.weights.break_structure+
             settings.weights.fvg+settings.weights.displacement+
             settings.weights.session+settings.weights.premium_discount;
   return (settings.ob_lookback>=40 && settings.displacement_factor>0.0 &&
           settings.confirmation_bars>=1 && settings.confirmation_bars<=6 &&
           settings.expiry_bars>=1 && settings.smt_lookback>=30 &&
           settings.pivot_left>=1 && settings.pivot_right>=1 &&
           settings.correlation_window>=settings.min_pairs &&
           settings.min_pairs>=60 && settings.correlation_threshold>0.0 &&
           settings.correlation_threshold<=1.0 &&
           settings.max_gap_bars>=0 && total==100 &&
           StringLen(settings.comparison1)<=24 &&
           StringLen(settings.comparison2)<=24 &&
           (settings.comparison1=="" || settings.comparison1!=settings.comparison2));
  }

bool SRMPAnalyzeICT(const string symbol,const SICTSettings &settings,
                    SICTSnapshot &snapshot)
  {
   ZeroMemory(snapshot);
   snapshot.recommendation=SRMP_ICT_NO_TRADE;
   if(!SRMPValidICTSettings(settings)) return false;
   snapshot.analyzed_bar=iTime(symbol,settings.ob_timeframe,1);
   if(settings.enable_ob)
     {
      snapshot.ob_available=SRMPFindOrderBlock(symbol,settings.ob_timeframe,
                     settings.ob_lookback,settings.ob_bounds,
                     settings.displacement_factor,settings.confirmation_bars,
                     snapshot.ob);
      if(snapshot.ob_available)
        {
         SRMPValidateOrderBlock(symbol,settings.ob_timeframe,
                                settings.mitigation,settings.invalidation,
                                settings.expiry_bars,snapshot.ob);
         SRMPScoreOrderBlock(snapshot.ob,settings.weights);
        }
     }
   if(settings.enable_smt)
     {
      if(settings.comparison1!="")
         snapshot.smt1_available=SRMPFindSMT(symbol,settings.comparison1,
                     settings.smt_timeframe,settings.smt_lookback,
                     settings.pivot_left,settings.pivot_right,
                     settings.correlation1,settings.correlation_window,
                     settings.min_pairs,settings.correlation_threshold,
                     settings.max_gap_bars,snapshot.smt1);
      if(settings.comparison2!="")
         snapshot.smt2_available=SRMPFindSMT(symbol,settings.comparison2,
                     settings.smt_timeframe,settings.smt_lookback,
                     settings.pivot_left,settings.pivot_right,
                     settings.correlation2,settings.correlation_window,
                     settings.min_pairs,settings.correlation_threshold,
                     settings.max_gap_bars,snapshot.smt2);
     }
   bool configured=(settings.enable_smt &&
                    (settings.comparison1!="" || settings.comparison2!=""));
   bool aligned=(snapshot.smt1_available &&
                 snapshot.smt1.direction==snapshot.ob.direction) ||
                (snapshot.smt2_available &&
                 snapshot.smt2.direction==snapshot.ob.direction);
   if(snapshot.ob_available && snapshot.ob.state==SRMP_OB_CONFIRMED)
      snapshot.score=(int)MathRound(snapshot.ob.score*(configured ? 0.7 : 1.0)+
                                    (aligned ? 30.0 : 0.0));
   if(!snapshot.ob_available)
      snapshot.recommendation=SRMP_ICT_WAIT_CONFIRMATION;
   else if(snapshot.ob.state==SRMP_OB_INVALIDATED ||
           snapshot.ob.state==SRMP_OB_EXPIRED)
      snapshot.recommendation=SRMP_ICT_INVALIDATED;
   else if(snapshot.ob.state==SRMP_OB_MITIGATED)
      snapshot.recommendation=SRMP_ICT_WAIT_CONFIRMATION;
   else if(configured && !aligned)
      snapshot.recommendation=SRMP_ICT_WAIT_CONFIRMATION;
   else if(snapshot.score<70)
      snapshot.recommendation=SRMP_ICT_WAIT_CONFIRMATION;
   else snapshot.recommendation=SRMP_ICT_WAIT_RETRACE;
   return true;
  }

#endif
