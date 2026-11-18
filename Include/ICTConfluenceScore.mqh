#ifndef ICT_CONFLUENCE_SCORE_MQH
#define ICT_CONFLUENCE_SCORE_MQH

enum ENUM_ICT_PRIORITY { ICT_PRIORITY_SELL=-1, ICT_PRIORITY_WAIT=0, ICT_PRIORITY_BUY=1 };
enum ENUM_ICT_ZONE_MODE { ICT_ZONE_FVG_ONLY=0, ICT_ZONE_OB_ONLY=1, ICT_ZONE_FVG_OR_OB=2 };
enum ENUM_ICT_EVIDENCE
  {
   ICT_E_HTF=1, ICT_E_SWEEP=2, ICT_E_MSS=4, ICT_E_DISPLACEMENT=8,
   ICT_E_FVG=16, ICT_E_OB=32, ICT_E_PD=64, ICT_E_SMT=128, ICT_E_SESSION=256
  };

// Separate settings keep legacy SICTDecisionConfig callers safe.
struct SICTConfluenceConfig
  {
   int htf, sweep, mss, displacement, fvg, ob, premium_discount, smt, session;
   int minimum_score;
   int minimum_lead; // Retained for source compatibility; never overrides dual-side veto.
   int strong_score;
   ENUM_ICT_ZONE_MODE entry_zone_mode;
   bool mandatory_smt;
   bool mandatory_session;
   int tester_broker_utc_offset_minutes; // 9999 = unknown; no session points in Tester.
  };

void ICTDefaultConfluenceConfig(SICTConfluenceConfig &c)
  {
   ZeroMemory(c);
   c.htf=20; c.sweep=15; c.mss=15; c.displacement=5;
   c.fvg=10; c.ob=10; c.premium_discount=10; c.smt=10; c.session=5;
   c.minimum_score=65; c.minimum_lead=0; c.strong_score=80;
   c.entry_zone_mode=ICT_ZONE_FVG_OR_OB;
   c.tester_broker_utc_offset_minutes=9999;
  }

bool ICTValidConfluenceConfig(const SICTConfluenceConfig &c)
  {
   return c.htf>=0 && c.sweep>=0 && c.mss>=0 && c.displacement>=0 &&
      c.fvg>=0 && c.ob>=0 && c.premium_discount>=0 && c.smt>=0 && c.session>=0 &&
      (long)c.htf+c.sweep+c.mss+c.displacement+c.fvg+c.ob+c.premium_discount+c.smt+c.session==100 &&
      c.minimum_score>=1 && c.minimum_score<=100 && c.minimum_lead>=0 && c.minimum_lead<=100 &&
      c.strong_score>=c.minimum_score && c.strong_score<=100 &&
      c.entry_zone_mode>=ICT_ZONE_FVG_ONLY && c.entry_zone_mode<=ICT_ZONE_FVG_OR_OB &&
      (c.tester_broker_utc_offset_minutes==9999 ||
       (c.tester_broker_utc_offset_minutes>=-840 && c.tester_broker_utc_offset_minutes<=840));
  }

int ICTWeightedScore(const uint evidence,const SICTConfluenceConfig &c)
  {
   return ((evidence&ICT_E_HTF)!=0 ? c.htf : 0)+
      ((evidence&ICT_E_SWEEP)!=0 ? c.sweep : 0)+
      ((evidence&ICT_E_MSS)!=0 ? c.mss : 0)+
      ((evidence&ICT_E_DISPLACEMENT)!=0 ? c.displacement : 0)+
      ((evidence&ICT_E_FVG)!=0 ? c.fvg : 0)+
      ((evidence&ICT_E_OB)!=0 ? c.ob : 0)+
      ((evidence&ICT_E_PD)!=0 ? c.premium_discount : 0)+
      ((evidence&ICT_E_SMT)!=0 ? c.smt : 0)+
      ((evidence&ICT_E_SESSION)!=0 ? c.session : 0);
  }

string ICTEvidenceText(const uint mask)
  {
   string names[9]={"HTF","Sweep","MSS","Displacement","FVG","OB","Premium/Discount","SMT","Session"};
   string result="";
   for(int i=0;i<9;i++)
      if((mask & (uint)(1<<i))!=0)
        { if(result!="") result+=", "; result+=names[i]; }
   return result=="" ? "none" : result;
  }

// Range mode groups the existing configurable FVG/OB/PD weights into IRL
// quality, so quality contributes continuously rather than being a probability.
int ICTRangeQualityConfluence(const uint evidence,const int quality,const SICTConfluenceConfig &c)
  {
   if(!ICTValidConfluenceConfig(c) || quality<0 || quality>100) return 0;
   int context=ICTWeightedScore(evidence & ~(uint)(ICT_E_FVG|ICT_E_OB|ICT_E_PD),c);
   return context+(int)MathRound((c.fvg+c.ob+c.premium_discount)*quality/100.0);
  }

// Pure functions shared by the live engine and deterministic script tests.
uint ICTRequiredEvidence(const SICTConfluenceConfig &c)
  {
   uint required=ICT_E_HTF|ICT_E_SWEEP|ICT_E_MSS|ICT_E_DISPLACEMENT|ICT_E_PD;
   if(c.entry_zone_mode==ICT_ZONE_FVG_ONLY) required|=ICT_E_FVG;
   if(c.entry_zone_mode==ICT_ZONE_OB_ONLY) required|=ICT_E_OB;
   if(c.mandatory_smt) required|=ICT_E_SMT;
   if(c.mandatory_session) required|=ICT_E_SESSION;
   return required;
  }

ENUM_ICT_PRIORITY ICTScorePriority(const int buy_score,const int sell_score,
                                  const bool hard_filters_passed,const SICTConfluenceConfig &c)
  {
   if(!hard_filters_passed || !ICTValidConfluenceConfig(c)) return ICT_PRIORITY_WAIT;
   if(buy_score>=c.minimum_score && sell_score>=c.minimum_score) return ICT_PRIORITY_WAIT;
   if(buy_score>=c.minimum_score && buy_score-sell_score>=c.minimum_lead)
      return ICT_PRIORITY_BUY;
   if(sell_score>=c.minimum_score && sell_score-buy_score>=c.minimum_lead)
      return ICT_PRIORITY_SELL;
   return ICT_PRIORITY_WAIT;
  }

// A priority must describe the same side as the risk-validated plan.
ENUM_ICT_PRIORITY ICTPlanPriority(const int buy_score,const int sell_score,
                                  const bool gates,const bool data_ok,const int direction,
                                  const uint confirmed,const SICTConfluenceConfig &c)
  {
   uint required=ICTRequiredEvidence(c);
   bool zone=(confirmed&(ICT_E_FVG|ICT_E_OB))!=0;
   if(!data_ok || !zone || (confirmed&required)!=required) return ICT_PRIORITY_WAIT;
   ENUM_ICT_PRIORITY result=ICTScorePriority(buy_score,sell_score,gates,c);
   if((int)result!=direction) return ICT_PRIORITY_WAIT;
   return result;
  }

bool ICTContextConflict(const int daily,const int higher,const int structure,
                         const int break_direction,const bool mss)
  {
   if(daily!=0 && higher!=0 && daily!=higher) return true;
   // An aligned MSS legitimately reverses the previous LTF structure bias.
   return higher!=0 && structure!=0 && structure!=higher &&
          !(mss && break_direction==higher);
  }

void ICTRankTarget(const int direction,const double entry,const double level,
                    const string name,double &first,string &first_name,
                    double &second,string &second_name)
  {
   if(!MathIsValidNumber(level) || level<=0 || (direction!=1 && direction!=-1) ||
      (level-entry)*direction<=0) return;
   if(level==first || level==second) return;
   if(first<=0 || (level-first)*direction<0)
     { second=first; second_name=first_name; first=level; first_name=name; }
   else if(second<=0 || (level-second)*direction<0)
     { second=level; second_name=name; }
  }

bool ICTQuoteValidAt(const MqlTick &quote,const datetime now,const int max_age_seconds)
  {
   if(!MathIsValidNumber(quote.bid) || !MathIsValidNumber(quote.ask) ||
      quote.bid<=0 || quote.ask<quote.bid || now<=0 || max_age_seconds<1 ||
      quote.time<=0 || quote.time>now || now-quote.time>max_age_seconds) return false;
   // The terminal clock has whole-second precision. Allow the same second's
   // milliseconds, but reject inconsistent or future-second tick timestamps.
   if(quote.time_msc<0) return false;
   if(quote.time_msc>0 && (quote.time_msc/1000!=(long)quote.time ||
      quote.time_msc/1000>(long)now)) return false;
   return true;
  }
#endif
