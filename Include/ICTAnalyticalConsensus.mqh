#ifndef ICT_ANALYTICAL_CONSENSUS_MQH
#define ICT_ANALYTICAL_CONSENSUS_MQH
#include "ICTStatisticalLearning.mqh"
#include "ICTUnifiedAnalysis.mqh"

// Advisory evidence only. No mutation of native decisions, models or risk plans.
#define ICT_ANALYSIS_GROUPS 6
enum ENUM_ICT_ANALYSIS_GROUP { ICT_A_PATH=0, ICT_A_CANDLE, ICT_A_LIQUIDITY, ICT_A_ZONES, ICT_A_SMT, ICT_A_DEEP };
struct SICTAnalyticalConfig
  {
   double minimum_score;
   int minimum_groups,minimum_supporters,event_window;
   bool require_deep;
  };
struct SICTAnalyticalContext
  {
   string symbol;
   bool valid;
   ENUM_TIMEFRAMES ltf,mtf,htf;
   datetime asof,ltf_closed,mtf_closed,htf_closed;
   int htf_bias,mtf_bias;
  };
struct SICTAnalyticalVotes
  {
   bool available[ICT_ANALYSIS_GROUPS];
   double value[ICT_ANALYSIS_GROUPS]; // Signed evidence [-1,1]; zero is observed neutrality.
  };
struct SICTAnalyticalResult
  {
   bool ready,signal,deep_used,context_aligned,experimental;
   int direction,groups,supporters,opponents;
   double score,mean;
   datetime asof;
   string reason;
  };
void ICTAnalyticalDefaults(SICTAnalyticalConfig &c)
  { c.minimum_score=60; c.minimum_groups=3; c.minimum_supporters=2; c.event_window=12; c.require_deep=false; }
bool ICTAnalyticalValidConfig(const SICTAnalyticalConfig &c)
  {
   return MathIsValidNumber(c.minimum_score) && c.minimum_score>50 && c.minimum_score<=95 &&
      c.minimum_groups>=2 && c.minimum_groups<=ICT_ANALYSIS_GROUPS &&
      c.minimum_supporters>=2 && c.minimum_supporters<=c.minimum_groups && c.event_window>=1 && c.event_window<=60;
  }
bool ICTAnalyticalContextReady(const SICTAnalyticalContext &c)
  {
   return c.valid && c.symbol!="" && c.asof>0 && c.ltf!=PERIOD_CURRENT &&
      PeriodSeconds(c.ltf)>0 && PeriodSeconds(c.ltf)<PeriodSeconds(c.mtf) && PeriodSeconds(c.mtf)<PeriodSeconds(c.htf) &&
      c.ltf_closed==c.asof && c.mtf_closed>0 && c.mtf_closed<=c.asof && c.htf_closed>0 && c.htf_closed<=c.asof &&
      (c.htf_bias==1 || c.htf_bias==-1) && c.mtf_bias==c.htf_bias;
  }
bool ICTAnalyticalEvaluate(const SICTAnalyticalConfig &c,const SICTAnalyticalContext &context,
                            const SICTAnalyticalVotes &votes,SICTAnalyticalResult &s)
  {
   ZeroMemory(s); s.asof=context.asof;
   if(!ICTAnalyticalValidConfig(c)) { s.reason="Cấu hình điểm / số nhóm không hợp lệ"; return false; }
   if(!ICTAnalyticalContextReady(context)) { s.reason="Chờ bối cảnh HTF / MTF đồng thuận và đủ nến đóng"; return false; }
   s.direction=context.htf_bias;
   for(int i=0;i<ICT_ANALYSIS_GROUPS;i++)
     {
      if(!votes.available[i]) continue;
      double v=votes.value[i];
      if(!MathIsValidNumber(v) || MathAbs(v)>1)
        { s.reason="Bằng chứng ngoài miền số hợp lệ"; return false; }
      s.mean+=v; s.groups++;
      if(v*s.direction>=0.2) s.supporters++;
      if(v*s.direction<=-0.2) s.opponents++;
     }
   s.deep_used=votes.available[ICT_A_DEEP];
   if(s.groups<c.minimum_groups) { s.reason="Chưa đủ nhóm dữ liệu; không thay dữ liệu thiếu bằng điểm thuận"; return false; }
   s.mean/=s.groups; s.score=50.0*(1.0+s.direction*s.mean); s.ready=true;
   if(c.require_deep && !s.deep_used) { s.reason="Chờ DNN đã hiệu chỉnh, vượt đối chứng và khớp nến LTF"; return false; }
   if(s.supporters<c.minimum_supporters) { s.reason="Chưa đủ nhóm bằng chứng ủng hộ"; return false; }
   if(s.score+1e-9<c.minimum_score) { s.reason="Điểm trung bình chưa đạt ngưỡng phân tích sớm"; return false; }
   s.signal=true; s.reason="Các nhóm bằng chứng đạt đồng thuận theo bối cảnh đa khung"; return true;
  }

bool ICTAnalyticalPriceVotes(const MqlRates &r[],const ENUM_TIMEFRAMES tf,const datetime asof,
                              const double point,SICTAnalyticalVotes &v,double &atr)
  {
   atr=0;
   int n=ICTClosedPrefix(r,ArraySize(r),tf,asof);
   if(n<33 || !SRMPValidDetectorRates(r,n) || ICTBarClose(tf,r[n-1].time)!=asof || point<=0) return false;
   int i=n-1; atr=ICTPriorATR(r,i);
   if(!MathIsValidNumber(atr) || atr<=0) return false;
   double travel=0;
   for(int j=i-11;j<=i;j++) travel+=MathAbs(r[j].close-r[j-1].close);
   double short_move=ICTStatClip((r[i].close-r[i-3].close)/(1.5*atr),-1,1);
   double long_move=ICTStatClip((r[i].close-r[i-12].close)/(3.0*atr),-1,1);
   double efficiency=(travel>0 ? (r[i].close-r[i-12].close)/travel : 0);
   v.value[ICT_A_PATH]=(short_move+long_move+efficiency)/3.0; v.available[ICT_A_PATH]=true;
   MqlRates bar=r[i]; double width=bar.high-bar.low;
   double body=ICTStatClip((bar.close-bar.open)/atr,-1,1);
   double location=(width>0 ? (2*bar.close-bar.high-bar.low)/width : 0);
   double rejection=(width>0 ? (MathMin(bar.open,bar.close)-bar.low-bar.high+MathMax(bar.open,bar.close))/width : 0);
   int mask=ICTStatPatternMask(r,i),patterns=0; double pattern=0;
   for(int k=0;k<8;k++) if((mask & (1<<k))!=0) { pattern+=(k%2==0 ? 1 : -1); patterns++; }
   if(patterns>0) pattern/=patterns;
   v.value[ICT_A_CANDLE]=(body+location+rejection+pattern)/4.0; v.available[ICT_A_CANDLE]=true;
   return true;
  }

void ICTAnalyticalLiquidityVote(const SICTRangeSnapshot &r,const string symbol,const datetime asof,
                                 const ENUM_TIMEFRAMES ltf,const int window,SICTAnalyticalVotes &v)
  {
   if(!r.valid || r.symbol!=symbol || r.as_of!=asof || r.ltf!=ltf || window<1 ||
      r.liquidity_event_count<0 || r.liquidity_event_count>ICT_RANGE_LIQUIDITY_EVENTS) return;
   v.available[ICT_A_LIQUIDITY]=true; v.value[ICT_A_LIQUIDITY]=0;
   datetime latest=0; double sum=0; int count=0;
   for(int i=0;i<r.liquidity_event_count;i++)
     {
      SICTRangeLiquidityEvent e=r.liquidity_events[i];
      if(e.confirmed_at<=0 || e.confirmed_at>asof || e.confirmed_at<asof-(long)window*PeriodSeconds(ltf) ||
         (e.side!=1 && e.side!=-1) || e.type==IR_EVENT_NONE) continue;
      if(e.confirmed_at<latest) continue;
      if(e.confirmed_at>latest) { latest=e.confirmed_at; sum=0; count=0; }
      sum+=(e.type==IR_EVENT_LIQUIDITY_SWEEP || e.type==IR_EVENT_FALSE_BREAKOUT ? -e.side : e.side); count++;
     }
   if(count>0) v.value[ICT_A_LIQUIDITY]=sum/count*(1.0-(double)(asof-latest)/((window+1.0)*PeriodSeconds(ltf)));
  }

double ICTAnalyticalZoneReaction(const MqlRates &bar,const int direction,const double low,const double high,
                                  const double quality,const double atr)
  {
   if((direction!=1 && direction!=-1) || !MathIsValidNumber(low) || !MathIsValidNumber(high) ||
      !MathIsValidNumber(quality) || low<=0 || high<=low || atr<=0 ||
      bar.low>high || bar.high<low || (bar.close-bar.open)*direction<=0 ||
      (direction>0 ? bar.close<low : bar.close>high)) return 0;
   double distance=(bar.close<low ? low-bar.close : bar.close>high ? bar.close-high : 0);
   return (0.5+0.5*ICTStatClip(quality/100.0,0,1))*ICTStatClip(1.0-distance/(2*atr),0,1);
  }
void ICTAnalyticalRangeZonesVote(const SICTRangeSnapshot &r,const string symbol,const datetime asof,
                                  const MqlRates &bar,const double atr,SICTAnalyticalVotes &v)
  {
   if(!r.valid || r.symbol!=symbol || r.as_of!=asof || r.zone_count<0 || r.zone_count>ICT_RANGE_ZONES) return;
   double bull=0,bear=0;
   for(int i=0;i<r.zone_count;i++)
     {
      SICTRangeZone z=r.zones[i];
      if(z.range_id!=r.range.id || z.state>IR_TOUCHED || z.confirmed_at<=0 || z.confirmed_at>bar.time) continue;
      double score=ICTAnalyticalZoneReaction(bar,z.direction,z.lower,z.upper,z.quality,atr);
      if(z.direction>0) bull=MathMax(bull,score); else bear=MathMax(bear,score);
     }
   v.available[ICT_A_ZONES]=true; v.value[ICT_A_ZONES]=bull-bear;
  }
void ICTAnalyticalUnifiedVotes(const SICTUnifiedSnapshot &u,const MqlRates &bar,const double atr,SICTAnalyticalVotes &v)
  {
   if(!u.valid || u.ob_count<0 || u.ob_count>ICT_SMART_OB_MAX || u.layer_count<0 || u.layer_count>4) return;
   double bull=MathMax(0,v.value[ICT_A_ZONES]),bear=MathMax(0,-v.value[ICT_A_ZONES]);
   for(int i=0;i<u.ob_count;i++)
     {
      SICTStrongOrderBlock z=u.zones[i];
      if(!ICTOBActive(z) || !z.hard_gates || z.ob.confirmation_time<=0 || z.ob.confirmation_time>bar.time) continue;
      double score=ICTAnalyticalZoneReaction(bar,z.ob.direction,z.ob.lower,z.ob.upper,z.current_context_score,atr);
      if(z.ob.direction>0) bull=MathMax(bull,score); else bear=MathMax(bear,score);
     }
   for(int i=0;i<3;i++)
     {
      SICTTierSnapshot t=u.tiers[i];
      if(t.closed_at<=0 || t.closed_at>u.asof) continue;
      if(t.fvg_ready && t.gap.status<=SRMP_FVG_PARTIALLY_FILLED && ICTBarClose(t.timeframe,t.gap.formed_time)<=bar.time)
        {
         double score=ICTAnalyticalZoneReaction(bar,t.gap.direction,t.gap.lower,t.gap.upper,60,atr);
         if(t.gap.direction>0) bull=MathMax(bull,score); else bear=MathMax(bear,score);
        }
      if(t.bpr_ready && t.bpr.confirmed_at>0 && t.bpr.confirmed_at<=bar.time)
        {
         double score=ICTAnalyticalZoneReaction(bar,t.bpr.direction,t.bpr.lower,t.bpr.upper,60,atr);
         if(t.bpr.direction>0) bull=MathMax(bull,score); else bear=MathMax(bear,score);
        }
     }
   v.available[ICT_A_ZONES]=true; v.value[ICT_A_ZONES]=bull-bear;
   double smt=0; int peers=0;
   for(int i=0;i<u.layer_count;i++)
      for(int j=0;j<2;j++)
        {
         SICTSMTPeerSnapshot p=u.layers[i].peers[j];
         string configured=(j==0 ? u.comparison1 : u.comparison2);
         if(configured=="" || p.comparison!=configured || !p.ready || !p.relation_known ||
            p.last_close<=0 || p.last_close!=u.layers[i].last_close || p.last_close>u.asof) continue;
         peers++;
         if(!p.conflict) smt+=(p.state==ICT_SMT_PEER_BULLISH ? 1 : p.state==ICT_SMT_PEER_BEARISH ? -1 : 0);
        }
   if(peers>0) { v.available[ICT_A_SMT]=true; v.value[ICT_A_SMT]=smt/peers; }
  }

bool ICTAnalyticalDeepVote(const SICTStatModel &m,const SICTStatSnapshot &s,const MqlRates &rates[],
                            const ENUM_TIMEFRAMES model_tf,const ENUM_TIMEFRAMES ltf,const datetime asof,
                            const double point,SICTAnalyticalVotes &v)
  {
   v.available[ICT_A_DEEP]=false; v.value[ICT_A_DEEP]=0;
   if(model_tf!=ltf || !m.fitted || !m.calibrated || !s.ready || !s.calibrated ||
      s.asof<=0 || ICTBarClose(ltf,s.asof)!=asof || s.horizon<1 ||
      m.train_end<=0 || m.cal_end<=m.train_end || m.test_end<m.cal_end ||
      ICTBarClose(ltf,m.test_end)>asof || !MathIsValidNumber(s.brier_dl) || !MathIsValidNumber(s.brier_baseline) ||
      s.brier_dl<0 || s.brier_dl>=s.brier_baseline) return false;
   int n=ICTClosedPrefix(rates,ArraySize(rates),ltf,asof);
   SICTStatSample sample;
   if(n<33 || rates[n-1].time!=s.asof || !SRMPValidDetectorRates(rates,n) || !ICTStatFeatures(rates,n-1,point,sample)) return false;
   for(int i=0;i<ICT_STAT_FEATURES;i++)
      if(!MathIsValidNumber(m.mean[i]) || !MathIsValidNumber(m.scale[i]) || m.scale[i]<=0 ||
         MathAbs((sample.x[i]-m.mean[i])/m.scale[i])>6) return false;
   double sum=0;
   for(int i=0;i<ICT_STAT_CLASSES;i++)
     { if(!MathIsValidNumber(s.dl[i]) || s.dl[i]<0 || s.dl[i]>1) return false; sum+=s.dl[i]; }
   if(MathAbs(sum-1)>0.000001) return false;
   v.value[ICT_A_DEEP]=s.dl[0]-s.dl[1]; v.available[ICT_A_DEEP]=true; return true;
  }

// An independent, explicitly advisory DL policy. The strict context evaluator
// above remains unchanged and is still used to identify native MTF alignment.
struct SICTAnalyticalPolicy
  {
   double minimum_score,minimum_dl_margin;
   int minimum_groups,minimum_supporters;
   bool strict_context,require_deep,allow_experimental;
  };
struct SICTAnalyticalDeepState
  {
   bool ready,validated,domain_ok;
   int direction;
   double probability[3],weight;
   string reason;
  };
void ICTAnalyticalPolicyDefaults(SICTAnalyticalPolicy &p)
  {
   p.minimum_score=55; p.minimum_dl_margin=0.04; p.minimum_groups=2; p.minimum_supporters=1;
   p.strict_context=false; p.require_deep=true; p.allow_experimental=true;
  }
bool ICTAnalyticalPolicyValid(const SICTAnalyticalPolicy &p)
  {
   return MathIsValidNumber(p.minimum_score) && p.minimum_score>50 && p.minimum_score<=95 &&
      MathIsValidNumber(p.minimum_dl_margin) && p.minimum_dl_margin>=0.02 && p.minimum_dl_margin<=0.5 &&
      p.minimum_groups>=2 && p.minimum_groups<=ICT_ANALYSIS_GROUPS &&
      p.minimum_supporters>=1 && p.minimum_supporters<=p.minimum_groups;
  }
bool ICTAnalyticalPriceContextReady(const SICTAnalyticalContext &c)
  {
   return c.valid && c.symbol!="" && c.asof>0 && c.ltf!=PERIOD_CURRENT && PeriodSeconds(c.ltf)>0 &&
      PeriodSeconds(c.ltf)<PeriodSeconds(c.mtf) && PeriodSeconds(c.mtf)<PeriodSeconds(c.htf) &&
      c.ltf_closed==c.asof && c.mtf_closed>=0 && c.mtf_closed<=c.asof && c.htf_closed>=0 && c.htf_closed<=c.asof;
  }
bool ICTAnalyticalDeepEvidence(const SICTStatModel &m,const SICTStatSnapshot &s,const MqlRates &rates[],
                                const ENUM_TIMEFRAMES model_tf,const ENUM_TIMEFRAMES ltf,const datetime asof,
                                const double point,SICTAnalyticalDeepState &deep,SICTAnalyticalVotes &v)
  {
   ZeroMemory(deep); v.available[ICT_A_DEEP]=false; v.value[ICT_A_DEEP]=0;
   deep.reason="Chờ DNN đã học và hiệu chỉnh trên dữ liệu trước nến phân tích";
   if(model_tf!=ltf) { deep.reason="DNN khác khung LTF"; return false; }
   if(!m.fitted || !m.calibrated || !s.ready || !s.calibrated || s.asof<=0 ||
      ICTBarClose(ltf,s.asof)!=asof || s.horizon<1 || m.train_end<=0 || m.cal_end<=m.train_end ||
      m.test_end<m.cal_end || ICTBarClose(ltf,m.test_end)>asof) return false;
   int n=ICTClosedPrefix(rates,ArraySize(rates),ltf,asof); SICTStatSample sample;
   if(n<33 || rates[n-1].time!=s.asof || !SRMPValidDetectorRates(rates,n) || !ICTStatFeatures(rates,n-1,point,sample)) return false;
   deep.domain_ok=true;
   for(int i=0;i<ICT_STAT_FEATURES;i++)
     {
      if(!MathIsValidNumber(m.mean[i]) || !MathIsValidNumber(m.scale[i]) || m.scale[i]<=0 || !MathIsValidNumber(sample.x[i])) return false;
      if(MathAbs((sample.x[i]-m.mean[i])/m.scale[i])>6) deep.domain_ok=false;
     }
   double sum=0;
   for(int i=0;i<3;i++)
     {
      if(!MathIsValidNumber(s.dl[i]) || s.dl[i]<0 || s.dl[i]>1) return false;
      deep.probability[i]=s.dl[i]; sum+=s.dl[i];
     }
   if(MathAbs(sum-1)>0.000001 || !MathIsValidNumber(s.brier_dl) || !MathIsValidNumber(s.brier_baseline) ||
      s.brier_dl<0 || s.brier_baseline<=0) return false;
   deep.validated=deep.domain_ok && s.brier_dl<s.brier_baseline;
   deep.weight=deep.validated ? 1.0 : 0.35;
   deep.reason=deep.validated ? "DNN hiệu chỉnh; Brier riêng vượt prior" :
      !deep.domain_ok ? "DL THAM KHẢO: feature ngoài miền train; giảm trọng số" :
      "DL THAM KHẢO: chưa vượt prior; giảm trọng số";
   deep.direction=(s.dl[0]>s.dl[1] ? 1 : s.dl[1]>s.dl[0] ? -1 : 0);
   if(MathMax(s.dl[0],s.dl[1])<=s.dl[2]) deep.direction=0;
   deep.ready=true; v.available[ICT_A_DEEP]=true; v.value[ICT_A_DEEP]=s.dl[0]-s.dl[1]; return true;
  }
bool ICTAnalyticalEvaluateEarly(const SICTAnalyticalPolicy &p,const SICTAnalyticalContext &c,
                                 const SICTAnalyticalVotes &v,const SICTAnalyticalDeepState &deep,SICTAnalyticalResult &s)
  {
   ZeroMemory(s); s.asof=c.asof; s.context_aligned=ICTAnalyticalContextReady(c);
   if(!ICTAnalyticalPolicyValid(p)) { s.reason="Cấu hình phân tích DL không hợp lệ"; return false; }
   if(!ICTAnalyticalPriceContextReady(c)) { s.reason="Chờ dữ liệu LTF đóng hợp lệ"; return false; }
   if(p.strict_context && !s.context_aligned) { s.reason="Chế độ MTF chặt: chờ HTF / MTF đồng thuận"; return false; }
   bool use_deep=deep.ready && v.available[ICT_A_DEEP] && (deep.validated || p.allow_experimental);
   s.deep_used=use_deep; s.experimental=use_deep && !deep.validated;
   if(p.require_deep && !use_deep) { s.reason=deep.reason; return false; }
   if(use_deep)
     {
      s.direction=deep.direction;
      if(s.direction==0 || MathAbs(v.value[ICT_A_DEEP])<p.minimum_dl_margin)
        { s.reason="DNN ưu tiên đi ngang hoặc chênh lệch hướng còn thấp"; return false; }
     }
   else
     {
      double direction=v.value[ICT_A_PATH]+v.value[ICT_A_CANDLE];
      s.direction=(direction>0 ? 1 : direction<0 ? -1 : 0);
      if(s.direction==0) { s.reason="Đường giá chưa tách hướng"; return false; }
     }
   double weight_sum=0;
   for(int i=0;i<ICT_ANALYSIS_GROUPS;i++)
     {
      if(!v.available[i] || (i==ICT_A_DEEP && !use_deep)) continue;
      double value=v.value[i];
      if(!MathIsValidNumber(value) || MathAbs(value)>1) { s.reason="Bằng chứng ngoài miền số hợp lệ"; return false; }
      // An observed absence of a sweep/zone adds no directional information.
      // It is displayed as neutral but no longer dilutes every active group.
      if(MathAbs(value)<0.025) continue;
      double weight=(i==ICT_A_DEEP ? deep.weight : 1.0);
      if(!MathIsValidNumber(weight) || weight<=0 || weight>1) return false;
      s.mean+=weight*value; weight_sum+=weight; s.groups++;
      if(value*s.direction>=0.1) s.supporters++;
      if(value*s.direction<=-0.1) s.opponents++;
     }
   if(s.groups<p.minimum_groups || weight_sum<=0) { s.reason="Chờ thêm nhóm có bằng chứng định hướng"; return false; }
   s.mean/=weight_sum;
   s.score=50*(1+s.direction*s.mean)+s.direction*(3*c.htf_bias+2*c.mtf_bias);
   if(s.experimental) s.score=50+(s.score-50)*0.65;
   s.score=ICTStatClip(s.score,0,100); s.ready=true;
   if(s.supporters<p.minimum_supporters) { s.reason="Chờ thêm bằng chứng ủng hộ hướng DL"; return false; }
   if(s.score+1e-9<p.minimum_score) { s.reason="Điểm DL và đường giá chưa đạt ngưỡng"; return false; }
   s.signal=true; s.reason=s.context_aligned ? "DL và đường giá đủ điểm; bối cảnh đồng thuận" :
      "DL phân tích sớm; bối cảnh MTF chưa đồng thuận, chưa xác nhận vào lệnh";
   return true;
  }
bool ICTAnalyticalStructureAt(const MqlRates &rates[],const ENUM_TIMEFRAMES tf,const datetime asof,
                               const int lookback,const int left,const int right,SMarketStructure &structure,datetime &closed)
  {
   ZeroMemory(structure); closed=0;
   int n=ICTClosedPrefix(rates,ArraySize(rates),tf,asof);
   if(n<lookback || lookback<40) return false;
   MqlRates window[]; ArrayResize(window,lookback);
   if(ArrayCopy(window,rates,0,n-lookback,lookback)!=lookback || !SRMPValidDetectorRates(window,lookback)) return false;
   closed=ICTBarClose(tf,window[lookback-1].time);
   return SRMPAnalyzeStructureFromRates(window,lookback,left,right,structure);
  }
#endif
