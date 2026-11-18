#ifndef ICT_TIMEFRAME_MAPPER_MQH
#define ICT_TIMEFRAME_MAPPER_MQH

enum ENUM_ICT_MTF_MODE { ICT_MTF_AUTO=0, ICT_MTF_MANUAL=1 };
enum ENUM_ICT_MTF_STATUS { ICT_MTF_INVALID=0, ICT_MTF_FULL=1, ICT_MTF_TWO_TIER=2, ICT_MTF_ONE_TIER=3 };
enum ENUM_ICT_TIER_ALIGNMENT { ICT_TIER_INSUFFICIENT=0, ICT_TIER_NEUTRAL=1,
   ICT_TIER_CONFLICT=2, ICT_TIER_ALIGNED=3 };
struct SICTTimeframes
  {
   ENUM_TIMEFRAMES ltf,mtf,htf;
   ENUM_ICT_MTF_MODE mode;
   ENUM_ICT_MTF_STATUS status;
  };

ENUM_ICT_TIER_ALIGNMENT ICTTierAlignment(const bool data_ready,const int htf_bias,
                                         const int mtf_bias,const int ltf_direction)
  {
   if(!data_ready || htf_bias<-1 || htf_bias>1 || mtf_bias<-1 || mtf_bias>1 ||
      ltf_direction<-1 || ltf_direction>1) return ICT_TIER_INSUFFICIENT;
   if(htf_bias==0) return ICT_TIER_NEUTRAL;
   if(mtf_bias==0 || mtf_bias!=htf_bias || (ltf_direction!=0 && ltf_direction!=htf_bias))
      return ICT_TIER_CONFLICT;
   return ICT_TIER_ALIGNED;
  }

// PERIOD_CURRENT represents an absent tier in the result; it is never passed
// as an implicit substitute timeframe to a market data request.
bool ICTMapTimeframes(const ENUM_TIMEFRAMES chart,const ENUM_ICT_MTF_MODE mode,
                      const ENUM_TIMEFRAMES manual_mtf,const ENUM_TIMEFRAMES manual_htf,
                      SICTTimeframes &out)
  {
   ZeroMemory(out); out.ltf=chart; out.mode=mode;
   if(PeriodSeconds(chart)<=0 || chart==PERIOD_CURRENT) return false;
   if(mode==ICT_MTF_MANUAL)
     {
      if(manual_mtf==PERIOD_CURRENT)
        {
         if(chart!=PERIOD_MN1 || manual_htf!=PERIOD_CURRENT) return false;
         out.status=ICT_MTF_ONE_TIER; return true;
        }
      if(PeriodSeconds(manual_mtf)<=PeriodSeconds(chart)) return false;
      out.mtf=manual_mtf;
      if(manual_htf==PERIOD_CURRENT)
        {
         if(chart!=PERIOD_W1 || manual_mtf!=PERIOD_MN1) return false;
         out.status=ICT_MTF_TWO_TIER; return true;
        }
      if(PeriodSeconds(manual_htf)<=PeriodSeconds(manual_mtf)) return false;
      out.htf=manual_htf; out.status=ICT_MTF_FULL; return true;
     }
   if(mode!=ICT_MTF_AUTO) return false;
   switch(chart)
     {
      case PERIOD_M1: case PERIOD_M2: case PERIOD_M3: case PERIOD_M4:
         out.mtf=PERIOD_M15; out.htf=PERIOD_H4; break;
      case PERIOD_M5: case PERIOD_M6: case PERIOD_M10: case PERIOD_M12:
      case PERIOD_M15: case PERIOD_M20:
         out.mtf=PERIOD_H1; out.htf=PERIOD_D1; break;
      case PERIOD_M30: case PERIOD_H1:
         out.mtf=PERIOD_H4; out.htf=PERIOD_D1; break;
      case PERIOD_H2: case PERIOD_H3:
         out.mtf=PERIOD_H4; out.htf=PERIOD_W1; break;
      case PERIOD_H4: case PERIOD_H6: case PERIOD_H8: case PERIOD_H12:
         out.mtf=PERIOD_D1; out.htf=PERIOD_W1; break;
      case PERIOD_D1: out.mtf=PERIOD_W1; out.htf=PERIOD_MN1; break;
      case PERIOD_W1: out.mtf=PERIOD_MN1; out.status=ICT_MTF_TWO_TIER; return true;
      case PERIOD_MN1: out.status=ICT_MTF_ONE_TIER; return true;
      default: return false;
     }
   out.status=ICT_MTF_FULL; return true;
  }

// PERIOD_CURRENT means "keep the automatic tier" for each independent override.
// The older MANUAL inputs remain supported by the caller.
bool ICTResolveTimeframes(const ENUM_TIMEFRAMES chart,const bool automatic,
                          const ENUM_TIMEFRAMES ltf_override,const ENUM_TIMEFRAMES mtf_override,
                          const ENUM_TIMEFRAMES htf_override,SICTTimeframes &out)
  {
   ENUM_TIMEFRAMES ltf=(ltf_override==PERIOD_CURRENT ? chart : ltf_override);
   if(!automatic) return ICTMapTimeframes(ltf,ICT_MTF_MANUAL,mtf_override,htf_override,out);
   if(!ICTMapTimeframes(ltf,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,out)) return false;
   if(mtf_override!=PERIOD_CURRENT) out.mtf=mtf_override;
   if(htf_override!=PERIOD_CURRENT) out.htf=htf_override;
   if(out.mtf==PERIOD_CURRENT || out.htf==PERIOD_CURRENT)
     {
      // W1/MN1 can display context, but never fabricate a third timeframe.
      if(mtf_override!=PERIOD_CURRENT || htf_override!=PERIOD_CURRENT) return false;
      return true;
     }
   if(PeriodSeconds(out.mtf)<=PeriodSeconds(out.ltf) || PeriodSeconds(out.htf)<=PeriodSeconds(out.mtf))
     { out.status=ICT_MTF_INVALID; return false; }
   out.status=ICT_MTF_FULL;
   return true;
  }
#endif
