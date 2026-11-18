#ifndef SRMP_CHART_ANALYSIS_RENDERER_MQH
#define SRMP_CHART_ANALYSIS_RENDERER_MQH

#include "MarketContext.mqh"
#include "ICTConfluenceEngine.mqh"
#include "OrderBlockRenderer.mqh"
#include "SMTChartRenderer.mqh"

void SRMPClearChartAnalysis(const string prefix)
  {
   ObjectDelete(0,prefix+"fvg");
   ObjectDelete(0,prefix+"fvg_mid");
   ObjectDelete(0,prefix+"fvg_label");
   ObjectDelete(0,prefix+"premium");
   ObjectDelete(0,prefix+"discount");
   ObjectDelete(0,prefix+"premium_label");
   ObjectDelete(0,prefix+"discount_label");
   ObjectDelete(0,prefix+"equilibrium");
   ObjectDelete(0,prefix+"bsl");
   ObjectDelete(0,prefix+"ssl");
   ObjectDelete(0,prefix+"eqh");
   ObjectDelete(0,prefix+"eql");
   ObjectDelete(0,prefix+"eqh_label");
   ObjectDelete(0,prefix+"eql_label");
   ObjectDelete(0,prefix+"sweep");
   ObjectDelete(0,prefix+"sweep_arrow");
   ObjectDelete(0,prefix+"bos");
   SRMPClearOBObjects(prefix+"ob_");
   SRMPClearSMTObjects(prefix+"smt1_");
   SRMPClearSMTObjects(prefix+"smt2_");
  }

void SRMPRenderChartAnalysis(const string prefix,
                             const SMarketContextSnapshot &market,
                             const SICTSnapshot &ict,
                             const ENUM_TIMEFRAMES structure_tf,
                             const ENUM_TIMEFRAMES smt_tf,
                             const ENUM_TIMEFRAMES setup_tf,
                             const datetime edge,
                             const bool show_fvg,
                             const bool show_ob,
                             const bool show_smt,
                             const bool show_pd,
                             const bool show_liquidity,
                             const bool show_structure,
                             const bool show_inactive_ob,
                             const bool show_inactive_fvg=false)
  {
   if(show_ob && ict.ob_available && ict.ob.formation_time>0 && ict.ob.upper>ict.ob.lower &&
      (show_inactive_ob || ict.ob.state==SRMP_OB_CONFIRMED) &&
      ICTChartReserveZone(setup_tf,ict.ob.formation_time,edge,ict.ob.lower,ict.ob.upper))
      SRMPRenderOrderBlock(prefix+"ob_",ict.ob,edge,show_inactive_ob);
   else SRMPClearOBObjects(prefix+"ob_");
   if(show_smt && ict.smt1_available &&
      (ict.smt1.state==SRMP_SMT_BULLISH || ict.smt1.state==SRMP_SMT_BEARISH))
      SRMPRenderSMT(prefix+"smt1_",ict.smt1,smt_tf);
   else SRMPClearSMTObjects(prefix+"smt1_");
   if(show_smt && ict.smt2_available &&
      (ict.smt2.state==SRMP_SMT_BULLISH || ict.smt2.state==SRMP_SMT_BEARISH))
      SRMPRenderSMT(prefix+"smt2_",ict.smt2,smt_tf);
   else SRMPClearSMTObjects(prefix+"smt2_");

   if(show_fvg && market.gap_ready && market.gap.formed_time>0 &&
      (show_inactive_fvg || !market.gap.mitigated) &&
      ICTChartReserveZone(setup_tf,market.gap.formed_time,edge,market.gap.lower,market.gap.upper))
     {
      color ink=(market.gap.mitigated ? C'160,160,160' : C'118,161,225');
      RMContextZone(prefix+"fvg",market.gap.formed_time,edge,
                    market.gap.lower,market.gap.upper,ink);
      ObjectSetString(0,prefix+"fvg",OBJPROP_TOOLTIP,(market.gap.direction>0 ? "Bullish FVG" : "Bearish FVG")+
                      " | "+EnumToString(setup_tf)+" | "+SRMPFVGStatusText(market.gap.status));
      RMContextLine(prefix+"fvg_mid",(market.gap.lower+market.gap.upper)/2.0,
                    ink,"FVG 50% midpoint");
      RMContextMarker(prefix+"fvg_label",market.gap.formed_time,
                      market.gap.upper,(market.gap.direction>0 ? "Bullish FVG" : "Bearish FVG")+
                      " | "+SRMPFVGStatusText(market.gap.status)+
                      (market.gap.inversion_evidence ? " | IFVG inversion evidence" : ""),
                      market.gap.direction>0 ? C'25,118,69' : C'174,54,60');
     }
   else
     {
      ObjectDelete(0,prefix+"fvg");
      ObjectDelete(0,prefix+"fvg_mid");
      ObjectDelete(0,prefix+"fvg_label");
     }

   bool range=market.structure_ready &&
              market.structure.recent_high>market.structure.recent_low &&
              market.structure.recent_high_time>0 &&
              market.structure.recent_low_time>0;
   datetime label_time=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,5);
   if(label_time<=0) label_time=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,1);
   if(show_pd && range && ICTChartZoneTimeframe(structure_tf))
     {
      datetime start=(datetime)MathMax((double)market.structure.recent_high_time,
                                        (double)market.structure.recent_low_time);
      double mid=market.equilibrium;
      RMContextZone(prefix+"premium",start,edge,mid,
                    market.structure.recent_high,C'244,214,215');
      RMContextZone(prefix+"discount",start,edge,
                    market.structure.recent_low,mid,C'206,238,215');
      RMContextLine(prefix+"equilibrium",mid,C'142,114,62',
                    "Dealing range equilibrium 50%");
      RMContextMarker(prefix+"premium_label",label_time,(mid+market.structure.recent_high)/2.0,
                      "PREMIUM | "+EnumToString(structure_tf),C'145,50,56');
      RMContextMarker(prefix+"discount_label",label_time,(mid+market.structure.recent_low)/2.0,
                      "DISCOUNT | "+EnumToString(structure_tf),C'32,120,65');
     }
   else
     {
      ObjectDelete(0,prefix+"premium");
      ObjectDelete(0,prefix+"discount");
      ObjectDelete(0,prefix+"equilibrium");
      ObjectDelete(0,prefix+"premium_label");
      ObjectDelete(0,prefix+"discount_label");
     }
   if(show_liquidity && market.liquidity_ready)
     {
      RMContextLine(prefix+"bsl",market.liquidity.previous_day_high,
                    C'186,107,56',"BSL previous day high");
      RMContextLine(prefix+"ssl",market.liquidity.previous_day_low,
                    C'44,136,174',"SSL previous day low");
      RMContextLine(prefix+"eqh",market.liquidity.equal_highs ? market.structure.recent_high : 0,
                    clrOrange,"EQH internal buy-side liquidity");
      RMContextLine(prefix+"eql",market.liquidity.equal_lows ? market.structure.recent_low : 0,
                    clrDeepSkyBlue,"EQL internal sell-side liquidity");
      RMContextMarker(prefix+"eqh_label",label_time,market.liquidity.equal_highs ? market.structure.recent_high : 0,
                      "EQH",clrDarkOrange);
      RMContextMarker(prefix+"eql_label",label_time,market.liquidity.equal_lows ? market.structure.recent_low : 0,
                      "EQL",clrDeepSkyBlue);
      if(market.liquidity.recent_sweep_time>0)
        {
         string arrow=prefix+"sweep_arrow";
         ENUM_OBJECT kind=(market.liquidity.recent_sweep_direction>0 ?
                           OBJ_ARROW_UP : OBJ_ARROW_DOWN);
         if(ObjectFind(0,arrow)>=0 &&
            (ENUM_OBJECT)ObjectGetInteger(0,arrow,OBJPROP_TYPE)!=kind)
            ObjectDelete(0,arrow);
         if(ObjectFind(0,arrow)<0)
            ObjectCreate(0,arrow,kind,0,
                         market.liquidity.recent_sweep_time,
                         market.liquidity.recent_sweep_extreme);
         ObjectMove(0,arrow,0,market.liquidity.recent_sweep_time,
                    market.liquidity.recent_sweep_extreme);
         ObjectSetInteger(0,arrow,OBJPROP_COLOR,C'163,89,19');
         ObjectSetInteger(0,arrow,OBJPROP_WIDTH,2);
         ObjectSetInteger(0,arrow,OBJPROP_SELECTABLE,false);
         double offset=SymbolInfoDouble(_Symbol,SYMBOL_POINT)*20.0;
         RMContextMarker(prefix+"sweep",market.liquidity.recent_sweep_time,
                         market.liquidity.recent_sweep_extreme+
                         (market.liquidity.recent_sweep_direction>0 ? -offset : offset),
                         market.liquidity.recent_sweep_direction>0 ?
                           (market.liquidity.recent_sweep_daily ?
                            "SWEEP LOW / PDL" : "SWEEP LOCAL LOW") :
                           (market.liquidity.recent_sweep_daily ?
                            "SWEEP HIGH / PDH" : "SWEEP LOCAL HIGH"),
                         C'163,89,19');
        }
      else
        {
         ObjectDelete(0,prefix+"sweep");
         ObjectDelete(0,prefix+"sweep_arrow");
        }
     }
   else
     {
      ObjectDelete(0,prefix+"bsl");
      ObjectDelete(0,prefix+"ssl");
      ObjectDelete(0,prefix+"eqh");
      ObjectDelete(0,prefix+"eql");
      ObjectDelete(0,prefix+"eqh_label");
      ObjectDelete(0,prefix+"eql_label");
      ObjectDelete(0,prefix+"sweep");
      ObjectDelete(0,prefix+"sweep_arrow");
     }
   if(show_structure && range && market.structure.bos_time>0)
      RMContextMarker(prefix+"bos",market.structure.bos_time,
                      market.structure.bos_level,
                      market.structure.mss ? "MSS "+EnumToString(structure_tf) :
                                             "BOS "+EnumToString(structure_tf),
                      C'135,90,31');
   else ObjectDelete(0,prefix+"bos");
  }

#endif
