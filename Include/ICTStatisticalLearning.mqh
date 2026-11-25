#ifndef ICT_STATISTICAL_LEARNING_MQH
#define ICT_STATISTICAL_LEARNING_MQH
#include "ICTRangeTypes.mqh"
#include "ICTBarSnapshot.mqh"

// Local, descriptive forecasts. No orders, native ICT scores or SL/TP access.
// Target: close after H trading candles vs confirmation close, outside an
// ATR band plus the recorded spread. This is NOT P(TP before SL) or net profit.
#define ICT_STAT_FEATURES 32
#define ICT_STAT_H1 12
#define ICT_STAT_H2 6
#define ICT_STAT_CLASSES 3
#define ICT_STAT_LR_WEIGHTS 99
#define ICT_STAT_DNN_WEIGHTS 495
#define ICT_STAT_EPOCHS 32
#define ICT_STAT_DEEP_EPOCHS 24

struct SICTStatConfig
  {
   int history_bars,horizon,min_train,min_evaluation,min_pattern,retrain_bars;
   double move_atr;
  };
struct SICTStatSample
  {
   double x[ICT_STAT_FEATURES];
   int label,mask;
   datetime asof,label_end;
  };
struct SICTStatModel
  {
   double mean[ICT_STAT_FEATURES],scale[ICT_STAT_FEATURES];
   double lr[ICT_STAT_LR_WEIGHTS],deep[ICT_STAT_DNN_WEIGHTS],prior[ICT_STAT_CLASSES];
   double lr_temperature,deep_temperature;
   int train_n,cal_start,cal_n,test_start,test_n,epoch,cursor;
   bool fitted,calibrated;
   datetime train_end,cal_start_time,cal_end,test_start_time,test_end;
  };
struct SICTStatSnapshot
  {
   bool ready,calibrated,beats_baseline;
   string status,reason,timeframe;
   int history_n,train_n,cal_n,test_n,horizon,progress,mask;
   double move_atr,ml[ICT_STAT_CLASSES],dl[ICT_STAT_CLASSES],combined[ICT_STAT_CLASSES];
   double brier_ml,brier_dl,brier_combined,brier_baseline,accuracy,baseline_accuracy;
   int pattern_n[8],pattern_hits[8];
   datetime asof,train_end,test_end;
  };

void ICTStatDefaultConfig(SICTStatConfig &c)
  {
   c.history_bars=6000; c.horizon=4; c.move_atr=0.25;
   c.min_train=400; c.min_evaluation=80; c.min_pattern=30; c.retrain_bars=64;
  }
bool ICTStatValidConfig(const SICTStatConfig &c)
  {
   return c.history_bars>=1000 && c.history_bars<=20000 && c.horizon>=1 && c.horizon<=24 &&
      MathIsValidNumber(c.move_atr) && c.move_atr>=0.05 && c.move_atr<=3 &&
      c.min_train>=200 && c.min_train<=5000 && c.min_evaluation>=30 && c.min_evaluation<=1000 &&
      c.min_pattern>=10 && c.min_pattern<=1000 && c.retrain_bars>=8 && c.retrain_bars<=1000;
  }
double ICTStatClip(const double x,const double lo,const double hi)
  { return MathMax(lo,MathMin(hi,x)); }
double ICTStatTanh(const double x)
  { return 2.0/(1.0+MathExp(-2.0*ICTStatClip(x,-20,20)))-1.0; }
bool ICTStatValidRates(const MqlRates &r[])
  {
   for(int i=0;i<ArraySize(r);i++)
     {
      if(r[i].time<=0 || (i>0 && r[i].time<=r[i-1].time) || r[i].spread<0 ||
         !MathIsValidNumber(r[i].open) || !MathIsValidNumber(r[i].high) ||
         !MathIsValidNumber(r[i].low) || !MathIsValidNumber(r[i].close) ||
         r[i].low<=0 || r[i].high<r[i].low || r[i].open<r[i].low || r[i].open>r[i].high ||
         r[i].close<r[i].low || r[i].close>r[i].high) return false;
     }
   return ArraySize(r)>32;
  }
double ICTStatATR(const MqlRates &r[],const int i)
  {
   if(i<14 || i>=ArraySize(r)) return 0;
   double sum=0;
   for(int k=i-13;k<=i;k++)
      sum+=MathMax(r[k].high-r[k].low,MathMax(MathAbs(r[k].high-r[k-1].close),MathAbs(r[k].low-r[k-1].close)));
   return sum/14.0;
  }
int ICTStatPatternMask(const MqlRates &r[],const int i)
  {
   if(i<32 || i>=ArraySize(r)) return 0;
   int mask=0;
   double high=r[i-1].high,low=r[i-1].low;
   for(int k=i-8;k<i;k++) { high=MathMax(high,r[k].high); low=MathMin(low,r[k].low); }
   // Two bits per family: bullish, bearish. Confirmation never uses i+1.
   if(r[i].low<low && r[i].close>low && r[i].close>r[i].open) mask|=1;
   if(r[i].high>high && r[i].close<high && r[i].close<r[i].open) mask|=2;
   if(r[i-1].close<r[i-1].open && r[i].close>r[i].open &&
      r[i].open<=r[i-1].close && r[i].close>=r[i-1].open) mask|=4;
   if(r[i-1].close>r[i-1].open && r[i].close<r[i].open &&
      r[i].open>=r[i-1].close && r[i].close<=r[i-1].open) mask|=8;
   if(r[i].close>high) mask|=16;
   if(r[i].close<low) mask|=32;
   for(int j=i-1;j>=i-20;j--)
     {
      double lower=r[j-2].high,upper=r[j].low;
      if(upper>lower && r[i].low<=upper && r[i].low>=lower && r[i].close>upper)
        {
         bool first=true;
         for(int k=j+1;k<i;k++) if(r[k].low<=upper) { first=false; break; }
         if(first) mask|=64;
        }
      lower=r[j].high; upper=r[j-2].low;
      if(upper>lower && r[i].high>=lower && r[i].high<=upper && r[i].close<lower)
        {
         bool first=true;
         for(int k=j+1;k<i;k++) if(r[k].high>=lower) { first=false; break; }
         if(first) mask|=128;
        }
     }
   return mask;
  }
bool ICTStatFeatures(const MqlRates &r[],const int i,const double point,SICTStatSample &s)
  {
   ZeroMemory(s);
   if(i<32 || i>=ArraySize(r) || !MathIsValidNumber(point) || point<=0) return false;
   double atr=ICTStatATR(r,i);
   if(!MathIsValidNumber(atr) || atr<=point) return false;
   for(int k=0;k<6;k++)
     {
      int at=i-5+k;
      s.x[k*4]=(r[at].open-r[i].close)/atr;
      s.x[k*4+1]=(r[at].high-r[i].close)/atr;
      s.x[k*4+2]=(r[at].low-r[i].close)/atr;
      s.x[k*4+3]=(r[at].close-r[i].close)/atr;
     }
   s.x[24]=(r[i].close-r[i-3].close)/atr;
   s.x[25]=(r[i].close-r[i-12].close)/atr;
   s.x[26]=(r[i].high-r[i].low)/atr;
   s.x[27]=r[i].spread*point/atr;
   s.mask=ICTStatPatternMask(r,i); s.asof=r[i].time;
   for(int k=0;k<4;k++) s.x[28+k]=((s.mask & (1<<(k*2)))!=0 ? 1.0 : 0.0)-((s.mask & (2<<(k*2)))!=0 ? 1.0 : 0.0);
   for(int k=0;k<ICT_STAT_FEATURES;k++) if(!MathIsValidNumber(s.x[k])) return false;
   return true;
  }
int ICTStatLabel(const MqlRates &r[],const int i,const int horizon,const double move_atr,const double point)
  {
   if(i<32 || horizon<1 || i+horizon>=ArraySize(r)) return -1;
   double atr=ICTStatATR(r,i),delta=r[i+horizon].close-r[i].close;
   if(atr<=point || !MathIsValidNumber(move_atr) || move_atr<=0 || point<=0) return -1;
   double band=move_atr*atr+r[i].spread*point;
   return delta>band ? 0 : delta < -band ? 1 : 2;
  }
bool ICTStatBuildSamples(const MqlRates &r[],const double point,const SICTStatConfig &c,SICTStatSample &samples[])
  {
   ArrayResize(samples,0);
   if(!ICTStatValidConfig(c) || !ICTStatValidRates(r) || !MathIsValidNumber(point) || point<=0) return false;
   int capacity=(ArraySize(r)-32)/c.horizon;
   if(capacity<1) return false;
   ArrayResize(samples,capacity); int n=0;
   // Disjoint forward horizons in ALL partitions; purge one additional sample
   // at each boundary below. Natural market closures count as trading bars.
   for(int i=32;i+c.horizon<ArraySize(r);i+=c.horizon)
     {
      SICTStatSample s;
      if(!ICTStatFeatures(r,i,point,s)) continue;
      s.label=ICTStatLabel(r,i,c.horizon,c.move_atr,point);
      if(s.label<0) continue;
      s.label_end=r[i+c.horizon].time;
      samples[n++]=s;
     }
   ArrayResize(samples,n);
   return n>0;
  }
void ICTStatSoftmax(const double &logits[],const double temperature,double &p[])
  {
   double peak=logits[0],sum=0;
   for(int k=1;k<3;k++) peak=MathMax(peak,logits[k]);
   for(int k=0;k<3;k++) { p[k]=MathExp(ICTStatClip((logits[k]-peak)/temperature,-60,0)); sum+=p[k]; }
   for(int k=0;k<3;k++) p[k]/=sum;
  }
void ICTStatNormalize(const SICTStatModel &m,const SICTStatSample &s,double &x[])
  {
   for(int k=0;k<ICT_STAT_FEATURES;k++) x[k]=ICTStatClip((s.x[k]-m.mean[k])/m.scale[k],-5,5);
  }
void ICTStatForward(const SICTStatModel &m,const SICTStatSample &s,const bool deep,const double temperature,double &p[])
  {
   double x[ICT_STAT_FEATURES],a[ICT_STAT_H1],b[ICT_STAT_H2],z[3];
   ICTStatNormalize(m,s,x);
   if(!deep)
     {
      for(int k=0;k<3;k++)
        {
         z[k]=m.lr[k*33+32];
         for(int f=0;f<32;f++) z[k]+=m.lr[k*33+f]*x[f];
        }
     }
   else
     {
      for(int h=0;h<12;h++)
        { double v=m.deep[h*33+32]; for(int f=0;f<32;f++) v+=m.deep[h*33+f]*x[f]; a[h]=ICTStatTanh(v); }
      for(int h=0;h<6;h++)
        { double v=m.deep[396+h*13+12]; for(int f=0;f<12;f++) v+=m.deep[396+h*13+f]*a[f]; b[h]=ICTStatTanh(v); }
      for(int k=0;k<3;k++)
        { z[k]=m.deep[474+k*7+6]; for(int h=0;h<6;h++) z[k]+=m.deep[474+k*7+h]*b[h]; }
     }
   ICTStatSoftmax(z,temperature,p);
  }
bool ICTStatPrepare(const SICTStatConfig &c,const SICTStatSample &samples[],SICTStatModel &m,SICTStatSnapshot &s)
  {
   ZeroMemory(m); ZeroMemory(s);
   s.status="INSUFFICIENT_DATA"; s.reason="Chưa đủ mẫu để chia train / hiệu chỉnh / kiểm định";
   s.horizon=c.horizon; s.move_atr=c.move_atr;
   if(!ICTStatValidConfig(c)) { s.status="INVALID_CONFIG"; s.reason="Tham số ML/DL không hợp lệ"; return false; }
   int n=ArraySize(samples);
   for(int i=0;i<n;i++)
     {
      if(samples[i].label<0 || samples[i].label>2 || samples[i].asof<=0 || samples[i].label_end<=samples[i].asof ||
         (i>0 && samples[i].asof<=samples[i-1].asof))
        { s.status="INVALID_SAMPLES"; s.reason="Mẫu hoặc nhãn thời gian không hợp lệ"; return false; }
      for(int f=0;f<32;f++)
         if(!MathIsValidNumber(samples[i].x[f]))
           { s.status="INVALID_SAMPLES"; s.reason="Feature không hữu hạn"; return false; }
     }
   m.train_n=n*65/100; m.cal_start=m.train_n+1; m.cal_n=n*15/100;
   m.test_start=m.cal_start+m.cal_n+1; m.test_n=n-m.test_start;
   s.train_n=m.train_n; s.cal_n=m.cal_n; s.test_n=m.test_n;
   if(m.train_n<c.min_train || m.cal_n<c.min_evaluation || m.test_n<c.min_evaluation) return false;
   m.train_end=samples[m.train_n-1].label_end; m.cal_start_time=samples[m.cal_start].asof;
   m.cal_end=samples[m.cal_start+m.cal_n-1].label_end; m.test_start_time=samples[m.test_start].asof;
   m.test_end=samples[n-1].label_end;
   if(m.train_end>=m.cal_start_time || m.cal_end>=m.test_start_time)
     { s.status="INVALID_SPLIT"; s.reason="Nhãn bị chồng lấn qua ranh giới thời gian"; return false; }
   int counts[3]; ArrayInitialize(counts,0);
   for(int i=0;i<m.train_n;i++)
     {
      if(samples[i].label<0 || samples[i].label>2) return false;
      counts[samples[i].label]++;
      for(int f=0;f<32;f++) m.mean[f]+=samples[i].x[f]/m.train_n;
     }
   for(int k=0;k<3;k++)
     {
      if(counts[k]<15) { s.status="INSUFFICIENT_CLASSES"; s.reason="Cần ít nhất 15 mẫu mỗi lớp trong train"; return false; }
      m.prior[k]=(counts[k]+1.0)/(m.train_n+3.0);
     }
   for(int i=0;i<m.train_n;i++)
      for(int f=0;f<32;f++) { double d=samples[i].x[f]-m.mean[f]; m.scale[f]+=d*d/m.train_n; }
   for(int f=0;f<32;f++) m.scale[f]=MathMax(0.000001,MathSqrt(m.scale[f]));
   for(int h=0;h<12;h++)
      for(int f=0;f<32;f++) m.deep[h*33+f]=MathSin((h*33+f+1)*12.9898)*MathSqrt(6.0/44.0);
   for(int h=0;h<6;h++)
      for(int f=0;f<12;f++) m.deep[396+h*13+f]=MathSin((h*13+f+501)*12.9898)*MathSqrt(6.0/18.0);
   for(int k=0;k<3;k++)
     {
      m.lr[k*33+32]=MathLog(m.prior[k]); m.deep[474+k*7+6]=MathLog(m.prior[k]);
      for(int h=0;h<6;h++) m.deep[474+k*7+h]=MathSin((k*7+h+701)*12.9898)*MathSqrt(6.0/9.0);
     }
   m.lr_temperature=1; m.deep_temperature=1;
   s.status="TRAINING"; s.reason="Đang học logistic + DNN 32-12-6-3 từ nến đóng";
   return true;
  }
void ICTStatTrainSample(SICTStatModel &m,const SICTStatSample &s,const bool train_deep)
  {
   double x[32],p[3],a[12],b[6],z[3],d3[3],d2[6],d1[12];
   ICTStatNormalize(m,s,x); ICTStatForward(m,s,false,1,p);
   double rate=0.015/(1.0+m.epoch*0.04),decay=0.0005;
   for(int k=0;k<3;k++)
     {
      double d=p[k]-(s.label==k ? 1.0 : 0.0);
      for(int f=0;f<32;f++) m.lr[k*33+f]-=rate*(d*x[f]+decay*m.lr[k*33+f]);
      m.lr[k*33+32]-=rate*d;
     }
   if(!train_deep) return;
   for(int h=0;h<12;h++)
     { double v=m.deep[h*33+32]; for(int f=0;f<32;f++) v+=m.deep[h*33+f]*x[f]; a[h]=ICTStatTanh(v); }
   for(int h=0;h<6;h++)
     { double v=m.deep[396+h*13+12]; for(int f=0;f<12;f++) v+=m.deep[396+h*13+f]*a[f]; b[h]=ICTStatTanh(v); }
   for(int k=0;k<3;k++)
     { z[k]=m.deep[474+k*7+6]; for(int h=0;h<6;h++) z[k]+=m.deep[474+k*7+h]*b[h]; }
   ICTStatSoftmax(z,1,p);
   for(int k=0;k<3;k++) d3[k]=p[k]-(s.label==k ? 1.0 : 0.0);
   for(int h=0;h<6;h++)
     { double d=0; for(int k=0;k<3;k++) d+=d3[k]*m.deep[474+k*7+h]; d2[h]=d*(1-b[h]*b[h]); }
   for(int h=0;h<12;h++)
     { double d=0; for(int k=0;k<6;k++) d+=d2[k]*m.deep[396+k*13+h]; d1[h]=d*(1-a[h]*a[h]); }
   for(int k=0;k<3;k++)
     {
      for(int h=0;h<6;h++) m.deep[474+k*7+h]-=rate*(d3[k]*b[h]+decay*m.deep[474+k*7+h]);
      m.deep[474+k*7+6]-=rate*d3[k];
     }
   for(int h=0;h<6;h++)
     {
      for(int f=0;f<12;f++) m.deep[396+h*13+f]-=rate*(d2[h]*a[f]+decay*m.deep[396+h*13+f]);
      m.deep[396+h*13+12]-=rate*d2[h];
     }
   for(int h=0;h<12;h++)
     {
      for(int f=0;f<32;f++) m.deep[h*33+f]-=rate*(d1[h]*x[f]+decay*m.deep[h*33+f]);
      m.deep[h*33+32]-=rate*d1[h];
     }
  }
bool ICTStatTrainStep(SICTStatModel &m,const SICTStatSample &samples[],SICTStatSnapshot &s)
  {
   if(m.train_n<1 || m.epoch>=ICT_STAT_EPOCHS) return false;
   // Bounded batches let the EA's timer budget yield between steps.
   for(int b=0;b<16 && m.epoch<ICT_STAT_EPOCHS;b++)
     {
      int i=(m.cursor+m.epoch*67)%m.train_n;
      ICTStatTrainSample(m,samples[i],m.epoch<ICT_STAT_DEEP_EPOCHS);
      if(++m.cursor>=m.train_n) { m.cursor=0; m.epoch++; }
     }
   s.progress=(m.epoch*m.train_n+m.cursor)*100/(ICT_STAT_EPOCHS*m.train_n);
   return m.epoch<ICT_STAT_EPOCHS;
  }
double ICTStatTemperature(const SICTStatModel &m,const SICTStatSample &samples[],const bool deep)
  {
   double temperatures[5]={0.75,1.0,1.5,2.0,3.0};
   double best=1,best_loss=1.0e100;
   for(int t=0;t<5;t++)
     {
      double loss=0; double p[3];
      for(int i=m.cal_start;i<m.cal_start+m.cal_n;i++)
        {
         ICTStatForward(m,samples[i],deep,temperatures[t],p);
         loss-=MathLog(MathMax(0.000000001,p[samples[i].label]));
        }
      if(loss<best_loss) { best_loss=loss; best=temperatures[t]; }
     }
   return best;
  }
double ICTStatBrier(const double &p[],const int label)
  {
   double result=0;
   for(int k=0;k<3;k++) { double d=p[k]-(k==label ? 1.0 : 0.0); result+=d*d; }
   return result;
  }
int ICTStatArgmax(const double &p[])
  { int best=0; for(int k=1;k<3;k++) if(p[k]>p[best]) best=k; return best; }
bool ICTStatFinish(SICTStatModel &m,const SICTStatSample &samples[],SICTStatSnapshot &s)
  {
   if(m.epoch<ICT_STAT_EPOCHS || m.test_n<1) return false;
   int counts[3]; ArrayInitialize(counts,0);
   for(int i=m.cal_start;i<m.cal_start+m.cal_n;i++) counts[samples[i].label]++;
   m.calibrated=counts[0]>=5 && counts[1]>=5 && counts[2]>=5;
   if(m.calibrated)
     { m.lr_temperature=ICTStatTemperature(m,samples,false); m.deep_temperature=ICTStatTemperature(m,samples,true); }
   s.brier_ml=0; s.brier_dl=0; s.brier_combined=0; s.brier_baseline=0;
   s.accuracy=0; s.baseline_accuracy=0;
   ArrayInitialize(s.pattern_n,0); ArrayInitialize(s.pattern_hits,0);
   for(int i=m.test_start;i<m.test_start+m.test_n;i++)
     {
      double ml[3],dl[3],both[3];
      ICTStatForward(m,samples[i],false,m.lr_temperature,ml);
      ICTStatForward(m,samples[i],true,m.deep_temperature,dl);
      for(int k=0;k<3;k++) both[k]=(ml[k]+dl[k])/2.0;
      s.brier_ml+=ICTStatBrier(ml,samples[i].label)/m.test_n;
      s.brier_dl+=ICTStatBrier(dl,samples[i].label)/m.test_n;
      s.brier_combined+=ICTStatBrier(both,samples[i].label)/m.test_n;
      s.brier_baseline+=ICTStatBrier(m.prior,samples[i].label)/m.test_n;
      if(ICTStatArgmax(both)==samples[i].label) s.accuracy+=1.0/m.test_n;
      if(ICTStatArgmax(m.prior)==samples[i].label) s.baseline_accuracy+=1.0/m.test_n;
      for(int k=0;k<8;k++)
         if((samples[i].mask & (1<<k))!=0)
           { s.pattern_n[k]++; if(samples[i].label==k%2) s.pattern_hits[k]++; }
     }
   for(int k=0;k<ICT_STAT_LR_WEIGHTS;k++) if(!MathIsValidNumber(m.lr[k])) return false;
   for(int k=0;k<ICT_STAT_DNN_WEIGHTS;k++) if(!MathIsValidNumber(m.deep[k])) return false;
   if(!MathIsValidNumber(s.brier_combined) || !MathIsValidNumber(s.brier_baseline)) return false;
   m.fitted=true; s.ready=true; s.calibrated=m.calibrated; s.progress=100;
   s.train_end=m.train_end; s.test_end=m.test_end;
   s.beats_baseline=s.brier_combined<s.brier_baseline;
   s.status=s.beats_baseline ? "VALIDATION_BETTER" : "BASELINE_NOT_BEATEN";
   s.reason=s.beats_baseline ? "Brier thấp hơn tần suất train trên đoạn kiểm định" : "Chưa vượt tần suất train trên đoạn kiểm định";
   return true;
  }
bool ICTStatPredict(const SICTStatModel &m,const SICTStatSample &sample,SICTStatSnapshot &s)
  {
   s.ready=false;
   if(!m.fitted) return false;
   for(int k=0;k<32;k++) if(!MathIsValidNumber(sample.x[k])) return false;
   ICTStatForward(m,sample,false,m.lr_temperature,s.ml);
   ICTStatForward(m,sample,true,m.deep_temperature,s.dl);
   double sum=0;
   for(int k=0;k<3;k++)
     {
      s.combined[k]=(s.ml[k]+s.dl[k])/2.0;
      if(!MathIsValidNumber(s.combined[k]) || s.combined[k]<0 || s.combined[k]>1) return false;
      sum+=s.combined[k];
     }
   if(MathAbs(sum-1)>0.000001) return false;
   s.mask=sample.mask; s.asof=sample.asof; s.ready=true;
   return true;
  }
void ICTStatWilson(const int hits,const int n,double &low,double &high)
  {
   low=0; high=1;
   if(n<1 || hits<0 || hits>n) return;
   double p=(double)hits/n,z=1.96,den=1+z*z/n;
   double center=(p+z*z/(2*n))/den;
   double half=z*MathSqrt(p*(1-p)/n+z*z/(4.0*n*n))/den;
   low=MathMax(0,center-half); high=MathMin(1,center+half);
  }

// Separate first-touch task. Class 0=BSL first, 1=SSL first, 2=no touch by H.
// These samples NEVER share a fitted model with the horizon-close task above.
struct SICTStatLiquidityPair
  {
   bool valid;
   string bsl_id,ssl_id;
   double bsl,ssl,spot;
   datetime asof,bsl_available,ssl_available,trend_closed_at;
   ENUM_TIMEFRAMES bsl_tf,ssl_tf;
   int trend_bias,htf_bias;
  };
struct SICTStatLiquidityAudit
  {
   int attempted,missing_pair,missing_trend,ambiguous,censored,eligible,test_classes[3];
   bool validation_pass;
   double brier_geometry,log_loss,ece;
  };
struct SICTStatLiquidityRecord
  { SICTStatLiquidityPair pair; datetime label_end; int label; };

bool ICTStatLiquidityValidPair(const SICTStatLiquidityPair &p)
  {
   return p.valid && p.asof>0 && MathIsValidNumber(p.spot) && MathIsValidNumber(p.bsl) && MathIsValidNumber(p.ssl) &&
      p.ssl>0 && p.ssl<p.spot && p.bsl>p.spot && p.bsl_available>0 && p.ssl_available>0 &&
      p.bsl_available<=p.asof && p.ssl_available<=p.asof;
  }
bool ICTStatLiquiditySamePair(const SICTStatLiquidityPair &a,const SICTStatLiquidityPair &b)
  {
   if(a.valid!=b.valid) return false;
   if(!a.valid) return true;
   return a.asof==b.asof && a.bsl_id==b.bsl_id && a.ssl_id==b.ssl_id && a.bsl==b.bsl && a.ssl==b.ssl &&
      a.bsl_tf==b.bsl_tf && a.ssl_tf==b.ssl_tf;
  }

bool ICTStatLiquidityPristine(const MqlRates &r[],const int count,const int seconds,
                              const SICTRangeLevel &l,const datetime asof)
  {
   if(count<1 || count>ArraySize(r) || seconds<=0 || ArrayGetAsSeries(r) ||
      !ICTRangeLevelUntouched(l,asof) || r[count-1].time+seconds!=asof || l.available_at<r[0].time)
      return false;
   if(l.available_at==asof) return true;
   int first=ICTRateIndex(r,count,l.available_at);
   if(first<0) return false; // Missing coverage cannot certify an untouched level.
   for(int j=first;j<count;j++)
     {
      if(!SRMPValidDetectorBar(r[j]) || (j>first && r[j].time!=r[j-1].time+seconds)) return false;
      if(l.side>0 ? r[j].high>=l.price : r[j].low<=l.price) return false;
     }
   return true;
  }

bool ICTStatLiquiditySelectPair(const SICTRangeSnapshot &s,const MqlRates &r[],const int count,
                                SICTStatLiquidityPair &p,const bool show_irl=true,const bool show_erl=true)
  {
   ZeroMemory(p);
   int seconds=PeriodSeconds(s.ltf);
   if(!s.valid || !s.range.valid || s.schema!=ICT_RANGE_SCHEMA || count<1 || count>ArraySize(r) ||
      seconds<=0 || s.as_of!=r[count-1].time+seconds || !SRMPValidDetectorBar(r[count-1])) return false;
   p.spot=r[count-1].close; p.asof=s.as_of; p.htf_bias=s.htf_bias;
   for(int i=0;i<s.level_count && i<ICT_RANGE_LEVELS;i++)
     {
      SICTRangeLevel l=s.levels[i];
      bool external=l.membership==IR_BOUNDARY || l.membership==IR_OUTSIDE;
      if(l.range_id!=s.range.id || PeriodSeconds(l.timeframe)<=0 ||
         (external ? !show_erl : l.membership!=IR_INTERNAL || !show_irl) ||
         !ICTStatLiquidityPristine(r,count,seconds,l,s.as_of)) continue;
      if(l.side>0 && l.price>p.spot && (p.bsl<=0 || l.price<p.bsl ||
         (l.price==p.bsl && PeriodSeconds(l.timeframe)>PeriodSeconds(p.bsl_tf))))
        { p.bsl=l.price; p.bsl_id=l.id; p.bsl_tf=l.timeframe; p.bsl_available=l.available_at; }
      if(l.side<0 && l.price<p.spot && (p.ssl<=0 || l.price>p.ssl ||
         (l.price==p.ssl && PeriodSeconds(l.timeframe)>PeriodSeconds(p.ssl_tf))))
        { p.ssl=l.price; p.ssl_id=l.id; p.ssl_tf=l.timeframe; p.ssl_available=l.available_at; }
     }
   p.valid=p.bsl_id!="" && p.ssl_id!="" && p.bsl>p.spot && p.ssl>0 && p.ssl<p.spot;
   return p.valid;
  }

bool ICTStatLiquidityFeatures(const MqlRates &r[],const int i,const int seconds,const double point,
                              const SICTStatLiquidityPair &p,SICTStatSample &s)
  {
   ZeroMemory(s);
   if(!ICTStatLiquidityValidPair(p) || seconds<=0 || i<32 || i>=ArraySize(r) || p.asof!=r[i].time+seconds ||
      p.spot!=r[i].close || p.ssl<=0 || p.ssl>=p.spot || p.bsl<=p.spot ||
      p.trend_closed_at<=0 || p.trend_closed_at>p.asof || p.trend_bias < -1 || p.trend_bias>1)
      return false;
   for(int j=i-32;j<=i;j++)
      if(!SRMPValidDetectorBar(r[j]) || (j>i-32 && r[j].time!=r[j-1].time+seconds)) return false;
   if(!ICTStatFeatures(r,i,point,s)) return false;
   double atr=ICTStatATR(r,i),up=p.bsl-p.spot,down=p.spot-p.ssl;
   s.x[20]=up/atr; s.x[21]=down/atr; s.x[22]=down/(up+down);
   s.x[23]=p.trend_bias; s.x[24]=p.htf_bias;
   s.x[25]=MathLog(1.0+(double)PeriodSeconds(p.bsl_tf)/seconds);
   s.x[26]=MathLog(1.0+(double)PeriodSeconds(p.ssl_tf)/seconds);
   s.x[28]=MathLog(1.0+(double)(p.asof-p.bsl_available)/seconds);
   s.x[29]=MathLog(1.0+(double)(p.asof-p.ssl_available)/seconds);
   s.x[30]=(r[i].close-r[i-3].close)/atr; s.x[31]=(r[i].close-r[i-12].close)/atr;
   s.mask=0; s.asof=p.asof;
   for(int k=0;k<32;k++) if(!MathIsValidNumber(s.x[k])) return false;
   return true;
  }

int ICTStatLiquidityLabel(const MqlRates &r[],const int count,const int i,const int horizon,
                          const int seconds,const SICTStatLiquidityPair &p,datetime &label_end)
  {
   label_end=0;
   if(!ICTStatLiquidityValidPair(p) || ArrayGetAsSeries(r) || seconds<=0 || horizon<1 || count>ArraySize(r) || i<0 || i+horizon>=count ||
      p.asof!=r[i].time+seconds || p.ssl<=0 || p.ssl>=p.spot || p.bsl<=p.spot) return -1;
   for(int j=i+1;j<=i+horizon;j++)
     {
      if(!SRMPValidDetectorBar(r[j]) || r[j].time!=r[j-1].time+seconds) return -1;
      label_end=r[j].time+seconds;
      // Open is observed before this candle's high/low. Otherwise both wicks
      // touching the frozen barriers cannot be ordered from OHLC.
      if(r[j].open>=p.bsl) return 0;
      if(r[j].open<=p.ssl) return 1;
      bool upper=r[j].high>=p.bsl,lower=r[j].low<=p.ssl;
      if(upper && lower) return -2;
      if(upper) return 0;
      if(lower) return 1;
     }
   return 2;
  }

void ICTStatLiquidityGeometry(const SICTStatSample &s,const double timeout,double &p[])
  {
   double neutral=ICTStatClip(timeout,0,1),upper=ICTStatClip(s.x[22],0,1);
   p[0]=(1-neutral)*upper; p[1]=(1-neutral)*(1-upper); p[2]=neutral;
  }

bool ICTStatLiquidityInSupport(const SICTStatModel &m,const SICTStatSample &s)
  {
   if(!m.fitted) return false;
   for(int f=0;f<32;f++)
      if(!MathIsValidNumber(s.x[f]) || !MathIsValidNumber(m.mean[f]) ||
         !MathIsValidNumber(m.scale[f]) || m.scale[f]<=0 || MathAbs((s.x[f]-m.mean[f])/m.scale[f])>5)
         return false;
   return true; // Do not turn clipped extrapolation into a confident forecast.
  }

bool ICTStatLiquidityAuditModel(const SICTStatModel &m,const SICTStatSample &samples[],
                                const SICTStatSnapshot &s,SICTStatLiquidityAudit &a)
  {
   a.validation_pass=false; a.brier_geometry=0; a.log_loss=0; a.ece=0;
   ArrayInitialize(a.test_classes,0);
   if(!m.fitted || !s.ready || m.test_n<1 || m.test_start+m.test_n>ArraySize(samples)) return false;
   int bins[10]; double confidence[10],hits[10];
   ArrayInitialize(bins,0); ArrayInitialize(confidence,0); ArrayInitialize(hits,0);
   for(int i=m.test_start;i<m.test_start+m.test_n;i++)
     {
      double ml[3],dl[3],both[3],geometry[3];
      ICTStatForward(m,samples[i],false,m.lr_temperature,ml);
      ICTStatForward(m,samples[i],true,m.deep_temperature,dl);
      for(int k=0;k<3;k++) both[k]=(ml[k]+dl[k])/2.0;
      ICTStatLiquidityGeometry(samples[i],m.prior[2],geometry);
      a.brier_geometry+=ICTStatBrier(geometry,samples[i].label)/m.test_n;
      a.log_loss-=MathLog(MathMax(1e-12,both[samples[i].label]))/m.test_n;
      a.test_classes[samples[i].label]++;
      int best=ICTStatArgmax(both),bin=(int)MathMin(9,(int)(both[best]*10));
      bins[bin]++; confidence[bin]+=both[best]; hits[bin]+=(best==samples[i].label ? 1.0 : 0.0);
     }
   for(int b=0;b<10;b++) if(bins[b]>0) a.ece+=MathAbs(confidence[b]-hits[b])/m.test_n;
   a.validation_pass=s.calibrated && s.beats_baseline && s.brier_combined<a.brier_geometry &&
      a.test_classes[0]>=5 && a.test_classes[1]>=5 && a.test_classes[2]>=5;
   return a.validation_pass;
  }
#endif
