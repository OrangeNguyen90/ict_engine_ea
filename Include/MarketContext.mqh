#ifndef SRMP_MARKET_CONTEXT_MQH
#define SRMP_MARKET_CONTEXT_MQH

#include "MarketStructure.mqh"
#include "LiquidityDetector.mqh"
#include "FVGDetector.mqh"
#include "AdviceBridge.mqh"

struct SMarketContextSnapshot
  {
   SMarketStructure higher;
   SMarketStructure structure;
   SFairValueGap gap;
   SLiquidityState liquidity;
   bool higher_ready;
   bool structure_ready;
   bool atr_ready;
   bool gap_ready;
   bool liquidity_ready;
   double atr;
   double equilibrium;
   datetime trigger_bar;
  };

void SRMPAnalyzeMarketContext(const string symbol,
                              const ENUM_TIMEFRAMES higher_tf,
                              const ENUM_TIMEFRAMES structure_tf,
                              const ENUM_TIMEFRAMES setup_tf,
                              const ENUM_TIMEFRAMES trigger_tf,
                              SMarketContextSnapshot &context)
  {
   ZeroMemory(context);
   context.trigger_bar=iTime(symbol,trigger_tf,1);
   context.higher_ready=SRMPAnalyzeStructure(symbol,higher_tf,120,2,context.higher);
   context.structure_ready=SRMPAnalyzeStructure(symbol,structure_tf,120,2,
                                                 context.structure);
   if(context.structure_ready)
      context.equilibrium=(context.structure.recent_high+
                           context.structure.recent_low)/2.0;
   int handle=iATR(symbol,structure_tf,14);
   double buffer[];
   context.atr_ready=(handle!=INVALID_HANDLE &&
                      CopyBuffer(handle,0,1,1,buffer)==1 && buffer[0]>0.0);
   if(context.atr_ready) context.atr=buffer[0];
   if(handle!=INVALID_HANDLE) IndicatorRelease(handle);
   double tolerance=(context.atr_ready ? context.atr*0.1 :
                     SymbolInfoDouble(symbol,SYMBOL_POINT)*10.0);
   context.liquidity_ready=SRMPAnalyzeLiquidity(symbol,trigger_tf,
                             context.structure,tolerance,
                             context.liquidity);
   if(context.liquidity_ready)
      SRMPFindRecentSweep(symbol,trigger_tf,96,context.liquidity);
   if(context.atr_ready)
      context.gap_ready=SRMPFindFVG(symbol,setup_tf,80,context.atr*0.05,
                                   context.gap);
  }

void SRMPPublishMarketContext(const string symbol,
                              const ENUM_TIMEFRAMES higher_tf,
                              const ENUM_TIMEFRAMES structure_tf,
                              const ENUM_TIMEFRAMES setup_tf,
                              const ENUM_TIMEFRAMES trigger_tf,
                              const SMarketContextSnapshot &c)
  {
   bool prior=GlobalVariableCheck(SRMPAdviceKey(symbol,"CTS"));
   bool revised=false;
   if(prior && c.structure_ready &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"H1HT"))==(double)c.structure.recent_high_time &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"H1HI"))!=c.structure.recent_high)
      revised=true;
   if(prior && c.structure_ready &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"H1LT"))==(double)c.structure.recent_low_time &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"H1LO"))!=c.structure.recent_low)
      revised=true;
   if(prior && c.structure.bos_time>0 &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"BOST"))==(double)c.structure.bos_time &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"BOSP"))!=c.structure.bos_level)
      revised=true;
   if(prior && c.gap_ready &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"FGT"))==(double)c.gap.formed_time &&
      (GlobalVariableGet(SRMPAdviceKey(symbol,"FGL"))!=c.gap.lower ||
       GlobalVariableGet(SRMPAdviceKey(symbol,"FGU"))!=c.gap.upper))
      revised=true;
   if(prior && c.liquidity.sweep_time>0 &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"SWT"))==(double)c.liquidity.sweep_time &&
      GlobalVariableGet(SRMPAdviceKey(symbol,"SWE"))!=c.liquidity.sweep_extreme)
      revised=true;
   GlobalVariableSet(SRMPAdviceKey(symbol,"CTS"),0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"HTF"),(double)higher_tf);
   GlobalVariableSet(SRMPAdviceKey(symbol,"STF"),(double)structure_tf);
   GlobalVariableSet(SRMPAdviceKey(symbol,"FTF"),(double)setup_tf);
   GlobalVariableSet(SRMPAdviceKey(symbol,"TTF"),(double)trigger_tf);
   GlobalVariableSet(SRMPAdviceKey(symbol,"CTBAR"),(double)c.trigger_bar);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H4OK"),c.higher_ready ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H1OK"),c.structure_ready ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"ATROK"),c.atr_ready ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"FGOK"),c.gap_ready ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"LQOK"),c.liquidity_ready ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H4BI"),(double)c.higher.bias);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H1BI"),(double)c.structure.bias);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H4HI"),c.higher.recent_high);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H4LO"),c.higher.recent_low);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H1HI"),c.structure.recent_high);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H1LO"),c.structure.recent_low);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H1HT"),(double)c.structure.recent_high_time);
   GlobalVariableSet(SRMPAdviceKey(symbol,"H1LT"),(double)c.structure.recent_low_time);
   GlobalVariableSet(SRMPAdviceKey(symbol,"BOS"),(double)c.structure.bos_direction);
   GlobalVariableSet(SRMPAdviceKey(symbol,"BOST"),(double)c.structure.bos_time);
   GlobalVariableSet(SRMPAdviceKey(symbol,"BOSP"),c.structure.bos_level);
   GlobalVariableSet(SRMPAdviceKey(symbol,"MSS"),c.structure.mss ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"EQ"),c.equilibrium);
   GlobalVariableSet(SRMPAdviceKey(symbol,"ATR"),c.atr);
   GlobalVariableSet(SRMPAdviceKey(symbol,"FGD"),(double)c.gap.direction);
   GlobalVariableSet(SRMPAdviceKey(symbol,"FGL"),c.gap.lower);
   GlobalVariableSet(SRMPAdviceKey(symbol,"FGU"),c.gap.upper);
   GlobalVariableSet(SRMPAdviceKey(symbol,"FGT"),(double)c.gap.formed_time);
   GlobalVariableSet(SRMPAdviceKey(symbol,"FGM"),c.gap.mitigated ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"PDH"),c.liquidity.previous_day_high);
   GlobalVariableSet(SRMPAdviceKey(symbol,"PDL"),c.liquidity.previous_day_low);
   GlobalVariableSet(SRMPAdviceKey(symbol,"EQH"),c.liquidity.equal_highs ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"EQL"),c.liquidity.equal_lows ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"SWB"),c.liquidity.bullish_sweep ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"SWS"),c.liquidity.bearish_sweep ? 1.0 : 0.0);
   GlobalVariableSet(SRMPAdviceKey(symbol,"SWE"),c.liquidity.sweep_extreme);
   GlobalVariableSet(SRMPAdviceKey(symbol,"SWT"),(double)c.liquidity.sweep_time);
   if(revised)
     {
      GlobalVariableSet(SRMPAdviceKey(symbol,"REV"),(double)TimeLocal());
      Print("Advisory confirmed history changed after broker history update: ",symbol);
     }
   GlobalVariableSet(SRMPAdviceKey(symbol,"CTS"),(double)TimeLocal());
  }

#endif
