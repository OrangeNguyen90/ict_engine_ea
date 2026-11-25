using System;
using System.Reflection;
using System.Text;
public static class ICTCoreRuntime_99776ce725d949c68a8d6fb520c13d17 {
 public const double DBL_MAX=double.MaxValue;
 public static double ICTNumber(object value){return Convert.ToDouble(value,System.Globalization.CultureInfo.InvariantCulture);}
 public const int PERIOD_CURRENT=0,PERIOD_M1=1,PERIOD_M2=2,PERIOD_M3=3,PERIOD_M4=4,PERIOD_M5=5,PERIOD_M6=6,PERIOD_M10=10,PERIOD_M12=12,PERIOD_M15=15,PERIOD_M20=20,PERIOD_M30=30;
 public const int PERIOD_H1=16385,PERIOD_H2=16386,PERIOD_H3=16387,PERIOD_H4=16388,PERIOD_H6=16390,PERIOD_H8=16392,PERIOD_H12=16396,PERIOD_D1=16408,PERIOD_W1=32769,PERIOD_MN1=49153;
 public const int clrMaroon=128,clrYellow=65535;
 public const int _Digits=2,TIME_DATE=1,TIME_MINUTES=2,TIME_SECONDS=4,SYMBOL_BID=1,SYMBOL_POINT=2;
 public static SICTChartZone[] g_ict_chart_zones=new SICTChartZone[0];
 public static bool g_ict_chart_collect=false;
 public static string g_ict_chart_prefix="";
 public static int g_ict_chart_zone_tf=PERIOD_CURRENT,g_ict_chart_font=10,g_ict_chart_zone_suppressed=0;
 public class MqlRates { public long time,tick_volume,real_volume; public int spread; public double open,high,low,close; }
 public class MqlDateTime { public int year,mon,day,hour,min,sec; }
 public static int PeriodSeconds(int tf) {if(tf>0 && tf<60)return tf*60;if(tf>=16385 && tf<=16408)return (tf-16384)*3600;if(tf==32769)return 604800;if(tf==49153)return 2592000;return 0;}
 public static long Stamp(string text) {return (long)(DateTime.ParseExact(text,new string[]{"yyyy.MM.dd","yyyy.MM.dd HH:mm","yyyy.MM.dd HH:mm:ss"},System.Globalization.CultureInfo.InvariantCulture,System.Globalization.DateTimeStyles.AssumeUniversal|System.Globalization.DateTimeStyles.AdjustToUniversal)-new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc)).TotalSeconds;}
 public static bool TimeToStruct(long time,MqlDateTime d) {DateTime t=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(time);d.year=t.Year;d.mon=t.Month;d.day=t.Day;d.hour=t.Hour;d.min=t.Minute;d.sec=t.Second;return true;}
 public static long StructToTime(MqlDateTime d) {return (long)(new DateTime(d.year,d.mon,d.day,d.hour,d.min,d.sec,DateTimeKind.Utc)-new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc)).TotalSeconds;}
 public static T NewValue<T>() {return typeof(T)==typeof(string) ? (T)(object)string.Empty : (T)Activator.CreateInstance(typeof(T));}
 public static T[] InitArray<T>(int n) {T[] a=new T[n];for(int i=0;i<n;i++)a[i]=NewValue<T>();return a;}
 public static void ArrayResize<T>(ref T[] a,int n) {int old=a.Length;Array.Resize(ref a,n);for(int i=old;i<n;i++)a[i]=NewValue<T>();}
 public static int ArraySize<T>(T[] a) {return a.Length;}
 public static bool ArrayGetAsSeries<T>(T[] a) {return false;}
 public static void ArrayInitialize<T>(T[] a,T value) {for(int i=0;i<a.Length;i++)a[i]=value;}
 public static int ArrayCopy<T>(ref T[] a,T[] b,int dest=0,int first=0,int count=-1) {if(count<0)count=b.Length-first;if(a.Length<dest+count)ArrayResize(ref a,dest+count);Array.Copy(b,first,a,dest,count);return count;}
 public static void ZeroMemory(object x) {foreach(FieldInfo f in x.GetType().GetFields(BindingFlags.Public|BindingFlags.Instance)){Type t=f.FieldType;if(t==typeof(string))f.SetValue(x,string.Empty);else if(t.IsArray){Array old=(Array)f.GetValue(x);int n=old==null?0:old.Length;Array a=Array.CreateInstance(t.GetElementType(),n);for(int i=0;i<n;i++)a.SetValue(t.GetElementType()==typeof(string)?(object)string.Empty:Activator.CreateInstance(t.GetElementType()),i);f.SetValue(x,a);}else f.SetValue(x,Activator.CreateInstance(t));}}
 public static double MathAbs(double x){return Math.Abs(x);} public static int MathAbs(int x){return Math.Abs(x);} public static long MathAbs(long x){return Math.Abs(x);}
 public static double MathMax(double a,double b){return Math.Max(a,b);} public static int MathMax(int a,int b){return Math.Max(a,b);} public static long MathMax(long a,long b){return Math.Max(a,b);}
 public static double MathMin(double a,double b){return Math.Min(a,b);} public static int MathMin(int a,int b){return Math.Min(a,b);} public static long MathMin(long a,long b){return Math.Min(a,b);}
 public static double MathLog(double x){return Math.Log(x);} public static double MathSqrt(double x){return Math.Sqrt(x);} public static double MathSin(double x){return Math.Sin(x);} public static double MathExp(double x){return Math.Exp(x);}
 public static double MathPow(double x,double y){return Math.Pow(x,y);} public static double MathRound(double x){return Math.Round(x,MidpointRounding.AwayFromZero);}
 public static bool MathIsValidNumber(double x){return !Double.IsNaN(x) && !Double.IsInfinity(x);}
 public static int StringLen(string x){return x.Length;} public static int StringGetCharacter(string x,int at){return x[at];}
 public static int StringFind(string text,string find,int start=0){return text.IndexOf(find,start,StringComparison.Ordinal);}
 public static int StringReplace(ref string text,string find,string replacement){int n=text.Split(new string[]{find},StringSplitOptions.None).Length-1;text=text.Replace(find,replacement);return n;}
 public static string TimeToString(long t,int mode=0){return t.ToString(System.Globalization.CultureInfo.InvariantCulture);}
 public static long TimeCurrent(){return 100300;} public static double SymbolInfoDouble(string symbol,int property){return 0;}
 public static string ICTChartLegend(){return "";}
 public static string IntegerToString(long x){return x.ToString(System.Globalization.CultureInfo.InvariantCulture);}
 public static string DoubleToString(double x,int digits){return x.ToString("F"+digits,System.Globalization.CultureInfo.InvariantCulture);}
 public static string EnumToString(int x){return x.ToString();}
 public static int StringCompare(string a,string b){return String.CompareOrdinal(a,b);}
 static int failures,checks;static StringBuilder log=new StringBuilder();
 public static void Check(string name,bool value){checks++;if(!value)failures++;log.AppendLine(name+(value?" PASS":" FAIL"));}
 public static string Run(){failures=0;checks=0;log.Length=0;RunUnifiedCoreFixtures();RunUnifiedDiagnosticFixtures();TestChartLayout();TestDashboardVietnamese();TestSignalBridge();RunICTStatisticalLearningFixtures();RunICTSweepFocusFixtures();RunICTAnalyticalFixtures();log.AppendLine("ICTCoreFixtures RESULT checks="+checks+" failures="+failures);return log.ToString();}
public const int ICT_SWEEP_SEQUENCE_MAX=32;
public const int ICT_SWEEP_SNAPSHOT_MAX=64;
public const int ICT_SMART_SMT_MAX=512;
public const int ICT_RANGE_LEVELS=24;
public const int ICT_RANGE_ZONES=16;
public const int ICT_RANGE_HISTORY=64;
public const int ICT_RANGE_EVENTS=256;
public const int ICT_RANGE_LIQUIDITY_EVENTS=128;
public const int ICT_RANGE_SCHEMA=4;
public const int ICT_UNIFIED_SCHEMA=3;
public const int ICT_SMART_OB_MAX=128;
public const int ICT_SMT_PAYLOAD_VERSION=2;
public const int ICT_SMT_PAYLOAD_MAGIC=1397576753;
public const int ICT_SMT_PAYLOAD_FIELDS=20;
public const int ICT_SMT_PAYLOAD_MAX_BYTES=4194304;
public const int ICT_U_NUMBERS_MAX=32768;
public const int ICT_U_STRINGS_MAX=4096;
public const int ICT_STAT_FEATURES=32;
public const int ICT_STAT_H1=12;
public const int ICT_STAT_H2=6;
public const int ICT_STAT_CLASSES=3;
public const int ICT_STAT_LR_WEIGHTS=99;
public const int ICT_STAT_DNN_WEIGHTS=495;
public const int ICT_STAT_EPOCHS=32;
public const int ICT_STAT_DEEP_EPOCHS=24;
public const int ICT_SWEEP_FOCUS_H1_BARS=120;
public const int ICT_ANALYSIS_GROUPS=6;





public const int ICT_MTF_AUTO=0;
public const int ICT_MTF_MANUAL=1;

public const int ICT_MTF_INVALID=0;
public const int ICT_MTF_FULL=1;
public const int ICT_MTF_TWO_TIER=2;
public const int ICT_MTF_ONE_TIER=3;

public const int ICT_TIER_INSUFFICIENT=0;
public const int ICT_TIER_NEUTRAL=1;
public const int ICT_TIER_CONFLICT=2;
public const int ICT_TIER_ALIGNED=3;

public class SICTTimeframes {
public int ltf;
public int mtf;
public int htf;
public int mode;
public int status;
}


public static int ICTTierAlignment(bool data_ready,int htf_bias,int mtf_bias,int ltf_direction) {
   if(!data_ready || htf_bias<-1 || htf_bias>1 || mtf_bias<-1 || mtf_bias>1 ||
      ltf_direction<-1 || ltf_direction>1) return ICT_TIER_INSUFFICIENT;
   if(htf_bias==0) return ICT_TIER_NEUTRAL;
   if(mtf_bias==0 || mtf_bias!=htf_bias || (ltf_direction!=0 && ltf_direction!=htf_bias))
      return ICT_TIER_CONFLICT;
   return ICT_TIER_ALIGNED;
  }



public static bool ICTMapTimeframes(int chart,int mode,int manual_mtf,int manual_htf,SICTTimeframes result_out) {
   ZeroMemory(result_out); result_out.ltf=chart; result_out.mode=mode;
   if(PeriodSeconds(chart)<=0 || chart==PERIOD_CURRENT) return false;
   if(mode==ICT_MTF_MANUAL)
     {
      if(manual_mtf==PERIOD_CURRENT)
        {
         if(chart!=PERIOD_MN1 || manual_htf!=PERIOD_CURRENT) return false;
         result_out.status=ICT_MTF_ONE_TIER; return true;
        }
      if(PeriodSeconds(manual_mtf)<=PeriodSeconds(chart)) return false;
      result_out.mtf=manual_mtf;
      if(manual_htf==PERIOD_CURRENT)
        {
         if(chart!=PERIOD_W1 || manual_mtf!=PERIOD_MN1) return false;
         result_out.status=ICT_MTF_TWO_TIER; return true;
        }
      if(PeriodSeconds(manual_htf)<=PeriodSeconds(manual_mtf)) return false;
      result_out.htf=manual_htf; result_out.status=ICT_MTF_FULL; return true;
     }
   if(mode!=ICT_MTF_AUTO) return false;
   switch(chart)
     {
      case PERIOD_M1: case PERIOD_M2: case PERIOD_M3: case PERIOD_M4:
         result_out.mtf=PERIOD_M15; result_out.htf=PERIOD_H4; break;
      case PERIOD_M5: case PERIOD_M6: case PERIOD_M10: case PERIOD_M12:
      case PERIOD_M15: case PERIOD_M20:
         result_out.mtf=PERIOD_H1; result_out.htf=PERIOD_D1; break;
      case PERIOD_M30: case PERIOD_H1:
         result_out.mtf=PERIOD_H4; result_out.htf=PERIOD_D1; break;
      case PERIOD_H2: case PERIOD_H3:
         result_out.mtf=PERIOD_H4; result_out.htf=PERIOD_W1; break;
      case PERIOD_H4: case PERIOD_H6: case PERIOD_H8: case PERIOD_H12:
         result_out.mtf=PERIOD_D1; result_out.htf=PERIOD_W1; break;
      case PERIOD_D1: result_out.mtf=PERIOD_W1; result_out.htf=PERIOD_MN1; break;
      case PERIOD_W1: result_out.mtf=PERIOD_MN1; result_out.status=ICT_MTF_TWO_TIER; return true;
      case PERIOD_MN1: result_out.status=ICT_MTF_ONE_TIER; return true;
      default: return false;
     }
   result_out.status=ICT_MTF_FULL; return true;
  }



public static bool ICTResolveTimeframes(int chart,bool automatic,int ltf_override,int mtf_override,int htf_override,SICTTimeframes result_out) {
   int ltf=(ltf_override==PERIOD_CURRENT ? chart : ltf_override);
   if(!automatic) return ICTMapTimeframes(ltf,ICT_MTF_MANUAL,mtf_override,htf_override,result_out);
   if(!ICTMapTimeframes(ltf,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,result_out)) return false;
   if(mtf_override!=PERIOD_CURRENT) result_out.mtf=mtf_override;
   if(htf_override!=PERIOD_CURRENT) result_out.htf=htf_override;
   if(result_out.mtf==PERIOD_CURRENT || result_out.htf==PERIOD_CURRENT)
     {

      if(mtf_override!=PERIOD_CURRENT || htf_override!=PERIOD_CURRENT) return false;
      return true;
     }
   if(PeriodSeconds(result_out.mtf)<=PeriodSeconds(result_out.ltf) || PeriodSeconds(result_out.htf)<=PeriodSeconds(result_out.mtf))
     { result_out.status=ICT_MTF_INVALID; return false; }
   result_out.status=ICT_MTF_FULL;
   return true;
  }






public const int ICT_SIGNAL_NO_TRADE=0;
public const int ICT_SIGNAL_WATCH_BUY=1;
public const int ICT_SIGNAL_WATCH_SELL=2;
public const int ICT_SIGNAL_BUY_CONFIRMED=3;
public const int ICT_SIGNAL_SELL_CONFIRMED=4;

public const int ICT_BAR_CONFLICT=0;
public const int ICT_BAR_KEEP_CONFIRMED=1;
public const int ICT_BAR_REFRESH_UNCONFIRMED=2;
public const int ICT_BAR_COMMIT_CONFIRMED=3;

public class SICTSignalResult {
public string id=string.Empty;
public string symbol=string.Empty;
public string reason=string.Empty;
public string htf_reason=string.Empty;
public string mtf_reason=string.Empty;
public string ltf_reason=string.Empty;
public string smt_reason=string.Empty;
public string source_pool_id=string.Empty;
public string target_pool_id=string.Empty;
public string target2_pool_id=string.Empty;
public string liquidity_event=string.Empty;
public SICTTimeframes frames=new SICTTimeframes();
public int state;
public long asof;
public long trigger_bar;
public long confirmation_time;
public long source_event_time;
public int direction;
public int score;
public bool data_ready;
public bool htf_pass;
public bool mtf_pass;
public bool ltf_pass;
public bool smt_required;
public bool smt_pass;
public bool risk_pass;
public bool confirmed;
public double entry;
public double stop;
public double tp1;
public double tp2;
public double rr;
public double source_price;
}

public static string ICTSignalStateText(int state) {
   if(state==ICT_SIGNAL_BUY_CONFIRMED) return "BUY_CONFIRMED";
   if(state==ICT_SIGNAL_SELL_CONFIRMED) return "SELL_CONFIRMED";
   if(state==ICT_SIGNAL_WATCH_BUY) return "WATCH_BUY";
   if(state==ICT_SIGNAL_WATCH_SELL) return "WATCH_SELL";
   return "NO_TRADE";
  }




public static bool ICTClosedZoneReaction(MqlRates bar,long asof,int direction,double lower,double upper,long zone_confirmed,long structure_confirmed) {
   if((direction!=1 && direction!=-1) || bar.time<=0 || asof<=bar.time ||
      zone_confirmed<=0 || structure_confirmed<=0 ||
      zone_confirmed>bar.time || structure_confirmed>bar.time ||
      !MathIsValidNumber(lower) || !MathIsValidNumber(upper) || lower<=0 || upper<=lower ||
      !MathIsValidNumber(bar.open) || !MathIsValidNumber(bar.high) ||
      !MathIsValidNumber(bar.low) || !MathIsValidNumber(bar.close) ||
      bar.low<=0 || bar.high<bar.low || bar.open<bar.low || bar.open>bar.high ||
      bar.close<bar.low || bar.close>bar.high) return false;
   double midpoint=(lower+upper)/2.0;
   if(bar.low>upper || bar.high<lower || (bar.close-bar.open)*direction<=0) return false;
   return direction>0 ? bar.low>lower && bar.close>midpoint :
                        bar.high<upper && bar.close<midpoint;
  }



public static bool ICTClosedRangeReaction(MqlRates bar,long asof,int direction,long zone_confirmed,long structure_confirmed,long reaction_confirmed,bool setup_ready,bool displacement_confirmed) {
   return setup_ready && displacement_confirmed && (direction==1 || direction==-1) &&
      bar.time>0 && asof>bar.time && reaction_confirmed==asof &&
      zone_confirmed>0 && zone_confirmed<=bar.time &&
      structure_confirmed>0 && structure_confirmed<=bar.time &&
      MathIsValidNumber(bar.open) && MathIsValidNumber(bar.high) &&
      MathIsValidNumber(bar.low) && MathIsValidNumber(bar.close) &&
      bar.low>0 && bar.high>=bar.low && bar.open>=bar.low && bar.open<=bar.high &&
      bar.close>=bar.low && bar.close<=bar.high && (bar.close-bar.open)*direction>0;
  }




public static bool ICTMTFStructureReady(bool range_mode,int direction,int latest_break,int setup_direction,bool setup_confirmed,long structure_confirmed,long asof) {
   if(direction!=1 && direction!=-1) return false;
   if(!range_mode) return latest_break==direction;
   return setup_direction==direction && setup_confirmed && structure_confirmed>0 &&
      structure_confirmed<=asof && (latest_break==0 || latest_break==direction);
  }
public static bool ICTSignalPlanValid(SICTSignalResult s,double minimum_rr) {
   if((s.direction!=1 && s.direction!=-1) || !MathIsValidNumber(minimum_rr) || minimum_rr<2 ||
      !MathIsValidNumber(s.entry) || !MathIsValidNumber(s.stop) || !MathIsValidNumber(s.tp1) ||
      !MathIsValidNumber(s.rr) || s.entry<=0 || s.stop<=0 || s.tp1<=0 ||
      (s.entry-s.stop)*s.direction<=0 || (s.tp1-s.entry)*s.direction<=0) return false;
   double gross=MathAbs(s.tp1-s.entry)/MathAbs(s.entry-s.stop);
   return s.rr+1e-9>=minimum_rr && gross+1e-9>=minimum_rr && s.rr<=gross+1e-9;
  }



public static int ICTSignalSameBarAction(SICTSignalResult previous,SICTSignalResult current) {
   if(previous.symbol=="" || previous.symbol!=current.symbol || previous.asof<=0 ||
      previous.asof!=current.asof || previous.trigger_bar<=0 ||
      previous.trigger_bar!=current.trigger_bar || previous.asof<=previous.trigger_bar ||
      previous.frames.ltf!=current.frames.ltf || previous.frames.mtf!=current.frames.mtf ||
      previous.frames.htf!=current.frames.htf || previous.frames.mode!=current.frames.mode ||
      previous.frames.status!=current.frames.status) return ICT_BAR_CONFLICT;
   if(previous.confirmed) return ICT_BAR_KEEP_CONFIRMED;
   if(!current.confirmed)
      return current.state==ICT_SIGNAL_BUY_CONFIRMED || current.state==ICT_SIGNAL_SELL_CONFIRMED ?
         ICT_BAR_CONFLICT : ICT_BAR_REFRESH_UNCONFIRMED;
   if(current.id=="" || current.frames.status!=ICT_MTF_FULL ||
      !current.data_ready || !current.htf_pass || !current.mtf_pass || !current.ltf_pass ||
      !current.risk_pass || (current.smt_required && !current.smt_pass) ||
      current.confirmation_time!=current.asof || current.source_event_time>current.asof ||
      current.target_pool_id=="" || !ICTSignalPlanValid(current,2) ||
      current.state!=(current.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED))
      return ICT_BAR_CONFLICT;
   return ICT_BAR_COMMIT_CONFIRMED;
  }



public static void ICTSignalReconcileCommittedLive(SICTSignalResult committed,SICTSignalResult current) {
   if(!current.confirmed) return;
   bool same=current.id==committed.id && current.symbol==committed.symbol &&
      current.asof==committed.asof && current.trigger_bar==committed.trigger_bar &&
      current.direction==committed.direction && current.entry==committed.entry &&
      current.stop==committed.stop && current.tp1==committed.tp1 && current.tp2==committed.tp2 &&
      current.source_pool_id==committed.source_pool_id && current.target_pool_id==committed.target_pool_id &&
      current.target2_pool_id==committed.target2_pool_id && current.source_event_time==committed.source_event_time &&
      current.data_ready && current.htf_pass && current.mtf_pass && current.ltf_pass && current.risk_pass &&
      (!current.smt_required || current.smt_pass) && current.frames.status==ICT_MTF_FULL &&
      current.confirmation_time==current.asof && current.source_event_time<=current.asof &&
      current.target_pool_id!="" && ICTSignalPlanValid(current,2) &&
      current.state==(current.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED);


   if(same) return;
   current.confirmed=false; current.state=ICT_SIGNAL_NO_TRADE; current.risk_pass=false;
   current.confirmation_time=0;
   current.reason="NO_TRADE: live plan differs from committed signal or failed recheck";
  }

public static bool ICTEvaluateSignal(SICTSignalResult s,double minimum_rr) {
   s.confirmed=false; s.state=ICT_SIGNAL_NO_TRADE; s.confirmation_time=0;
   s.id=s.symbol+"|"+IntegerToString((int)s.frames.ltf)+"|"+IntegerToString((long)s.trigger_bar)+"|"+IntegerToString(s.direction);
   if(!s.data_ready || s.frames.status!=ICT_MTF_FULL)
     { s.reason="DATA INSUFFICIENT: three closed timeframe tiers required"; return false; }
   if((s.direction!=1 && s.direction!=-1) || !s.htf_pass || !s.mtf_pass)
     { s.reason="NO_TRADE: HTF bias / MTF setup conflict or missing"; return false; }
   if(!s.ltf_pass || s.trigger_bar<=0 || s.asof<=s.trigger_bar || s.source_event_time>s.asof)
     {
      s.state=(s.direction>0 ? ICT_SIGNAL_WATCH_BUY : ICT_SIGNAL_WATCH_SELL);
      s.reason="WATCH: waiting for a valid closed LTF trigger"; return false;
     }
   if(s.smt_required && !s.smt_pass)
     { s.reason="NO_TRADE: required SMT unavailable, conflicting or unaligned"; return false; }
   if(s.tp1<=0 || s.target_pool_id=="")
     { s.reason="TARGET UNAVAILABLE"; return false; }
   if(!s.risk_pass || !ICTSignalPlanValid(s,minimum_rr))
     { s.reason="RISK FILTER FAIL: invalid plan or net RR below configured minimum"; return false; }
   s.state=(s.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED);
   s.confirmed=true; s.confirmation_time=s.asof;
   s.reason=s.htf_reason+" / "+s.mtf_reason+" / "+s.ltf_reason;
   return true;
  }
public static bool ICTSignalInsideWindow(SICTSignalResult s,long oldest_bar,long latest_close) {
   return s.confirmed && s.trigger_bar>=oldest_bar && s.confirmation_time<=latest_close &&
      s.confirmation_time>s.trigger_bar;
  }


public static bool ICTMergeConfirmedSignal(SICTSignalResult s,ref SICTSignalResult[] history,int maximum) {
   if(!s.confirmed || s.id=="" || maximum<1 || s.confirmation_time<=s.trigger_bar) return false;
   for(int i=0;i<ArraySize(history);i++)
      if(history[i].id==s.id || (history[i].symbol==s.symbol && history[i].frames.ltf==s.frames.ltf &&
                              history[i].trigger_bar==s.trigger_bar)) return false;
   int n=ArraySize(history);
   if(n>=maximum) return false;
   ArrayResize(ref history,n+1); history[n]=s; return true;
  }






public static bool SRMPValidDetectorBar(MqlRates bar) {
   return bar.time>0 && MathIsValidNumber(bar.open) && MathIsValidNumber(bar.high) &&
          MathIsValidNumber(bar.low) && MathIsValidNumber(bar.close) &&
          bar.high>=bar.low && bar.open>=bar.low && bar.open<=bar.high &&
          bar.close>=bar.low && bar.close<=bar.high;
  }

public static bool SRMPValidDetectorRates(MqlRates[] rates,int count) {
   if(count<1 || count>ArraySize(rates) || ArrayGetAsSeries(rates)) return false;
   for(int i=0;i<count;i++)
      if(!SRMPValidDetectorBar(rates[i]) || (i>0 && rates[i].time<=rates[i-1].time)) return false;
   return true;
  }
public class SMarketStructure {
public int bias;
public int bos_direction;
public bool mss;
public double recent_high;
public double prior_high;
public double recent_low;
public double prior_low;
public long recent_high_time;
public long prior_high_time;
public long recent_low_time;
public long prior_low_time;
public long recent_high_confirmed_time;
public long prior_high_confirmed_time;
public long recent_low_confirmed_time;
public long prior_low_confirmed_time;
public long bos_time;
public double bos_level;
public long latest_closed_bar;
}


public static bool SRMPConfirmedSwingAt(MqlRates[] rates,int count,int index,int left,int right,bool high) {
   if(count>ArraySize(rates) || left<1 || right<1 || index<left || index+right>=count) return false;
   for(int k=1;k<=left;k++)
      if(high ? rates[index].high<=rates[index-k].high : rates[index].low>=rates[index-k].low) return false;
   for(int k=1;k<=right;k++)
      if(high ? rates[index].high<=rates[index+k].high : rates[index].low>=rates[index+k].low) return false;
   return true;
  }

public static bool SRMPAnalyzeStructureFromRates(MqlRates[] rates,int count,int left,int right,SMarketStructure structure) {
   ZeroMemory(structure);
   if(count<30 || !SRMPValidDetectorRates(rates,count) ||
      left<1 || right<1 || count<left+right+10) return false;
   structure.latest_closed_bar=rates[count-1].time;
   int highs=0,lows=0;
   for(int i=left;i<count-right;i++)
     {
      bool is_high=SRMPConfirmedSwingAt(rates,count,i,left,right,true);
      bool is_low=SRMPConfirmedSwingAt(rates,count,i,left,right,false);
      if(is_high)
        {
         structure.prior_high=structure.recent_high;
         structure.prior_high_time=structure.recent_high_time;
         structure.prior_high_confirmed_time=structure.recent_high_confirmed_time;
         structure.recent_high_confirmed_time=rates[i+right].time;
         structure.recent_high=rates[i].high;
         structure.recent_high_time=rates[i].time;
         highs++;
        }
      if(is_low)
        {
         structure.prior_low=structure.recent_low;
         structure.prior_low_time=structure.recent_low_time;
         structure.prior_low_confirmed_time=structure.recent_low_confirmed_time;
         structure.recent_low_confirmed_time=rates[i+right].time;
         structure.recent_low=rates[i].low;
         structure.recent_low_time=rates[i].time;
         lows++;
        }
     }
   if(highs<2 || lows<2 || structure.recent_high<=structure.recent_low)
      return false;
   if(structure.recent_high>structure.prior_high &&
      structure.recent_low>structure.prior_low) structure.bias=1;
   else if(structure.recent_high<structure.prior_high &&
           structure.recent_low<structure.prior_low) structure.bias=-1;
   double close_now=rates[count-1].close;
   double close_before=rates[count-2].close;
   if(close_now>structure.recent_high && close_before<=structure.recent_high)
     { structure.bos_direction=1; structure.bos_time=rates[count-1].time;
       structure.bos_level=structure.recent_high; }
   else if(close_now<structure.recent_low && close_before>=structure.recent_low)
     { structure.bos_direction=-1; structure.bos_time=rates[count-1].time;
       structure.bos_level=structure.recent_low; }
   structure.mss=(structure.bias!=0 && structure.bos_direction!=0 &&
                  structure.bos_direction!=structure.bias);
   return true;
  }













public static long ICTBarClose(int tf,long opened) {
   if(opened<=0 || tf==PERIOD_CURRENT || PeriodSeconds(tf)<=0) return 0;
   if(tf!=PERIOD_MN1) return opened+PeriodSeconds(tf);
   MqlDateTime d=new MqlDateTime(); if(!TimeToStruct(opened,d)) return 0;
   d.day=1; d.hour=0; d.min=0; d.sec=0;
   if(d.mon==12) { d.mon=1; d.year++; } else d.mon++;
   return StructToTime(d);
  }

public static int ICTClosedPrefix(MqlRates[] bars,int count,int tf,long asof) {
   if(count<0 || count>ArraySize(bars) || tf==PERIOD_CURRENT) return 0;
   int n=0;
   while(n<count)
     {
      long closed=ICTBarClose(tf,bars[n].time);
      if(closed<=0 || closed>asof) break;
      n++;
     }
   return n;
  }




public static double ICTPriorATR(MqlRates[] bars,int end,int period=14) {
   if(end<period+1 || end>ArraySize(bars)) return 0;
   double sum=0;
   for(int i=end-period;i<end;i++)
      sum+=MathMax(bars[i].high-bars[i].low,MathMax(MathAbs(bars[i].high-bars[i-1].close),MathAbs(bars[i].low-bars[i-1].close)));
   return sum/period;
  }

public static int ICTRateIndex(MqlRates[] bars,int count,long timestamp) {
   int low=0,high=count-1;
   while(low<=high)
     { int middle=(low+high)/2; if(bars[middle].time==timestamp) return middle;
       if(bars[middle].time<timestamp) low=middle+1; else high=middle-1; }
   return -1;
  }

public static uint ICTStableHash(string value) {
   uint h=2166136261;
   for(int i=0;i<StringLen(value);i++) h=(h^(uint)StringGetCharacter(value,i))*16777619;
   return h;
  }











public class SICTSessionOffset {
public long from_utc;
public long to_utc;
public int minutes_east;
}


public const int ICT_SESSION_ASIA=0;
public const int ICT_SESSION_LONDON=1;
public const int ICT_SESSION_NEW_YORK=2;


public const int ICT_SESSION_READY=0;
public const int ICT_SESSION_BAD_CONFIG=1;
public const int ICT_SESSION_BAD_SCHEDULE=2;
public const int ICT_SESSION_AMBIGUOUS_TIME=3;
public const int ICT_SESSION_NOT_CLOSED=4;
public const int ICT_SESSION_INCOMPLETE_DATA=5;
public const int ICT_SESSION_INVALID_BAR=6;


public class SICTSessionDefinition {
public int kind;
public int start_minute;
public int end_minute;
}


public class SICTSessionLiquidity {
public int status;
public int kind;
public long start_utc;
public long end_utc;
public long confirmed_utc;
public double high;
public double low;
public int bar_count;
}


public static bool ICTSessionOffsetsValid(SICTSessionOffset[] schedule) {
   int n=ArraySize(schedule);
   if(n<1) return false;
   for(int i=0;i<n;i++)
     {
      if(schedule[i].from_utc<=0 || schedule[i].to_utc<=schedule[i].from_utc ||
         schedule[i].minutes_east < -840 || schedule[i].minutes_east > 840)
         return false;
      if(i>0 && schedule[i-1].to_utc!=schedule[i].from_utc) return false;
     }
   return true;
  }

public static int ICTSessionOffsetAt(SICTSessionOffset[] schedule,long utc) {
   for(int i=0;i<ArraySize(schedule);i++)
      if(utc>=schedule[i].from_utc && utc<schedule[i].to_utc) return i;
   return -1;
  }



public static bool ICTSessionWallToUTC(SICTSessionOffset[] schedule,long wall,ref long utc) {
   int matches=0;
   utc=0;
   for(int i=0;i<ArraySize(schedule);i++)
     {
      long candidate=wall-schedule[i].minutes_east*60;
      if(candidate>=schedule[i].from_utc && candidate<schedule[i].to_utc)
        { matches++; utc=candidate; }
     }
   if(matches!=1) { utc=0; return false; }
   return true;
  }









public static bool ICTBuildSessionLiquidity(SICTSessionDefinition definition,long local_midnight,SICTSessionOffset[] session_offsets,SICTSessionOffset[] broker_offsets,MqlRates[] bars,int period_seconds,long as_of_utc,SICTSessionLiquidity result) {
   ZeroMemory(result);
   result.kind=definition.kind;
   result.status=ICT_SESSION_BAD_CONFIG;
   if((int)definition.kind<(int)ICT_SESSION_ASIA || (int)definition.kind>(int)ICT_SESSION_NEW_YORK ||
      definition.start_minute<0 || definition.start_minute>=1440 ||
      definition.end_minute<0 || definition.end_minute>=1440 ||
      definition.start_minute==definition.end_minute || local_midnight<=0 ||
      (long)local_midnight%86400!=0 || period_seconds<60 || period_seconds>86400 ||
      period_seconds%60!=0 || as_of_utc<=0) return false;
   result.status=ICT_SESSION_BAD_SCHEDULE;
   if(!ICTSessionOffsetsValid(session_offsets) || !ICTSessionOffsetsValid(broker_offsets)) return false;
   long start_wall=local_midnight+definition.start_minute*60;
   long end_wall=local_midnight+definition.end_minute*60;
   if(definition.end_minute<definition.start_minute) end_wall+=86400;
   result.status=ICT_SESSION_AMBIGUOUS_TIME;
   if(!ICTSessionWallToUTC(session_offsets,start_wall,ref result.start_utc) ||
      !ICTSessionWallToUTC(session_offsets,end_wall,ref result.end_utc)) return false;
   if(result.end_utc<=result.start_utc ||
      ICTSessionOffsetAt(session_offsets,result.start_utc)<0 ||
      ICTSessionOffsetAt(session_offsets,result.end_utc-1)<0 ||
      ICTSessionOffsetAt(broker_offsets,result.start_utc)<0 ||
      ICTSessionOffsetAt(broker_offsets,result.end_utc-1)<0) return false;
   result.status=ICT_SESSION_BAD_CONFIG;
   long duration=result.end_utc-result.start_utc;
   if(duration%period_seconds!=0 || duration/period_seconds>1440) return false;
   result.status=ICT_SESSION_NOT_CLOSED;
   if(as_of_utc<result.end_utc) return false;
   long first_wall=0,last_wall=0;
   for(int k=0;k<ArraySize(broker_offsets);k++)
     {
      long from=(long)MathMax((long)result.start_utc,(long)broker_offsets[k].from_utc);
      long to=(long)MathMin((long)result.end_utc,(long)broker_offsets[k].to_utc);
      if(from>=to) continue;
      long wall_from=from+broker_offsets[k].minutes_east*60;
      long wall_to=to+broker_offsets[k].minutes_east*60;
      if(first_wall==0 || wall_from<first_wall) first_wall=wall_from;
      if(last_wall==0 || wall_to>last_wall) last_wall=wall_to;
     }
   int expected=(int)(duration/period_seconds);
   bool[] seen=InitArray<bool>(0);
   ArrayResize(ref seen,expected);
   ArrayInitialize(seen,false);
   double high=0,low=0;
   int count=0;
   result.status=ICT_SESSION_INCOMPLETE_DATA;
   for(int i=0;i<ArraySize(bars);i++)
     {
      if(bars[i].time<first_wall || bars[i].time>=last_wall) continue;
      long utc=0;
      if(!ICTSessionWallToUTC(broker_offsets,bars[i].time,ref utc))
        { result.status=ICT_SESSION_AMBIGUOUS_TIME; return false; }
      if(utc<result.start_utc || utc>=result.end_utc) continue;
      long elapsed=utc-result.start_utc;
      if(elapsed%period_seconds!=0) return false;
      int slot=(int)(elapsed/period_seconds);
      if(seen[slot]) return false;
      int begin_offset=ICTSessionOffsetAt(broker_offsets,utc);
      int end_offset=ICTSessionOffsetAt(broker_offsets,utc+period_seconds-1);
      if(begin_offset<0 || end_offset!=begin_offset)
        { result.status=ICT_SESSION_AMBIGUOUS_TIME; return false; }
      if(!SRMPValidDetectorBar(bars[i]) || bars[i].low<=0)
        { result.status=ICT_SESSION_INVALID_BAR; return false; }
      if(count==0 || bars[i].high>high) high=bars[i].high;
      if(count==0 || bars[i].low<low) low=bars[i].low;
      seen[slot]=true;
      count++;
     }
   if(count!=expected) return false;
   result.high=high; result.low=low; result.bar_count=count;
   result.status=ICT_SESSION_READY;
   result.confirmed_utc=result.end_utc;
   return true;
  }






public const int SMT_AUTO=0;
public const int SMT_POSITIVE=1;
public const int SMT_NEGATIVE=-1;

public const int SMT_CORR_INSUFFICIENT=0;
public const int SMT_CORR_POSITIVE=1;
public const int SMT_CORR_NEGATIVE=2;
public const int SMT_CORR_WEAK=3;
public const int SMT_CORR_INVALID=4;


public class SSymbolCorrelation {
public int state;
public double coefficient;
public int pairs;
public long asof;
}



public static void SRMPRankComparison(string symbol,double correlation,ref string first,ref double first_strength,ref string second,ref double second_strength) {
   if(symbol=="" || !MathIsValidNumber(correlation)) return;
   double strength=MathAbs(correlation);
   if(symbol==first || symbol==second) return;
   if(first=="" || strength>first_strength ||
      (strength==first_strength && StringCompare(symbol,first)<0))
     { second=first; second_strength=first_strength; first=symbol; first_strength=strength; }
   else if(second=="" || strength>second_strength ||
           (strength==second_strength && StringCompare(symbol,second)<0))
     { second=symbol; second_strength=strength; }
  }


public static void SRMPResolveSMTSlots(string manual1,string manual2,bool auto1,bool auto2,string first,string second,ref string one,ref string two) {
   one=manual1; two=manual2;
   if(one=="" && auto1) one=(first!=two ? first : second);
   if(two=="" && auto2) two=(first!=one ? first : second);
   if(one!="" && two==one && manual2=="") two="";
  }












public const int SRMP_SMT_NOT_CONFIGURED=0;
public const int SRMP_SMT_INVALID_SYMBOL=1;
public const int SRMP_SMT_INSUFFICIENT=2;
public const int SRMP_SMT_WEAK=3;
public const int SRMP_SMT_UNCONFIRMED=4;
public const int SRMP_SMT_BULLISH=5;
public const int SRMP_SMT_BEARISH=6;
public const int SRMP_SMT_COMP_ONLY=7;


public static string SRMPSMTStateText(int state) {
   if(state==SRMP_SMT_NOT_CONFIGURED) return "NOT CONFIGURED";
   if(state==SRMP_SMT_INVALID_SYMBOL) return "UNAVAILABLE: INVALID SYMBOL";
   if(state==SRMP_SMT_INSUFFICIENT) return "UNAVAILABLE: DATA/TIME ALIGNMENT";
   if(state==SRMP_SMT_WEAK) return "UNAVAILABLE: CORRELATION";
   if(state==SRMP_SMT_UNCONFIRMED) return "UNCONFIRMED";
   if(state==SRMP_SMT_BULLISH) return "BULLISH SMT";
   if(state==SRMP_SMT_BEARISH) return "BEARISH SMT";
   return "COMPARISON ONLY BREAK";
  }












public class SSMTDivergence {
public int state;
public string comparison=string.Empty;
public int direction;
public double correlation;
public int correlation_pairs;
public long primary_pivot_time;
public long primary_prior_time;
public long comparison_pivot_time;
public long pivot_confirmation_time;
public long confirmation_time;
public double primary_prior;
public double primary_recent;
public int timeframe;
public int relation;
public bool comparator_extreme;
public long comparison_prior_time;
public double comparison_prior;
public double comparison_recent;
public string event_id=string.Empty;
}


public static bool SRMPAlignedCorrelationFromRates(MqlRates[] a,int an,MqlRates[] b,int bn,int window,int skip,ref double value,ref int pairs) {
   value=0; pairs=0;
   if(window<2 || skip<0 || an<2 || bn<2 || an>ArraySize(a) || bn>ArraySize(b)) return false;
   double sx=0,sy=0,sxx=0,syy=0,sxy=0;
   int i=an-1,j=bn-1,ignored=0;
   while(i>0 && j>0 && pairs<window)
     {
      if(a[i].time>b[j].time) { i--; continue; }
      if(a[i].time<b[j].time) { j--; continue; }
      if(a[i-1].time==b[j-1].time && a[i].close>0 && a[i-1].close>0 && b[j].close>0 && b[j-1].close>0)
        {
         if(ignored<skip) ignored++;
         else
           {
            double x=MathLog(a[i].close/a[i-1].close),y=MathLog(b[j].close/b[j-1].close);
            sx+=x; sy+=y; sxx+=x*x; syy+=y*y; sxy+=x*y; pairs++;
           }
        }
      i--; j--;
     }
   double vx=pairs*sxx-sx*sx,vy=pairs*syy-sy*sy;
   if(pairs<window || vx<=0 || vy<=0) return false;
   value=(pairs*sxy-sx*sy)/MathSqrt(vx*vy);
   return MathIsValidNumber(value) && MathAbs(value)<=1.000001;
  }



public static bool SRMPFindSMTPairFromRates(string primary,string comparison,int tf,MqlRates[] a,int an,MqlRates[] b,int bn,int left,int right,int gap,int relation,double primary_tolerance,double comparison_tolerance,int direction,SSMTDivergence s) {
   ZeroMemory(s); s.comparison=comparison; s.state=SRMP_SMT_INSUFFICIENT;
   if(primary=="" || comparison=="" || primary==comparison || an<30 || bn<30 ||
      !SRMPValidDetectorRates(a,an) || !SRMPValidDetectorRates(b,bn) ||
      a[an-1].time!=b[bn-1].time || (relation!=1 && relation!=-1) ||
      (direction!=1 && direction!=-1) || left<1 || right<1 || gap<0 ||
      !MathIsValidNumber(primary_tolerance) || primary_tolerance<0 ||
      !MathIsValidNumber(comparison_tolerance) || comparison_tolerance<0) return false;
   int recent=-1,prior=-1;
   bool high=direction<0;
   for(int i=an-right-1;i>=left;i--)
      if(SRMPConfirmedSwingAt(a,an,i,left,right,high))
        { if(recent<0) recent=i; else { prior=i; break; } }
   if(prior<0) { s.state=SRMP_SMT_UNCONFIRMED; return false; }
   int matched_recent=-1,matched_prior=-1,best_recent=2147483647,best_prior=2147483647;
   bool other_high=(relation>0 ? high : !high);
   for(int j=left;j<bn-right;j++)
     {
      if(!SRMPConfirmedSwingAt(b,bn,j,left,right,other_high)) continue;
      int primary_index=ICTRateIndex(a,an,b[j].time);
      if(primary_index<0) continue;
      int distance=(int)MathAbs(primary_index-recent);
      if(distance<=gap && distance<best_recent) { matched_recent=j; best_recent=distance; }
     }
   if(matched_recent<0) return false;
   for(int j=left;j<matched_recent;j++)
     {
      if(!SRMPConfirmedSwingAt(b,bn,j,left,right,other_high)) continue;
      int primary_index=ICTRateIndex(a,an,b[j].time);
      if(primary_index<0) continue;
      int distance=(int)MathAbs(primary_index-prior);
      if(distance<=gap && distance<best_prior) { matched_prior=j; best_prior=distance; }
     }
   if(matched_prior<0) return false;


   int start=(int)MathMax(0,MathMin(prior,recent)-gap);
   for(int k=start;k<an;k++)
     {
      if(ICTRateIndex(b,bn,a[k].time)<0) return false;
     }
   double p1=(high ? a[prior].high : a[prior].low),p2=(high ? a[recent].high : a[recent].low);
   double o1=(other_high ? b[matched_prior].high : b[matched_prior].low);
   double o2=(other_high ? b[matched_recent].high : b[matched_recent].low);
   bool primary_break=(p2-p1)*(-direction)>primary_tolerance;
   bool comparison_break=(o2-o1)*relation*(-direction)>comparison_tolerance;
   if(primary_break==comparison_break) { s.state=SRMP_SMT_UNCONFIRMED; return false; }
   s.direction=direction; s.timeframe=tf; s.relation=relation;
   s.primary_prior_time=a[prior].time; s.primary_pivot_time=a[recent].time;
   s.primary_prior=p1; s.primary_recent=p2; s.comparison_prior_time=b[matched_prior].time;
   s.comparison_pivot_time=b[matched_recent].time; s.comparison_prior=o1; s.comparison_recent=o2;
   s.comparator_extreme=comparison_break;
   s.pivot_confirmation_time=(long)MathMax(ICTBarClose(tf,a[recent+right].time),ICTBarClose(tf,b[matched_recent+right].time));
   s.confirmation_time=ICTBarClose(tf,a[an-1].time);
   s.event_id=primary+"|"+comparison+"|"+IntegerToString((int)tf)+"|"+IntegerToString(direction)+"|"+
      IntegerToString(relation)+"|"+IntegerToString((long)a[prior].time)+"|"+IntegerToString((long)a[recent].time)+"|"+
      IntegerToString((long)b[matched_prior].time)+"|"+IntegerToString((long)b[matched_recent].time);
   s.state=(direction>0 ? SRMP_SMT_BULLISH : SRMP_SMT_BEARISH);
   return s.pivot_confirmation_time>0 && s.pivot_confirmation_time<=s.confirmation_time;
  }











public const int SRMP_FVG_ACTIVE=0;
public const int SRMP_FVG_PARTIALLY_FILLED=1;
public const int SRMP_FVG_FULLY_FILLED=2;
public const int SRMP_FVG_INVALIDATED=3;


public static string SRMPFVGStatusText(int status) {
   switch(status)
     {
      case SRMP_FVG_ACTIVE: return "Active";
      case SRMP_FVG_PARTIALLY_FILLED: return "Partially filled";
      case SRMP_FVG_FULLY_FILLED: return "Fully filled";
      case SRMP_FVG_INVALIDATED: return "Invalidated";
     }
   return "Unknown";
  }
public class SFairValueGap {
public int direction;
public double lower;
public double upper;
public bool mitigated;
public long formed_time;
public int status;
public long first_touch_time;
public long fully_filled_time;
public long invalidated_time;
public bool inversion_evidence;
public int inversion_direction;
public long inversion_time;
}



public static void SRMPUpdateFVGEvidence(MqlRates bar,SFairValueGap gap) {
   if(!SRMPValidDetectorBar(bar) || bar.time<=gap.formed_time ||
      (gap.direction!=1 && gap.direction!=-1) || !MathIsValidNumber(gap.lower) ||
      !MathIsValidNumber(gap.upper) || gap.upper<=gap.lower) return;
   bool overlap=(bar.low<=gap.upper && bar.high>=gap.lower);
   if(overlap)
     {
      gap.mitigated=true;
      if(gap.first_touch_time==0) gap.first_touch_time=bar.time;
      if(gap.status==SRMP_FVG_ACTIVE) gap.status=SRMP_FVG_PARTIALLY_FILLED;
     }
   bool full=(gap.direction==1 ? bar.low<=gap.lower : bar.high>=gap.upper);
   if(full && gap.fully_filled_time==0) gap.fully_filled_time=bar.time;
   if(full && gap.status!=SRMP_FVG_INVALIDATED) gap.status=SRMP_FVG_FULLY_FILLED;
   bool invalid=(gap.direction==1 ? bar.close<gap.lower : bar.close>gap.upper);
   if(invalid)
     {
      gap.status=SRMP_FVG_INVALIDATED;
      gap.mitigated=true;
      if(gap.invalidated_time==0) gap.invalidated_time=bar.time;
      gap.inversion_evidence=true;
      gap.inversion_direction=-gap.direction;
      if(gap.inversion_time==0) gap.inversion_time=bar.time;
     }
  }


public static bool SRMPFVGAtRates(MqlRates[] rates,int count,int index,double min_gap,SFairValueGap gap) {
   ZeroMemory(gap);
   if(index<2 || index>=count || count>ArraySize(rates) || min_gap<=0) return false;
   if(rates[index].low-rates[index-2].high>=min_gap)
     { gap.direction=1; gap.lower=rates[index-2].high; gap.upper=rates[index].low; }
   else if(rates[index-2].low-rates[index].high>=min_gap)
     { gap.direction=-1; gap.lower=rates[index].high; gap.upper=rates[index-2].low; }
   else return false;
   gap.formed_time=rates[index].time;
   for(int j=index+1;j<count;j++) SRMPUpdateFVGEvidence(rates[j],gap);
   return true;
  }



public static bool SRMPFindFVGFromRates(MqlRates[] rates,int count,double min_gap,SFairValueGap gap,int desired_direction=0) {
   ZeroMemory(gap);
   if(count<5 || !SRMPValidDetectorRates(rates,count) || !MathIsValidNumber(min_gap) ||
      min_gap<=0.0 || desired_direction<-1 || desired_direction>1) return false;
   bool found=false;
   for(int i=count-1;i>=2;i--)
     {
      SFairValueGap candidate=new SFairValueGap();
      if(!SRMPFVGAtRates(rates,count,i,min_gap,candidate)) continue;
      if(desired_direction!=0 && candidate.direction!=desired_direction) continue;
      if(!found) { gap=candidate; found=true; }

      if(!candidate.mitigated) { gap=candidate; return true; }
     }
   return found;
  }









public const int SRMP_OB_FULL=0;
public const int SRMP_OB_BODY=1;
public const int SRMP_OB_HYBRID=2;

public const int SRMP_OB_NONE=0;
public const int SRMP_OB_CANDIDATE=1;
public const int SRMP_OB_CONFIRMED=2;
public const int SRMP_OB_MITIGATED=3;
public const int SRMP_OB_INVALIDATED=4;
public const int SRMP_OB_EXPIRED=5;

public const int SRMP_OB_TOUCH=0;
public const int SRMP_OB_MIDPOINT=1;
public const int SRMP_OB_FULL_FILL=2;

public const int SRMP_OB_CLOSE=0;
public const int SRMP_OB_WICK=1;


public class SOrderBlock {
public int direction;
public int state;
public long formation_time;
public long confirmation_time;
public long state_time;
public double upper;
public double lower;
public double midpoint;
public bool displacement;
public bool break_confirmed;
public bool liquidity_sweep;
public bool fvg;
public bool pd_match;
public bool session_match;
public int score;
}


public static string SRMPOBStateText(int state) {
   if(state==SRMP_OB_CANDIDATE) return "CANDIDATE";
   if(state==SRMP_OB_CONFIRMED) return "CONFIRMED";
   if(state==SRMP_OB_MITIGATED) return "MITIGATED";
   if(state==SRMP_OB_INVALIDATED) return "INVALIDATED";
   if(state==SRMP_OB_EXPIRED) return "EXPIRED";
   return "NONE";
  }


public static void SRMPValidateOrderBlockFromRates(MqlRates[] rates,int count,int mitigation,int invalidation,int expiry_bars,SOrderBlock block) {
   if(block.state!=SRMP_OB_CONFIRMED || expiry_bars<1) return;
   if(count>0 && !SRMPValidDetectorRates(rates,count))
     { block.state=SRMP_OB_NONE; return; }
   int age=0;
   for(int i=0;i<count;i++)
     {
      MqlRates bar=rates[i];
      if(bar.time<=block.confirmation_time) continue;
      age++;
      bool invalid=(block.direction>0 ?
         (invalidation==SRMP_OB_WICK ? bar.low<block.lower : bar.close<block.lower) :
         (invalidation==SRMP_OB_WICK ? bar.high>block.upper : bar.close>block.upper));
      if(invalid) { block.state=SRMP_OB_INVALIDATED; block.state_time=bar.time; return; }
      bool touched=bar.low<=block.upper && bar.high>=block.lower;
      bool filled=(mitigation==SRMP_OB_TOUCH ? touched :
         (block.direction>0 ? bar.low<=(mitigation==SRMP_OB_MIDPOINT ? block.midpoint : block.lower) :
                             bar.high>=(mitigation==SRMP_OB_MIDPOINT ? block.midpoint : block.upper)));
      if(filled && block.state==SRMP_OB_CONFIRMED)
        { block.state=SRMP_OB_MITIGATED; block.state_time=bar.time; }
      if(age>=expiry_bars) { block.state=SRMP_OB_EXPIRED; block.state_time=bar.time; return; }
     }
  }



public static bool SRMPFindOrderBlockFromRates(MqlRates[] rates,int count,int bounds,double min_displacement_factor,int max_confirmation_bars,SOrderBlock block,int desired_direction=0,bool active_only=false,int expiry_bars=48) {
   ZeroMemory(block);
   if(count<40 || min_displacement_factor<=0.0 ||
      max_confirmation_bars<1 || max_confirmation_bars>6 ||
      desired_direction<-1 || desired_direction>1 || expiry_bars<1) return false;
   if(!SRMPValidDetectorRates(rates,count)) return false;
   bool has_candidate=false;

   for(int i=count-1;i>=15;i--)
     {
      int direction=0;
      if(rates[i].close<rates[i].open) direction=1;
      else if(rates[i].close>rates[i].open) direction=-1;
      if(direction==0) continue;
      if(desired_direction!=0 && direction!=desired_direction) continue;
      double prior_high=rates[i-1].high,prior_low=rates[i-1].low;
      double avg_range=0.0;
      for(int k=i-10;k<i;k++)
        {
         prior_high=MathMax(prior_high,rates[k].high);
         prior_low=MathMin(prior_low,rates[k].low);
         avg_range+=rates[k].high-rates[k].low;
        }
      avg_range/=10.0;
      if(avg_range<=0.0) continue;
      if(!has_candidate && i>=count-1-max_confirmation_bars)
        {
         block.direction=direction;
         block.state=SRMP_OB_CANDIDATE;
         block.formation_time=rates[i].time;
         block.state_time=rates[i].time;
         double body_upper=MathMax(rates[i].open,rates[i].close);
         double body_lower=MathMin(rates[i].open,rates[i].close);
         block.upper=(bounds==SRMP_OB_BODY ? body_upper : rates[i].high);
         block.lower=(bounds==SRMP_OB_BODY ? body_lower : rates[i].low);
         if(bounds==SRMP_OB_HYBRID)
           {
            block.upper=(direction>0 ? body_upper : rates[i].high);
            block.lower=(direction>0 ? rates[i].low : body_lower);
           }
         block.midpoint=(block.upper+block.lower)/2.0;
         block.liquidity_sweep=(direction>0 ? rates[i].low<prior_low :
                                             rates[i].high>prior_high);
         has_candidate=true;
        }
      for(int j=i+1;j<=MathMin(count-1,i+max_confirmation_bars);j++)
        {
         double body=MathAbs(rates[j].close-rates[j].open);
         bool directional=(direction>0 ? rates[j].close>rates[j].open :
                                        rates[j].close<rates[j].open);
         bool displacement=directional &&
                           body>=avg_range*min_displacement_factor;
         bool broken=(direction>0 ? rates[j].close>prior_high :
                                      rates[j].close<prior_low);
         if(!displacement || !broken) continue;
         block.direction=direction;
         block.formation_time=rates[i].time;
         block.confirmation_time=rates[j].time;
         block.state_time=rates[j].time;
         block.state=SRMP_OB_CONFIRMED;
         double body_upper=MathMax(rates[i].open,rates[i].close);
         double body_lower=MathMin(rates[i].open,rates[i].close);
         block.upper=(bounds==SRMP_OB_BODY ? body_upper : rates[i].high);
         block.lower=(bounds==SRMP_OB_BODY ? body_lower : rates[i].low);
         if(bounds==SRMP_OB_HYBRID)
           {
            block.upper=(direction>0 ? body_upper : rates[i].high);
            block.lower=(direction>0 ? rates[i].low : body_lower);
           }
         block.midpoint=(block.upper+block.lower)/2.0;
         block.displacement=true;
         block.break_confirmed=true;
         block.liquidity_sweep=(direction>0 ? rates[i].low<prior_low :
                                             rates[i].high>prior_high);
         for(int f=i+2;f<=j;f++)
           {
            if(direction>0 && rates[f].low>rates[f-2].high)
               block.fvg=true;
            if(direction<0 && rates[f].high<rates[f-2].low)
               block.fvg=true;
           }
         double equilibrium=(prior_high+prior_low)/2.0;
         block.pd_match=(direction>0 ? block.midpoint<=equilibrium :
                                       block.midpoint>=equilibrium);
         MqlDateTime tm=new MqlDateTime();
         TimeToStruct(block.formation_time,tm);
         block.session_match=(tm.hour>=7 && tm.hour<21);
         if(active_only)
           {
            SRMPValidateOrderBlockFromRates(rates,count,SRMP_OB_TOUCH,SRMP_OB_CLOSE,expiry_bars,block);
            if(block.state!=SRMP_OB_CONFIRMED) break;
           }
         return true;
        }
     }
   if(active_only) { ZeroMemory(block); return false; }
   return has_candidate;
  }









public class SOBScoreWeights {
public int sweep;
public int break_structure;
public int fvg;
public int displacement;
public int session;
public int premium_discount;
}


public static void SRMPDefaultOBWeights(SOBScoreWeights weights) {
   weights.sweep=20;
   weights.break_structure=25;
   weights.fvg=20;
   weights.displacement=15;
   weights.session=10;
   weights.premium_discount=10;
  }

public static bool SRMPScoreOrderBlock(SOrderBlock block,SOBScoreWeights weights) {
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









public const int ICT_SWEEP_CANDIDATE=0;
public const int ICT_SWEEP_CONFIRMED=1;
public const int ICT_SWEEP_INVALIDATED=2;

public const int SWEEP_1_ALLOWED=0;
public const int SWEEP_2_PREFERRED=1;
public const int SWEEP_2_REQUIRED=2;

public class SICTSweepRecord {
public string pool_id=string.Empty;
public int side;
public int number;
public int status;
public double level;
public double extreme;
public double depth;
public long event_time;
public long confirmed_at;
}

public class SICTSweepSequence {
public string pool_id=string.Empty;
public int side;
public int count;
public int bars_after_confirmation;
public int candidate_age;
public int outside_closes;
public double level;
public long available_at;
public long last_bar;
public bool valid;
public bool armed;
public bool candidate;
public SICTSweepRecord[] events=InitArray<SICTSweepRecord>(ICT_SWEEP_SEQUENCE_MAX);
}


public static void ICTSweepSequenceStart(SICTSweepSequence s,string pool_id,int side,double level,long available_at) {
   ZeroMemory(s);
   if(pool_id=="" || (side!=1 && side!=-1) || !MathIsValidNumber(level) ||
      level<=0 || available_at<=0) return;
   s.pool_id=pool_id; s.side=side; s.level=level; s.available_at=available_at;
   s.valid=true; s.armed=true;
  }



public static void ICTSweepSequenceStep(SICTSweepSequence s,MqlRates bar,int seconds,double penetration,double rejection,int min_bars,int validation_bars,int invalidation_closes,long actual_close=0) {
   if(!s.valid || seconds<=0 || !SRMPValidDetectorBar(bar) || bar.time<s.available_at ||
      bar.time<=s.last_bar || !MathIsValidNumber(penetration) || penetration<0 ||
      !MathIsValidNumber(rejection) || rejection<0 || min_bars<1 || validation_bars<1 ||
      invalidation_closes<1) return;
   s.last_bar=bar.time;
   double extreme=(s.side>0 ? bar.high : bar.low);
   double excursion=(extreme-s.level)*s.side;
   double outside=(bar.close-s.level)*s.side;
   if(outside>penetration) s.outside_closes++; else s.outside_closes=0;
   if(s.outside_closes>=invalidation_closes)
     {
      if(s.candidate && s.count>0) s.events[s.count-1].status=ICT_SWEEP_INVALIDATED;
      s.valid=false; s.candidate=false; return;
     }
   if(!s.armed && !s.candidate)
     {
      s.bars_after_confirmation++;
      if(s.bars_after_confirmation>=min_bars && outside<=-rejection)
         s.armed=true;
      return;
     }
   if(s.armed && !s.candidate && excursion>penetration)
     {
      if(s.count>=ICT_SWEEP_SEQUENCE_MAX) { s.valid=false; return; }
      SICTSweepRecord e=new SICTSweepRecord(); ZeroMemory(e);
      e.pool_id=s.pool_id; e.side=s.side; e.number=s.count+1;
      e.level=s.level; e.extreme=extreme; e.depth=excursion;
      e.event_time=bar.time; e.status=ICT_SWEEP_CANDIDATE;
      s.events[s.count++]=e; s.candidate=true; s.armed=false; s.candidate_age=0;
     }
   if(!s.candidate) return;
   int n=s.count-1;
   if(excursion>s.events[n].depth)
     { s.events[n].depth=excursion; s.events[n].extreme=extreme; s.events[n].event_time=bar.time; }
   s.candidate_age++;
   if(outside<0)
     {
      s.events[n].status=ICT_SWEEP_CONFIRMED;
      s.events[n].confirmed_at=(actual_close>bar.time ? actual_close : bar.time+seconds);
      s.candidate=false; s.bars_after_confirmation=0; return;
     }
   if(s.candidate_age>=validation_bars)
     { s.events[n].status=ICT_SWEEP_INVALIDATED; s.candidate=false; s.valid=false; }
  }










public const int ICT_OB_WEAK=0;
public const int ICT_OB_MEDIUM=1;
public const int ICT_OB_STRONG=2;

public const int ICT_OB_CANDIDATE=0;
public const int ICT_OB_CONFIRMED=1;
public const int ICT_OB_ACTIVE=2;
public const int ICT_OB_TOUCHED=3;
public const int ICT_OB_PARTIAL=4;
public const int ICT_OB_MITIGATED=5;
public const int ICT_OB_INVALIDATED=6;
public const int ICT_OB_EXPIRED=7;

public class SICTStrongOBConfig {
public int max_group;
public int confirmation_bars;
public int left;
public int right;
public int expiry_bars;
public int weight_sweep;
public int weight_displacement;
public int weight_structure;
public int weight_fvg;
public int weight_bias;
public int weight_pd;
public int weight_freshness;
public int strong_threshold;
public int moderate_threshold;
public int touch_penalty;
public int bounds;
public double displacement_atr;
public double body_ratio;
public double max_overlap;
public double fvg_atr;
public double tolerance_ticks;
public double mitigation_fraction;
public bool require_fvg;
public bool invalidate_on_close;
public bool allow_continuation;
}

public static void ICTDefaultStrongOBConfig(SICTStrongOBConfig c) {
   ZeroMemory(c); c.max_group=3; c.confirmation_bars=3; c.left=2; c.right=2;
   c.expiry_bars=300; c.bounds=SRMP_OB_HYBRID; c.displacement_atr=1.2;
   c.body_ratio=0.60; c.max_overlap=0.80; c.fvg_atr=0.10;
   c.tolerance_ticks=1; c.mitigation_fraction=0.5; c.invalidate_on_close=true; c.allow_continuation=true;
   c.weight_sweep=20; c.weight_displacement=20; c.weight_structure=15; c.weight_fvg=15;
   c.weight_bias=15; c.weight_pd=10; c.weight_freshness=5;
   c.strong_threshold=80; c.moderate_threshold=60; c.touch_penalty=5;
  }
public static bool ICTValidStrongOBConfig(SICTStrongOBConfig c) {
   double[] v = new double[] {c.displacement_atr,c.body_ratio,c.max_overlap,c.fvg_atr,c.tolerance_ticks,c.mitigation_fraction};
   for(int i=0;i<ArraySize(v);i++) if(!MathIsValidNumber(v[i]) || v[i]<0) return false;
   int[] weights = new int[] {c.weight_sweep,c.weight_displacement,c.weight_structure,c.weight_fvg,c.weight_bias,c.weight_pd,c.weight_freshness};
   int total=0;
   for(int i=0;i<ArraySize(weights);i++) { if(weights[i]<0 || weights[i]>100) return false; total+=weights[i]; }
   return c.max_group>=1 && c.max_group<=10 && c.confirmation_bars>=1 && c.confirmation_bars<=10 &&
      c.left>=1 && c.right>=1 && c.expiry_bars>=1 && c.bounds>=SRMP_OB_FULL && c.bounds<=SRMP_OB_HYBRID &&
      c.displacement_atr>0 && c.body_ratio>0 && c.body_ratio<=1 && c.max_overlap<=1 &&
       c.mitigation_fraction>0 && c.mitigation_fraction<=1 && total==100 &&
       c.moderate_threshold>=1 && c.moderate_threshold<c.strong_threshold && c.strong_threshold<=100 &&
       c.touch_penalty>=0 && c.touch_penalty<=100;
  }
public class SICTStrongOrderBlock {
public SOrderBlock ob=new SOrderBlock();
public string id=string.Empty;
public string gate_reason=string.Empty;
public string invalidation_reason=string.Empty;
public int timeframe;
public int grade;
public int confirmation_grade;
public int life;
public int candles;
public int confirmation_score;
public int current_context_score;
public int touch_count;
public int age;
public int sweep_count;
public int sweep_points;
public int displacement_points;
public int structure_points;
public int fvg_points;
public int bias_points;
public int pd_points;
public int freshness_points;
public bool hard_gates;
public bool continuation;
public bool in_contact;
public bool departed;
public long group_end;
public long processed_at;
public double open_reference;
public double mitigation_depth;
public double invalidation;
}

public static string ICTOBGradeText(int g) { return g==ICT_OB_STRONG ? "STRONG" : (g==ICT_OB_MEDIUM ? "MODERATE" : "WEAK"); }
public static string ICTOBLifeText(int s) {
   string[] values = new string[] {"CANDIDATE","CONFIRMED","ACTIVE","TOUCHED","PARTIALLY MITIGATED","MITIGATED","INVALIDATED","EXPIRED"};
   return (int)s>=0 && (int)s<8 ? values[(int)s] : "UNKNOWN";
  }
public static bool ICTOBActive(SICTStrongOrderBlock z) { return z.life==ICT_OB_CONFIRMED || z.life==ICT_OB_ACTIVE || z.life==ICT_OB_TOUCHED || z.life==ICT_OB_PARTIAL; }



public static void ICTScoreStrongOBWithConfig(SICTStrongOrderBlock z,bool htf_match,bool fresh,SICTStrongOBConfig c) {
   z.sweep_points=z.ob.liquidity_sweep ? c.weight_sweep : 0;
   z.displacement_points=z.ob.displacement ? c.weight_displacement : 0;
   z.structure_points=z.ob.break_confirmed ? c.weight_structure : 0;
   z.fvg_points=z.ob.fvg ? c.weight_fvg : 0; z.bias_points=htf_match ? c.weight_bias : 0;
   z.pd_points=z.ob.pd_match ? c.weight_pd : 0; z.freshness_points=fresh ? c.weight_freshness : 0;
   z.confirmation_score=z.sweep_points+z.displacement_points+z.structure_points+z.fvg_points+
      z.bias_points+z.pd_points+z.freshness_points;
   z.ob.score=z.confirmation_score; z.current_context_score=z.confirmation_score;
   z.hard_gates=z.ob.upper>z.ob.lower && z.ob.lower>0 && z.ob.displacement && z.ob.break_confirmed &&
       (z.continuation ? c.allow_continuation && htf_match : z.ob.liquidity_sweep) && (!c.require_fvg || z.ob.fvg);
   z.gate_reason=z.hard_gates ? (z.continuation ? "Continuation: displacement+BOS+HTF aligned" :
      "Reversal: sweep+displacement+MSS/BOS") : "Missing candidate/displacement/structure/sweep or continuation HTF/FVG gate";
   z.grade=(z.confirmation_score>=c.strong_threshold && z.hard_gates ? ICT_OB_STRONG :
       (z.confirmation_score>=c.moderate_threshold ? ICT_OB_MEDIUM : ICT_OB_WEAK));
   z.confirmation_grade=z.grade;
  }

public static void ICTScoreStrongOB(SICTStrongOrderBlock z,bool htf_match,bool fresh,bool require_fvg,bool allow_continuation) {
   SICTStrongOBConfig c=new SICTStrongOBConfig(); ICTDefaultStrongOBConfig(c); c.require_fvg=require_fvg; c.allow_continuation=allow_continuation;
   ICTScoreStrongOBWithConfig(z,htf_match,fresh,c);
  }
public static void ICTRefreshOBQuality(SICTStrongOrderBlock z,SICTStrongOBConfig c) {
   if(z.life==ICT_OB_MITIGATED || z.life==ICT_OB_INVALIDATED || z.life==ICT_OB_EXPIRED)
     { z.current_context_score=0; z.ob.score=0; z.grade=ICT_OB_WEAK; return; }
   int penalty=(z.touch_count>0 ? z.freshness_points : 0)+c.touch_penalty*(int)MathMax(0,z.touch_count-1);
   z.current_context_score=(int)MathMax(0,z.confirmation_score-penalty); z.ob.score=z.current_context_score;
   z.grade=(z.current_context_score>=c.strong_threshold && z.hard_gates && z.touch_count==0 ? ICT_OB_STRONG :
      z.current_context_score>=c.moderate_threshold ? ICT_OB_MEDIUM : ICT_OB_WEAK);
  }

public static void ICTAdvanceStrongOB(MqlRates bar,long closed,SICTStrongOBConfig c,double tolerance,SICTStrongOrderBlock z) {
   if(!SRMPValidDetectorBar(bar) || closed<=z.processed_at || bar.time<z.ob.confirmation_time ||
      z.life==ICT_OB_INVALIDATED || z.life==ICT_OB_EXPIRED || closed<=bar.time) return;
   z.processed_at=closed; z.age++;
   double test=(c.invalidate_on_close ? bar.close : (z.ob.direction>0 ? bar.low : bar.high));
   bool invalid=(z.ob.direction>0 ? test<z.ob.lower-tolerance : test>z.ob.upper+tolerance);
   if(invalid)
     {
      z.life=ICT_OB_INVALIDATED; z.ob.state=SRMP_OB_INVALIDATED; z.ob.state_time=closed;
      z.invalidation_reason=c.invalidate_on_close ? "Closed beyond invalidation boundary" : "Wick beyond invalidation boundary";
       ICTRefreshOBQuality(z,c);
      return;
     }
   bool intersects=bar.low<=z.ob.upper && bar.high>=z.ob.lower;
   if(!intersects) { z.departed=true; z.in_contact=false; if(z.life==ICT_OB_CONFIRMED) z.life=ICT_OB_ACTIVE; }
   if(intersects && z.departed)
     {
      if(!z.in_contact) z.touch_count++;
      z.in_contact=true;
      double depth=(z.ob.direction>0 ? z.ob.upper-bar.low : bar.high-z.ob.lower)/(z.ob.upper-z.ob.lower);
      z.mitigation_depth=MathMax(z.mitigation_depth,MathMin(1.0,MathMax(0.0,depth)));
      int next=(z.mitigation_depth>=c.mitigation_fraction ? ICT_OB_MITIGATED :
                              (z.mitigation_depth>0 ? ICT_OB_PARTIAL : ICT_OB_TOUCHED));
      if(next>z.life) { z.life=next; z.ob.state_time=closed; }
      if(z.life==ICT_OB_MITIGATED) z.ob.state=SRMP_OB_MITIGATED;
     }
   if(z.age>=c.expiry_bars)
     { z.life=ICT_OB_EXPIRED; z.ob.state=SRMP_OB_EXPIRED; z.ob.state_time=closed; z.invalidation_reason="Configured closed-bar age reached"; }
   ICTRefreshOBQuality(z,c);
  }



public static bool ICTStrongOBAt(string symbol,int tf,MqlRates[] rates,int count,int end,double tick,SICTStrongOBConfig c,MqlRates[] higher,int higher_count,int higher_tf,SICTStrongOrderBlock z,bool advance_lifecycle=true) {
   ZeroMemory(z);
   if(!ICTValidStrongOBConfig(c) || !SRMPValidDetectorRates(rates,count) || end<30 || end>=count || tick<=0 ||
      tf==PERIOD_CURRENT || higher_count<0 || higher_count>ArraySize(higher)) return false;
   int dir=(rates[end].close<rates[end].open ? 1 : rates[end].close>rates[end].open ? -1 : 0);
   if(dir==0) return false;
   if(end+1<count && (rates[end+1].close-rates[end+1].open)*dir<0) return false;
   int start=end;
   while(start>0 && end-start+1<c.max_group && (rates[start-1].close-rates[start-1].open)*dir<0) start--;
   SMarketStructure before=new SMarketStructure();
   if(!SRMPAnalyzeStructureFromRates(rates,start,c.left,c.right,before)) return false;
   double lower=rates[start].low,upper=rates[start].high,body_low=MathMin(rates[start].open,rates[start].close),body_high=MathMax(rates[start].open,rates[start].close);
   for(int k=start+1;k<=end;k++)
     { lower=MathMin(lower,rates[k].low); upper=MathMax(upper,rates[k].high);
       body_low=MathMin(body_low,MathMin(rates[k].open,rates[k].close)); body_high=MathMax(body_high,MathMax(rates[k].open,rates[k].close)); }
   if(c.bounds==SRMP_OB_BODY) { lower=body_low; upper=body_high; }
   if(c.bounds==SRMP_OB_HYBRID) { if(dir>0) upper=rates[end].open; else lower=rates[end].open; }
   if(upper-lower<tick*0.5 || lower<=0) return false;
   double tolerance=c.tolerance_ticks*tick;
   for(int j=end+1;j<count && j<=end+c.confirmation_bars;j++)
     {
      if((rates[j].close-rates[j].open)*dir<0) break;
      double atr=ICTPriorATR(rates,j),body=(rates[j].close-rates[j].open)*dir,width=rates[j].high-rates[j].low;
      double overlap=MathMax(0.0,MathMin(rates[j].high,rates[j-1].high)-MathMax(rates[j].low,rates[j-1].low));
      bool displacement=atr>0 && width>0 && body>=atr*c.displacement_atr && body/width>=c.body_ratio && overlap/width<=c.max_overlap;
       bool broken=(dir>0 ? rates[j].close>before.recent_high+tolerance && rates[j-1].close<=before.recent_high+tolerance && rates[j].close>upper :
                            rates[j].close<before.recent_low-tolerance && rates[j-1].close>=before.recent_low-tolerance && rates[j].close<lower);
      if(!displacement || !broken) continue;
      bool fvg=false;
      for(int f=end+1;f<=j;f++)
        { SFairValueGap gap=new SFairValueGap(); if(SRMPFVGAtRates(rates,f+1,f,MathMax(tick,c.fvg_atr*atr),gap) && gap.direction==dir) fvg=true; }
      if(c.require_fvg && !fvg) continue;
      z.timeframe=tf; z.ob.direction=dir; z.ob.lower=lower; z.ob.upper=upper;
      z.ob.midpoint=(lower+upper)*0.5; z.open_reference=rates[end].open;
      z.ob.formation_time=rates[start].time; z.group_end=rates[end].time;
      z.ob.confirmation_time=ICTBarClose(tf,rates[j].time); z.ob.state_time=z.ob.confirmation_time;
      z.processed_at=z.ob.confirmation_time; z.life=ICT_OB_CONFIRMED; z.ob.state=SRMP_OB_CONFIRMED;
      z.candles=end-start+1; z.ob.displacement=true; z.ob.break_confirmed=true; z.ob.fvg=fvg;
      z.continuation=before.bias==dir;
      z.id=symbol+"|"+IntegerToString((int)tf)+"|"+IntegerToString((long)rates[start].time)+"|"+
         IntegerToString((long)rates[end].time)+"|"+IntegerToString(dir)+"|"+IntegerToString((int)c.bounds);
      z.invalidation=(dir>0 ? lower : upper); z.departed=(dir>0 ? rates[j].close>upper : rates[j].close<lower);
      SICTSweepSequence pool=new SICTSweepSequence();
      double level=(dir>0 ? before.recent_low : before.recent_high);
      long pivot=(dir>0 ? before.recent_low_time : before.recent_high_time);
      long available=ICTBarClose(tf,dir>0 ? before.recent_low_confirmed_time : before.recent_high_confirmed_time);
      ICTSweepSequenceStart(pool,symbol+IntegerToString((int)tf)+IntegerToString((long)pivot),-dir,level,available);
      for(int k=0;k<=j;k++) ICTSweepSequenceStep(pool,rates[k],PeriodSeconds(tf),tolerance,tick*3,2,3,2,ICTBarClose(tf,rates[k].time));
      for(int k=0;k<pool.count;k++) if(pool.events[k].status==ICT_SWEEP_CONFIRMED && pool.events[k].confirmed_at<=z.ob.confirmation_time) z.sweep_count++;
      z.ob.liquidity_sweep=z.sweep_count>0;
      SMarketStructure hs=new SMarketStructure(); ZeroMemory(hs);
      int hn=ICTClosedPrefix(higher,higher_count,higher_tf,z.ob.confirmation_time);
      bool higher_ready=higher_tf!=PERIOD_CURRENT && SRMPAnalyzeStructureFromRates(higher,hn,c.left,c.right,hs);
      double equilibrium=(higher_ready ? (hs.recent_high+hs.recent_low)*0.5 : (before.recent_high+before.recent_low)*0.5);
      z.ob.pd_match=(dir>0 ? z.ob.midpoint<equilibrium : z.ob.midpoint>equilibrium);
      ICTScoreStrongOBWithConfig(z,higher_ready && hs.bias==dir,true,c);
      if(advance_lifecycle)
         for(int k=j+1;k<count;k++) ICTAdvanceStrongOB(rates[k],ICTBarClose(tf,rates[k].time),c,tolerance,z);
      return true;
     }
   return false;
  }








public const int AUTO_LTF=0;
public const int AUTO_MTF=1;
public const int AUTO_HTF=2;
public const int AUTO_ALL=3;
public const int SMT_MANUAL=4;

public const int SMT_SLOT_AUTO=0;
public const int SMT_SLOT_MANUAL=1;
public const int SMT_SLOT_DISABLED=2;

public const int ICT_SMT_PENDING=0;
public const int ICT_SMT_CONFIRMED=1;
public const int ICT_SMT_INVALIDATED=2;
public const int ICT_SMT_EXPIRED=3;

public const int ICT_SMT_PEER_NA=0;
public const int ICT_SMT_PEER_NONE=1;
public const int ICT_SMT_PEER_BULLISH=2;
public const int ICT_SMT_PEER_BEARISH=3;

public class SICTDynamicSMTConfig {
public int mode;
public int manual_tf;
public int relation;
public int relation1;
public int relation2;
public int slot1;
public int slot2;
public string manual1=string.Empty;
public string manual2=string.Empty;
public string pair_map=string.Empty;
public int display_bars;
public int detection_bars;
public int left;
public int right;
public int max_gap;
public int correlation_window;
public double correlation_threshold;
public double tolerance_ticks;
public bool show_ltf;
public bool show_mtf;
public bool show_htf;
}

public class SICTSMTEvent {
public SSMTDivergence signal=new SSMTDivergence();
public int life;
public long changed_at;
public bool seed_context;
}

public class SICTSMTPeerSnapshot {
public string comparison=string.Empty;
public string event_id=string.Empty;
public string reason=string.Empty;
public bool ready;
public bool relation_known;
public bool conflict;
public int relation;
public int state;
public long last_close;
public long primary_pivot_time;
public long comparison_pivot_time;
public long pivot_confirmation_time;
public long confirmation_time;
public double primary_pivot;
public double comparison_pivot;
}

public class SICTSMTLayer {
public int timeframe;
public bool ready;
public bool relation_known;
public int detected;
public int displayed;
public int bullish;
public int bearish;
public long last_close;
public long window_start;
public string reason=string.Empty;
public SICTSMTPeerSnapshot[] peers=InitArray<SICTSMTPeerSnapshot>(2);
}

public static void ICTDefaultDynamicSMTConfig(SICTDynamicSMTConfig c) {
   ZeroMemory(c); c.mode=AUTO_ALL; c.manual_tf=PERIOD_H1; c.relation=SMT_AUTO;
   c.slot1=SMT_SLOT_AUTO; c.slot2=SMT_SLOT_AUTO; c.display_bars=60; c.detection_bars=60;
   c.left=2; c.right=2; c.max_gap=3; c.correlation_window=60; c.correlation_threshold=0.60;
   c.tolerance_ticks=1; c.show_ltf=true; c.show_mtf=true; c.show_htf=true;
   c.pair_map="EURUSD:GBPUSD,DXY;GBPUSD:EURUSD,DXY;XAUUSD:XAGUSD,DXY;XAGUSD:XAUUSD,DXY;ES:NQ,YM;NQ:ES,YM";
  }
public static bool ICTValidDynamicSMTConfig(SICTDynamicSMTConfig c) {
   return (int)c.mode>=0 && (int)c.mode<=4 && c.manual_tf!=PERIOD_CURRENT && PeriodSeconds(c.manual_tf)>0 &&
      (int)c.slot1>=0 && (int)c.slot1<=2 && (int)c.slot2>=0 && (int)c.slot2<=2 &&
      (c.relation==SMT_AUTO || c.relation==SMT_POSITIVE || c.relation==SMT_NEGATIVE) &&
       (c.relation1==SMT_AUTO || c.relation1==SMT_POSITIVE || c.relation1==SMT_NEGATIVE) &&
       (c.relation2==SMT_AUTO || c.relation2==SMT_POSITIVE || c.relation2==SMT_NEGATIVE) &&
      c.display_bars>=10 && c.display_bars<=500 && c.detection_bars>=60 && c.detection_bars<=500 &&
      c.left>=1 && c.left<=10 && c.right>=1 && c.right<=10 && c.max_gap>=0 && c.max_gap<=20 &&
      c.correlation_window>=60 && c.correlation_window<=200 && MathIsValidNumber(c.correlation_threshold) &&
      c.correlation_threshold>0 && c.correlation_threshold<=1 && MathIsValidNumber(c.tolerance_ticks) && c.tolerance_ticks>=0;
  }
public static int ICTSMTTimeframes(SICTTimeframes map,int mode,int manual,ref int[] frames,int chart_tf=PERIOD_CURRENT) {
   ArrayResize(ref frames,0);
   int[] requested=InitArray<int>(3); int n=0;
   if(mode==AUTO_ALL) { requested[0]=map.ltf; requested[1]=map.mtf; requested[2]=map.htf; n=3; }
   else { requested[0]=(mode==AUTO_LTF ? map.ltf : mode==AUTO_MTF ? map.mtf : mode==AUTO_HTF ? map.htf : manual); n=1; }
   for(int i=0;i<n;i++)
     {
      if(requested[i]==PERIOD_CURRENT) continue;
      bool duplicate=false; for(int j=0;j<ArraySize(frames);j++) if(frames[j]==requested[i]) duplicate=true;
      if(!duplicate) { int size=ArraySize(frames); ArrayResize(ref frames,size+1); frames[size]=requested[i]; }
     }


   if(mode!=SMT_MANUAL && chart_tf!=PERIOD_CURRENT && PeriodSeconds(chart_tf)>0)
     {
      bool present=false; for(int i=0;i<ArraySize(frames);i++) if(frames[i]==chart_tf) present=true;
      if(!present) { int size=ArraySize(frames); ArrayResize(ref frames,size+1); frames[size]=chart_tf; }
     }
   return ArraySize(frames);
  }
public static bool ICTSMTInsideDisplayWindow(long confirmation,long start,long asof) { return start>0 && confirmation>=start && confirmation<=asof; }

public static int ICTSMTPeerRelation(SICTDynamicSMTConfig c,int peer) {
   int selected=(peer==0 ? c.relation1 : c.relation2);
   return selected==SMT_AUTO ? c.relation : selected;
  }
public static string ICTSMTPeerStateText(int state) {
   if(state==ICT_SMT_PEER_BULLISH) return "BULLISH";
   if(state==ICT_SMT_PEER_BEARISH) return "BEARISH";
   return state==ICT_SMT_PEER_NONE ? "NONE" : "N/A";
  }
public static void ICTResetSMTPeer(string comparison,string reason,SICTSMTPeerSnapshot peer) {
   ZeroMemory(peer); peer.comparison=comparison; peer.state=ICT_SMT_PEER_NA; peer.reason=reason;
  }

public static int ICTSMTRelationFromRates(MqlRates[] a,int an,MqlRates[] b,int bn,SICTDynamicSMTConfig c,ref double rho,ref int pairs) {
   rho=0; pairs=0;
   if(an<60 || bn<60 || !SRMPValidDetectorRates(a,an) || !SRMPValidDetectorRates(b,bn) ||
      a[an-1].time!=b[bn-1].time) return 0;
   bool measured=SRMPAlignedCorrelationFromRates(a,an,b,bn,c.correlation_window,0,ref rho,ref pairs);
   if(c.relation!=SMT_AUTO) return (int)c.relation;
   double old_rho=0; int old_pairs=0;
   bool stable=measured && SRMPAlignedCorrelationFromRates(a,an,b,bn,c.correlation_window,c.correlation_window,ref old_rho,ref old_pairs) &&
      MathAbs(rho)>=c.correlation_threshold && MathAbs(old_rho)>=c.correlation_threshold && rho*old_rho>0;
   return stable ? (rho>0 ? 1 : -1) : 0;
  }
public static bool ICTSMTPeerEventUsable(SICTSMTEvent evt,int tf,long asof,long window_start,SICTSMTPeerSnapshot peer) {
   return peer.ready && peer.relation_known && peer.comparison!="" && peer.last_close>0 && peer.last_close<=asof &&
      evt.signal.comparison==peer.comparison && evt.signal.timeframe==tf && evt.signal.relation==peer.relation &&
      evt.life==ICT_SMT_CONFIRMED && !evt.seed_context && evt.signal.confirmation_time>0 &&
      evt.signal.confirmation_time>=window_start && evt.signal.confirmation_time<=asof;
  }


public static void ICTSummarizeSMTPeer(SICTSMTEvent[] events,int count,int tf,long asof,long window_start,SICTSMTPeerSnapshot peer) {
   peer.event_id=""; peer.primary_pivot_time=0; peer.comparison_pivot_time=0;
   peer.pivot_confirmation_time=0; peer.confirmation_time=0; peer.primary_pivot=0; peer.comparison_pivot=0;
   peer.conflict=false; bool bull=false,bear=false;
   for(int i=0;i<count && i<ArraySize(events);i++)
     {
      SICTSMTEvent evt=events[i];
      if(evt.signal.comparison!=peer.comparison || evt.signal.timeframe!=tf || evt.seed_context ||
         evt.signal.confirmation_time>asof) continue;
      if(evt.signal.confirmation_time>peer.confirmation_time)
        {
         peer.event_id=evt.signal.event_id; peer.confirmation_time=evt.signal.confirmation_time;
         peer.primary_pivot_time=evt.signal.primary_pivot_time; peer.comparison_pivot_time=evt.signal.comparison_pivot_time;
         peer.pivot_confirmation_time=evt.signal.pivot_confirmation_time;
         peer.primary_pivot=evt.signal.primary_recent; peer.comparison_pivot=evt.signal.comparison_recent;
        }
      if(!ICTSMTPeerEventUsable(evt,tf,asof,window_start,peer)) continue;
      if(evt.signal.direction>0) bull=true; else if(evt.signal.direction<0) bear=true;
     }
   if(!peer.ready || !peer.relation_known) { peer.state=ICT_SMT_PEER_NA; return; }
   peer.conflict=bull && bear;
   peer.state=(peer.conflict ? ICT_SMT_PEER_NONE : bull ? ICT_SMT_PEER_BULLISH : bear ? ICT_SMT_PEER_BEARISH : ICT_SMT_PEER_NONE);
   peer.reason=peer.conflict ? "SMT_CONFLICT: both live directions" : bull || bear ? "CONFIRMED PIVOT" : "NONE: no active divergence";
  }







public static int ICTReplaySMT(string primary,string comparison,int tf,MqlRates[] a,int an,MqlRates[] b,int bn,double primary_tick,double comparison_tick,SICTDynamicSMTConfig c,ref SICTSMTEvent[] events,ref bool relation_known) {
   ArrayResize(ref events,0); relation_known=false;
   if(an<60 || bn<60 || !SRMPValidDetectorRates(a,an) || !SRMPValidDetectorRates(b,bn) ||
      primary_tick<=0 || comparison_tick<=0) return 0;
   int warmup=(c.relation==SMT_AUTO ? c.correlation_window*2+1 : 61);
   string[] seen=InitArray<string>(0);
   for(int n=warmup;n<=an;n++)
     {
      long asof=ICTBarClose(tf,a[n-1].time);
      int m=ICTClosedPrefix(b,bn,tf,asof); if(m<60 || b[m-1].time!=a[n-1].time) continue;
       double rho=0; int pairs=0;
       int relation=ICTSMTRelationFromRates(a,n,b,m,c,ref rho,ref pairs);
      if(n==an) relation_known=relation!=0;
      if(relation==0) continue;
      for(int dir=-1;dir<=1;dir+=2)
        {
         SSMTDivergence s=new SSMTDivergence();
         if(!SRMPFindSMTPairFromRates(primary,comparison,tf,a,n,b,m,c.left,c.right,c.max_gap,relation,
                primary_tick*c.tolerance_ticks,comparison_tick*c.tolerance_ticks,dir,s)) continue;
         bool duplicate=false; for(int i=0;i<ArraySize(seen);i++) if(seen[i]==s.event_id) { duplicate=true; break; }
         if(duplicate) continue;
         int used=ArraySize(seen); ArrayResize(ref seen,used+1); seen[used]=s.event_id;
         s.correlation=rho; s.correlation_pairs=pairs;
         SICTSMTEvent e=new SICTSMTEvent(); ZeroMemory(e); e.signal=s; e.life=ICT_SMT_CONFIRMED; e.changed_at=s.confirmation_time;
         e.seed_context=n==warmup;
         int size=ArraySize(events); ArrayResize(ref events,size+1); events[size]=e;
        }
     }
   return ArraySize(events);
  }

public static void ICTAdvanceSMT(MqlRates bar,long closed,double tolerance,long expiry_start,SICTSMTEvent evt) {
   if(evt.life!=ICT_SMT_CONFIRMED || closed<=evt.signal.confirmation_time) return;
   bool invalid=(evt.signal.direction>0 ? bar.close<evt.signal.primary_recent-tolerance :
                                         bar.close>evt.signal.primary_recent+tolerance);
   if(invalid) { evt.life=ICT_SMT_INVALIDATED; evt.changed_at=closed; }
   else if(evt.signal.confirmation_time<expiry_start) { evt.life=ICT_SMT_EXPIRED; evt.changed_at=closed; }
  }













public const int IR_OUTSIDE=0;
public const int IR_INTERNAL=1;
public const int IR_BOUNDARY=2;
public const int IR_CROSSING=3;

public const int IR_UNTOUCHED=0;
public const int IR_APPROACHING=1;
public const int IR_SWEPT=2;
public const int IR_BREAKOUT=3;
public const int IR_CONSUMED=4;
public const int IR_LEVEL_INVALIDATED=5;


public const int IR_EVENT_NONE=0;
public const int IR_EVENT_LIQUIDITY_SWEEP=1;
public const int IR_EVENT_BREAKOUT_CONFIRMED=2;
public const int IR_EVENT_FALSE_BREAKOUT=3;
public const int IR_EVENT_RETEST_CONFIRMED=4;

public const int IR_FVG=0;
public const int IR_OB=1;
public const int IR_BREAKER=2;

public const int IR_FRESH=0;
public const int IR_TOUCHED=1;
public const int IR_MITIGATED=2;
public const int IR_ZONE_INVALIDATED=3;

public const int IR_RANGE_IDENTIFIED=0;
public const int IR_ERL_APPROACH=1;
public const int IR_SWEEP_CANDIDATE=2;
public const int IR_SWEEP_CONFIRMED=3;
public const int IR_STRUCTURE_SHIFT=4;
public const int IR_RETRACEMENT=5;
public const int IR_REACTION=6;
public const int IR_TARGETING=7;
public const int IR_TARGET_REACHED=8;
public const int IR_SETUP_INVALIDATED=9;

public const int IR_CONSOLIDATION=0;
public const int IR_REVERSAL=1;
public const int IR_CONTINUATION=2;
public const int IR_BREAKOUT_CONTINUATION=3;
public const int IR_FAILED_SWEEP=4;

public const int IR_OK=0;
public const int IR_DATA=1;
public const int IR_CONFIG=2;
public const int IR_NO_RANGE=3;
public const int IR_CONFLICT=4;
public const int IR_WAIT_SWEEP=5;
public const int IR_WAIT_STRUCTURE=6;
public const int IR_NO_ZONE=7;
public const int IR_WAIT_REACTION=8;
public const int IR_NO_TARGET=9;
public const int IR_INVALIDATION=10;
public const int IR_EXPIRED=11;
public const int IR_HISTORY_REVISED=12;
public const int IR_RISK=13;
public const int IR_SCORE=14;
public const int IR_DISABLED=15;


public class SICTRangeConfig {
public bool enabled;
public int htf;
public int mtf;
public int ltf;
public int lookback;
public int left;
public int right;
public int max_zone_age;
public int breakout_bars;
public int zone_mode;
public int liquidity_seed_bars;
public double min_range_ticks;
public double tolerance_ticks;
public double tolerance_atr;
public double equal_ticks;
public double equal_atr;
public double equal_spread;
public double penetration_ticks;
public double penetration_atr;
public double approach_atr;
public double min_fvg_ticks;
public double min_fvg_atr;
public double displacement_atr;
public double displacement_fraction;
public double stop_buffer_ticks;
public bool require_mss;
public bool require_displacement;
public bool use_ob;
public bool allow_continuation;
public bool export_history;
public bool log_events;
public bool breakout_displacement_confirms;
public bool breakout_require_displacement;
public double breakout_buffer_ticks;
public double breakout_buffer_atr;
public double breakout_failure_ticks;
public double retest_tolerance_ticks;
public double retest_tolerance_atr;
public double retest_close_buffer_ticks;
public int retest_window_bars;
public int liquidity_history_bars;
public bool enable_sweep_sequence;
public int sweep_mode;
public int sweep_min_bars;
public int sweep_validation_bars;
public double sweep_rejection_ticks;
public double sweep_tolerance_ticks;
}


public static void ICTDefaultRangeConfig(SICTRangeConfig c) {
   ZeroMemory(c); c.enabled=true; c.htf=PERIOD_H4; c.mtf=PERIOD_M15; c.ltf=PERIOD_M5;
   c.lookback=240; c.liquidity_seed_bars=10000; c.left=2; c.right=2; c.max_zone_age=48; c.breakout_bars=2;
   c.zone_mode=2;
   c.min_range_ticks=20; c.tolerance_ticks=2; c.tolerance_atr=0.02; c.equal_ticks=3;
   c.equal_atr=0.02; c.equal_spread=1.0;
   c.penetration_ticks=3; c.penetration_atr=0.05; c.approach_atr=0.25;
   c.min_fvg_ticks=2; c.min_fvg_atr=0.05; c.displacement_atr=1;
   c.displacement_fraction=0.6; c.stop_buffer_ticks=2;
   c.require_mss=true; c.require_displacement=true; c.use_ob=true;
   c.allow_continuation=true; c.export_history=true;


   c.breakout_displacement_confirms=true; c.breakout_require_displacement=false;
   c.breakout_buffer_ticks=0; c.breakout_buffer_atr=0; c.breakout_failure_ticks=0;
   c.retest_tolerance_ticks=2; c.retest_tolerance_atr=0.02; c.retest_close_buffer_ticks=1;
   c.retest_window_bars=8; c.liquidity_history_bars=60;
   c.enable_sweep_sequence=true; c.sweep_min_bars=2; c.sweep_validation_bars=3;
   c.sweep_mode=SWEEP_1_ALLOWED;
   c.sweep_rejection_ticks=3; c.sweep_tolerance_ticks=0;
  }

public static bool ICTValidRangeConfig(SICTRangeConfig c) {
   double[] values = new double[] {c.min_range_ticks,c.tolerance_ticks,c.tolerance_atr,c.equal_ticks,c.equal_atr,c.equal_spread,
      c.penetration_ticks,c.penetration_atr,c.approach_atr,c.min_fvg_ticks,c.min_fvg_atr,
       c.displacement_atr,c.displacement_fraction,c.stop_buffer_ticks,c.sweep_rejection_ticks,c.sweep_tolerance_ticks,
       c.breakout_buffer_ticks,c.breakout_buffer_atr,c.breakout_failure_ticks,
       c.retest_tolerance_ticks,c.retest_tolerance_atr,c.retest_close_buffer_ticks};
   for(int i=0;i<22;i++) if(!MathIsValidNumber(values[i]) || values[i]<0) return false;
   return PeriodSeconds(c.htf)>PeriodSeconds(c.mtf) && PeriodSeconds(c.mtf)>PeriodSeconds(c.ltf) &&
      PeriodSeconds(c.ltf)>0 && c.lookback>=80 && c.lookback<=1000 &&
      c.liquidity_seed_bars>=c.lookback && c.liquidity_seed_bars<=50000 && c.left>=1 && c.right>=1 &&
      c.left+c.right+30<c.lookback && c.max_zone_age>=1 && c.max_zone_age<=c.lookback &&
      c.breakout_bars>=2 && c.breakout_bars<=10 && c.zone_mode>=0 && c.zone_mode<=2 && c.min_range_ticks>0 &&
      c.min_fvg_ticks>0 && c.displacement_atr>0 && c.displacement_fraction>0 &&
      c.displacement_fraction<=1 && c.stop_buffer_ticks>=1 &&
      c.sweep_min_bars>=1 && c.sweep_validation_bars>=1 &&
       c.retest_window_bars>=1 && c.retest_window_bars<=1000 &&
       c.liquidity_history_bars>=1 && c.liquidity_history_bars<=1000 &&
      (int)c.sweep_mode>=0 && (int)c.sweep_mode<=2 &&
      (c.sweep_mode!=SWEEP_2_REQUIRED || c.enable_sweep_sequence);
  }

public static double ICTRangeEqualTolerance(double tick,double atr,double spread_price,SICTRangeConfig c) {
   if(!MathIsValidNumber(tick) || tick<=0 || !MathIsValidNumber(atr) || atr<0 ||
      !MathIsValidNumber(spread_price) || spread_price<0 ||
      !MathIsValidNumber(c.equal_ticks) || c.equal_ticks<0 ||
      !MathIsValidNumber(c.equal_atr) || c.equal_atr<0 ||
      !MathIsValidNumber(c.equal_spread) || c.equal_spread<0) return -1;
   return MathMax(c.equal_ticks*tick,MathMax(c.equal_atr*atr,c.equal_spread*spread_price));
  }

public class SICTDealingRange {
public string id=string.Empty;
public int version;
public double high;
public double low;
public double midpoint;
public double width;
public int direction;
public int bias;
public int timeframe;
public long high_time;
public long low_time;
public long confirmed_at;
public long retired_at;
public bool valid;
}


public class SICTRangeLevel {
public string id=string.Empty;
public string range_id=string.Empty;
public string name=string.Empty;
public double price;
public int side;
public int membership;
public int state;
public int timeframe;
public long available_at;
public long event_at;
public long last_bar;
public int outside_closes;
public bool candidate;
public int last_event;
public long event_bar_time;
public long event_wick_time;
public double event_wick;
public double event_close;
public long candidate_wick_time;
public long breakout_at;
public double candidate_wick;
public bool candidate_displacement;
public bool retest_pending;
public bool sweep_armed;
public int breakout_age;
public int sweep_count;
public int sweep_wait_bars;
}


public class SICTRangeLiquidityEvent {
public string id=string.Empty;
public string pool_id=string.Empty;
public string range_id=string.Empty;
public string pool_name=string.Empty;
public int type;
public int membership;
public int source_tf;
public int event_tf;
public int side;
public int sweep_number;
public long bar_time;
public long wick_time;
public long confirmed_at;
public double level;
public double wick;
public double close;
}




public static bool ICTRangeLevelUntouched(SICTRangeLevel l,long asof) {
   return l.id!="" && l.available_at>0 && l.available_at<=asof &&
      MathIsValidNumber(l.price) && l.price>0 && (l.side==1 || l.side==-1) &&
      (l.state==IR_UNTOUCHED || l.state==IR_APPROACHING) &&
      l.last_event==IR_EVENT_NONE && l.sweep_count==0 && !l.candidate && l.outside_closes==0;
  }

public class SICTRangeZone {
public string id=string.Empty;
public string range_id=string.Empty;
public int type;
public int state;
public int membership;
public int timeframe;
public int direction;
public int quality;
public double upper;
public double lower;
public double midpoint;
public double invalidation;
public long formed_at;
public long confirmed_at;
public bool displacement;
public bool structure_match;
public bool confluence;
}


public static bool ICTRangeExternal(SICTRangeLevel level,SICTDealingRange range) {
   return level.range_id==range.id && (level.membership==IR_OUTSIDE || level.membership==IR_BOUNDARY) &&
      (level.side>0 ? level.price>=range.high : level.price<=range.low);
  }

public class SICTRangeSnapshot {
public int schema;
public string symbol=string.Empty;
public string signal_id=string.Empty;
public string reason=string.Empty;
public string target_reason=string.Empty;
public string source_reason=string.Empty;
public string source_pool_id=string.Empty;
public string target1_pool_id=string.Empty;
public string target2_pool_id=string.Empty;
public int source_pool_tf;
public int target1_pool_tf;
public int target2_pool_tf;
public int source_event;
public long source_event_at;
public long liquidity_display_start;
public int reason_code;
public SICTDealingRange range=new SICTDealingRange();
public int mtf;
public int ltf;
public long as_of;
public long phase_at;
public long sweep_at;
public long structure_at;
public long reaction_at;
public long last_mtf_event;
public int phase;
public int scenario;
public int direction;
public int htf_bias;
public bool valid;
public bool technical_ready;
public bool displacement;
public bool structure_confirmed;
public double sweep_extreme;
public double sweep_level;
public double invalidation;
public double entry;
public double stop;
public double tp1;
public double tp2;
public double target_distance;
public double last_close;
public int target1_index;
public int target2_index;
public SICTRangeZone active_zone=new SICTRangeZone();
public int level_count;
public int zone_count;
public SICTRangeLevel[] levels=InitArray<SICTRangeLevel>(ICT_RANGE_LEVELS);
public SICTRangeZone[] zones=InitArray<SICTRangeZone>(ICT_RANGE_ZONES);
public int liquidity_event_count;
public SICTRangeLiquidityEvent[] liquidity_events=InitArray<SICTRangeLiquidityEvent>(ICT_RANGE_LIQUIDITY_EVENTS);
public int sweep_event_count;
public SICTSweepRecord[] sweep_events=InitArray<SICTSweepRecord>(ICT_SWEEP_SNAPSHOT_MAX);
public int proposed_action;
public int score;
public double risk_money;
public double volume;
public double rr;
}


public class SICTRangeEvent {
public string range_id=string.Empty;
public string signal_id=string.Empty;
public string trigger=string.Empty;
public string reason=string.Empty;
public int direction;
public int from_phase;
public int to_phase;
public long confirmed_at;
public double open;
public double high;
public double low;
public double close;
public double invalidation;
public double zone_low;
public double zone_high;
public double target;
}


public static bool ICTRangePlanGeometry(SICTRangeSnapshot s,double minimum_rr) {
   if(!s.valid || !s.technical_ready || !s.range.valid ||
      s.active_zone.range_id!=s.range.id || (s.direction!=1 && s.direction!=-1) ||
      !MathIsValidNumber(s.entry) || !MathIsValidNumber(s.stop) || !MathIsValidNumber(s.tp1) ||
      !MathIsValidNumber(minimum_rr) || minimum_rr<2 || s.entry<=0 || s.stop<=0 || s.tp1<=0 ||
      (s.entry-s.stop)*s.direction<=0 || (s.tp1-s.entry)*s.direction<=0) return false;
   return MathAbs(s.tp1-s.entry)/MathAbs(s.entry-s.stop)+1e-9>=minimum_rr;
  }



public static bool ICTRangeLiveTargetSafe(int direction,double bid,double ask,double target) {
   if((direction!=1 && direction!=-1) || !MathIsValidNumber(bid) || !MathIsValidNumber(ask) ||
      !MathIsValidNumber(target) || bid<=0 || ask<bid || target<=0) return false;
   return direction>0 ? bid<target : ask>target;
  }



public static bool ICTRangeReactionTargetSafe(int direction,MqlRates bar,double target) {
   if((direction!=1 && direction!=-1) || !SRMPValidDetectorBar(bar) || bar.low<=0 ||
      !MathIsValidNumber(target) || target<=0) return false;
   return direction>0 ? bar.high<target : bar.low>target;
  }

public static string ICTRangePhaseText(int p) {
   string[] names = new string[] {"RANGE_IDENTIFIED","ERL_APPROACH","ERL_SWEEP_CANDIDATE",
      "ERL_SWEEP_CONFIRMED","STRUCTURE_SHIFT_CONFIRMED","IRL_RETRACEMENT",
      "IRL_REACTION_CONFIRMED","ERL_TARGETING","TARGET_REACHED","SETUP_INVALIDATED"};
   return (int)p>=0 && (int)p<10 ? names[(int)p] : "UNKNOWN";
  }
public static string ICTRangeLevelText(int s) {
   string[] names = new string[] {"UNTOUCHED","APPROACHING","SWEPT","BREAKOUT","CONSUMED","INVALIDATED"};
   return (int)s>=0 && (int)s<6 ? names[(int)s] : "UNKNOWN";
  }
public static string ICTRangeLevelEventText(int evt) {
   string[] names = new string[] {"NONE","LIQUIDITY_SWEEP","BREAKOUT_CONFIRMED","FALSE_BREAKOUT","RETEST_CONFIRMED"};
   return (int)evt>=0 && (int)evt<5 ? names[(int)evt] : "N/A";
  }

public static string ICTRangeZoneText(int t) { return t==IR_FVG ? "FVG" : (t==IR_OB ? "OB" : "BREAKER"); }
public static string ICTRangeZoneStateText(int state) { return state==IR_FRESH ? "Fresh" : (state==IR_TOUCHED ? "Touched/partial" :
           (state==IR_MITIGATED ? "Fully mitigated/expired" : "Invalidated")); }
public static string ICTRangeLocation(SICTDealingRange r,double price) {
   if(!r.valid) return "UNKNOWN";
   if(price>r.high || price<r.low) return "OUTSIDE";
   return price>r.midpoint ? "PREMIUM" : (price<r.midpoint ? "DISCOUNT" : "EQUILIBRIUM");
  }



















public static int ICTRangeClosedCount(MqlRates[] rates,int count,int tf,long asof) {
   if(count<1 || count>ArraySize(rates) || PeriodSeconds(tf)<=0) return 0;
   int n=0;
   while(n<count && ICTBarClose(tf,rates[n].time)<=asof) n++;
   return n;
  }

public static double ICTRangeATR(MqlRates[] rates,int count,int period=14) {
   if(count<=period) return 0;
   double sum=0;
   for(int i=count-period;i<count;i++)
      sum+=MathMax(rates[i].high-rates[i].low,
           MathMax(MathAbs(rates[i].high-rates[i-1].close),MathAbs(rates[i].low-rates[i-1].close)));
   return sum/period;
  }

public static bool ICTRangeDisplacement(MqlRates[] rates,int index,int direction,SICTRangeConfig c) {
   if(index<15 || index>=ArraySize(rates)) return false;
   double atr=ICTRangeATR(rates,index);
   double body=(rates[index].close-rates[index].open)*direction;
   double width=rates[index].high-rates[index].low;
   return atr>0 && width>0 && body>=c.displacement_atr*atr && body/width>=c.displacement_fraction;
  }

public static bool ICTRangeFromStructure(string symbol,int tf,SMarketStructure s,double min_width,long asof,SICTDealingRange r) {
   ZeroMemory(r);
   long high_confirm=ICTBarClose(tf,s.recent_high_confirmed_time);
   long low_confirm=ICTBarClose(tf,s.recent_low_confirmed_time);
   if(!MathIsValidNumber(s.recent_high) || !MathIsValidNumber(s.recent_low) || min_width<=0 ||
      s.recent_high_time<=0 || s.recent_low_time<=0 ||
      s.recent_high_confirmed_time<=0 || s.recent_low_confirmed_time<=0 ||
      s.recent_high_time==s.recent_low_time || high_confirm>asof || low_confirm>asof ||
      s.recent_high-s.recent_low<min_width || s.recent_low<=0) return false;
   r.high=s.recent_high; r.low=s.recent_low;
   r.width=r.high-r.low; r.midpoint=(r.high+r.low)/2;
   r.high_time=s.recent_high_time; r.low_time=s.recent_low_time;
   r.direction=(r.high_time>r.low_time ? 1 : -1); r.bias=s.bias; r.timeframe=tf;
   r.confirmed_at=(long)MathMax(high_confirm,low_confirm); r.valid=true;
   r.id=symbol+"_"+IntegerToString((int)tf)+"_"+IntegerToString((long)r.high_time)+"_"+IntegerToString((long)r.low_time);
   return true;
  }

public static int ICTRangeMembership(SICTDealingRange r,double low,double high,double tolerance) {
   if(!r.valid || high<low) return IR_OUTSIDE;
   if(high<r.low-tolerance || low>r.high+tolerance) return IR_OUTSIDE;
   if(low==high && (MathAbs(low-r.low)<=tolerance || MathAbs(high-r.high)<=tolerance)) return IR_BOUNDARY;
   if(low>r.low+tolerance && high<r.high-tolerance) return IR_INTERNAL;
   return IR_CROSSING;
  }

public static void ICTRangeAddLevel(SICTRangeSnapshot s,string name,double price,int side,long available,double tolerance,int source_tf=PERIOD_CURRENT) {
   if(s.level_count>=ICT_RANGE_LEVELS || !MathIsValidNumber(price) || price<=0 || available>s.as_of || available<=0) return;
   SICTRangeLevel level=new SICTRangeLevel(); ZeroMemory(level);
   level.id=name+"_"+IntegerToString((long)available)+"_"+DoubleToString(price,8);
   for(int i=0;i<s.level_count;i++) if(s.levels[i].id==level.id) return;
   level.range_id=s.range.id; level.name=name; level.price=price; level.side=side;
   level.timeframe=source_tf;
   if(level.timeframe==PERIOD_CURRENT)
      level.timeframe=(StringFind(name,"PD")==0 ? PERIOD_D1 : StringFind(name,"PW")==0 ? PERIOD_W1 :
                       StringFind(name,"PM")==0 ? PERIOD_MN1 : s.ltf);
   level.available_at=available; level.membership=ICTRangeMembership(s.range,price,price,tolerance);
   s.levels[s.level_count++]=level;
  }

public static void ICTRangeSetLevelEvent(SICTRangeLevel l,int evt,MqlRates bar,long close_time,long wick_time,double wick) {
   l.last_event=evt; l.event_at=close_time; l.event_bar_time=bar.time;
   l.event_wick_time=wick_time; l.event_wick=wick; l.event_close=bar.close;
  }
public static void ICTRangeClearLevelCandidate(SICTRangeLevel l) {
   l.candidate=false; l.outside_closes=0; l.candidate_displacement=false;
   l.candidate_wick=0; l.candidate_wick_time=0; l.breakout_age=0;
  }




public static void ICTRangeAdvanceLevelConfigured(MqlRates bar,long close_time,double penetration,double approach,bool displacement,SICTRangeConfig c,double tick,double atr,SICTRangeLevel l) {
   double[] values = new double[] {penetration,approach,tick,atr,c.breakout_buffer_ticks,c.breakout_buffer_atr,
      c.breakout_failure_ticks,c.retest_tolerance_ticks,c.retest_tolerance_atr,c.retest_close_buffer_ticks,
      c.sweep_rejection_ticks,c.sweep_tolerance_ticks};
   for(int i=0;i<12;i++) if(!MathIsValidNumber(values[i]) || values[i]<0) return;
   if(tick<=0 || c.breakout_bars<1 || c.sweep_min_bars<1 || c.sweep_validation_bars<1 || c.retest_window_bars<1 ||
      !SRMPValidDetectorBar(bar) || !MathIsValidNumber(l.price) || l.price<=0 ||
      (l.side!=1 && l.side!=-1) || bar.time<l.available_at || bar.time<=l.last_bar || close_time<=bar.time) return;
   if(l.last_bar==0 && l.last_event==IR_EVENT_NONE) l.sweep_armed=true;
   l.last_bar=bar.time;
   if(l.state==IR_CONSUMED || l.state==IR_LEVEL_INVALIDATED) return;
   double extreme=(l.side>0 ? bar.high : bar.low);
   double excursion=(extreme-l.price)*l.side;
   double outside=(bar.close-l.price)*l.side;
   double breakout_buffer=MathMax(penetration,MathMax(c.breakout_buffer_ticks*tick,c.breakout_buffer_atr*atr));
   double failure_buffer=c.breakout_failure_ticks*tick;
   if(l.state==IR_BREAKOUT)
     {
      l.breakout_age++;
      if(outside<-failure_buffer)
        {

         ICTRangeSetLevelEvent(l,IR_EVENT_FALSE_BREAKOUT,bar,close_time,bar.time,extreme);
         l.state=IR_CONSUMED; l.retest_pending=false; return;
        }
      if(l.breakout_age>c.retest_window_bars) { l.retest_pending=false; return; }
      double tolerance=MathMax(c.retest_tolerance_ticks*tick,c.retest_tolerance_atr*atr);
      bool touched=bar.low<=l.price+tolerance && bar.high>=l.price-tolerance;
      if(l.retest_pending && bar.time>=l.breakout_at && touched &&
         outside>c.retest_close_buffer_ticks*tick && (bar.close-bar.open)*l.side>0)
        {
         ICTRangeSetLevelEvent(l,IR_EVENT_RETEST_CONFIRMED,bar,close_time,bar.time,
                               l.side>0 ? bar.low : bar.high);
         l.retest_pending=false;
        }
      return;
     }
   if(l.state==IR_SWEPT)
     {
      if(outside>breakout_buffer) { l.state=IR_CONSUMED; return; }
     }


   if(!l.sweep_armed && !l.candidate)
     {
      l.sweep_wait_bars++;
      if(l.sweep_wait_bars>=c.sweep_min_bars && outside<=-c.sweep_rejection_ticks*tick)
         l.sweep_armed=true;
      return;
     }
   if(l.candidate && (l.candidate_wick_time<=0 || (extreme-l.candidate_wick)*l.side>0))
     { l.candidate_wick=extreme; l.candidate_wick_time=bar.time; }
   if(l.candidate) l.breakout_age++;
   if(outside>breakout_buffer)
     {
      if(!l.candidate) { l.candidate_wick=extreme; l.candidate_wick_time=bar.time; l.breakout_age=1; }
      l.candidate=true; l.outside_closes++;
      l.candidate_displacement=l.candidate_displacement || displacement;
      bool closes=l.outside_closes>=c.breakout_bars;
      bool impulse=c.breakout_displacement_confirms && displacement;
      if((closes || impulse) && (!c.breakout_require_displacement || l.candidate_displacement))
        {
         l.state=IR_BREAKOUT; l.breakout_at=close_time; l.breakout_age=0; l.retest_pending=true;
         ICTRangeSetLevelEvent(l,IR_EVENT_BREAKOUT_CONFIRMED,bar,close_time,l.candidate_wick_time,l.candidate_wick);
         ICTRangeClearLevelCandidate(l);
        }
      return;
     }
   if(l.candidate && outside<-failure_buffer)
     {
      if(l.breakout_age>c.sweep_validation_bars)
        {


         l.state=IR_LEVEL_INVALIDATED; ICTRangeClearLevelCandidate(l); return;
        }
      l.state=IR_SWEPT;
      ICTRangeSetLevelEvent(l,IR_EVENT_FALSE_BREAKOUT,bar,close_time,l.candidate_wick_time,l.candidate_wick);
      l.sweep_armed=false; l.sweep_wait_bars=0; ICTRangeClearLevelCandidate(l); return;
     }
   if(!l.candidate && l.sweep_armed && excursion>penetration+c.sweep_tolerance_ticks*tick && outside<0)
     {
      l.state=IR_SWEPT; l.sweep_count++;
      ICTRangeSetLevelEvent(l,IR_EVENT_LIQUIDITY_SWEEP,bar,close_time,bar.time,extreme);
      l.sweep_armed=false; l.sweep_wait_bars=0; ICTRangeClearLevelCandidate(l); return;
     }
   l.outside_closes=0; l.candidate_displacement=false;
   if(l.state!=IR_SWEPT) l.state=(MathAbs(bar.close-l.price)<=approach ? IR_APPROACHING : IR_UNTOUCHED);
  }


public static void ICTRangeAdvanceLevel(MqlRates bar,long close_time,double penetration,double approach,bool displacement,int breakout_bars,SICTRangeLevel l) {
   SICTRangeConfig c=new SICTRangeConfig(); ICTDefaultRangeConfig(c); c.breakout_bars=breakout_bars;
   ICTRangeAdvanceLevelConfigured(bar,close_time,penetration,approach,displacement,c,1.0,0.0,l);
  }

public static void ICTRangeRecordLiquidityEvent(SICTRangeSnapshot s,SICTRangeLevel l) {
   if(l.last_event==IR_EVENT_NONE || l.event_at<=0 || l.event_at>s.as_of ||
      l.event_at<s.range.confirmed_at || l.event_bar_time<s.liquidity_display_start) return;
   for(int i=0;i<s.liquidity_event_count;i++)
      if(s.liquidity_events[i].pool_id==l.id && s.liquidity_events[i].confirmed_at==l.event_at &&
         s.liquidity_events[i].type==l.last_event) return;
   SICTRangeLiquidityEvent e=new SICTRangeLiquidityEvent(); ZeroMemory(e);
   e.pool_id=l.id; e.range_id=l.range_id; e.pool_name=l.name; e.type=l.last_event;
   e.id=l.id+"|"+IntegerToString((int)l.last_event)+"|"+IntegerToString((long)l.event_at);
   e.membership=l.membership; e.source_tf=l.timeframe; e.event_tf=s.ltf;
   e.side=l.side; e.sweep_number=l.sweep_count; e.bar_time=l.event_bar_time;
   e.wick_time=l.event_wick_time; e.confirmed_at=l.event_at;
   e.level=l.price; e.wick=l.event_wick; e.close=l.event_close;
   if(s.liquidity_event_count==ICT_RANGE_LIQUIDITY_EVENTS)
     {
      if(e.confirmed_at<s.liquidity_events[0].confirmed_at) return;
      for(int i=1;i<s.liquidity_event_count;i++) s.liquidity_events[i-1]=s.liquidity_events[i];
      s.liquidity_event_count--;
     }
   int at=s.liquidity_event_count;
   while(at>0 && s.liquidity_events[at-1].confirmed_at>e.confirmed_at)
     { s.liquidity_events[at]=s.liquidity_events[at-1]; at--; }
   s.liquidity_events[at]=e; s.liquidity_event_count++;
  }




public static void ICTRangeAdvanceBoundarySequence(SICTSweepSequence sequence,SICTRangeLevel level,MqlRates bar,long close_time,SICTRangeConfig c,double penetration,double tick) {
   if(!sequence.valid) return;
   ICTSweepSequenceStep(sequence,bar,PeriodSeconds(c.ltf),penetration+c.sweep_tolerance_ticks*tick,
      c.sweep_rejection_ticks*tick,c.sweep_min_bars,c.sweep_validation_bars,2147483647,close_time);
   if(level.state==IR_BREAKOUT || level.state==IR_CONSUMED || level.state==IR_LEVEL_INVALIDATED)
     {
      if(sequence.candidate && sequence.count>0) sequence.events[sequence.count-1].status=ICT_SWEEP_INVALIDATED;
      sequence.valid=false; sequence.candidate=false;
     }
  }




public static bool ICTRangeSeedLevel(SICTRangeLevel level,SICTSweepSequence sequence,bool track_sequence,MqlRates[] rates,int count,long before,SICTRangeConfig c,double tick,SICTRangeSnapshot snapshot,bool record_events) {
   if(count<1 || count>ArraySize(rates) || level.available_at<=0 ||
      level.available_at<rates[0].time || before<=0 || tick<=0) return false;
   int first=0,last_index=count;
   while(first<last_index)
     {
      int middle=(first+last_index)/2;
      if(rates[middle].time<level.available_at) first=middle+1; else last_index=middle;
     }
   long last=0;
   for(int j=first;j<count && rates[j].time<before;j++)
     {
      if(!SRMPValidDetectorBar(rates[j]) || (last>0 && rates[j].time<=last)) return false;
      last=rates[j].time;
      long prior_close=ICTBarClose(c.ltf,rates[j].time);
      if(prior_close<=0 || prior_close>before) continue;
      double atr=ICTRangeATR(rates,j+1);
      double penetration=MathMax(c.penetration_ticks*tick,c.penetration_atr*atr);
      ICTRangeAdvanceLevelConfigured(rates[j],prior_close,penetration,c.approach_atr*atr,
         ICTRangeDisplacement(rates,j,level.side,c),c,tick,atr,level);
      if(record_events) ICTRangeRecordLiquidityEvent(snapshot,level);
      if(track_sequence) ICTRangeAdvanceBoundarySequence(sequence,level,rates[j],prior_close,c,penetration,tick);
     }
   return true;
  }

public static bool ICTRangeZoneEligible(SICTRangeZone z,SICTRangeSnapshot s) {
   return z.range_id==s.range.id && z.membership==IR_INTERNAL &&
      z.direction==s.direction && (z.state==IR_FRESH || z.state==IR_TOUCHED) &&
      z.confirmed_at<=s.as_of && z.confirmed_at>=s.structure_at &&
      (z.direction>0 ? z.midpoint<=s.range.midpoint : z.midpoint>=s.range.midpoint);
  }

public static int ICTRangeZoneQuality(SICTRangeZone z,int bias,bool confluence,bool pd_match) {
   if(z.membership!=IR_INTERNAL || z.state>IR_TOUCHED) return 0;
   return (z.structure_match ? 20 : 0)+(z.displacement ? 15 : 0)+
      (z.state==IR_FRESH ? 15 : (z.state==IR_TOUCHED ? 5 : 0))+
      (z.direction==bias ? 10 : 0)+(confluence ? 20 : 0)+(pd_match ? 20 : 0);
  }

public static void ICTRangeAddZone(SICTRangeSnapshot s,SICTRangeZone z,double tolerance) {
   if(s.zone_count>=ICT_RANGE_ZONES || z.lower<=0 || z.upper<=z.lower || z.confirmed_at>s.as_of) return;
   z.range_id=s.range.id; z.midpoint=(z.upper+z.lower)/2;
   z.membership=ICTRangeMembership(s.range,z.lower,z.upper,tolerance);
   z.invalidation=(z.direction>0 ? z.lower : z.upper);
   s.zones[s.zone_count++]=z;
  }



public static void ICTRangeUpdateZoneConfluence(SICTRangeSnapshot s) {
   for(int i=0;i<s.zone_count;i++) s.zones[i].confluence=false;
   if(!s.range.valid || s.range.id=="") return;
   for(int i=0;i<s.zone_count;i++)
      for(int j=i+1;j<s.zone_count;j++)
        {
         if(s.zones[i].range_id!=s.range.id || s.zones[j].range_id!=s.range.id ||
            s.zones[i].membership!=IR_INTERNAL || s.zones[j].membership!=IR_INTERNAL ||
            (s.zones[i].state!=IR_FRESH && s.zones[i].state!=IR_TOUCHED) ||
            (s.zones[j].state!=IR_FRESH && s.zones[j].state!=IR_TOUCHED) ||
            s.zones[i].confirmed_at<=0 || s.zones[j].confirmed_at<=0 ||
            s.zones[i].confirmed_at>s.as_of || s.zones[j].confirmed_at>s.as_of ||
            s.zones[i].type==s.zones[j].type ||
            (s.zones[i].direction!=1 && s.zones[i].direction!=-1) ||
            s.zones[i].direction!=s.zones[j].direction ||
            s.zones[i].lower>s.zones[j].upper || s.zones[i].upper<s.zones[j].lower) continue;
         s.zones[i].confluence=true; s.zones[j].confluence=true;
        }
  }



public static void ICTRangeSelectTargets(SICTRangeSnapshot s,double entry) {
   s.tp1=0; s.tp2=0; s.target1_index=-1; s.target2_index=-1;
   s.target1_pool_id=""; s.target2_pool_id=""; s.target1_pool_tf=PERIOD_CURRENT; s.target2_pool_tf=PERIOD_CURRENT;
   for(int i=0;i<s.level_count;i++)
     {
      SICTRangeLevel l=s.levels[i];
      if(!ICTRangeExternal(l,s.range) || (l.state!=IR_UNTOUCHED && l.state!=IR_APPROACHING) ||
         l.side!=s.direction || (l.price-entry)*s.direction<=0) continue;
      if(s.tp1<=0 || (l.price-s.tp1)*s.direction<0)
        { s.tp2=s.tp1; s.target2_index=s.target1_index; s.tp1=l.price; s.target1_index=i; }
      else if(l.price!=s.tp1 && (s.tp2<=0 || (l.price-s.tp2)*s.direction<0))
        { s.tp2=l.price; s.target2_index=i; }
     }
   s.target_distance=(s.tp1>0 ? MathAbs(s.tp1-entry) : 0);
   if(s.target1_index>=0)
     { s.target1_pool_id=s.levels[s.target1_index].id; s.target1_pool_tf=s.levels[s.target1_index].timeframe; }
   if(s.target2_index>=0)
     { s.target2_pool_id=s.levels[s.target2_index].id; s.target2_pool_tf=s.levels[s.target2_index].timeframe; }
   s.target_reason=(s.tp1>0 ? "Nearest unconsumed same-range ERL: "+s.levels[s.target1_index].name+" | "+
      EnumToString(s.target1_pool_tf)+" | "+s.target1_pool_id+"; conditional, not a forecast" :
      "TARGET UNAVAILABLE: no fresh same-range ERL or retained LTF coverage incomplete");
  }










public const int ICT_BPR_NONE=0;
public const int ICT_BPR_CONFIRMED=1;
public const int ICT_BPR_INVALIDATED=2;

public class SICTBalancedPriceRange {
public string id=string.Empty;
public int timeframe;
public int state;
public int direction;
public double lower;
public double upper;
public double invalidation;
public long first_fvg_time;
public long second_fvg_time;
public long confirmed_at;
public long invalidated_at;
}




public static bool ICTFindBPRFromRates(string symbol,int timeframe,MqlRates[] rates,int count,double minimum_gap,double minimum_overlap,SICTBalancedPriceRange result_out) {
   ZeroMemory(result_out);
   int seconds=PeriodSeconds(timeframe);
   if(symbol=="" || seconds<=0 || count<4 || count>ArraySize(rates) ||
      !SRMPValidDetectorRates(rates,count) || !MathIsValidNumber(minimum_gap) ||
      !MathIsValidNumber(minimum_overlap) || minimum_gap<=0 || minimum_overlap<=0) return false;
   for(int i=count-1;i>=3;i--)
     {
      SFairValueGap recent=new SFairValueGap();
      if(!SRMPFVGAtRates(rates,i+1,i,minimum_gap,recent)) continue;
      for(int j=i-1;j>=2;j--)
        {
         SFairValueGap older=new SFairValueGap();
         if(!SRMPFVGAtRates(rates,j+1,j,minimum_gap,older) || older.direction==recent.direction) continue;
         double low=MathMax(older.lower,recent.lower),high=MathMin(older.upper,recent.upper);
         if(high-low<minimum_overlap) continue;
         result_out.id=symbol+"_"+IntegerToString((int)timeframe)+"_"+
                IntegerToString((long)older.formed_time)+"_"+IntegerToString((long)recent.formed_time);
         result_out.timeframe=timeframe; result_out.direction=recent.direction; result_out.lower=low; result_out.upper=high;
         result_out.first_fvg_time=older.formed_time; result_out.second_fvg_time=recent.formed_time;
         result_out.confirmed_at=ICTBarClose(timeframe,recent.formed_time);
         result_out.invalidation=(result_out.direction>0 ? low : high); result_out.state=ICT_BPR_CONFIRMED;
         for(int k=i+1;k<count;k++)
            if((result_out.direction>0 && rates[k].close<low) || (result_out.direction<0 && rates[k].close>high))
              { result_out.invalidated_at=ICTBarClose(timeframe,rates[k].time); result_out.state=ICT_BPR_INVALIDATED; break; }
         return true;
        }
     }
   return false;
  }















public const int ICT_CONTEXT_INSUFFICIENT=0;
public const int ICT_CONTEXT_NEUTRAL=1;
public const int ICT_CONTEXT_BULLISH=2;
public const int ICT_CONTEXT_BEARISH=3;

public const int ICT_STRUCTURE_INSUFFICIENT=0;
public const int ICT_STRUCTURE_ALIGNED=1;
public const int ICT_STRUCTURE_COUNTER=2;
public const int ICT_STRUCTURE_TRANSITION=3;
public const int ICT_STRUCTURE_NEUTRAL=4;

public class SICTTierSnapshot {
public int timeframe;
public int status;
public SMarketStructure structure=new SMarketStructure();
public long closed_at;
public string reason=string.Empty;
public bool fvg_ready;
public bool bpr_ready;
public MqlRates last_bar=new MqlRates();
public bool displacement_up;
public bool displacement_down;
public SFairValueGap gap=new SFairValueGap();
public SICTBalancedPriceRange bpr=new SICTBalancedPriceRange();
}

public class SICTUnifiedConfig {
public SICTTimeframes frames=new SICTTimeframes();
public int chart_tf;
public SICTDynamicSMTConfig smt=new SICTDynamicSMTConfig();
public SICTStrongOBConfig ob=new SICTStrongOBConfig();
public int structure_lookback;
public int ob_lookback;
public bool enable_ob;
public bool ob_multi;
public bool ob_show_higher;
public bool enable_smt;
}

public class SICTUnifiedSnapshot {
public int schema;
public int revision;
public int detection_bars;
public int display_bars;
public string symbol=string.Empty;
public string comparison1=string.Empty;
public string comparison2=string.Empty;
public string reason=string.Empty;
public string comparator_reason=string.Empty;
public SICTTimeframes frames=new SICTTimeframes();
public int chart_tf;
public SICTSignalResult signal=new SICTSignalResult();
public long asof;
public long display_start;
public bool valid;
public bool capacity_ok;
public int mtf_state;
public SICTTierSnapshot[] tiers=InitArray<SICTTierSnapshot>(3);
public int layer_count;
public int event_count;
public int ob_count;
public SICTSMTLayer[] layers=InitArray<SICTSMTLayer>(4);
public SICTSMTEvent[] events=InitArray<SICTSMTEvent>(ICT_SMART_SMT_MAX);
public SICTStrongOrderBlock[] zones=InitArray<SICTStrongOrderBlock>(ICT_SMART_OB_MAX);
}

public class SICTCachedSeries {
public int timeframe;
public MqlRates[] bars=InitArray<MqlRates>(0);
public long last_open;
public bool ready;
}

public class SICTSMTJournalCursor {
public string comparison=string.Empty;
public int timeframe;
public long through;
}





public static bool ICTNormalizeSMTJournalCursor(int mapped_tf,long saved,SICTSMTJournalCursor cursor) {
   if(saved<=0 || cursor.through<0 || cursor.through>saved) return false;
   if(cursor.comparison=="")
     {
      if(cursor.timeframe==PERIOD_CURRENT && cursor.through!=0) return false;
      if(cursor.timeframe!=PERIOD_CURRENT && cursor.timeframe!=mapped_tf) return false;
      cursor.timeframe=PERIOD_CURRENT; cursor.through=0;
      return true;
     }
   return mapped_tf!=PERIOD_CURRENT && cursor.timeframe==mapped_tf;
  }



public static bool ICTUnifiedTierAvailable(SICTUnifiedSnapshot s,int tf) {
   if(tf==PERIOD_CURRENT || s.asof<=0) return false;
   for(int i=0;i<3;i++)
      if(s.tiers[i].timeframe==tf && s.tiers[i].status!=ICT_CONTEXT_INSUFFICIENT &&
         s.tiers[i].closed_at>0 && s.tiers[i].closed_at<=s.asof) return true;
   return false;
  }
public static void ICTPackSMTPayload(SICTSMTEvent e,ref double[] v) {
   ArrayResize(ref v,ICT_SMT_PAYLOAD_FIELDS); SSMTDivergence s=e.signal;
   v[0]=s.state; v[1]=s.direction; v[2]=s.timeframe; v[3]=s.relation; v[4]=(s.comparator_extreme ? 1 : 0);
   v[5]=s.correlation; v[6]=s.correlation_pairs; v[7]=(double)s.primary_pivot_time; v[8]=(double)s.primary_prior_time;
   v[9]=(double)s.comparison_pivot_time; v[10]=(double)s.comparison_prior_time; v[11]=(double)s.pivot_confirmation_time;
   v[12]=(double)s.confirmation_time; v[13]=s.primary_prior; v[14]=s.primary_recent;
   v[15]=s.comparison_prior; v[16]=s.comparison_recent; v[17]=e.life; v[18]=(double)e.changed_at; v[19]=(e.seed_context ? 1 : 0);
  }
public static bool ICTUnpackSMTPayload(string symbol,string comparison,string id,double[] v,long asof,SICTSMTEvent e) {
   ZeroMemory(e);
   if(ArraySize(v)!=ICT_SMT_PAYLOAD_FIELDS || comparison=="" || comparison==symbol || id=="") return false;
   for(int i=0;i<ArraySize(v);i++)
     {
      if(!MathIsValidNumber(v[i])) return false;
      if(i!=5 && (i<13 || i>16) && (v[i]< -2147483648.0 || v[i]>9007199254740991.0 || (double)(long)v[i]!=v[i])) return false;
     }
   if((v[0]!=SRMP_SMT_BULLISH && v[0]!=SRMP_SMT_BEARISH) || (v[1]!=1 && v[1]!=-1) ||
      (v[3]!=1 && v[3]!=-1) || (v[4]!=0 && v[4]!=1) || (v[19]!=0 && v[19]!=1) ||
      v[2]<=0 || v[2]>49153 || v[6]<0 || v[6]>200 || MathAbs(v[5])>1.000001 ||
      v[17]<ICT_SMT_CONFIRMED || v[17]>ICT_SMT_EXPIRED) return false;
   SSMTDivergence s=new SSMTDivergence(); ZeroMemory(s); s.comparison=comparison; s.event_id=id;
   s.state=(int)(int)v[0]; s.direction=(int)v[1]; s.timeframe=(int)(int)v[2];
   s.relation=(int)v[3]; s.comparator_extreme=(v[4]!=0); s.correlation=v[5]; s.correlation_pairs=(int)v[6];
   s.primary_pivot_time=(long)v[7]; s.primary_prior_time=(long)v[8]; s.comparison_pivot_time=(long)v[9];
   s.comparison_prior_time=(long)v[10]; s.pivot_confirmation_time=(long)v[11]; s.confirmation_time=(long)v[12];
   s.primary_prior=v[13]; s.primary_recent=v[14]; s.comparison_prior=v[15]; s.comparison_recent=v[16];
   e.signal=s; e.life=(int)(int)v[17]; e.changed_at=(long)v[18]; e.seed_context=(v[19]!=0);
   string expected=symbol+"|"+comparison+"|"+IntegerToString((int)s.timeframe)+"|"+IntegerToString(s.direction)+"|"+
      IntegerToString(s.relation)+"|"+IntegerToString((long)s.primary_prior_time)+"|"+IntegerToString((long)s.primary_pivot_time)+"|"+
      IntegerToString((long)s.comparison_prior_time)+"|"+IntegerToString((long)s.comparison_pivot_time);
   return id==expected && s.timeframe!=PERIOD_CURRENT && PeriodSeconds(s.timeframe)>0 &&
      s.state==(s.direction>0 ? SRMP_SMT_BULLISH : SRMP_SMT_BEARISH) &&
      s.primary_prior_time>0 && s.primary_prior_time<s.primary_pivot_time && s.comparison_prior_time>0 &&
      s.comparison_prior_time<s.comparison_pivot_time && s.primary_prior>0 && s.primary_recent>0 && s.comparison_prior>0 && s.comparison_recent>0 &&
      s.pivot_confirmation_time>=ICTBarClose(s.timeframe,s.primary_pivot_time) &&
      s.pivot_confirmation_time>=ICTBarClose(s.timeframe,s.comparison_pivot_time) &&
      s.confirmation_time>=s.pivot_confirmation_time && s.confirmation_time<=asof &&
      e.changed_at>=s.confirmation_time && e.changed_at<=asof;
  }

public static bool ICTValidUnifiedConfig(SICTUnifiedConfig c) {
   return c.frames.status!=ICT_MTF_INVALID && c.frames.ltf!=PERIOD_CURRENT &&
      c.chart_tf!=PERIOD_CURRENT && PeriodSeconds(c.chart_tf)>0 &&
      c.structure_lookback>=40 && c.structure_lookback<=1000 && c.ob_lookback>=40 && c.ob_lookback<=1000 &&
      ICTValidDynamicSMTConfig(c.smt) && ICTValidStrongOBConfig(c.ob);
  }


public static bool ICTUnifiedSMTAligned(SICTUnifiedSnapshot s,int direction) {
   bool same=false,opposite=false;
   if(!s.valid || (direction!=1 && direction!=-1)) return false;
   for(int layer=0;layer<s.layer_count;layer++)
      for(int comp=0;comp<2;comp++)
        {
         SICTSMTPeerSnapshot peer=s.layers[layer].peers[comp];
         string configured=(comp==0 ? s.comparison1 : s.comparison2);
         if(peer.comparison=="" || peer.comparison!=configured || !peer.ready || !peer.relation_known ||
            peer.last_close!=s.layers[layer].last_close || peer.last_close>s.asof) continue;
         if(peer.conflict) opposite=true;
         int bias=(peer.state==ICT_SMT_PEER_BULLISH ? 1 : peer.state==ICT_SMT_PEER_BEARISH ? -1 : 0);
         if(bias==direction) same=true;
         if(bias==-direction) opposite=true;
        }
   return same && !opposite;
  }
public static int ICTNearestActiveOB(SICTUnifiedSnapshot s,double price,int direction=0) {
   int best=-1; double distance=DBL_MAX;
   for(int i=0;i<s.ob_count;i++)
     {
      if(!ICTOBActive(s.zones[i]) || !s.zones[i].hard_gates ||
         (direction!=0 && s.zones[i].ob.direction!=direction)) continue;
      double d=(price<s.zones[i].ob.lower ? s.zones[i].ob.lower-price :
                price>s.zones[i].ob.upper ? price-s.zones[i].ob.upper : 0);
       if(s.zones[i].ob.confirmation_time>s.asof) continue;
       if(best<0 || d<distance || (d==distance && s.zones[i].current_context_score>s.zones[best].current_context_score))
        { best=i; distance=d; }
     }
   return best;
  }















public static double ICTUTake(double[] v,ref int n,ref bool ok) { if(n>=ArraySize(v)) { ok=false; return 0; } return v[n++]; }
public static int ICTUEnumTake(double[] v,ref int n,ref bool ok) {
   double value=ICTUTake(v,ref n,ref ok);
   if(!MathIsValidNumber(value) || value< -2147483648.0 || value>2147483647.0) { ok=false; return 0; }
   int result=(int)value; if((double)result!=value) ok=false; return result;
  }
public static string ICTUText(string[] v,ref int n,ref bool ok) { if(n>=ArraySize(v)) { ok=false; return ""; } return v[n++]; }



public static void ICTUPackStructure(SMarketStructure s,ref double[] v,ref int n) {
   v[n++]=ICTNumber(s.bias); v[n++]=ICTNumber(s.bos_direction); v[n++]=ICTNumber(s.mss); v[n++]=ICTNumber(s.recent_high); v[n++]=ICTNumber(s.prior_high); v[n++]=ICTNumber(s.recent_low); v[n++]=ICTNumber(s.prior_low);
   v[n++]=ICTNumber(s.recent_high_time); v[n++]=ICTNumber(s.prior_high_time); v[n++]=ICTNumber(s.recent_low_time); v[n++]=ICTNumber(s.prior_low_time);
   v[n++]=ICTNumber(s.recent_high_confirmed_time); v[n++]=ICTNumber(s.prior_high_confirmed_time); v[n++]=ICTNumber(s.recent_low_confirmed_time); v[n++]=ICTNumber(s.prior_low_confirmed_time);
   v[n++]=ICTNumber(s.bos_time); v[n++]=ICTNumber(s.bos_level); v[n++]=ICTNumber(s.latest_closed_bar);
  }
public static void ICTUUnpackStructure(SMarketStructure s,double[] v,ref int n,ref bool ok) {
   s.bias=(int)ICTUTake(v,ref n,ref ok); s.bos_direction=(int)ICTUTake(v,ref n,ref ok); s.mss=(ICTUTake(v,ref n,ref ok)!=0);
   s.recent_high=(double)ICTUTake(v,ref n,ref ok); s.prior_high=(double)ICTUTake(v,ref n,ref ok); s.recent_low=(double)ICTUTake(v,ref n,ref ok); s.prior_low=(double)ICTUTake(v,ref n,ref ok);
   s.recent_high_time=(long)ICTUTake(v,ref n,ref ok); s.prior_high_time=(long)ICTUTake(v,ref n,ref ok); s.recent_low_time=(long)ICTUTake(v,ref n,ref ok); s.prior_low_time=(long)ICTUTake(v,ref n,ref ok);
   s.recent_high_confirmed_time=(long)ICTUTake(v,ref n,ref ok); s.prior_high_confirmed_time=(long)ICTUTake(v,ref n,ref ok);
   s.recent_low_confirmed_time=(long)ICTUTake(v,ref n,ref ok); s.prior_low_confirmed_time=(long)ICTUTake(v,ref n,ref ok);
   s.bos_time=(long)ICTUTake(v,ref n,ref ok); s.bos_level=(double)ICTUTake(v,ref n,ref ok); s.latest_closed_bar=(long)ICTUTake(v,ref n,ref ok);
  }
public static bool ICTUValidFrame(int tf,bool allow_current=true) {
   if(tf==PERIOD_CURRENT) return allow_current;
   int[] frames = new int[] {PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,PERIOD_M10,PERIOD_M12,PERIOD_M15,
      PERIOD_M20,PERIOD_M30,PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
   for(int i=0;i<ArraySize(frames);i++) if(tf==frames[i]) return true;
   return false;
  }
public static bool ICTUValidFrames(SICTTimeframes f) {
   if(!ICTUValidFrame(f.ltf,false) || !ICTUValidFrame(f.mtf) || !ICTUValidFrame(f.htf) ||
      (f.mode!=ICT_MTF_AUTO && f.mode!=ICT_MTF_MANUAL)) return false;
   if(f.status==ICT_MTF_FULL) return f.mtf!=PERIOD_CURRENT && f.htf!=PERIOD_CURRENT &&
      PeriodSeconds(f.ltf)<PeriodSeconds(f.mtf) && PeriodSeconds(f.mtf)<PeriodSeconds(f.htf);
   if(f.status==ICT_MTF_TWO_TIER) return f.mtf!=PERIOD_CURRENT && f.htf==PERIOD_CURRENT && PeriodSeconds(f.ltf)<PeriodSeconds(f.mtf);
   return f.status==ICT_MTF_ONE_TIER && f.mtf==PERIOD_CURRENT && f.htf==PERIOD_CURRENT;
  }
public static void ICTUPackSignal(SICTSignalResult a,ref double[] v,ref int n,ref string[] t,ref int k) {
   t[k++]=a.id; t[k++]=a.symbol; t[k++]=a.reason; t[k++]=a.htf_reason; t[k++]=a.mtf_reason; t[k++]=a.ltf_reason; t[k++]=a.smt_reason;
   t[k++]=a.source_pool_id; t[k++]=a.target_pool_id; t[k++]=a.target2_pool_id; t[k++]=a.liquidity_event;
   v[n++]=ICTNumber(a.frames.ltf); v[n++]=ICTNumber(a.frames.mtf); v[n++]=ICTNumber(a.frames.htf); v[n++]=ICTNumber(a.frames.mode); v[n++]=ICTNumber(a.frames.status);
   v[n++]=ICTNumber(a.state); v[n++]=ICTNumber(a.asof); v[n++]=ICTNumber(a.trigger_bar); v[n++]=ICTNumber(a.confirmation_time); v[n++]=ICTNumber(a.source_event_time); v[n++]=ICTNumber(a.direction); v[n++]=ICTNumber(a.score);
   v[n++]=ICTNumber(a.data_ready); v[n++]=ICTNumber(a.htf_pass); v[n++]=ICTNumber(a.mtf_pass); v[n++]=ICTNumber(a.ltf_pass); v[n++]=ICTNumber(a.smt_required); v[n++]=ICTNumber(a.smt_pass); v[n++]=ICTNumber(a.risk_pass); v[n++]=ICTNumber(a.confirmed);
   v[n++]=ICTNumber(a.entry); v[n++]=ICTNumber(a.stop); v[n++]=ICTNumber(a.tp1); v[n++]=ICTNumber(a.tp2); v[n++]=ICTNumber(a.rr); v[n++]=ICTNumber(a.source_price);
  }
public static void ICTUUnpackSignal(SICTSignalResult a,double[] v,ref int n,string[] t,ref int k,ref bool ok) {
   a.id=ICTUText(t,ref k,ref ok); a.symbol=ICTUText(t,ref k,ref ok); a.reason=ICTUText(t,ref k,ref ok); a.htf_reason=ICTUText(t,ref k,ref ok); a.mtf_reason=ICTUText(t,ref k,ref ok); a.ltf_reason=ICTUText(t,ref k,ref ok); a.smt_reason=ICTUText(t,ref k,ref ok);
   a.source_pool_id=ICTUText(t,ref k,ref ok); a.target_pool_id=ICTUText(t,ref k,ref ok); a.target2_pool_id=ICTUText(t,ref k,ref ok); a.liquidity_event=ICTUText(t,ref k,ref ok);
   a.frames.ltf=(int)ICTUEnumTake(v,ref n,ref ok); a.frames.mtf=(int)ICTUEnumTake(v,ref n,ref ok); a.frames.htf=(int)ICTUEnumTake(v,ref n,ref ok);
   a.frames.mode=(int)ICTUEnumTake(v,ref n,ref ok); a.frames.status=(int)ICTUEnumTake(v,ref n,ref ok);
   a.state=(int)ICTUEnumTake(v,ref n,ref ok); a.asof=(long)ICTUTake(v,ref n,ref ok); a.trigger_bar=(long)ICTUTake(v,ref n,ref ok); a.confirmation_time=(long)ICTUTake(v,ref n,ref ok);
   a.source_event_time=(long)ICTUTake(v,ref n,ref ok); a.direction=(int)ICTUTake(v,ref n,ref ok); a.score=(int)ICTUTake(v,ref n,ref ok);
   a.data_ready=(ICTUTake(v,ref n,ref ok)!=0); a.htf_pass=(ICTUTake(v,ref n,ref ok)!=0); a.mtf_pass=(ICTUTake(v,ref n,ref ok)!=0); a.ltf_pass=(ICTUTake(v,ref n,ref ok)!=0);
   a.smt_required=(ICTUTake(v,ref n,ref ok)!=0); a.smt_pass=(ICTUTake(v,ref n,ref ok)!=0); a.risk_pass=(ICTUTake(v,ref n,ref ok)!=0); a.confirmed=(ICTUTake(v,ref n,ref ok)!=0);
   a.entry=(double)ICTUTake(v,ref n,ref ok); a.stop=(double)ICTUTake(v,ref n,ref ok); a.tp1=(double)ICTUTake(v,ref n,ref ok); a.tp2=(double)ICTUTake(v,ref n,ref ok); a.rr=(double)ICTUTake(v,ref n,ref ok); a.source_price=(double)ICTUTake(v,ref n,ref ok);
  }
public static bool ICTUnifiedPack(SICTUnifiedSnapshot s,ref double[] v,ref string[] t) {
   if(s.event_count<0 || s.event_count>ICT_SMART_SMT_MAX || s.ob_count<0 || s.ob_count>ICT_SMART_OB_MAX || s.layer_count<0 || s.layer_count>4) return false;
   ArrayResize(ref v,ICT_U_NUMBERS_MAX); ArrayResize(ref t,ICT_U_STRINGS_MAX); int n=0,k=0;
   t[k++]=s.symbol; t[k++]=s.comparison1; t[k++]=s.comparison2; t[k++]=s.reason; t[k++]=s.comparator_reason;
   v[n++]=ICTNumber(s.schema); v[n++]=ICTNumber(s.revision); v[n++]=ICTNumber(s.detection_bars); v[n++]=ICTNumber(s.display_bars);
   v[n++]=ICTNumber(s.frames.ltf); v[n++]=ICTNumber(s.frames.mtf); v[n++]=ICTNumber(s.frames.htf); v[n++]=ICTNumber(s.frames.mode); v[n++]=ICTNumber(s.frames.status); v[n++]=ICTNumber(s.chart_tf);
   v[n++]=ICTNumber(s.asof); v[n++]=ICTNumber(s.display_start); v[n++]=ICTNumber(s.valid); v[n++]=ICTNumber(s.capacity_ok); v[n++]=ICTNumber(s.mtf_state);
   v[n++]=ICTNumber(s.layer_count); v[n++]=ICTNumber(s.event_count); v[n++]=ICTNumber(s.ob_count);
   ICTUPackSignal(s.signal,ref v,ref n,ref t,ref k);
   for(int i=0;i<3;i++)
     {
      v[n++]=ICTNumber(s.tiers[i].timeframe); v[n++]=ICTNumber(s.tiers[i].status); v[n++]=ICTNumber(s.tiers[i].closed_at); t[k++]=s.tiers[i].reason; ICTUPackStructure(s.tiers[i].structure,ref v,ref n);
       MqlRates last=s.tiers[i].last_bar;
       v[n++]=ICTNumber(last.time); v[n++]=ICTNumber(last.open); v[n++]=ICTNumber(last.high); v[n++]=ICTNumber(last.low); v[n++]=ICTNumber(last.close);
       v[n++]=ICTNumber(s.tiers[i].displacement_up); v[n++]=ICTNumber(s.tiers[i].displacement_down);
      v[n++]=ICTNumber(s.tiers[i].fvg_ready); v[n++]=ICTNumber(s.tiers[i].bpr_ready);
      SFairValueGap g=s.tiers[i].gap;
      v[n++]=ICTNumber(g.direction); v[n++]=ICTNumber(g.lower); v[n++]=ICTNumber(g.upper); v[n++]=ICTNumber(g.mitigated); v[n++]=ICTNumber(g.formed_time); v[n++]=ICTNumber(g.status);
      v[n++]=ICTNumber(g.first_touch_time); v[n++]=ICTNumber(g.fully_filled_time); v[n++]=ICTNumber(g.invalidated_time); v[n++]=ICTNumber(g.inversion_evidence); v[n++]=ICTNumber(g.inversion_direction); v[n++]=ICTNumber(g.inversion_time);
      SICTBalancedPriceRange b=s.tiers[i].bpr; t[k++]=b.id; v[n++]=ICTNumber(b.timeframe); v[n++]=ICTNumber(b.state); v[n++]=ICTNumber(b.direction); v[n++]=ICTNumber(b.lower); v[n++]=ICTNumber(b.upper);
      v[n++]=ICTNumber(b.invalidation); v[n++]=ICTNumber(b.first_fvg_time); v[n++]=ICTNumber(b.second_fvg_time); v[n++]=ICTNumber(b.confirmed_at); v[n++]=ICTNumber(b.invalidated_at);
     }
   for(int i=0;i<s.layer_count;i++)
     {
      SICTSMTLayer l=s.layers[i]; v[n++]=ICTNumber(l.timeframe); v[n++]=ICTNumber(l.ready); v[n++]=ICTNumber(l.relation_known); v[n++]=ICTNumber(l.detected); v[n++]=ICTNumber(l.displayed);
      v[n++]=ICTNumber(l.bullish); v[n++]=ICTNumber(l.bearish); v[n++]=ICTNumber(l.last_close); v[n++]=ICTNumber(l.window_start); t[k++]=l.reason;
       for(int comp=0;comp<2;comp++)
         {
          SICTSMTPeerSnapshot p=l.peers[comp]; t[k++]=p.comparison; t[k++]=p.event_id; t[k++]=p.reason;
          v[n++]=ICTNumber(p.ready); v[n++]=ICTNumber(p.relation_known); v[n++]=ICTNumber(p.conflict); v[n++]=ICTNumber(p.relation); v[n++]=ICTNumber(p.state); v[n++]=ICTNumber(p.last_close);
          v[n++]=ICTNumber(p.primary_pivot_time); v[n++]=ICTNumber(p.comparison_pivot_time); v[n++]=ICTNumber(p.pivot_confirmation_time); v[n++]=ICTNumber(p.confirmation_time);
          v[n++]=ICTNumber(p.primary_pivot); v[n++]=ICTNumber(p.comparison_pivot);
         }
     }
   for(int i=0;i<s.event_count;i++)
     {
      SICTSMTEvent e=s.events[i]; SSMTDivergence a=e.signal;
      t[k++]=a.comparison; t[k++]=a.event_id; v[n++]=ICTNumber(a.state); v[n++]=ICTNumber(a.direction); v[n++]=ICTNumber(a.timeframe); v[n++]=ICTNumber(a.relation); v[n++]=ICTNumber(a.comparator_extreme);
      v[n++]=ICTNumber(a.correlation); v[n++]=ICTNumber(a.correlation_pairs); v[n++]=ICTNumber(a.primary_pivot_time); v[n++]=ICTNumber(a.primary_prior_time); v[n++]=ICTNumber(a.comparison_pivot_time);
      v[n++]=ICTNumber(a.comparison_prior_time); v[n++]=ICTNumber(a.pivot_confirmation_time); v[n++]=ICTNumber(a.confirmation_time);
      v[n++]=ICTNumber(a.primary_prior); v[n++]=ICTNumber(a.primary_recent); v[n++]=ICTNumber(a.comparison_prior); v[n++]=ICTNumber(a.comparison_recent);
      v[n++]=ICTNumber(e.life); v[n++]=ICTNumber(e.changed_at); v[n++]=ICTNumber(e.seed_context);
     }
   for(int i=0;i<s.ob_count;i++)
     {
      SICTStrongOrderBlock z=s.zones[i]; SOrderBlock b=z.ob;
      t[k++]=z.id; t[k++]=z.gate_reason; t[k++]=z.invalidation_reason;
      v[n++]=ICTNumber(b.direction); v[n++]=ICTNumber(b.state); v[n++]=ICTNumber(b.formation_time); v[n++]=ICTNumber(b.confirmation_time); v[n++]=ICTNumber(b.state_time); v[n++]=ICTNumber(b.upper); v[n++]=ICTNumber(b.lower); v[n++]=ICTNumber(b.midpoint);
      v[n++]=ICTNumber(b.displacement); v[n++]=ICTNumber(b.break_confirmed); v[n++]=ICTNumber(b.liquidity_sweep); v[n++]=ICTNumber(b.fvg); v[n++]=ICTNumber(b.pd_match); v[n++]=ICTNumber(b.session_match); v[n++]=ICTNumber(b.score);
       v[n++]=ICTNumber(z.timeframe); v[n++]=ICTNumber(z.grade); v[n++]=ICTNumber(z.confirmation_grade); v[n++]=ICTNumber(z.life); v[n++]=ICTNumber(z.candles); v[n++]=ICTNumber(z.confirmation_score); v[n++]=ICTNumber(z.current_context_score); v[n++]=ICTNumber(z.touch_count); v[n++]=ICTNumber(z.age); v[n++]=ICTNumber(z.sweep_count);
      v[n++]=ICTNumber(z.sweep_points); v[n++]=ICTNumber(z.displacement_points); v[n++]=ICTNumber(z.structure_points); v[n++]=ICTNumber(z.fvg_points); v[n++]=ICTNumber(z.bias_points); v[n++]=ICTNumber(z.pd_points); v[n++]=ICTNumber(z.freshness_points);
      v[n++]=ICTNumber(z.hard_gates); v[n++]=ICTNumber(z.continuation); v[n++]=ICTNumber(z.in_contact); v[n++]=ICTNumber(z.departed); v[n++]=ICTNumber(z.group_end); v[n++]=ICTNumber(z.processed_at);
      v[n++]=ICTNumber(z.open_reference); v[n++]=ICTNumber(z.mitigation_depth); v[n++]=ICTNumber(z.invalidation);
     }
   ArrayResize(ref v,n); ArrayResize(ref t,k); return true;
  }
public static bool ICTUnifiedUnpack(double[] v,string[] t,SICTUnifiedSnapshot s) {
   ZeroMemory(s); int n=0,k=0; bool ok=true;
   if(ArraySize(v)>ICT_U_NUMBERS_MAX || ArraySize(t)>ICT_U_STRINGS_MAX) return false;
   for(int i=0;i<ArraySize(v);i++) if(!MathIsValidNumber(v[i])) return false;
   s.symbol=ICTUText(t,ref k,ref ok); s.comparison1=ICTUText(t,ref k,ref ok); s.comparison2=ICTUText(t,ref k,ref ok); s.reason=ICTUText(t,ref k,ref ok); s.comparator_reason=ICTUText(t,ref k,ref ok);
   s.schema=(int)ICTUTake(v,ref n,ref ok); s.revision=(int)ICTUTake(v,ref n,ref ok); s.detection_bars=(int)ICTUTake(v,ref n,ref ok); s.display_bars=(int)ICTUTake(v,ref n,ref ok);
   s.frames.ltf=(int)ICTUEnumTake(v,ref n,ref ok); s.frames.mtf=(int)ICTUEnumTake(v,ref n,ref ok); s.frames.htf=(int)ICTUEnumTake(v,ref n,ref ok);
   s.frames.mode=(int)ICTUEnumTake(v,ref n,ref ok); s.frames.status=(int)ICTUEnumTake(v,ref n,ref ok); s.chart_tf=(int)ICTUEnumTake(v,ref n,ref ok);
   s.asof=(long)ICTUTake(v,ref n,ref ok); s.display_start=(long)ICTUTake(v,ref n,ref ok); s.valid=(ICTUTake(v,ref n,ref ok)!=0); s.capacity_ok=(ICTUTake(v,ref n,ref ok)!=0); s.mtf_state=(int)ICTUTake(v,ref n,ref ok);
   s.layer_count=(int)ICTUTake(v,ref n,ref ok); s.event_count=(int)ICTUTake(v,ref n,ref ok); s.ob_count=(int)ICTUTake(v,ref n,ref ok);
   if(!ok || s.schema!=ICT_UNIFIED_SCHEMA || s.symbol=="" || s.asof<=0 || s.layer_count<0 || s.layer_count>4 ||
       s.event_count<0 || s.event_count>ICT_SMART_SMT_MAX || s.ob_count<0 || s.ob_count>ICT_SMART_OB_MAX ||
       !ICTUValidFrames(s.frames) || !ICTUValidFrame(s.chart_tf,false)) return false;
   ICTUUnpackSignal(s.signal,v,ref n,t,ref k,ref ok);
   SICTSignalResult signal=s.signal;
   if((int)signal.state<0 || (int)signal.state>4 || signal.score<0 || signal.score>100 || signal.direction< -1 || signal.direction>1) ok=false;
   if(signal.symbol!="" || signal.asof!=0 || signal.confirmed)
     {
      if(signal.symbol!=s.symbol || signal.asof!=s.asof || !ICTUValidFrames(signal.frames) ||
         signal.frames.ltf!=s.frames.ltf || signal.frames.mtf!=s.frames.mtf || signal.frames.htf!=s.frames.htf ||
         signal.frames.status!=s.frames.status ||
         signal.trigger_bar>signal.asof || signal.confirmation_time>signal.asof || signal.source_event_time>signal.asof) ok=false;
      if(signal.confirmed && (signal.id=="" || !signal.data_ready || !signal.htf_pass || !signal.mtf_pass || !signal.ltf_pass ||
         !signal.risk_pass || (signal.smt_required && !signal.smt_pass) || signal.frames.status!=ICT_MTF_FULL ||
         signal.confirmation_time!=signal.asof || signal.trigger_bar<=0 || signal.trigger_bar>=signal.confirmation_time ||
         signal.target_pool_id=="" || !ICTSignalPlanValid(signal,2) ||
         signal.state!=(signal.direction>0 ? ICT_SIGNAL_BUY_CONFIRMED : ICT_SIGNAL_SELL_CONFIRMED))) ok=false;
      if(!signal.confirmed && (signal.state==ICT_SIGNAL_BUY_CONFIRMED || signal.state==ICT_SIGNAL_SELL_CONFIRMED)) ok=false;
     }
   else if(signal.frames.ltf!=PERIOD_CURRENT || signal.frames.mtf!=PERIOD_CURRENT || signal.frames.htf!=PERIOD_CURRENT ||
      signal.frames.mode!=ICT_MTF_AUTO || signal.frames.status!=ICT_MTF_INVALID || signal.state!=ICT_SIGNAL_NO_TRADE) ok=false;
   for(int i=0;i<3;i++)
     { s.tiers[i].timeframe=(int)ICTUTake(v,ref n,ref ok); s.tiers[i].status=(int)ICTUTake(v,ref n,ref ok);
       s.tiers[i].closed_at=(long)ICTUTake(v,ref n,ref ok); s.tiers[i].reason=ICTUText(t,ref k,ref ok); ICTUUnpackStructure(s.tiers[i].structure,v,ref n,ref ok);
        s.tiers[i].last_bar.time=(long)ICTUTake(v,ref n,ref ok); s.tiers[i].last_bar.open=(double)ICTUTake(v,ref n,ref ok); s.tiers[i].last_bar.high=(double)ICTUTake(v,ref n,ref ok);
        s.tiers[i].last_bar.low=(double)ICTUTake(v,ref n,ref ok); s.tiers[i].last_bar.close=(double)ICTUTake(v,ref n,ref ok);
        s.tiers[i].displacement_up=(ICTUTake(v,ref n,ref ok)!=0); s.tiers[i].displacement_down=(ICTUTake(v,ref n,ref ok)!=0);
        int expected=(i==0 ? s.frames.ltf : i==1 ? s.frames.mtf : s.frames.htf);
        if(s.tiers[i].timeframe!=expected || s.tiers[i].closed_at>s.asof || (int)s.tiers[i].status<0 || (int)s.tiers[i].status>3 ||
           (s.tiers[i].displacement_up && s.tiers[i].displacement_down)) ok=false;
        if(s.tiers[i].last_bar.time>0 && (!SRMPValidDetectorBar(s.tiers[i].last_bar) ||
           ICTBarClose(expected,s.tiers[i].last_bar.time)!=s.tiers[i].closed_at)) ok=false;
        if(s.valid && expected!=PERIOD_CURRENT && s.tiers[i].status!=ICT_CONTEXT_INSUFFICIENT && s.tiers[i].last_bar.time<=0) ok=false;
       s.tiers[i].fvg_ready=(ICTUTake(v,ref n,ref ok)!=0); s.tiers[i].bpr_ready=(ICTUTake(v,ref n,ref ok)!=0);
       s.tiers[i].gap.direction=(int)ICTUTake(v,ref n,ref ok); s.tiers[i].gap.lower=(double)ICTUTake(v,ref n,ref ok); s.tiers[i].gap.upper=(double)ICTUTake(v,ref n,ref ok);
       s.tiers[i].gap.mitigated=(ICTUTake(v,ref n,ref ok)!=0); s.tiers[i].gap.formed_time=(long)ICTUTake(v,ref n,ref ok); s.tiers[i].gap.status=(int)ICTUTake(v,ref n,ref ok);
       s.tiers[i].gap.first_touch_time=(long)ICTUTake(v,ref n,ref ok); s.tiers[i].gap.fully_filled_time=(long)ICTUTake(v,ref n,ref ok); s.tiers[i].gap.invalidated_time=(long)ICTUTake(v,ref n,ref ok);
       s.tiers[i].gap.inversion_evidence=(ICTUTake(v,ref n,ref ok)!=0); s.tiers[i].gap.inversion_direction=(int)ICTUTake(v,ref n,ref ok); s.tiers[i].gap.inversion_time=(long)ICTUTake(v,ref n,ref ok);
       s.tiers[i].bpr.id=ICTUText(t,ref k,ref ok); s.tiers[i].bpr.timeframe=(int)ICTUTake(v,ref n,ref ok); s.tiers[i].bpr.state=(int)ICTUTake(v,ref n,ref ok);
       s.tiers[i].bpr.direction=(int)ICTUTake(v,ref n,ref ok); s.tiers[i].bpr.lower=(double)ICTUTake(v,ref n,ref ok); s.tiers[i].bpr.upper=(double)ICTUTake(v,ref n,ref ok); s.tiers[i].bpr.invalidation=(double)ICTUTake(v,ref n,ref ok);
       s.tiers[i].bpr.first_fvg_time=(long)ICTUTake(v,ref n,ref ok); s.tiers[i].bpr.second_fvg_time=(long)ICTUTake(v,ref n,ref ok); s.tiers[i].bpr.confirmed_at=(long)ICTUTake(v,ref n,ref ok); s.tiers[i].bpr.invalidated_at=(long)ICTUTake(v,ref n,ref ok);
       if(s.tiers[i].bpr_ready && (s.tiers[i].bpr.upper<=s.tiers[i].bpr.lower || s.tiers[i].bpr.confirmed_at>s.asof)) ok=false;
     }
   for(int i=0;i<s.layer_count;i++)
     {
      s.layers[i].timeframe=(int)ICTUTake(v,ref n,ref ok); s.layers[i].ready=(ICTUTake(v,ref n,ref ok)!=0); s.layers[i].relation_known=(ICTUTake(v,ref n,ref ok)!=0);
      s.layers[i].detected=(int)ICTUTake(v,ref n,ref ok); s.layers[i].displayed=(int)ICTUTake(v,ref n,ref ok); s.layers[i].bullish=(int)ICTUTake(v,ref n,ref ok); s.layers[i].bearish=(int)ICTUTake(v,ref n,ref ok);
      s.layers[i].last_close=(long)ICTUTake(v,ref n,ref ok); s.layers[i].window_start=(long)ICTUTake(v,ref n,ref ok); s.layers[i].reason=ICTUText(t,ref k,ref ok);
      if(s.layers[i].last_close>s.asof) ok=false;
       if(!ICTUValidFrame(s.layers[i].timeframe,false)) ok=false;
       for(int comp=0;comp<2;comp++)
         {
          SICTSMTPeerSnapshot p=new SICTSMTPeerSnapshot(); ZeroMemory(p); p.comparison=ICTUText(t,ref k,ref ok); p.event_id=ICTUText(t,ref k,ref ok); p.reason=ICTUText(t,ref k,ref ok);
          p.ready=(ICTUTake(v,ref n,ref ok)!=0); p.relation_known=(ICTUTake(v,ref n,ref ok)!=0); p.conflict=(ICTUTake(v,ref n,ref ok)!=0); p.relation=(int)ICTUTake(v,ref n,ref ok);
          p.state=(int)ICTUTake(v,ref n,ref ok); p.last_close=(long)ICTUTake(v,ref n,ref ok); p.primary_pivot_time=(long)ICTUTake(v,ref n,ref ok);
          p.comparison_pivot_time=(long)ICTUTake(v,ref n,ref ok); p.pivot_confirmation_time=(long)ICTUTake(v,ref n,ref ok); p.confirmation_time=(long)ICTUTake(v,ref n,ref ok);
          p.primary_pivot=(double)ICTUTake(v,ref n,ref ok); p.comparison_pivot=(double)ICTUTake(v,ref n,ref ok);
          string configured=(comp==0 ? s.comparison1 : s.comparison2);
          if(p.comparison!=configured || (int)p.state<0 || (int)p.state>3 || p.relation< -1 || p.relation>1 ||
             p.last_close>s.asof || p.confirmation_time>s.asof || p.pivot_confirmation_time>p.confirmation_time ||
             (p.ready && (p.comparison=="" || p.last_close<=0 || p.last_close!=s.layers[i].last_close)) ||
             (p.relation_known && (!p.ready || p.relation==0)) ||
             (p.state!=ICT_SMT_PEER_NA && (!p.ready || !p.relation_known)) ||
             (p.conflict && p.state!=ICT_SMT_PEER_NONE)) ok=false;
          s.layers[i].peers[comp]=p;
         }
     }
   for(int i=0;i<s.event_count;i++)
     {
      SSMTDivergence a=new SSMTDivergence(); ZeroMemory(a); a.comparison=ICTUText(t,ref k,ref ok); a.event_id=ICTUText(t,ref k,ref ok);
      a.state=(int)ICTUTake(v,ref n,ref ok); a.direction=(int)ICTUTake(v,ref n,ref ok); a.timeframe=(int)ICTUTake(v,ref n,ref ok); a.relation=(int)ICTUTake(v,ref n,ref ok); a.comparator_extreme=(ICTUTake(v,ref n,ref ok)!=0);
      a.correlation=(double)ICTUTake(v,ref n,ref ok); a.correlation_pairs=(int)ICTUTake(v,ref n,ref ok); a.primary_pivot_time=(long)ICTUTake(v,ref n,ref ok); a.primary_prior_time=(long)ICTUTake(v,ref n,ref ok);
      a.comparison_pivot_time=(long)ICTUTake(v,ref n,ref ok); a.comparison_prior_time=(long)ICTUTake(v,ref n,ref ok); a.pivot_confirmation_time=(long)ICTUTake(v,ref n,ref ok); a.confirmation_time=(long)ICTUTake(v,ref n,ref ok);
      a.primary_prior=(double)ICTUTake(v,ref n,ref ok); a.primary_recent=(double)ICTUTake(v,ref n,ref ok); a.comparison_prior=(double)ICTUTake(v,ref n,ref ok); a.comparison_recent=(double)ICTUTake(v,ref n,ref ok);
      s.events[i].signal=a; s.events[i].life=(int)ICTUTake(v,ref n,ref ok); s.events[i].changed_at=(long)ICTUTake(v,ref n,ref ok); s.events[i].seed_context=(ICTUTake(v,ref n,ref ok)!=0);
      if(a.event_id=="" || a.comparison=="" || (a.direction!=1 && a.direction!=-1) || (a.relation!=1 && a.relation!=-1) ||
         a.confirmation_time>s.asof || a.confirmation_time<a.pivot_confirmation_time || a.primary_prior_time>=a.primary_pivot_time ||
         a.primary_prior<=0 || a.primary_recent<=0 || (int)s.events[i].life<0 || (int)s.events[i].life>3 || s.events[i].changed_at>s.asof) ok=false;
     }
   for(int i=0;i<s.ob_count;i++)
     {
      SICTStrongOrderBlock z=new SICTStrongOrderBlock(); ZeroMemory(z); z.id=ICTUText(t,ref k,ref ok); z.gate_reason=ICTUText(t,ref k,ref ok); z.invalidation_reason=ICTUText(t,ref k,ref ok);
      z.ob.direction=(int)ICTUTake(v,ref n,ref ok); z.ob.state=(int)ICTUTake(v,ref n,ref ok); z.ob.formation_time=(long)ICTUTake(v,ref n,ref ok); z.ob.confirmation_time=(long)ICTUTake(v,ref n,ref ok);
      z.ob.state_time=(long)ICTUTake(v,ref n,ref ok); z.ob.upper=(double)ICTUTake(v,ref n,ref ok); z.ob.lower=(double)ICTUTake(v,ref n,ref ok); z.ob.midpoint=(double)ICTUTake(v,ref n,ref ok);
      z.ob.displacement=(ICTUTake(v,ref n,ref ok)!=0); z.ob.break_confirmed=(ICTUTake(v,ref n,ref ok)!=0); z.ob.liquidity_sweep=(ICTUTake(v,ref n,ref ok)!=0); z.ob.fvg=(ICTUTake(v,ref n,ref ok)!=0);
      z.ob.pd_match=(ICTUTake(v,ref n,ref ok)!=0); z.ob.session_match=(ICTUTake(v,ref n,ref ok)!=0); z.ob.score=(int)ICTUTake(v,ref n,ref ok);
       z.timeframe=(int)ICTUTake(v,ref n,ref ok); z.grade=(int)ICTUTake(v,ref n,ref ok); z.confirmation_grade=(int)ICTUTake(v,ref n,ref ok); z.life=(int)ICTUTake(v,ref n,ref ok);
      z.candles=(int)ICTUTake(v,ref n,ref ok); z.confirmation_score=(int)ICTUTake(v,ref n,ref ok); z.current_context_score=(int)ICTUTake(v,ref n,ref ok); z.touch_count=(int)ICTUTake(v,ref n,ref ok); z.age=(int)ICTUTake(v,ref n,ref ok); z.sweep_count=(int)ICTUTake(v,ref n,ref ok);
      z.sweep_points=(int)ICTUTake(v,ref n,ref ok); z.displacement_points=(int)ICTUTake(v,ref n,ref ok); z.structure_points=(int)ICTUTake(v,ref n,ref ok); z.fvg_points=(int)ICTUTake(v,ref n,ref ok); z.bias_points=(int)ICTUTake(v,ref n,ref ok); z.pd_points=(int)ICTUTake(v,ref n,ref ok); z.freshness_points=(int)ICTUTake(v,ref n,ref ok);
      z.hard_gates=(ICTUTake(v,ref n,ref ok)!=0); z.continuation=(ICTUTake(v,ref n,ref ok)!=0); z.in_contact=(ICTUTake(v,ref n,ref ok)!=0); z.departed=(ICTUTake(v,ref n,ref ok)!=0);
      z.group_end=(long)ICTUTake(v,ref n,ref ok); z.processed_at=(long)ICTUTake(v,ref n,ref ok); z.open_reference=(double)ICTUTake(v,ref n,ref ok); z.mitigation_depth=(double)ICTUTake(v,ref n,ref ok); z.invalidation=(double)ICTUTake(v,ref n,ref ok);
      if(z.id=="" || (z.ob.direction!=1 && z.ob.direction!=-1) || z.ob.lower<=0 || z.ob.upper<=z.ob.lower ||
         z.ob.confirmation_time>s.asof || z.ob.confirmation_time<=z.ob.formation_time || z.processed_at>s.asof ||
          z.confirmation_score<0 || z.confirmation_score>100 || z.current_context_score<0 || z.current_context_score>z.confirmation_score ||
          z.touch_count<0 || z.mitigation_depth<0 || z.mitigation_depth>1 || !ICTUValidFrame(z.timeframe,false) ||
          (int)z.life<0 || (int)z.life>7 || (int)z.grade<0 || (int)z.grade>2 || (int)z.confirmation_grade<0 || (int)z.confirmation_grade>2) ok=false;
      s.zones[i]=z;
     }
   return ok && n==ArraySize(v) && k==ArraySize(t);
  }










public const int ICT_POSITION_BALANCE=0;
public const int ICT_POSITION_EQUITY=1;
public const int ICT_POSITION_CONSERVATIVE=2;

public const int ICT_RISK_LIMIT_UNKNOWN=-1;
public const int ICT_RISK_LIMIT_NORMAL=0;
public const int ICT_RISK_LIMIT_WARNING=1;
public const int ICT_RISK_LIMIT_CLOSE=2;




public class SICTPositionRiskInput {
public ulong ticket;
public string symbol=string.Empty;
public int direction;
public int digits;
public double volume;
public double entry;
public double stop;
public double target;
public double profit;
public double swap;
public double gross_at_stop;
public double gross_at_target;
public bool stop_valued;
public bool target_valued;
}


public class SICTPositionRisk {
public SICTPositionRiskInput position=new SICTPositionRiskInput();
public bool valid;
public bool capital_valid;
public bool stop_valid;
public bool target_valid;
public bool floating_valid;
public bool rr_valid;
public double costs;
public double floating;
public double floating_percent;
public double net_at_stop;
public double net_at_target;
public double risk_money;
public double risk_percent;
public double locked_money;
public double locked_percent;
public double target_percent;
public double rr;
public double remaining_risk_money;
}


public class SICTPositionRiskTotals {
public int count;
public int unknown_stops;
public int unknown_targets;
public int unknown_floating;
public int invalid_positions;
public double volume;
public double risk_money;
public double target_money;
public double floating;
public double costs;
public double remaining_risk_money;
}


public class SICTPositionRiskSnapshot {
public long observed_at;
public string symbol_filter=string.Empty;
public string currency=string.Empty;
public int currency_digits;
public int selection_errors;
public int capital_mode;
public double balance;
public double equity;
public double capital;
public double cost_per_lot;
public bool connected;
public int pending_count;
public int unknown_pending;
public double pending_risk_money;
public double margin;
public double free_margin;
public double margin_level;
public double daily_net;
public bool daily_valid;
public bool margin_valid;
public bool protection_online;
public bool protection_armed;
public bool protection_healthy;
public bool daily_opened_valid;
public double daily_opened_risk_money;
public int protection_state;
public SICTPositionRiskTotals totals=new SICTPositionRiskTotals();
public SICTPositionRisk[] positions=InitArray<SICTPositionRisk>(0);
}


public static bool ICTPositionCapitalValid(double capital) { return MathIsValidNumber(capital) && capital>0.0; }

public static double ICTPositionPercent(double money,double capital) {
   if(!MathIsValidNumber(money) || !ICTPositionCapitalValid(capital)) return 0.0;
   return money/capital*100.0;
  }


public static double ICTConservativeRiskCapital(double reference,double balance,double equity) {
   if(!ICTPositionCapitalValid(reference) || !ICTPositionCapitalValid(balance) ||
      !ICTPositionCapitalValid(equity)) return 0.0;
   return MathMin(reference,MathMin(balance,equity));
  }




public static int ICTEvaluatePositionRiskLimit(bool known,double risk_money,double capital,double warning_percent=3.0,double close_percent=5.0) {
   if(!known || !MathIsValidNumber(risk_money) || risk_money<0.0 || !ICTPositionCapitalValid(capital) ||
      !MathIsValidNumber(warning_percent) || !MathIsValidNumber(close_percent) ||
      warning_percent<=0.0 || close_percent<=warning_percent || close_percent>100.0)
      return ICT_RISK_LIMIT_UNKNOWN;
   double percent=ICTPositionPercent(risk_money,capital);
   if(!MathIsValidNumber(percent)) return ICT_RISK_LIMIT_UNKNOWN;
   if(percent>close_percent) return ICT_RISK_LIMIT_CLOSE;
   if(percent>warning_percent) return ICT_RISK_LIMIT_WARNING;
   return ICT_RISK_LIMIT_NORMAL;
  }

public static bool ICTCalculatePositionRisk(SICTPositionRiskInput exposure,double capital,double cost_per_lot,SICTPositionRisk risk) {
   ZeroMemory(risk); risk.position=exposure;
   risk.capital_valid=ICTPositionCapitalValid(capital);
   if((exposure.direction!=1 && exposure.direction!=-1) || exposure.symbol=="" ||
      !MathIsValidNumber(exposure.volume) || exposure.volume<=0.0 ||
      !MathIsValidNumber(exposure.entry) || exposure.entry<=0.0 ||
      !MathIsValidNumber(cost_per_lot) || cost_per_lot<0.0) return false;
   risk.costs=exposure.volume*cost_per_lot;
   if(!MathIsValidNumber(risk.costs)) return false;
   risk.valid=true;
   if(MathIsValidNumber(exposure.profit) && MathIsValidNumber(exposure.swap))
     {
      risk.floating=exposure.profit+exposure.swap;
      risk.floating_valid=MathIsValidNumber(risk.floating);
      if(risk.floating_valid) risk.floating_percent=ICTPositionPercent(risk.floating,capital);
     }
   if(exposure.stop_valued && MathIsValidNumber(exposure.stop) && exposure.stop>0.0 &&
      MathIsValidNumber(exposure.gross_at_stop) && MathIsValidNumber(exposure.swap))
     {
      risk.net_at_stop=exposure.gross_at_stop+exposure.swap-risk.costs;
      risk.stop_valid=MathIsValidNumber(risk.net_at_stop);
      if(risk.stop_valid)
        {
         risk.risk_money=MathMax(0.0,-risk.net_at_stop);
         risk.locked_money=MathMax(0.0,risk.net_at_stop);
         risk.risk_percent=ICTPositionPercent(risk.risk_money,capital);
         risk.locked_percent=ICTPositionPercent(risk.locked_money,capital);
         if(risk.floating_valid)
            risk.remaining_risk_money=MathMax(0.0,risk.floating-risk.net_at_stop);
        }
     }
   if(exposure.target_valued && MathIsValidNumber(exposure.target) && exposure.target>0.0 &&
      MathIsValidNumber(exposure.gross_at_target) && MathIsValidNumber(exposure.swap))
     {
      risk.net_at_target=exposure.gross_at_target+exposure.swap-risk.costs;
      risk.target_valid=MathIsValidNumber(risk.net_at_target);
      if(risk.target_valid) risk.target_percent=ICTPositionPercent(risk.net_at_target,capital);
     }
   if(risk.stop_valid && risk.target_valid && risk.risk_money>0.0 && risk.net_at_target>0.0)
     {
      risk.rr=risk.net_at_target/risk.risk_money;
      risk.rr_valid=MathIsValidNumber(risk.rr);
     }
   return true;
  }



public static void ICTAccumulatePositionRisk(SICTPositionRisk risk,SICTPositionRiskTotals totals) {
   totals.count++;
   if(!risk.valid)
     {
      totals.invalid_positions++; totals.unknown_stops++;
      totals.unknown_targets++; totals.unknown_floating++; return;
     }
   totals.volume+=risk.position.volume; totals.costs+=risk.costs;
   if(risk.stop_valid) totals.risk_money+=risk.risk_money; else totals.unknown_stops++;
   if(risk.target_valid) totals.target_money+=risk.net_at_target; else totals.unknown_targets++;
   if(risk.floating_valid) totals.floating+=risk.floating; else totals.unknown_floating++;
   if(risk.stop_valid && risk.floating_valid) totals.remaining_risk_money+=risk.remaining_risk_money;
  }



public static bool ICTPositionEntryBudgetAllowed(SICTPositionRiskSnapshot s,double candidate_risk,double reference,double portfolio_limit,double daily_limit,ref string reason,bool require_daily_risk=true) {
   reason="";
   double capital=ICTConservativeRiskCapital(reference,s.balance,s.equity);
   if(!ICTPositionCapitalValid(capital) || !MathIsValidNumber(candidate_risk) || candidate_risk<=0.0 ||
      !MathIsValidNumber(portfolio_limit) || portfolio_limit<0.0 || portfolio_limit>100.0 ||
      !MathIsValidNumber(daily_limit) || daily_limit<=0.0 || daily_limit>6.0 ||
      candidate_risk>capital*3.0/100.0+1e-8)
     { reason="Invalid account risk budget"; return false; }
   if(s.symbol_filter!="" || !s.connected || s.selection_errors>0 || s.totals.invalid_positions>0 ||
      s.totals.unknown_stops>0 || s.totals.unknown_floating>0 || s.unknown_pending>0)
     { reason="Account exposure or SL valuation unavailable"; return false; }
   if(!MathIsValidNumber(s.totals.risk_money) || s.totals.risk_money<0.0 ||
      !MathIsValidNumber(s.totals.remaining_risk_money) || s.totals.remaining_risk_money<0.0 ||
      !MathIsValidNumber(s.pending_risk_money) || s.pending_risk_money<0.0)
     { reason="Invalid account exposure totals"; return false; }
   double loss=s.totals.risk_money+s.pending_risk_money+candidate_risk;
   double remaining=s.totals.remaining_risk_money+s.pending_risk_money+candidate_risk;
   if(!MathIsValidNumber(loss) || !MathIsValidNumber(remaining))
     { reason="Account exposure overflow"; return false; }
   if(portfolio_limit>0.0 && MathMax(loss,remaining)>capital*portfolio_limit/100.0+1e-8)
     { reason="Portfolio SL risk budget exceeded (positions + pending + new trade)"; return false; }


   if(daily_limit>0.0 && (!s.daily_valid || !MathIsValidNumber(s.daily_net) ||
      s.daily_net<=-capital*daily_limit/100.0 ||
      s.daily_net-remaining < -capital*daily_limit/100.0-1e-8))
     { reason="Daily loss budget exhausted or account history unavailable"; return false; }
   if(require_daily_risk && (!s.daily_opened_valid || !MathIsValidNumber(s.daily_opened_risk_money) ||
      s.daily_opened_risk_money<0.0 ||
      s.daily_opened_risk_money+s.pending_risk_money+candidate_risk>capital*daily_limit/100.0+1e-8))
     { reason="Daily opened-risk budget exhausted or original SL history unavailable"; return false; }
   return true;
  }








public class SPositionPlanValidation {
public int direction;
public long opened_at;
public long now;
public long plan_revision;
public long plan_published;
public long quote_time;
public int max_position_age;
public int max_plan_age;
public int max_quote_age;
public int max_entry_deviation_points;
public double entry;
public double planned_entry;
public double sl;
public double tp;
public double existing_sl;
public double existing_tp;
public double bid;
public double ask;
public double point;
public double tick;
public double stops_points;
public double freeze_points;
}


public static bool SRMPValidatePositionPlan(SPositionPlanValidation p,ref string reason) {
   reason="Invalid plan or market data";
   double[] values = new double[] {p.entry,p.planned_entry,p.sl,p.tp,p.existing_sl,p.existing_tp,
                    p.bid,p.ask,p.point,p.tick,p.stops_points,p.freeze_points};
   for(int i=0;i<ArraySize(values);i++) if(!MathIsValidNumber(values[i])) return false;
   if((p.direction!=1 && p.direction!=-1) || p.entry<=0 || p.planned_entry<=0 ||
      p.sl<=0 || p.tp<=0 || p.existing_sl<0 || p.existing_tp<0 ||
      p.bid<=0 || p.ask<p.bid || p.point<=0 || p.tick<=0 ||
      p.stops_points<0 || p.freeze_points<0 || p.max_position_age<1 ||
      p.max_plan_age<1 || p.max_quote_age<1 || p.max_entry_deviation_points<0) return false;
   if(p.existing_sl>0 || p.existing_tp>0)
     { reason="Existing SL or TP preserved"; return false; }
   if(p.opened_at<=0 || p.now<p.opened_at || p.now-p.opened_at>p.max_position_age)
     { reason="Position is not recent"; return false; }
   if(p.plan_revision<=0 || p.plan_revision>p.opened_at || p.plan_published<p.plan_revision ||
      p.plan_published>p.now || p.now-p.plan_published>p.max_plan_age)
     { reason="Plan is stale or changed after entry"; return false; }
   if(p.quote_time<=0 || p.quote_time>p.now || p.now-p.quote_time>p.max_quote_age)
     { reason="Quote is stale"; return false; }
   if(MathAbs(p.entry-p.planned_entry)>p.max_entry_deviation_points*p.point+1e-10*p.point)
     { reason="Entry differs from plan"; return false; }
   if(MathAbs(p.sl/p.tick-MathRound(p.sl/p.tick))>1e-5 ||
      MathAbs(p.tp/p.tick-MathRound(p.tp/p.tick))>1e-5 ||
      (p.direction==1 && !(p.sl<p.entry && p.tp>p.entry)) ||
      (p.direction==-1 && !(p.sl>p.entry && p.tp<p.entry)))
     { reason="Invalid SL/TP geometry or tick grid"; return false; }
   double market=(p.direction==1 ? p.bid : p.ask);
   double gap=MathMax(p.stops_points,p.freeze_points)*p.point+p.tick;
   if((p.direction==1 && (p.sl>=market-gap || p.tp<=market+gap)) ||
      (p.direction==-1 && (p.sl<=market+gap || p.tp>=market-gap)))
     { reason="SL/TP inside broker stop or freeze distance"; return false; }
   reason="Position and plan geometry valid";
   return true;
  }


public static bool SRMPValidatePositionPlanRisk(double gross_loss,double gross_reward,double estimated_cost,double reference,double max_risk_percent,double min_rr,ref string reason) {
   reason="Invalid risk inputs";
   if(!MathIsValidNumber(gross_loss) || !MathIsValidNumber(gross_reward) ||
      !MathIsValidNumber(estimated_cost) || !MathIsValidNumber(reference) ||
      !MathIsValidNumber(max_risk_percent) || !MathIsValidNumber(min_rr) ||
      gross_loss>=0 || gross_reward<=0 || estimated_cost<0 || reference<=0 ||
      max_risk_percent<=0 || max_risk_percent>3 || min_rr<2)
      return false;
   double loss=-gross_loss+estimated_cost,reward=gross_reward-estimated_cost;
   if(loss<=0 || reward<=0 || loss>reference*max_risk_percent/100.0+1e-8 || reward/loss+1e-9<min_rr)
     { reason="Position risk or net RR outside limits"; return false; }
   reason="Position risk and net RR valid";
   return true;
  }



















public class SICTStatConfig {
public int history_bars;
public int horizon;
public int min_train;
public int min_evaluation;
public int min_pattern;
public int retrain_bars;
public double move_atr;
}

public class SICTStatSample {
public double[] x=InitArray<double>(ICT_STAT_FEATURES);
public int label;
public int mask;
public long asof;
public long label_end;
}

public class SICTStatModel {
public double[] mean=InitArray<double>(ICT_STAT_FEATURES);
public double[] scale=InitArray<double>(ICT_STAT_FEATURES);
public double[] lr=InitArray<double>(ICT_STAT_LR_WEIGHTS);
public double[] deep=InitArray<double>(ICT_STAT_DNN_WEIGHTS);
public double[] prior=InitArray<double>(ICT_STAT_CLASSES);
public double lr_temperature;
public double deep_temperature;
public int train_n;
public int cal_start;
public int cal_n;
public int test_start;
public int test_n;
public int epoch;
public int cursor;
public bool fitted;
public bool calibrated;
public long train_end;
public long cal_start_time;
public long cal_end;
public long test_start_time;
public long test_end;
}

public class SICTStatSnapshot {
public bool ready;
public bool calibrated;
public bool beats_baseline;
public string status=string.Empty;
public string reason=string.Empty;
public string timeframe=string.Empty;
public int history_n;
public int train_n;
public int cal_n;
public int test_n;
public int horizon;
public int progress;
public int mask;
public double move_atr;
public double[] ml=InitArray<double>(ICT_STAT_CLASSES);
public double[] dl=InitArray<double>(ICT_STAT_CLASSES);
public double[] combined=InitArray<double>(ICT_STAT_CLASSES);
public double brier_ml;
public double brier_dl;
public double brier_combined;
public double brier_baseline;
public double accuracy;
public double baseline_accuracy;
public int[] pattern_n=InitArray<int>(8);
public int[] pattern_hits=InitArray<int>(8);
public long asof;
public long train_end;
public long test_end;
}


public static void ICTStatDefaultConfig(SICTStatConfig c) {
   c.history_bars=6000; c.horizon=4; c.move_atr=0.25;
   c.min_train=400; c.min_evaluation=80; c.min_pattern=30; c.retrain_bars=64;
  }
public static bool ICTStatValidConfig(SICTStatConfig c) {
   return c.history_bars>=1000 && c.history_bars<=20000 && c.horizon>=1 && c.horizon<=24 &&
      MathIsValidNumber(c.move_atr) && c.move_atr>=0.05 && c.move_atr<=3 &&
      c.min_train>=200 && c.min_train<=5000 && c.min_evaluation>=30 && c.min_evaluation<=1000 &&
      c.min_pattern>=10 && c.min_pattern<=1000 && c.retrain_bars>=8 && c.retrain_bars<=1000;
  }
public static double ICTStatClip(double x,double lo,double hi) { return MathMax(lo,MathMin(hi,x)); }
public static double ICTStatTanh(double x) { return 2.0/(1.0+MathExp(-2.0*ICTStatClip(x,-20,20)))-1.0; }
public static bool ICTStatValidRates(MqlRates[] r) {
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
public static double ICTStatATR(MqlRates[] r,int i) {
   if(i<14 || i>=ArraySize(r)) return 0;
   double sum=0;
   for(int k=i-13;k<=i;k++)
      sum+=MathMax(r[k].high-r[k].low,MathMax(MathAbs(r[k].high-r[k-1].close),MathAbs(r[k].low-r[k-1].close)));
   return sum/14.0;
  }
public static int ICTStatPatternMask(MqlRates[] r,int i) {
   if(i<32 || i>=ArraySize(r)) return 0;
   int mask=0;
   double high=r[i-1].high,low=r[i-1].low;
   for(int k=i-8;k<i;k++) { high=MathMax(high,r[k].high); low=MathMin(low,r[k].low); }

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
public static bool ICTStatFeatures(MqlRates[] r,int i,double point,SICTStatSample s) {
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
public static int ICTStatLabel(MqlRates[] r,int i,int horizon,double move_atr,double point) {
   if(i<32 || horizon<1 || i+horizon>=ArraySize(r)) return -1;
   double atr=ICTStatATR(r,i),delta=r[i+horizon].close-r[i].close;
   if(atr<=point || !MathIsValidNumber(move_atr) || move_atr<=0 || point<=0) return -1;
   double band=move_atr*atr+r[i].spread*point;
   return delta>band ? 0 : delta < -band ? 1 : 2;
  }
public static bool ICTStatBuildSamples(MqlRates[] r,double point,SICTStatConfig c,ref SICTStatSample[] samples) {
   ArrayResize(ref samples,0);
   if(!ICTStatValidConfig(c) || !ICTStatValidRates(r) || !MathIsValidNumber(point) || point<=0) return false;
   int capacity=(ArraySize(r)-32)/c.horizon;
   if(capacity<1) return false;
   ArrayResize(ref samples,capacity); int n=0;


   for(int i=32;i+c.horizon<ArraySize(r);i+=c.horizon)
     {
      SICTStatSample s=new SICTStatSample();
      if(!ICTStatFeatures(r,i,point,s)) continue;
      s.label=ICTStatLabel(r,i,c.horizon,c.move_atr,point);
      if(s.label<0) continue;
      s.label_end=r[i+c.horizon].time;
      samples[n++]=s;
     }
   ArrayResize(ref samples,n);
   return n>0;
  }
public static void ICTStatSoftmax(double[] logits,double temperature,ref double[] p) {
   double peak=logits[0],sum=0;
   for(int k=1;k<3;k++) peak=MathMax(peak,logits[k]);
   for(int k=0;k<3;k++) { p[k]=MathExp(ICTStatClip((logits[k]-peak)/temperature,-60,0)); sum+=p[k]; }
   for(int k=0;k<3;k++) p[k]/=sum;
  }
public static void ICTStatNormalize(SICTStatModel m,SICTStatSample s,ref double[] x) {
   for(int k=0;k<ICT_STAT_FEATURES;k++) x[k]=ICTStatClip((s.x[k]-m.mean[k])/m.scale[k],-5,5);
  }
public static void ICTStatForward(SICTStatModel m,SICTStatSample s,bool deep,double temperature,ref double[] p) {
   double[] x=InitArray<double>(ICT_STAT_FEATURES); double[] a=InitArray<double>(ICT_STAT_H1); double[] b=InitArray<double>(ICT_STAT_H2); double[] z=InitArray<double>(3);
   ICTStatNormalize(m,s,ref x);
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
   ICTStatSoftmax(z,temperature,ref p);
  }
public static bool ICTStatPrepare(SICTStatConfig c,SICTStatSample[] samples,SICTStatModel m,SICTStatSnapshot s) {
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
   int[] counts=InitArray<int>(3); ArrayInitialize(counts,0);
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
public static void ICTStatTrainSample(SICTStatModel m,SICTStatSample s,bool train_deep) {
   double[] x=InitArray<double>(32); double[] p=InitArray<double>(3); double[] a=InitArray<double>(12); double[] b=InitArray<double>(6); double[] z=InitArray<double>(3); double[] d3=InitArray<double>(3); double[] d2=InitArray<double>(6); double[] d1=InitArray<double>(12);
   ICTStatNormalize(m,s,ref x); ICTStatForward(m,s,false,1,ref p);
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
   ICTStatSoftmax(z,1,ref p);
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
public static bool ICTStatTrainStep(SICTStatModel m,SICTStatSample[] samples,SICTStatSnapshot s) {
   if(m.train_n<1 || m.epoch>=ICT_STAT_EPOCHS) return false;

   for(int b=0;b<16 && m.epoch<ICT_STAT_EPOCHS;b++)
     {
      int i=(m.cursor+m.epoch*67)%m.train_n;
      ICTStatTrainSample(m,samples[i],m.epoch<ICT_STAT_DEEP_EPOCHS);
      if(++m.cursor>=m.train_n) { m.cursor=0; m.epoch++; }
     }
   s.progress=(m.epoch*m.train_n+m.cursor)*100/(ICT_STAT_EPOCHS*m.train_n);
   return m.epoch<ICT_STAT_EPOCHS;
  }
public static double ICTStatTemperature(SICTStatModel m,SICTStatSample[] samples,bool deep) {
   double[] temperatures = new double[] {0.75,1.0,1.5,2.0,3.0};
   double best=1,best_loss=1.0e100;
   for(int t=0;t<5;t++)
     {
      double loss=0; double[] p=InitArray<double>(3);
      for(int i=m.cal_start;i<m.cal_start+m.cal_n;i++)
        {
         ICTStatForward(m,samples[i],deep,temperatures[t],ref p);
         loss-=MathLog(MathMax(0.000000001,p[samples[i].label]));
        }
      if(loss<best_loss) { best_loss=loss; best=temperatures[t]; }
     }
   return best;
  }
public static double ICTStatBrier(double[] p,int label) {
   double result=0;
   for(int k=0;k<3;k++) { double d=p[k]-(k==label ? 1.0 : 0.0); result+=d*d; }
   return result;
  }
public static int ICTStatArgmax(double[] p) { int best=0; for(int k=1;k<3;k++) if(p[k]>p[best]) best=k; return best; }
public static bool ICTStatFinish(SICTStatModel m,SICTStatSample[] samples,SICTStatSnapshot s) {
   if(m.epoch<ICT_STAT_EPOCHS || m.test_n<1) return false;
   int[] counts=InitArray<int>(3); ArrayInitialize(counts,0);
   for(int i=m.cal_start;i<m.cal_start+m.cal_n;i++) counts[samples[i].label]++;
   m.calibrated=counts[0]>=5 && counts[1]>=5 && counts[2]>=5;
   if(m.calibrated)
     { m.lr_temperature=ICTStatTemperature(m,samples,false); m.deep_temperature=ICTStatTemperature(m,samples,true); }
   s.brier_ml=0; s.brier_dl=0; s.brier_combined=0; s.brier_baseline=0;
   s.accuracy=0; s.baseline_accuracy=0;
   ArrayInitialize(s.pattern_n,0); ArrayInitialize(s.pattern_hits,0);
   for(int i=m.test_start;i<m.test_start+m.test_n;i++)
     {
      double[] ml=InitArray<double>(3); double[] dl=InitArray<double>(3); double[] both=InitArray<double>(3);
      ICTStatForward(m,samples[i],false,m.lr_temperature,ref ml);
      ICTStatForward(m,samples[i],true,m.deep_temperature,ref dl);
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
public static bool ICTStatPredict(SICTStatModel m,SICTStatSample sample,SICTStatSnapshot s) {
   s.ready=false;
   if(!m.fitted) return false;
   for(int k=0;k<32;k++) if(!MathIsValidNumber(sample.x[k])) return false;
   ICTStatForward(m,sample,false,m.lr_temperature,ref s.ml);
   ICTStatForward(m,sample,true,m.deep_temperature,ref s.dl);
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
public static void ICTStatWilson(int hits,int n,ref double low,ref double high) {
   low=0; high=1;
   if(n<1 || hits<0 || hits>n) return;
   double p=(double)hits/n,z=1.96,den=1+z*z/n;
   double center=(p+z*z/(2*n))/den;
   double half=z*MathSqrt(p*(1-p)/n+z*z/(4.0*n*n))/den;
   low=MathMax(0,center-half); high=MathMin(1,center+half);
  }



public class SICTStatLiquidityPair {
public bool valid;
public string bsl_id=string.Empty;
public string ssl_id=string.Empty;
public double bsl;
public double ssl;
public double spot;
public long asof;
public long bsl_available;
public long ssl_available;
public long trend_closed_at;
public int bsl_tf;
public int ssl_tf;
public int trend_bias;
public int htf_bias;
}

public class SICTStatLiquidityAudit {
public int attempted;
public int missing_pair;
public int missing_trend;
public int ambiguous;
public int censored;
public int eligible;
public int[] test_classes=InitArray<int>(3);
public bool validation_pass;
public double brier_geometry;
public double log_loss;
public double ece;
}

public class SICTStatLiquidityRecord {
public SICTStatLiquidityPair pair=new SICTStatLiquidityPair();
public long label_end;
public int label;
}


public static bool ICTStatLiquidityValidPair(SICTStatLiquidityPair p) {
   return p.valid && p.asof>0 && MathIsValidNumber(p.spot) && MathIsValidNumber(p.bsl) && MathIsValidNumber(p.ssl) &&
      p.ssl>0 && p.ssl<p.spot && p.bsl>p.spot && p.bsl_available>0 && p.ssl_available>0 &&
      p.bsl_available<=p.asof && p.ssl_available<=p.asof;
  }
public static bool ICTStatLiquiditySamePair(SICTStatLiquidityPair a,SICTStatLiquidityPair b) {
   if(a.valid!=b.valid) return false;
   if(!a.valid) return true;
   return a.asof==b.asof && a.bsl_id==b.bsl_id && a.ssl_id==b.ssl_id && a.bsl==b.bsl && a.ssl==b.ssl &&
      a.bsl_tf==b.bsl_tf && a.ssl_tf==b.ssl_tf;
  }

public static bool ICTStatLiquidityPristine(MqlRates[] r,int count,int seconds,SICTRangeLevel l,long asof) {
   if(count<1 || count>ArraySize(r) || seconds<=0 || ArrayGetAsSeries(r) ||
      !ICTRangeLevelUntouched(l,asof) || r[count-1].time+seconds!=asof || l.available_at<r[0].time)
      return false;
   if(l.available_at==asof) return true;
   int first=ICTRateIndex(r,count,l.available_at);
   if(first<0) return false;
   for(int j=first;j<count;j++)
     {
      if(!SRMPValidDetectorBar(r[j]) || (j>first && r[j].time!=r[j-1].time+seconds)) return false;
      if(l.side>0 ? r[j].high>=l.price : r[j].low<=l.price) return false;
     }
   return true;
  }

public static bool ICTStatLiquiditySelectPair(SICTRangeSnapshot s,MqlRates[] r,int count,SICTStatLiquidityPair p,bool show_irl=true,bool show_erl=true) {
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

public static bool ICTStatLiquidityFeatures(MqlRates[] r,int i,int seconds,double point,SICTStatLiquidityPair p,SICTStatSample s) {
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

public static int ICTStatLiquidityLabel(MqlRates[] r,int count,int i,int horizon,int seconds,SICTStatLiquidityPair p,ref long label_end) {
   label_end=0;
   if(!ICTStatLiquidityValidPair(p) || ArrayGetAsSeries(r) || seconds<=0 || horizon<1 || count>ArraySize(r) || i<0 || i+horizon>=count ||
      p.asof!=r[i].time+seconds || p.ssl<=0 || p.ssl>=p.spot || p.bsl<=p.spot) return -1;
   for(int j=i+1;j<=i+horizon;j++)
     {
      if(!SRMPValidDetectorBar(r[j]) || r[j].time!=r[j-1].time+seconds) return -1;
      label_end=r[j].time+seconds;


      if(r[j].open>=p.bsl) return 0;
      if(r[j].open<=p.ssl) return 1;
      bool upper=r[j].high>=p.bsl,lower=r[j].low<=p.ssl;
      if(upper && lower) return -2;
      if(upper) return 0;
      if(lower) return 1;
     }
   return 2;
  }

public static void ICTStatLiquidityGeometry(SICTStatSample s,double timeout,ref double[] p) {
   double neutral=ICTStatClip(timeout,0,1),upper=ICTStatClip(s.x[22],0,1);
   p[0]=(1-neutral)*upper; p[1]=(1-neutral)*(1-upper); p[2]=neutral;
  }

public static bool ICTStatLiquidityInSupport(SICTStatModel m,SICTStatSample s) {
   if(!m.fitted) return false;
   for(int f=0;f<32;f++)
      if(!MathIsValidNumber(s.x[f]) || !MathIsValidNumber(m.mean[f]) ||
         !MathIsValidNumber(m.scale[f]) || m.scale[f]<=0 || MathAbs((s.x[f]-m.mean[f])/m.scale[f])>5)
         return false;
   return true;
  }

public static bool ICTStatLiquidityAuditModel(SICTStatModel m,SICTStatSample[] samples,SICTStatSnapshot s,SICTStatLiquidityAudit a) {
   a.validation_pass=false; a.brier_geometry=0; a.log_loss=0; a.ece=0;
   ArrayInitialize(a.test_classes,0);
   if(!m.fitted || !s.ready || m.test_n<1 || m.test_start+m.test_n>ArraySize(samples)) return false;
   int[] bins=InitArray<int>(10); double[] confidence=InitArray<double>(10); double[] hits=InitArray<double>(10);
   ArrayInitialize(bins,0); ArrayInitialize(confidence,0); ArrayInitialize(hits,0);
   for(int i=m.test_start;i<m.test_start+m.test_n;i++)
     {
      double[] ml=InitArray<double>(3); double[] dl=InitArray<double>(3); double[] both=InitArray<double>(3); double[] geometry=InitArray<double>(3);
      ICTStatForward(m,samples[i],false,m.lr_temperature,ref ml);
      ICTStatForward(m,samples[i],true,m.deep_temperature,ref dl);
      for(int k=0;k<3;k++) both[k]=(ml[k]+dl[k])/2.0;
      ICTStatLiquidityGeometry(samples[i],m.prior[2],ref geometry);
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












public const int ICT_FOCUS_WAIT=0;
public const int ICT_FOCUS_MSS=1;
public const int ICT_FOCUS_BOS=2;
public const int ICT_FOCUS_WEAK_BREAK=3;
public const int ICT_FOCUS_EXPIRED=4;
public const int ICT_FOCUS_INVALIDATED=5;
public const int ICT_FOCUS_NO_SWING=6;
public const int ICT_FOCUS_PREBROKEN=7;

public class SICTSweepFocusConfig {
public int left;
public int right;
public int max_bars;
public bool require_displacement;
public double buffer_ticks;
public double body_atr;
public double body_fraction;
}

public class SICTSweepFocus {
public bool valid;
public bool forecast_ready;
public bool forecast_calibrated;
public bool h1_ready;
public SICTRangeLiquidityEvent evt=new SICTRangeLiquidityEvent();
public int status;
public long anchor_time;
public long pivot_time;
public long mss_time;
public long mss_confirmed_at;
public long forecast_asof;
public long h1_closed_at;
public double pivot_level;
public double mss_close;
public double body_ratio;
public double atr;
public double[] ml=InitArray<double>(3);
public double[] dl=InitArray<double>(3);
public int prior_bias;
public int closed_after;
public int h1_bias;
public string forecast_reason=string.Empty;
}


public static bool ICTSweepFocusEligible(SICTRangeLiquidityEvent e,long asof,long oldest,int tf,bool show_irl,bool show_erl) {
   bool external=e.membership==IR_BOUNDARY || e.membership==IR_OUTSIDE;
   return e.type==IR_EVENT_LIQUIDITY_SWEEP && (e.side==1 || e.side==-1) &&
      e.id!="" && e.event_tf==tf && e.bar_time>=oldest && e.wick_time>0 &&
      e.wick_time<=e.bar_time && e.confirmed_at>e.bar_time && e.confirmed_at<=asof &&
      MathIsValidNumber(e.level) && MathIsValidNumber(e.wick) && MathIsValidNumber(e.close) &&
      e.level>0 && (e.wick-e.level)*e.side>0 &&
      (external ? show_erl : e.membership==IR_INTERNAL && show_irl);
  }



public static bool ICTSweepFocusH1Context(MqlRates[] bars,int count,int left,int right,SICTSweepFocus v) {
   v.h1_ready=false; v.h1_bias=0; v.h1_closed_at=0;
   if(!v.valid || v.evt.confirmed_at<=0 || count<1 || count>ArraySize(bars) ||
      ArrayGetAsSeries(bars)) return false;
   int n=ICTClosedPrefix(bars,count,PERIOD_H1,v.evt.confirmed_at);
   if(n<ICT_SWEEP_FOCUS_H1_BARS) return false;
   long closed=ICTBarClose(PERIOD_H1,bars[n-1].time);

   if(closed<=0 || v.evt.confirmed_at-closed>=PeriodSeconds(PERIOD_H1)) return false;
   MqlRates[] window=InitArray<MqlRates>(0); ArrayResize(ref window,ICT_SWEEP_FOCUS_H1_BARS);
   if(ArrayCopy(ref window,bars,0,n-ICT_SWEEP_FOCUS_H1_BARS,ICT_SWEEP_FOCUS_H1_BARS)!=ICT_SWEEP_FOCUS_H1_BARS)
      return false;
   SMarketStructure structure=new SMarketStructure();
   if(!SRMPAnalyzeStructureFromRates(window,ICT_SWEEP_FOCUS_H1_BARS,left,right,structure)) return false;
   v.h1_ready=true; v.h1_bias=structure.bias; v.h1_closed_at=closed;
   return true;
  }

public static bool ICTSweepFocusAlignedH1(SICTSweepFocus v) { return v.valid && v.h1_ready && (v.evt.side==1 || v.evt.side==-1) && v.h1_bias==-v.evt.side; }

public static bool ICTSweepFocusPrefer(SICTSweepFocus candidate,SICTSweepFocus current,bool prefer_h1) {
   if(!candidate.valid) return false;
   if(!current.valid) return true;
   bool aligned=ICTSweepFocusAlignedH1(candidate),other=ICTSweepFocusAlignedH1(current);
   if(prefer_h1 && aligned!=other) return aligned;
   if(candidate.evt.confirmed_at!=current.evt.confirmed_at)
      return candidate.evt.confirmed_at>current.evt.confirmed_at;
   return PeriodSeconds(candidate.evt.source_tf)>PeriodSeconds(current.evt.source_tf);
  }

public static bool ICTSweepFocusAnalyze(MqlRates[] r,int count,SICTRangeLiquidityEvent e,long asof,int seconds,double tick,SICTSweepFocusConfig c,SICTSweepFocus v) {
   ZeroMemory(v); v.evt=e; v.status=ICT_FOCUS_NO_SWING;
   if(seconds<=0 || !MathIsValidNumber(tick) || tick<=0 ||
      c.left<1 || c.right<1 || c.max_bars<1 || c.max_bars>100 ||
      !MathIsValidNumber(c.buffer_ticks) || c.buffer_ticks<0 ||
      !MathIsValidNumber(c.body_atr) || c.body_atr<=0 ||
      !MathIsValidNumber(c.body_fraction) || c.body_fraction<=0 || c.body_fraction>1 ||
      !ICTSweepFocusEligible(e,asof,1,e.event_tf,true,true) ||
      count<1 || count>ArraySize(r) || ArrayGetAsSeries(r)) return false;
   int wick=-1,confirmation=-1,last=-1;
   for(int i=0;i<count;i++)
     {
      if(r[i].time+seconds>asof) break;
      last=i;
      if(r[i].time==e.wick_time) wick=i;
      if(r[i].time==e.bar_time) confirmation=i;
     }
   if(wick<15 || confirmation<wick || last<confirmation || !SRMPValidDetectorRates(r,last+1) ||
      e.confirmed_at<r[confirmation].time+seconds) return false;

   double actual_wick=(e.side>0 ? r[wick].high : r[wick].low);
   if(MathAbs(actual_wick-e.wick)>tick*0.51 ||
      MathAbs(r[confirmation].close-e.close)>tick*0.51 ||
      (e.close-e.level)*e.side>=0) return false;
   v.valid=true; v.atr=ICTStatATR(r,wick);
   v.anchor_time=r[(int)MathMax(0,wick-20)].time;


   double tolerance=MathMax(tick*2,v.atr*0.02);
   for(int p=wick-1;p>=MathMax(0,wick-80);p--)
      if(MathAbs((e.side>0 ? r[p].high : r[p].low)-e.level)<=tolerance)
        { v.anchor_time=r[p].time; break; }


   int pivot=-1;
   for(int p=wick-c.right-1;p>=c.left;p--)
      if(SRMPConfirmedSwingAt(r,wick,p,c.left,c.right,e.side<0)) { pivot=p; break; }
   if(pivot<0) return true;
   v.pivot_time=r[pivot].time; v.pivot_level=(e.side>0 ? r[pivot].low : r[pivot].high);
   SMarketStructure structure=new SMarketStructure();
   if(SRMPAnalyzeStructureFromRates(r,wick,c.left,c.right,structure)) v.prior_bias=structure.bias;
   double buffer=c.buffer_ticks*tick;
   for(int i=pivot+c.right+1;i<=confirmation;i++)
      if((r[i].close-v.pivot_level)*(-e.side)>buffer)
        { v.status=ICT_FOCUS_PREBROKEN; return true; }
   v.status=ICT_FOCUS_WAIT;
   int end=(int)MathMin(last,confirmation+c.max_bars);
   for(int i=confirmation+1;i<=end;i++)
     {
      v.closed_after=i-confirmation;
      if((r[i].close-e.wick)*e.side>buffer)
        { v.status=ICT_FOCUS_INVALIDATED; return true; }
      double beyond=(r[i].close-v.pivot_level)*(-e.side);
      double previous=(r[i-1].close-v.pivot_level)*(-e.side);
      if(beyond<=buffer || previous>buffer) continue;
      double atr=ICTStatATR(r,i-1),body=MathAbs(r[i].close-r[i].open),range=r[i].high-r[i].low;
      bool directional=(r[i].close-r[i].open)*(-e.side)>0;
      bool displacement=atr>0 && range>0 && directional && body>=c.body_atr*atr && body/range>=c.body_fraction;
      if(c.require_displacement && !displacement) { v.status=ICT_FOCUS_WEAK_BREAK; continue; }
      v.body_ratio=(atr>0 ? body/atr : 0); v.mss_time=r[i].time;
      v.mss_confirmed_at=r[i].time+seconds; v.mss_close=r[i].close;

      v.status=(v.prior_bias==e.side ? ICT_FOCUS_MSS : ICT_FOCUS_BOS); return true;
     }
   if(last-confirmation>=c.max_bars && v.status==ICT_FOCUS_WAIT) v.status=ICT_FOCUS_EXPIRED;
   return true;
  }

public static bool ICTSweepFocusForecast(MqlRates[] r,int count,double point,SICTStatModel model,int model_tf,SICTSweepFocus v) {
   v.forecast_ready=false; v.forecast_calibrated=false;
   ArrayInitialize(v.ml,0); ArrayInitialize(v.dl,0);
   if(!v.valid) { v.forecast_reason="Chưa có sweep hợp lệ"; return false; }
   if(model_tf!=v.evt.event_tf) { v.forecast_reason="Khung DL khác khung nến sweep"; return false; }
   if(!model.fitted) { v.forecast_reason="Đang chờ mô hình DL học xong"; return false; }


   if(model.train_end<=0 || model.cal_end<model.train_end ||
      model.cal_end>=v.evt.bar_time)
     { v.forecast_reason="Train/hiệu chỉnh chưa kết thúc trước sweep"; return false; }
   int index=-1;
   for(int i=0;i<count && i<ArraySize(r);i++) if(r[i].time==v.evt.bar_time) { index=i; break; }
   SICTStatSample sample=new SICTStatSample(); SICTStatSnapshot prediction=new SICTStatSnapshot();
   if(index<32 || !ICTStatFeatures(r,index,point,sample) || !ICTStatPredict(model,sample,prediction))
     { v.forecast_reason="Thiếu cửa sổ giá tại nến xác nhận sweep"; return false; }
   for(int k=0;k<3;k++) { v.ml[k]=prediction.ml[k]; v.dl[k]=prediction.dl[k]; }
   v.forecast_ready=true; v.forecast_calibrated=model.calibrated;
   v.forecast_asof=v.evt.confirmed_at; v.forecast_reason="Dự báo hướng sau nến xác nhận, không phải P(TP trước SL)";
   return true;
  }









public const int ICT_A_PATH=0;
public const int ICT_A_CANDLE=1;
public const int ICT_A_LIQUIDITY=2;
public const int ICT_A_ZONES=3;
public const int ICT_A_SMT=4;
public const int ICT_A_DEEP=5;

public class SICTAnalyticalConfig {
public double minimum_score;
public int minimum_groups;
public int minimum_supporters;
public int event_window;
public bool require_deep;
}

public class SICTAnalyticalContext {
public string symbol=string.Empty;
public bool valid;
public int ltf;
public int mtf;
public int htf;
public long asof;
public long ltf_closed;
public long mtf_closed;
public long htf_closed;
public int htf_bias;
public int mtf_bias;
}

public class SICTAnalyticalVotes {
public bool[] available=InitArray<bool>(ICT_ANALYSIS_GROUPS);
public double[] value=InitArray<double>(ICT_ANALYSIS_GROUPS);
}

public class SICTAnalyticalResult {
public bool ready;
public bool signal;
public bool deep_used;
public bool context_aligned;
public bool experimental;
public int direction;
public int groups;
public int supporters;
public int opponents;
public double score;
public double mean;
public long asof;
public string reason=string.Empty;
}

public static void ICTAnalyticalDefaults(SICTAnalyticalConfig c) { c.minimum_score=60; c.minimum_groups=3; c.minimum_supporters=2; c.event_window=12; c.require_deep=false; }
public static bool ICTAnalyticalValidConfig(SICTAnalyticalConfig c) {
   return MathIsValidNumber(c.minimum_score) && c.minimum_score>50 && c.minimum_score<=95 &&
      c.minimum_groups>=2 && c.minimum_groups<=ICT_ANALYSIS_GROUPS &&
      c.minimum_supporters>=2 && c.minimum_supporters<=c.minimum_groups && c.event_window>=1 && c.event_window<=60;
  }
public static bool ICTAnalyticalContextReady(SICTAnalyticalContext c) {
   return c.valid && c.symbol!="" && c.asof>0 && c.ltf!=PERIOD_CURRENT &&
      PeriodSeconds(c.ltf)>0 && PeriodSeconds(c.ltf)<PeriodSeconds(c.mtf) && PeriodSeconds(c.mtf)<PeriodSeconds(c.htf) &&
      c.ltf_closed==c.asof && c.mtf_closed>0 && c.mtf_closed<=c.asof && c.htf_closed>0 && c.htf_closed<=c.asof &&
      (c.htf_bias==1 || c.htf_bias==-1) && c.mtf_bias==c.htf_bias;
  }
public static bool ICTAnalyticalEvaluate(SICTAnalyticalConfig c,SICTAnalyticalContext context,SICTAnalyticalVotes votes,SICTAnalyticalResult s) {
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

public static bool ICTAnalyticalPriceVotes(MqlRates[] r,int tf,long asof,double point,SICTAnalyticalVotes v,ref double atr) {
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

public static void ICTAnalyticalLiquidityVote(SICTRangeSnapshot r,string symbol,long asof,int ltf,int window,SICTAnalyticalVotes v) {
   if(!r.valid || r.symbol!=symbol || r.as_of!=asof || r.ltf!=ltf || window<1 ||
      r.liquidity_event_count<0 || r.liquidity_event_count>ICT_RANGE_LIQUIDITY_EVENTS) return;
   v.available[ICT_A_LIQUIDITY]=true; v.value[ICT_A_LIQUIDITY]=0;
   long latest=0; double sum=0; int count=0;
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

public static double ICTAnalyticalZoneReaction(MqlRates bar,int direction,double low,double high,double quality,double atr) {
   if((direction!=1 && direction!=-1) || !MathIsValidNumber(low) || !MathIsValidNumber(high) ||
      !MathIsValidNumber(quality) || low<=0 || high<=low || atr<=0 ||
      bar.low>high || bar.high<low || (bar.close-bar.open)*direction<=0 ||
      (direction>0 ? bar.close<low : bar.close>high)) return 0;
   double distance=(bar.close<low ? low-bar.close : bar.close>high ? bar.close-high : 0);
   return (0.5+0.5*ICTStatClip(quality/100.0,0,1))*ICTStatClip(1.0-distance/(2*atr),0,1);
  }
public static void ICTAnalyticalRangeZonesVote(SICTRangeSnapshot r,string symbol,long asof,MqlRates bar,double atr,SICTAnalyticalVotes v) {
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
public static void ICTAnalyticalUnifiedVotes(SICTUnifiedSnapshot u,MqlRates bar,double atr,SICTAnalyticalVotes v) {
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

public static bool ICTAnalyticalDeepVote(SICTStatModel m,SICTStatSnapshot s,MqlRates[] rates,int model_tf,int ltf,long asof,double point,SICTAnalyticalVotes v) {
   v.available[ICT_A_DEEP]=false; v.value[ICT_A_DEEP]=0;
   if(model_tf!=ltf || !m.fitted || !m.calibrated || !s.ready || !s.calibrated ||
      s.asof<=0 || ICTBarClose(ltf,s.asof)!=asof || s.horizon<1 ||
      m.train_end<=0 || m.cal_end<=m.train_end || m.test_end<m.cal_end ||
      ICTBarClose(ltf,m.test_end)>asof || !MathIsValidNumber(s.brier_dl) || !MathIsValidNumber(s.brier_baseline) ||
      s.brier_dl<0 || s.brier_dl>=s.brier_baseline) return false;
   int n=ICTClosedPrefix(rates,ArraySize(rates),ltf,asof);
   SICTStatSample sample=new SICTStatSample();
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



public class SICTAnalyticalPolicy {
public double minimum_score;
public double minimum_dl_margin;
public int minimum_groups;
public int minimum_supporters;
public bool strict_context;
public bool require_deep;
public bool allow_experimental;
}

public class SICTAnalyticalDeepState {
public bool ready;
public bool validated;
public bool domain_ok;
public int direction;
public double[] probability=InitArray<double>(3);
public double weight;
public string reason=string.Empty;
}

public static void ICTAnalyticalPolicyDefaults(SICTAnalyticalPolicy p) {
   p.minimum_score=55; p.minimum_dl_margin=0.04; p.minimum_groups=2; p.minimum_supporters=1;
   p.strict_context=false; p.require_deep=true; p.allow_experimental=true;
  }
public static bool ICTAnalyticalPolicyValid(SICTAnalyticalPolicy p) {
   return MathIsValidNumber(p.minimum_score) && p.minimum_score>50 && p.minimum_score<=95 &&
      MathIsValidNumber(p.minimum_dl_margin) && p.minimum_dl_margin>=0.02 && p.minimum_dl_margin<=0.5 &&
      p.minimum_groups>=2 && p.minimum_groups<=ICT_ANALYSIS_GROUPS &&
      p.minimum_supporters>=1 && p.minimum_supporters<=p.minimum_groups;
  }
public static bool ICTAnalyticalPriceContextReady(SICTAnalyticalContext c) {
   return c.valid && c.symbol!="" && c.asof>0 && c.ltf!=PERIOD_CURRENT && PeriodSeconds(c.ltf)>0 &&
      PeriodSeconds(c.ltf)<PeriodSeconds(c.mtf) && PeriodSeconds(c.mtf)<PeriodSeconds(c.htf) &&
      c.ltf_closed==c.asof && c.mtf_closed>=0 && c.mtf_closed<=c.asof && c.htf_closed>=0 && c.htf_closed<=c.asof;
  }
public static bool ICTAnalyticalDeepEvidence(SICTStatModel m,SICTStatSnapshot s,MqlRates[] rates,int model_tf,int ltf,long asof,double point,SICTAnalyticalDeepState deep,SICTAnalyticalVotes v) {
   ZeroMemory(deep); v.available[ICT_A_DEEP]=false; v.value[ICT_A_DEEP]=0;
   deep.reason="Chờ DNN đã học và hiệu chỉnh trên dữ liệu trước nến phân tích";
   if(model_tf!=ltf) { deep.reason="DNN khác khung LTF"; return false; }
   if(!m.fitted || !m.calibrated || !s.ready || !s.calibrated || s.asof<=0 ||
      ICTBarClose(ltf,s.asof)!=asof || s.horizon<1 || m.train_end<=0 || m.cal_end<=m.train_end ||
      m.test_end<m.cal_end || ICTBarClose(ltf,m.test_end)>asof) return false;
   int n=ICTClosedPrefix(rates,ArraySize(rates),ltf,asof); SICTStatSample sample=new SICTStatSample();
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
public static bool ICTAnalyticalEvaluateEarly(SICTAnalyticalPolicy p,SICTAnalyticalContext c,SICTAnalyticalVotes v,SICTAnalyticalDeepState deep,SICTAnalyticalResult s) {
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
public static bool ICTAnalyticalStructureAt(MqlRates[] rates,int tf,long asof,int lookback,int left,int right,SMarketStructure structure,ref long closed) {
   ZeroMemory(structure); closed=0;
   int n=ICTClosedPrefix(rates,ArraySize(rates),tf,asof);
   if(n<lookback || lookback<40) return false;
   MqlRates[] window=InitArray<MqlRates>(0); ArrayResize(ref window,lookback);
   if(ArrayCopy(ref window,rates,0,n-lookback,lookback)!=lookback || !SRMPValidDetectorRates(window,lookback)) return false;
   closed=ICTBarClose(tf,window[lookback-1].time);
   return SRMPAnalyzeStructureFromRates(window,lookback,left,right,structure);
  }


public static string ICTUnifiedSMTDiagnostic(SICTUnifiedSnapshot snapshot,int direction) {
   if(!snapshot.valid) return "UNAVAILABLE: shared snapshot invalid";
   if(direction!=1 && direction!=-1) return "UNKNOWN: decision direction unavailable";
   if(snapshot.layer_count<=0) return "UNAVAILABLE: SMT analysis disabled or no timeframe";
   bool same=false,opposite=false,conflict=false,available=false,unavailable=false;
   for(int layer=0;layer<snapshot.layer_count;layer++)
      for(int comp=0;comp<2;comp++)
        {
         SICTSMTPeerSnapshot peer=snapshot.layers[layer].peers[comp];
         string configured=(comp==0 ? snapshot.comparison1 : snapshot.comparison2);
         if(peer.reason=="DISABLED" && peer.comparison=="" && configured=="") continue;
         if(peer.comparison=="" || peer.comparison!=configured || !peer.ready || !peer.relation_known ||
            peer.last_close!=snapshot.layers[layer].last_close || peer.last_close>snapshot.asof)
           { unavailable=true; continue; }
         available=true;
         if(peer.conflict) conflict=true;
         int bias=(peer.state==ICT_SMT_PEER_BULLISH ? 1 : peer.state==ICT_SMT_PEER_BEARISH ? -1 : 0);
         if(bias==direction) same=true;
         if(bias==-direction) opposite=true;
        }
   string partial=(unavailable ? " (some peer data unavailable)" : "");
   if(conflict || (same && opposite)) return "CONFLICT: opposing active divergences"+partial;
   if(same) return "ALIGNED: active divergence supports direction"+partial;
   if(opposite) return "OPPOSITE: active divergence opposes direction"+partial;
   if(available) return "NONE: no active divergence"+partial;
   return "UNAVAILABLE: no usable comparator data";
  }







public static void FixtureBar(MqlRates b,long t,double open,double high,double low,double close) { ZeroMemory(b); b.time=t; b.open=open; b.high=high; b.low=low; b.close=close; }
public static void FlatFixture(ref MqlRates[] bars,int count) {
   ArrayResize(ref bars,count);
   for(int i=0;i<count;i++) FixtureBar(bars[i],100000+i*300,95,100,90,95);
  }
public static void TestUnifiedMappingCalendar() {
   int[] chart = new int[] {PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,PERIOD_M5,PERIOD_M6,PERIOD_M10,PERIOD_M12,PERIOD_M15,PERIOD_M20,
      PERIOD_M30,PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,PERIOD_D1,PERIOD_W1,PERIOD_MN1};
   int[] mid = new int[] {PERIOD_M15,PERIOD_M15,PERIOD_M15,PERIOD_M15,PERIOD_H1,PERIOD_H1,PERIOD_H1,PERIOD_H1,PERIOD_H1,PERIOD_H1,
      PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_W1,PERIOD_MN1,PERIOD_CURRENT};
   int[] high = new int[] {PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_H4,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,PERIOD_D1,
      PERIOD_D1,PERIOD_D1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_W1,PERIOD_MN1,PERIOD_CURRENT,PERIOD_CURRENT};
   SICTTimeframes f=new SICTTimeframes();
   for(int i=0;i<ArraySize(chart);i++)
      Check("AUTO map "+EnumToString(chart[i]),ICTMapTimeframes(chart[i],ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f) && f.ltf==chart[i] && f.mtf==mid[i] && f.htf==high[i]);
   ICTMapTimeframes(PERIOD_M5,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f);
   ICTMapTimeframes(PERIOD_M1,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f);
   Check("chart change removes old H1",f.mtf==PERIOD_M15 && f.htf==PERIOD_H4);
   ICTMapTimeframes(PERIOD_H4,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f);
   Check("chart change to H4",f.mtf==PERIOD_D1 && f.htf==PERIOD_W1);
   Check("valid manual",ICTMapTimeframes(PERIOD_M5,ICT_MTF_MANUAL,PERIOD_H2,PERIOD_W1,f));
   Check("manual wrong order",!ICTMapTimeframes(PERIOD_H1,ICT_MTF_MANUAL,PERIOD_M15,PERIOD_D1,f));
   Check("manual missing middle",!ICTMapTimeframes(PERIOD_M5,ICT_MTF_MANUAL,PERIOD_CURRENT,PERIOD_D1,f));
   Check("W1 two tier",ICTMapTimeframes(PERIOD_W1,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f) && f.status==ICT_MTF_TWO_TIER);
   Check("MN1 one tier",ICTMapTimeframes(PERIOD_MN1,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,f) && f.status==ICT_MTF_ONE_TIER);
   Check("31-day month",ICTBarClose(PERIOD_MN1,Stamp("2026.01.01"))==Stamp("2026.02.01"));
   Check("leap month",ICTBarClose(PERIOD_MN1,Stamp("2024.02.01"))==Stamp("2024.03.01"));
   Check("28-day month",ICTBarClose(PERIOD_MN1,Stamp("2026.02.01"))==Stamp("2026.03.01"));
   Check("year rollover",ICTBarClose(PERIOD_MN1,Stamp("2026.12.01"))==Stamp("2027.01.01"));
   MqlRates[] months=InitArray<MqlRates>(2); FixtureBar(months[0],Stamp("2026.01.01"),100,101,99,100); FixtureBar(months[1],Stamp("2026.02.01"),100,101,99,100);
   Check("HTF unfinished month excluded",ICTClosedPrefix(months,2,PERIOD_MN1,Stamp("2026.01.31 23:59:59"))==0);
   Check("HTF month available only after close",ICTClosedPrefix(months,2,PERIOD_MN1,Stamp("2026.02.01"))==1);
   Check("aligned BUY matrix",ICTTierAlignment(true,1,1,1)==ICT_TIER_ALIGNED);
   Check("aligned SELL matrix",ICTTierAlignment(true,-1,-1,-1)==ICT_TIER_ALIGNED);
   Check("counter trend WAIT",ICTTierAlignment(true,1,-1,1)==ICT_TIER_CONFLICT);
   Check("neutral no trade",ICTTierAlignment(true,0,1,1)==ICT_TIER_NEUTRAL);
   Check("missing data no trade",ICTTierAlignment(false,1,1,1)==ICT_TIER_INSUFFICIENT);
   Check("independent LTF override remaps automatic upper tiers",ICTResolveTimeframes(PERIOD_M1,true,PERIOD_M5,PERIOD_CURRENT,PERIOD_CURRENT,f) &&
      f.ltf==PERIOD_M5 && f.mtf==PERIOD_H1 && f.htf==PERIOD_D1);
   Check("independent MTF override preserves HTF",ICTResolveTimeframes(PERIOD_M5,true,PERIOD_CURRENT,PERIOD_H4,PERIOD_CURRENT,f) &&
      f.ltf==PERIOD_M5 && f.mtf==PERIOD_H4 && f.htf==PERIOD_D1);
   Check("independent HTF override preserves MTF",ICTResolveTimeframes(PERIOD_M5,true,PERIOD_CURRENT,PERIOD_CURRENT,PERIOD_W1,f) && f.mtf==PERIOD_H1 && f.htf==PERIOD_W1);
   Check("independent invalid ordering rejected",!ICTResolveTimeframes(PERIOD_M5,true,PERIOD_CURRENT,PERIOD_D1,PERIOD_H4,f));
  }
public static void TestUnifiedSMT() {
   MqlRates[] a=InitArray<MqlRates>(0); MqlRates[] b=InitArray<MqlRates>(0); FlatFixture(ref a,90); FlatFixture(ref b,90);
   a[51].high=110; a[65].high=115; b[52].high=112; b[66].high=111;
   SSMTDivergence s=new SSMTDivergence();
   Check("positive bearish mismatched but nearby confirmed pivots",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,1,0.1,0.1,-1,s) && s.direction==-1 && !s.comparator_extreme);
   string id=s.event_id;
   Check("no future right bar",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,67,b,67,2,2,2,1,0.1,0.1,-1,s));
   Check("comparator right bar must close",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,68,b,68,2,2,2,1,0.1,0.1,-1,s));
   Check("confirmed at actual prefix close",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,69,b,69,2,2,2,1,0.1,0.1,-1,s) && s.confirmation_time==ICTBarClose(PERIOD_M5,a[68].time));
   Check("gap outside tolerance rejected",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,0,1,0.1,0.1,-1,s));
   a[65].high=109; b[66].high=115;
   Check("comparator-only source is explicit",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,1,0.1,0.1,-1,s) && s.comparator_extreme);
   FlatFixture(ref a,90); FlatFixture(ref b,90); a[51].low=85; a[65].low=80; b[52].low=84; b[66].low=86;
   Check("positive bullish",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,1,0.1,0.1,1,s));
   FlatFixture(ref a,90); FlatFixture(ref b,90); a[51].high=110; a[65].high=115; b[52].low=85; b[66].low=86;
   Check("inverse HH versus LL",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,-1,0.1,0.1,-1,s));
   FlatFixture(ref a,90); FlatFixture(ref b,90); a[51].low=85; a[65].low=80; b[52].high=110; b[66].high=109;
   Check("inverse LL versus HH",SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,-1,0.1,0.1,1,s));
   b[66].high=115;
   Check("inverse matching extreme is not divergence",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,b,80,2,2,2,-1,0.1,0.1,1,s));
   FlatFixture(ref a,90); FlatFixture(ref b,90); a[51].high=110; a[65].high=115; b[52].high=112; b[66].high=111;
   MqlRates[] missing=InitArray<MqlRates>(0); ArrayResize(ref missing,79);
   for(int i=0;i<79;i++) missing[i]=b[i<60 ? i : i+1];
   Check("missing session bar does not create SMT",!SRMPFindSMTPairFromRates("A","B",PERIOD_M5,a,80,missing,79,2,2,2,1,0.1,0.1,-1,s));
   SICTDynamicSMTConfig c=new SICTDynamicSMTConfig(); ICTDefaultDynamicSMTConfig(c); c.relation=SMT_POSITIVE;
   SICTSMTEvent[] events=InitArray<SICTSMTEvent>(0); bool related=false;
   ICTReplaySMT("A","B",PERIOD_M5,a,80,b,80,0.1,0.1,c,ref events,ref related);
   Check("one evt, not one evt per refresh/bar",ArraySize(events)==1 && !events[0].seed_context);
   long confirmation=(ArraySize(events)>0 ? events[0].signal.confirmation_time : 0);
   string event_id=(ArraySize(events)>0 ? events[0].signal.event_id : "");
   a[85].high=120;
   ICTReplaySMT("A","B",PERIOD_M5,a,90,b,90,0.1,0.1,c,ref events,ref related);
   Check("first confirmation and ID immutable with future suffix",ArraySize(events)>=1 && events[0].signal.confirmation_time==confirmation && events[0].signal.event_id==event_id);
   Check("display includes bar sixty boundary",ICTSMTInsideDisplayWindow(1000,1000,2000));
   Check("display excludes earlier confirmation",!ICTSMTInsideDisplayWindow(999,1000,2000));
   Check("display excludes future confirmation",!ICTSMTInsideDisplayWindow(2001,1000,2000));
   SICTTimeframes map=new SICTTimeframes(); ICTMapTimeframes(PERIOD_M5,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,map);
   int[] frames=InitArray<int>(0);
   Check("AUTO_ALL three distinct frames",ICTSMTTimeframes(map,AUTO_ALL,PERIOD_H1,ref frames)==3 && frames[0]==PERIOD_M5 && frames[1]==PERIOD_H1 && frames[2]==PERIOD_D1);
   Check("AUTO chart override adds independent SMT source",ICTSMTTimeframes(map,AUTO_ALL,PERIOD_H1,ref frames,PERIOD_M1)==4 &&
      frames[0]==PERIOD_M5 && frames[1]==PERIOD_H1 && frames[2]==PERIOD_D1 && frames[3]==PERIOD_M1);
   Check("AUTO chart matching LTF reuses source",ICTSMTTimeframes(map,AUTO_ALL,PERIOD_H1,ref frames,PERIOD_M5)==3);
   Check("MANUAL pins SMT despite chart override",ICTSMTTimeframes(map,SMT_MANUAL,PERIOD_H2,ref frames,PERIOD_M1)==1 && frames[0]==PERIOD_H2);
   Check("AUTO_LTF",ICTSMTTimeframes(map,AUTO_LTF,PERIOD_H1,ref frames)==1 && frames[0]==PERIOD_M5);
   Check("AUTO_MTF",ICTSMTTimeframes(map,AUTO_MTF,PERIOD_H1,ref frames)==1 && frames[0]==PERIOD_H1);
   Check("AUTO_HTF",ICTSMTTimeframes(map,AUTO_HTF,PERIOD_H1,ref frames)==1 && frames[0]==PERIOD_D1);
   Check("MANUAL SMT",ICTSMTTimeframes(map,SMT_MANUAL,PERIOD_H2,ref frames)==1 && frames[0]==PERIOD_H2);
   ICTMapTimeframes(PERIOD_MN1,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,map);
   Check("no fabricated HTF on MN1",ICTSMTTimeframes(map,AUTO_HTF,PERIOD_H1,ref frames)==0);
   FlatFixture(ref a,160); FlatFixture(ref b,160);
   for(int i=0;i<160;i++)
     {
      double close=100+i*0.2+MathSin(i*0.71);
      FixtureBar(a[i],a[i].time,close,close+2,close-2,close);
      FixtureBar(b[i],b[i].time,close*2,close*2+2,close*2-2,close*2);
     }
   double rho=0; int pairs=0;
   Check("positive measured relation",SRMPAlignedCorrelationFromRates(a,160,b,160,60,0,ref rho,ref pairs) && rho>0.999 && pairs==60);
   for(int i=0;i<160;i++) { double close=10000/a[i].close; FixtureBar(b[i],b[i].time,close,close+2,close-2,close); }
   Check("inverse measured relation",SRMPAlignedCorrelationFromRates(a,160,b,160,60,0,ref rho,ref pairs) && rho< -0.999);
   FlatFixture(ref a,160); FlatFixture(ref b,160);
   Check("flat data relation unknown",!SRMPAlignedCorrelationFromRates(a,160,b,160,60,0,ref rho,ref pairs));
  }
public static void OBFixture(ref MqlRates[] bars,int candles) {
   ArrayResize(ref bars,60);
   for(int i=0;i<60;i++)
     { double center=100+4*MathSin(i*0.8)-i*0.03; FixtureBar(bars[i],100000+i*300,center,center+1,center-1,center); }
   int start=53-candles;
   FixtureBar(bars[start-1],bars[start-1].time,98,103,97,102);
   for(int i=start;i<=52;i++)
     { double open=101+(52-i); FixtureBar(bars[i],bars[i].time,open,open+1,i==start ? 90 : 97,open-1); }
   FixtureBar(bars[53],bars[53].time,105,120,104,119);
   FixtureBar(bars[54],bars[54].time,122,125,121,123);
   FixtureBar(bars[55],bars[55].time,111,115,100,111);
   FixtureBar(bars[56],bars[56].time,100,110,95,101);
   FixtureBar(bars[57],bars[57].time,122,125,121,123);
   FixtureBar(bars[58],bars[58].time,111,115,100,111);
   FixtureBar(bars[59],bars[59].time,90,100,88,89);
  }
public static void TestUnifiedStrongOB() {
   SICTStrongOBConfig c=new SICTStrongOBConfig(); ICTDefaultStrongOBConfig(c); c.tolerance_ticks=0;
   MqlRates[] bars=InitArray<MqlRates>(0); MqlRates[] higher=InitArray<MqlRates>(0); SICTStrongOrderBlock z=new SICTStrongOrderBlock();
   for(int group=1;group<=3;group++)
     {
      OBFixture(ref bars,group);
      Check("OB group "+IntegerToString(group),ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z) && z.candles==group && z.ob.lower==90 && z.ob.upper==101);
      Check("OB waits for closed displacement "+IntegerToString(group),!ICTStrongOBAt("TEST",PERIOD_M5,bars,53,52,0.1,c,higher,0,PERIOD_CURRENT,z));
     }
   OBFixture(ref bars,3);
   ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z);
   string stable_id=z.id; long formed=z.ob.formation_time; int frozen=z.confirmation_score;
   Check("OB actual confirmation close",z.ob.confirmation_time==ICTBarClose(PERIOD_M5,bars[53].time));
   ICTAdvanceStrongOB(bars[54],ICTBarClose(PERIOD_M5,bars[54].time),c,0,z);
   Check("fresh after departure",z.life==ICT_OB_ACTIVE && z.touch_count==0);
   ICTAdvanceStrongOB(bars[55],ICTBarClose(PERIOD_M5,bars[55].time),c,0,z);
   Check("first touch partial",z.touch_count==1 && z.life==ICT_OB_PARTIAL && z.mitigation_depth>0 && z.mitigation_depth<0.5);
   ICTAdvanceStrongOB(bars[55],ICTBarClose(PERIOD_M5,bars[55].time),c,0,z);
   Check("same candle never increments touch",z.touch_count==1);
   ICTAdvanceStrongOB(bars[56],ICTBarClose(PERIOD_M5,bars[56].time),c,0,z);
   Check("50 percent mitigation, same touch",z.touch_count==1 && z.life==ICT_OB_MITIGATED && z.mitigation_depth>=0.5);
   ICTAdvanceStrongOB(bars[57],ICTBarClose(PERIOD_M5,bars[57].time),c,0,z);
   ICTAdvanceStrongOB(bars[58],ICTBarClose(PERIOD_M5,bars[58].time),c,0,z);
   Check("second touch after leaving is not sweep two",z.touch_count==2 && z.sweep_count==1);
   ICTAdvanceStrongOB(bars[59],ICTBarClose(PERIOD_M5,bars[59].time),c,0,z);
   Check("invalidation after mitigation",z.life==ICT_OB_INVALIDATED && z.ob.state_time==ICTBarClose(PERIOD_M5,bars[59].time));
   Check("ID, boundaries, formation and score immutable",z.id==stable_id && z.ob.formation_time==formed && z.confirmation_score==frozen && z.ob.lower==90 && z.ob.upper==101);
   SICTStrongOrderBlock score=new SICTStrongOrderBlock(); ZeroMemory(score); score.ob.lower=90; score.ob.upper=101;
   score.ob.liquidity_sweep=true; score.ob.displacement=true; score.ob.break_confirmed=true; score.ob.fvg=true; score.ob.pd_match=true;
   ICTScoreStrongOB(score,true,true,false,true);
   Check("seven scores total 100",score.confirmation_score==100 && score.grade==ICT_OB_STRONG);
   score.ob.fvg=false; ICTScoreStrongOB(score,true,true,false,true);
   Check("optional FVG reduces exactly fifteen",score.confirmation_score==85 && score.grade==ICT_OB_STRONG);
   score.ob.liquidity_sweep=false; score.ob.fvg=true; ICTScoreStrongOB(score,true,true,false,true);
   Check("80 points missing reversal gate is medium",score.confirmation_score==80 && score.grade==ICT_OB_MEDIUM && !score.hard_gates);
   score.continuation=true; ICTScoreStrongOB(score,true,true,false,true);
   Check("continuation separate gates do not require reversal sweep",score.confirmation_score==80 && score.grade==ICT_OB_STRONG && score.hard_gates);
   ICTScoreStrongOB(score,true,true,false,false);
   Check("disabled continuation cannot be strong",score.grade==ICT_OB_MEDIUM && !score.hard_gates);
   OBFixture(ref bars,2); c.bounds=SRMP_OB_FULL;
   Check("full wick group bounds",ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z) && z.ob.lower==90 && z.ob.upper==103);
   c.bounds=SRMP_OB_BODY;
   Check("body bounds",ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z) && z.ob.lower==100 && z.ob.upper==102);
   ICTDefaultStrongOBConfig(c); c.expiry_bars=2; c.tolerance_ticks=0;
   ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z);
   ICTAdvanceStrongOB(bars[54],ICTBarClose(PERIOD_M5,bars[54].time),c,0,z); ICTAdvanceStrongOB(bars[55],ICTBarClose(PERIOD_M5,bars[55].time),c,0,z);
   Check("OB expiry by actual closed bars",z.life==ICT_OB_EXPIRED);
   ICTDefaultStrongOBConfig(c); c.invalidate_on_close=false; c.tolerance_ticks=0;
   ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z);
   MqlRates wick=new MqlRates(); FixtureBar(wick,bars[54].time,105,110,89,105);
   ICTAdvanceStrongOB(wick,ICTBarClose(PERIOD_M5,wick.time),c,0,z);
   Check("wick invalidation",z.life==ICT_OB_INVALIDATED);
   c.invalidate_on_close=true; ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z);
   ICTAdvanceStrongOB(wick,ICTBarClose(PERIOD_M5,wick.time),c,0,z);
   Check("same wick does not invalidate close mode",z.life!=ICT_OB_INVALIDATED);
   OBFixture(ref bars,1); bars[53].open=118; bars[53].close=119;
   Check("ordinary opposing candle is not a strong OB",!ICTStrongOBAt("TEST",PERIOD_M5,bars,54,52,0.1,c,higher,0,PERIOD_CURRENT,z));
  }
public static void SignalFixture(SICTSignalResult s,int direction=1) {
   ZeroMemory(s); s.symbol="TEST"; ICTMapTimeframes(PERIOD_M5,ICT_MTF_AUTO,PERIOD_CURRENT,PERIOD_CURRENT,s.frames);
   s.asof=100300; s.trigger_bar=100000; s.source_event_time=99000;
   s.direction=direction; s.score=100;
   s.data_ready=true; s.htf_pass=true; s.mtf_pass=true; s.ltf_pass=true; s.risk_pass=true;
   s.entry=100; s.stop=direction>0 ? 95 : 105; s.tp1=direction>0 ? 115 : 85; s.rr=3;
   s.target_pool_id=direction>0 ? "BSL" : "SSL"; s.source_pool_id=direction>0 ? "SSL" : "BSL";
   s.htf_reason="HTF bias"; s.mtf_reason="MTF setup"; s.ltf_reason="LTF trigger";
  }
public static void TestUnifiedSignals() {
   SICTSignalResult s=new SICTSignalResult();
   SignalFixture(s); Check("closed BUY confirms all hard gates",ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_BUY_CONFIRMED && s.confirmation_time==s.asof);
   SignalFixture(s,-1); Check("closed SELL mirrors BUY",ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_SELL_CONFIRMED);
   SignalFixture(s); s.htf_pass=false; Check("100 points cannot bypass HTF",!ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_NO_TRADE);
   SignalFixture(s); s.mtf_pass=false; Check("100 points cannot bypass MTF",!ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_NO_TRADE);
   SignalFixture(s); s.ltf_pass=false; Check("100 points without trigger is WATCH only",!ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_WATCH_BUY && !s.confirmed);
   SignalFixture(s); s.data_ready=false; Check("missing data cannot confirm",!ICTEvaluateSignal(s,2) && s.state==ICT_SIGNAL_NO_TRADE);
   SignalFixture(s); s.frames.status=ICT_MTF_TWO_TIER; Check("reduced tier never confirms",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.asof=s.trigger_bar; Check("forming LTF never confirms",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.source_event_time=s.asof+1; Check("future source evt rejected",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.smt_required=true; Check("required missing SMT veto",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.smt_required=false; Check("optional missing SMT does not veto",ICTEvaluateSignal(s,2));
   SignalFixture(s); s.smt_required=true; s.smt_pass=true; Check("required aligned SMT passes",ICTEvaluateSignal(s,2));
   SignalFixture(s); s.target_pool_id=""; Check("no invented target",!ICTEvaluateSignal(s,2) && s.reason=="TARGET UNAVAILABLE");
   SignalFixture(s); s.stop=101; Check("invalid BUY stop rejected",!ICTEvaluateSignal(s,2));
   SignalFixture(s,-1); s.tp1=115; Check("invalid SELL target rejected",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.rr=1.99; Check("net RR below two veto",!ICTEvaluateSignal(s,2));
   SignalFixture(s); s.rr=2.5; Check("higher existing RR threshold preserved",!ICTEvaluateSignal(s,3));
   SignalFixture(s); s.risk_pass=false; Check("risk manager veto cannot be scored away",!ICTEvaluateSignal(s,2));
   SICTSignalResult original=new SICTSignalResult(); SICTSignalResult changed=new SICTSignalResult(); SICTSignalResult opposite=new SICTSignalResult();
   SignalFixture(original); ICTEvaluateSignal(original,2);
   SICTSignalResult[] history=InitArray<SICTSignalResult>(0);
   Check("confirmation stored once",ICTMergeConfirmedSignal(original,ref history,60) && ArraySize(history)==1);
   SignalFixture(changed); changed.entry=101; changed.rr=2; ICTEvaluateSignal(changed,2);
   Check("later prices cannot repaint committed candle",!ICTMergeConfirmedSignal(changed,ref history,60) && history[0].entry==100);
   SignalFixture(opposite,-1); ICTEvaluateSignal(opposite,2);
   Check("opposite side cannot replace same candle",!ICTMergeConfirmedSignal(opposite,ref history,60) && history[0].direction==1);
   Check("oldest closed candle retained inclusive",ICTSignalInsideWindow(original,original.trigger_bar,original.asof));
   Check("sixty-first older candle excluded",!ICTSignalInsideWindow(original,original.trigger_bar+300,original.asof));
   Check("future confirmation excluded from history",!ICTSignalInsideWindow(original,original.trigger_bar,original.asof-1));
   SignalFixture(s); s.tp1=101; Check("claimed RR cannot exceed actual plan geometry",!ICTEvaluateSignal(s,2));
  }

public static void TestCausalReactions(int direction) {
   MqlRates bar=new MqlRates();
   LiquidityFixtureBar(bar,100000,104,112,103,110,direction);
   double lower=(direction>0 ? 100 : 90),upper=(direction>0 ? 110 : 100);
   Check("closed zone reaction after prior structure "+IntegerToString(direction),
      ICTClosedZoneReaction(bar,100300,direction,lower,upper,99000,99700));
   Check("future zone cannot confirm reaction "+IntegerToString(direction),
      !ICTClosedZoneReaction(bar,100300,direction,lower,upper,100001,99700));
   Check("future structure cannot confirm reaction "+IntegerToString(direction),
      !ICTClosedZoneReaction(bar,100300,direction,lower,upper,99000,100001));
   Check("unclosed reaction rejected "+IntegerToString(direction),
      !ICTClosedZoneReaction(bar,100000,direction,lower,upper,99000,99700));
   Check("range reaction can follow displacement on an earlier bar "+IntegerToString(direction),
      ICTClosedRangeReaction(bar,100300,direction,99000,99700,100300,true,true));
   Check("range reaction without displacement rejected "+IntegerToString(direction),
      !ICTClosedRangeReaction(bar,100300,direction,99000,99700,100300,true,false));
   Check("range reaction without a valid setup rejected "+IntegerToString(direction),
      !ICTClosedRangeReaction(bar,100300,direction,99000,99700,100300,false,true));
   Check("old reaction not reissued on a later candle "+IntegerToString(direction),
      !ICTClosedRangeReaction(bar,100600,direction,99000,99700,100300,true,true));
   Check("saved MTF break survives a later quiet candle "+IntegerToString(direction),
      ICTMTFStructureReady(true,direction,0,direction,true,99700,100300));
   Check("opposite MTF break vetoes saved setup "+IntegerToString(direction),
      !ICTMTFStructureReady(true,direction,-direction,direction,true,99700,100300));
   Check("future MTF evt cannot confirm setup "+IntegerToString(direction),
      !ICTMTFStructureReady(true,direction,0,direction,true,100301,100300));
   Check("legacy still requires its current MTF break "+IntegerToString(direction),
      !ICTMTFStructureReady(false,direction,0,direction,true,99700,100300));
   if(direction>0) bar.low=lower; else bar.high=upper;
   Check("fully traversed zone rejected "+IntegerToString(direction),
      !ICTClosedZoneReaction(bar,100300,direction,lower,upper,99000,99700));
  }

public static void TestSameBarSignalJournal() {
   SICTSignalResult previous=new SICTSignalResult(); SICTSignalResult current=new SICTSignalResult();
   SignalFixture(previous); previous.state=ICT_SIGNAL_NO_TRADE; previous.confirmed=false;
   previous.risk_pass=false; previous.confirmation_time=0;
   SignalFixture(current); current.state=ICT_SIGNAL_WATCH_BUY; current.confirmed=false;
   Check("same bar allows an updated unconfirmed observation",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_REFRESH_UNCONFIRMED);
   SignalFixture(current); ICTEvaluateSignal(current,2);
   Check("risk recovery allows same-bar confirmation with all gates",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_COMMIT_CONFIRMED);
   current.risk_pass=false;
   Check("same-bar promotion cannot bypass risk",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_CONFLICT);
   SignalFixture(current); ICTEvaluateSignal(current,2); current.trigger_bar++;
   Check("different candle cannot replace current journal row",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_CONFLICT);
   SignalFixture(previous); ICTEvaluateSignal(previous,2);
   SignalFixture(current,-1); ICTEvaluateSignal(current,2);
   Check("confirmed candle is immutable even for opposite later evidence",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_KEEP_CONFIRMED);
   current.symbol="OTHER";
   Check("different symbol cannot reuse a confirmed record",
      ICTSignalSameBarAction(previous,current)==ICT_BAR_CONFLICT);
  }
public static void TestUnifiedPeerStates() {
   SICTDynamicSMTConfig c=new SICTDynamicSMTConfig(); ICTDefaultDynamicSMTConfig(c); c.relation=SMT_POSITIVE; c.relation2=SMT_NEGATIVE;
   Check("peer one inherits legacy positive",ICTSMTPeerRelation(c,0)==SMT_POSITIVE);
   Check("peer two independent inverse",ICTSMTPeerRelation(c,1)==SMT_NEGATIVE);
   SICTSMTPeerSnapshot peer=new SICTSMTPeerSnapshot(); ICTResetSMTPeer("PEER1","DATA INSUFFICIENT",peer);
   SICTSMTEvent[] events=InitArray<SICTSMTEvent>(2);
   for(int i=0;i<2;i++)
     {
      ZeroMemory(events[i]); events[i].life=ICT_SMT_CONFIRMED;
      events[i].signal.comparison="PEER1"; events[i].signal.timeframe=PERIOD_M5;
      events[i].signal.relation=1; events[i].signal.confirmation_time=100300+i*300;
      events[i].signal.primary_pivot_time=99000; events[i].signal.primary_recent=100;
      events[i].signal.event_id="P"+IntegerToString(i); events[i].signal.direction=i==0 ? 1 : -1;
     }
   ICTSummarizeSMTPeer(events,1,PERIOD_M5,100600,100000,peer);
   Check("missing peer remains NA despite historical evt",peer.state==ICT_SMT_PEER_NA);
   peer.ready=true; peer.relation_known=true; peer.relation=1; peer.last_close=100600;
   ICTSummarizeSMTPeer(events,1,PERIOD_M5,100600,100000,peer);
   Check("qualified peer bullish",peer.state==ICT_SMT_PEER_BULLISH && peer.confirmation_time==100300);
   ICTSummarizeSMTPeer(events,2,PERIOD_M5,100600,100000,peer);
   Check("opposed peer events never green confluence",peer.conflict && peer.state==ICT_SMT_PEER_NONE);
   peer.comparison="OTHER";
   ICTSummarizeSMTPeer(events,2,PERIOD_M5,100600,100000,peer);
   Check("old comparator events cannot leak after mapping change",peer.state==ICT_SMT_PEER_NONE);
   peer.comparison="PEER1"; peer.relation=-1;
   Check("wrong relation cannot supply current evidence",!ICTSMTPeerEventUsable(events[0],PERIOD_M5,100600,100000,peer));
   peer.relation=1;
   Check("future SMT evt unavailable",!ICTSMTPeerEventUsable(events[1],PERIOD_M5,100300,100000,peer));
   Check("wrong source timeframe unavailable",!ICTSMTPeerEventUsable(events[0],PERIOD_H1,100600,100000,peer));
   events[0].life=ICT_SMT_INVALIDATED;
   ICTSummarizeSMTPeer(events,1,PERIOD_M5,100600,100000,peer);
   Check("invalidated SMT keeps confirmation metadata without live points",peer.state==ICT_SMT_PEER_NONE && peer.confirmation_time==100300);
  }
public static void TestUnifiedOBQuality() {
   SICTStrongOBConfig c=new SICTStrongOBConfig(); ICTDefaultStrongOBConfig(c);
   SICTStrongOrderBlock z=new SICTStrongOrderBlock(); ZeroMemory(z); z.ob.lower=90; z.ob.upper=100;
   z.ob.liquidity_sweep=true; z.ob.displacement=true; z.ob.break_confirmed=true; z.ob.fvg=true; z.ob.pd_match=true;
   ICTScoreStrongOBWithConfig(z,true,true,c); z.life=ICT_OB_ACTIVE;
   Check("default configured OB weights valid",ICTValidStrongOBConfig(c) && z.confirmation_score==100);
   z.touch_count=1; z.life=ICT_OB_PARTIAL; ICTRefreshOBQuality(z,c);
   Check("touched OB loses freshness but frozen score remains",z.confirmation_score==100 && z.current_context_score==95 && z.grade!=ICT_OB_STRONG);
   z.touch_count=3; ICTRefreshOBQuality(z,c);
   Check("repeat touches lower current quality",z.current_context_score==85 && z.confirmation_score==100);
   z.life=ICT_OB_INVALIDATED; ICTRefreshOBQuality(z,c);
   Check("invalidated OB is never STRONG",z.current_context_score==0 && z.grade!=ICT_OB_STRONG && z.confirmation_grade==ICT_OB_STRONG);
   c.weight_sweep=25; Check("invalid OB weight total rejected",!ICTValidStrongOBConfig(c));
   c.weight_fvg=10; Check("alternative OB weights sum 100",ICTValidStrongOBConfig(c));
   z.ob.fvg=false; ICTScoreStrongOBWithConfig(z,true,true,c);
   Check("configured FVG weight applied",z.confirmation_score==90);
  }
public static void LiquidityFixtureBar(MqlRates bar,long time,double open,double high,double low,double close,int side) {
   if(side>0) FixtureBar(bar,time,open,high,low,close);
   else FixtureBar(bar,time,200-open,200-low,200-high,200-close);
  }
public static void TestUnifiedLiquidity(int side) {
   SICTRangeConfig c=new SICTRangeConfig(); ICTDefaultRangeConfig(c); c.breakout_displacement_confirms=false;
   c.retest_tolerance_ticks=1; c.retest_tolerance_atr=0; c.retest_close_buffer_ticks=1;
   SICTRangeLevel pool=new SICTRangeLevel(); ZeroMemory(pool); pool.id="POOL"; pool.range_id="RANGE";
   pool.price=100; pool.side=side; pool.available_at=1000; pool.timeframe=PERIOD_H1; pool.membership=IR_INTERNAL;
   MqlRates bar=new MqlRates();
   LiquidityFixtureBar(bar,1000,99,105,98,104,side);
   ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   Check("liquidity outside close is not breakout "+IntegerToString(side),pool.candidate && pool.last_event==IR_EVENT_NONE);
   LiquidityFixtureBar(bar,1300,104,106,103,105,side);
   ICTRangeAdvanceLevelConfigured(bar,1600,1,5,false,c,1,0,pool);
   Check("liquidity two closed holds confirm breakout "+IntegerToString(side),pool.state==IR_BREAKOUT && pool.last_event==IR_EVENT_BREAKOUT_CONFIRMED);
   SICTRangeSnapshot snapshot=new SICTRangeSnapshot(); ZeroMemory(snapshot); snapshot.as_of=1600; snapshot.ltf=PERIOD_M5;
   snapshot.liquidity_display_start=1000;
   ICTRangeRecordLiquidityEvent(snapshot,pool); ICTRangeRecordLiquidityEvent(snapshot,pool);
   Check("liquidity evt committed once "+IntegerToString(side),snapshot.liquidity_event_count==1);
   LiquidityFixtureBar(bar,1600,100.5,104,99,103,side);
   ICTRangeAdvanceLevelConfigured(bar,1900,1,5,false,c,1,0,pool);
   Check("liquidity retest needs later hold "+IntegerToString(side),pool.last_event==IR_EVENT_RETEST_CONFIRMED && pool.breakout_at==1600 && pool.state==IR_BREAKOUT);
   snapshot.as_of=1900; ICTRangeRecordLiquidityEvent(snapshot,pool);
   Check("retest does not repaint breakout "+IntegerToString(side),snapshot.liquidity_event_count==2 && snapshot.liquidity_events[0].type==IR_EVENT_BREAKOUT_CONFIRMED && snapshot.liquidity_events[0].confirmed_at==1600);
   LiquidityFixtureBar(bar,1900,103,104,97,98,side);
   ICTRangeAdvanceLevelConfigured(bar,2200,1,5,false,c,1,0,pool);
   Check("liquidity explicit false breakout "+IntegerToString(side),pool.last_event==IR_EVENT_FALSE_BREAKOUT && pool.state==IR_CONSUMED);
   snapshot.as_of=2200; ICTRangeRecordLiquidityEvent(snapshot,pool);
   ICTRangeAdvanceLevelConfigured(bar,2200,1,5,false,c,1,0,pool); ICTRangeRecordLiquidityEvent(snapshot,pool);
   Check("duplicate false breakout does not count twice "+IntegerToString(side),snapshot.liquidity_event_count==3);
   LiquidityFixtureBar(bar,2200,99,104,98,99,side);
   ICTRangeAdvanceLevelConfigured(bar,2500,1,5,false,c,1,0,pool);
   Check("consumed pool cannot become fresh again "+IntegerToString(side),pool.state==IR_CONSUMED && pool.event_at==2200);
   ZeroMemory(pool); pool.id="SWEEP"; pool.price=100; pool.side=side; pool.available_at=1000;
   LiquidityFixtureBar(bar,1000,99,104,98,99,side);
   ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   Check("wick reclaim distinct from outside-close failure "+IntegerToString(side),pool.last_event==IR_EVENT_LIQUIDITY_SWEEP && pool.sweep_count==1);
   ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   Check("same sweep bar never recounted "+IntegerToString(side),pool.sweep_count==1);
   LiquidityFixtureBar(bar,1300,98,99,95,96,side); ICTRangeAdvanceLevelConfigured(bar,1600,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1600,97,99,95,96,side); ICTRangeAdvanceLevelConfigured(bar,1900,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1900,99,104,98,99,side); ICTRangeAdvanceLevelConfigured(bar,2200,1,5,false,c,1,0,pool);
   Check("separated second sweep same pool "+IntegerToString(side),pool.sweep_count==2 && pool.last_event==IR_EVENT_LIQUIDITY_SWEEP);

   ZeroMemory(pool); pool.id="LATE"; pool.price=100; pool.side=side; pool.available_at=1000;
   c.sweep_validation_bars=3;
   LiquidityFixtureBar(bar,1000,99,105,98,104,side); ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1300,100.5,101,100,100.5,side); ICTRangeAdvanceLevelConfigured(bar,1600,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1600,100.5,101,100,100.5,side); ICTRangeAdvanceLevelConfigured(bar,1900,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1900,100.5,101,98,99,side); ICTRangeAdvanceLevelConfigured(bar,2200,1,5,false,c,1,0,pool);
   Check("late reclaim cannot become a reversal "+IntegerToString(side),
      pool.state==IR_LEVEL_INVALIDATED && pool.last_event==IR_EVENT_NONE);

   ZeroMemory(pool); pool.id="ON_TIME"; pool.price=100; pool.side=side; pool.available_at=1000;
   LiquidityFixtureBar(bar,1000,99,105,98,104,side); ICTRangeAdvanceLevelConfigured(bar,1300,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1300,100.5,101,100,100.5,side); ICTRangeAdvanceLevelConfigured(bar,1600,1,5,false,c,1,0,pool);
   LiquidityFixtureBar(bar,1600,100.5,101,98,99,side); ICTRangeAdvanceLevelConfigured(bar,1900,1,5,false,c,1,0,pool);
   Check("reclaim at configured window remains valid "+IntegerToString(side),
      pool.state==IR_SWEPT && pool.last_event==IR_EVENT_FALSE_BREAKOUT);
  }

public static void TestLiquidityHistorySeed(int side) {
   SICTRangeConfig c=new SICTRangeConfig(); ICTDefaultRangeConfig(c); c.penetration_ticks=1; c.penetration_atr=0;
   c.breakout_displacement_confirms=false;
   MqlRates[] bars=InitArray<MqlRates>(24);
   for(int i=0;i<24;i++) LiquidityFixtureBar(bars[i],1000+i*300,95,97,94,96,side);
   LiquidityFixtureBar(bars[5],2500,96,103,94,99,side);

   LiquidityFixtureBar(bars[10],4000,99,104,98,103,side);
   LiquidityFixtureBar(bars[11],4300,103,105,102,104,side);
   SICTRangeLevel pool=new SICTRangeLevel(); ZeroMemory(pool); pool.id="OLD_POOL"; pool.range_id="R";
   pool.price=100; pool.side=side; pool.available_at=1600; pool.timeframe=PERIOD_H1;
   SICTSweepSequence sequence=new SICTSweepSequence(); ICTSweepSequenceStart(sequence,pool.id,side,pool.price,pool.available_at);
   SICTRangeSnapshot snapshot=new SICTRangeSnapshot(); ZeroMemory(snapshot); snapshot.as_of=3700; snapshot.ltf=PERIOD_M5;
   snapshot.liquidity_display_start=1000;
   Check("older pool seeded with complete closed history "+IntegerToString(side),
      ICTRangeSeedLevel(pool,sequence,true,bars,24,3700,c,1,snapshot,true));
   Check("prior sweep retained; future suffix ignored "+IntegerToString(side),
      pool.state==IR_SWEPT && pool.sweep_count==1 && pool.event_at==2800 &&
      sequence.count==1 && sequence.events[0].status==ICT_SWEEP_CONFIRMED);
   Check("seed observation stored once "+IntegerToString(side),snapshot.liquidity_event_count==1);
   SICTRangeLevel before_range=new SICTRangeLevel(); ZeroMemory(before_range); before_range.id="EARLIER";
   before_range.range_id="R"; before_range.price=100; before_range.side=side;
   before_range.available_at=1600; before_range.timeframe=PERIOD_H1;
   SICTSweepSequence earlier=new SICTSweepSequence(); ZeroMemory(earlier);
   SICTRangeSnapshot later_range=new SICTRangeSnapshot(); ZeroMemory(later_range); later_range.as_of=3700;
   later_range.ltf=PERIOD_M5; later_range.liquidity_display_start=1000;
   later_range.range.confirmed_at=3000;
   Check("pre-range events still update the pool lifecycle "+IntegerToString(side),
      ICTRangeSeedLevel(before_range,earlier,false,bars,24,3700,c,1,later_range,true) &&
      before_range.state==IR_SWEPT && before_range.sweep_count==1);
   Check("no evt is attributed to a range before its confirmation "+IntegerToString(side),
      later_range.liquidity_event_count==0);
   SICTRangeLevel missing=new SICTRangeLevel(); ZeroMemory(missing); missing.id="MISSING"; missing.price=100;
   missing.side=side; missing.available_at=999;
   SICTSweepSequence other=new SICTSweepSequence(); ZeroMemory(other);
   Check("uncovered pool cannot be assumed fresh "+IntegerToString(side),
      !ICTRangeSeedLevel(missing,other,false,bars,24,3700,c,1,snapshot,false));
  }
public static void TestAdaptiveEqualityTolerance() {
   SICTRangeConfig c=new SICTRangeConfig(); ICTDefaultRangeConfig(c);
   c.equal_ticks=3; c.equal_atr=0.1; c.equal_spread=2;
   Check("equal tolerance uses minimum ticks",ICTRangeEqualTolerance(0.1,1,0.05,c)>=0.3-1e-9);
   Check("equal tolerance uses ATR",MathAbs(ICTRangeEqualTolerance(0.1,10,0.05,c)-1)<1e-9);
   Check("equal tolerance uses historical spread price",MathAbs(ICTRangeEqualTolerance(0.1,1,0.4,c)-0.8)<1e-9);
   Check("invalid spread cannot silently lower tolerance",ICTRangeEqualTolerance(0.1,1,-1,c)<0);
   c.liquidity_seed_bars=79; c.lookback=80;
   Check("seed history cannot be shorter than structural history",!ICTValidRangeConfig(c));
  }
public static void TestTargetAvailability() {
   MqlRates bar=new MqlRates(); FixtureBar(bar,100000,100,105,95,101);
   Check("BUY exit quote still below target",ICTRangeLiveTargetSafe(1,104,104.2,105));
   Check("BUY exit quote at target is not actionable",!ICTRangeLiveTargetSafe(1,105,105.2,105));
   Check("SELL exit quote still above target",ICTRangeLiveTargetSafe(-1,95.8,96,95));
   Check("SELL exit quote at target is not actionable",!ICTRangeLiveTargetSafe(-1,94.8,95,95));
   Check("missing or inverted quote fails closed",!ICTRangeLiveTargetSafe(1,100,99,110));
   Check("reaction candle touching BUY target is ambiguous",!ICTRangeReactionTargetSafe(1,bar,105));
   Check("reaction candle touching SELL target is ambiguous",!ICTRangeReactionTargetSafe(-1,bar,95));
   Check("BUY target beyond reaction candle is unambiguous",ICTRangeReactionTargetSafe(1,bar,106));
   Check("SELL target beyond reaction candle is unambiguous",ICTRangeReactionTargetSafe(-1,bar,94));
  }
public static void TestSMTDiagnosticCore() {
   SICTUnifiedSnapshot s=new SICTUnifiedSnapshot(); ZeroMemory(s); s.valid=true; s.asof=100300; s.layer_count=1;
   s.layers[0].last_close=s.asof; s.comparison1="PEER1";
   s.layers[0].peers[0].comparison="PEER1"; s.layers[0].peers[1].reason="DISABLED";
   Check("SMT diagnostic unavailable",StringFind(ICTUnifiedSMTDiagnostic(s,1),"UNAVAILABLE:")==0);
   s.layers[0].peers[0].ready=true; s.layers[0].peers[0].relation_known=true;
   s.layers[0].peers[0].last_close=s.asof; s.layers[0].peers[0].state=ICT_SMT_PEER_NONE;
   Check("SMT diagnostic none",StringFind(ICTUnifiedSMTDiagnostic(s,1),"NONE:")==0);
   s.layers[0].peers[0].state=ICT_SMT_PEER_BULLISH;
   Check("SMT diagnostic aligned matches gate",StringFind(ICTUnifiedSMTDiagnostic(s,1),"ALIGNED:")==0 && ICTUnifiedSMTAligned(s,1));
   Check("SMT diagnostic opposite matches gate",StringFind(ICTUnifiedSMTDiagnostic(s,-1),"OPPOSITE:")==0 && !ICTUnifiedSMTAligned(s,-1));
   s.layers[0].peers[0].conflict=true;
   Check("SMT diagnostic conflict matches veto",StringFind(ICTUnifiedSMTDiagnostic(s,1),"CONFLICT:")==0 && !ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[0].conflict=false; s.layers[0].peers[0].last_close--;
   Check("SMT diagnostic stale peer unavailable",StringFind(ICTUnifiedSMTDiagnostic(s,1),"UNAVAILABLE:")==0 && !ICTUnifiedSMTAligned(s,1));
  }
public static void RunUnifiedCoreFixtures() { TestUnifiedMappingCalendar(); TestUnifiedSMT(); TestUnifiedStrongOB(); TestUnifiedSignals(); TestSameBarSignalJournal();
      TestCausalReactions(1); TestCausalReactions(-1); TestUnifiedPeerStates(); TestUnifiedOBQuality();
    TestUnifiedLiquidity(1); TestUnifiedLiquidity(-1); TestLiquidityHistorySeed(1); TestLiquidityHistorySeed(-1);
    TestAdaptiveEqualityTolerance(); TestTargetAvailability(); TestICTConfluenceLifecycle(); TestICTSessionLiquidity(); TestSMTDiagnosticCore(); TestICTSignalJournalLive();
    TestLivePositionRisk(); TestLivePositionRiskDisplay(); }







public static void TestICTConfluenceLifecycle() {
   SICTRangeSnapshot s=new SICTRangeSnapshot(); ZeroMemory(s);
   s.range.valid=true; s.range.id="R1"; s.as_of=2000; s.zone_count=2;
   s.zones[0].range_id="R1"; s.zones[1].range_id="R1";
   s.zones[0].membership=IR_INTERNAL; s.zones[1].membership=IR_INTERNAL;
   s.zones[0].type=IR_FVG; s.zones[1].type=IR_OB;
   s.zones[0].state=IR_FRESH; s.zones[1].state=IR_TOUCHED;
   s.zones[0].direction=1; s.zones[1].direction=1;
   s.zones[0].confirmed_at=1000; s.zones[1].confirmed_at=1500;
   s.zones[0].lower=100; s.zones[0].upper=105;
   s.zones[1].lower=103; s.zones[1].upper=108;
   ICTRangeUpdateZoneConfluence(s);
   Check("fresh/touched overlapping pair marks both zones",s.zones[0].confluence && s.zones[1].confluence);

   s.zones[0].state=IR_MITIGATED; ICTRangeUpdateZoneConfluence(s);
   Check("mitigated first zone clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[0].state=IR_FRESH; s.zones[1].state=IR_ZONE_INVALIDATED; ICTRangeUpdateZoneConfluence(s);
   Check("invalidated second zone clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].state=IR_FRESH; s.zones[1].range_id="R2"; ICTRangeUpdateZoneConfluence(s);
   Check("foreign range clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].range_id="R1"; s.zones[0].membership=IR_CROSSING; ICTRangeUpdateZoneConfluence(s);
   Check("non-internal first zone clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[0].membership=IR_INTERNAL; s.zones[1].membership=IR_OUTSIDE; ICTRangeUpdateZoneConfluence(s);
   Check("non-internal second zone clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].membership=IR_INTERNAL; s.zones[1].confirmed_at=2001; ICTRangeUpdateZoneConfluence(s);
   Check("future confirmation clears both",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].confirmed_at=1500; s.zones[1].direction=-1; ICTRangeUpdateZoneConfluence(s);
   Check("opposite directions do not combine",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].direction=1; s.zones[1].lower=106; ICTRangeUpdateZoneConfluence(s);
   Check("separate zones do not combine",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].lower=103; s.zones[1].type=IR_FVG; ICTRangeUpdateZoneConfluence(s);
   Check("same type zones do not combine",!s.zones[0].confluence && !s.zones[1].confluence);
   s.zones[1].type=IR_OB; s.zones[0].direction=-1; s.zones[1].direction=-1;
   ICTRangeUpdateZoneConfluence(s);
   Check("sell pair marks both zones",s.zones[0].confluence && s.zones[1].confluence);
   s.range.valid=false; ICTRangeUpdateZoneConfluence(s);
   Check("invalid owning range clears both",!s.zones[0].confluence && !s.zones[1].confluence);
  }








public static void ICTSessionFixtureBar(MqlRates bar,long wall,double high,double low) {
   ZeroMemory(bar);
   bar.time=wall; bar.high=high; bar.low=low; bar.open=(high+low)/2; bar.close=bar.open;
  }

public static void TestICTSessionLiquidity() {
   SICTSessionOffset[] local=InitArray<SICTSessionOffset>(0); SICTSessionOffset[] broker=InitArray<SICTSessionOffset>(0);
   ArrayResize(ref local,1); ArrayResize(ref broker,1);
   local[0].from_utc=Stamp("2026.01.01"); local[0].to_utc=Stamp("2027.01.01"); local[0].minutes_east=0;
   broker[0].from_utc=local[0].from_utc; broker[0].to_utc=local[0].to_utc; broker[0].minutes_east=120;
   SICTSessionDefinition d=new SICTSessionDefinition(); d.kind=ICT_SESSION_ASIA; d.start_minute=22*60; d.end_minute=2*60;
   MqlRates[] bars=InitArray<MqlRates>(0); ArrayResize(ref bars,5);
   ICTSessionFixtureBar(bars[0],Stamp("2026.06.02 00:00"),101,90);
   ICTSessionFixtureBar(bars[1],Stamp("2026.06.02 01:00"),103,91);
   ICTSessionFixtureBar(bars[2],Stamp("2026.06.02 02:00"),102,88);
   ICTSessionFixtureBar(bars[3],Stamp("2026.06.02 03:00"),100,89);
   ICTSessionFixtureBar(bars[4],Stamp("2026.06.02 04:00"),999,1);
   SICTSessionLiquidity result=new SICTSessionLiquidity();
   Check("Asia crossing midnight, broker UTC+2 and closed bars",
      ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.02 02:00"),result) &&
      result.status==ICT_SESSION_READY && result.high==103 && result.low==88 && result.bar_count==4 &&
      result.start_utc==Stamp("2026.06.01 22:00") && result.confirmed_utc==Stamp("2026.06.02 02:00"));
   Check("session not confirmed one second before end",
      !ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.02 01:59:59"),result) &&
      result.status==ICT_SESSION_NOT_CLOSED);
   bars[4].time=Stamp("2028.06.02 04:00");
   Check("future suffix outside offset schedule cannot change confirmed result",
      ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.02 02:00"),result) &&
      result.high==103 && result.low==88);
   bars[1].time=bars[0].time;
   Check("duplicate slot rejected",!ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.02 02:00"),result) &&
      result.status==ICT_SESSION_INCOMPLETE_DATA);
   bars[1].time=Stamp("2026.06.02 05:00");
   Check("missing slot rejected",!ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.02 02:00"),result) &&
      result.status==ICT_SESSION_INCOMPLETE_DATA && result.high==0 && result.low==0 && result.bar_count==0);
   bars[1].time=Stamp("2026.06.02 01:00"); bars[1].low=0;
   Check("invalid OHLC rejected",!ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.02 02:00"),result) &&
      result.status==ICT_SESSION_INVALID_BAR);
   bars[1].low=91;
   bars[1].open=bars[1].high+1;
   Check("invalid candle open rejected",!ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.02 02:00"),result) &&
      result.status==ICT_SESSION_INVALID_BAR);
   bars[1].open=(bars[1].high+bars[1].low)/2;
   Check("incompatible timeframe rejected",!ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,5400,Stamp("2026.06.02 02:00"),result) &&
      result.status==ICT_SESSION_BAD_CONFIG);
   broker[0].to_utc=Stamp("2026.06.02 00:00");
   Check("broker offset coverage required",!ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.02 02:00"),result));
   broker[0].to_utc=Stamp("2027.01.01"); broker[0].minutes_east=0;
   local[0].minutes_east=60;
   d.kind=ICT_SESSION_LONDON; d.start_minute=8*60; d.end_minute=10*60;
   ArrayResize(ref bars,2);
   ICTSessionFixtureBar(bars[0],Stamp("2026.06.01 07:00"),104,90);
   ICTSessionFixtureBar(bars[1],Stamp("2026.06.01 08:00"),101,87);
   Check("London local daylight offset mapped independently from broker",
      ICTBuildSessionLiquidity(d,Stamp("2026.06.01"),local,broker,bars,3600,Stamp("2026.06.01 09:00"),result) &&
      result.kind==ICT_SESSION_LONDON && result.high==104 && result.low==87);


   ArrayResize(ref local,2);
   local[0].from_utc=Stamp("2026.01.01"); local[0].to_utc=Stamp("2026.03.08 07:00"); local[0].minutes_east=-300;
   local[1].from_utc=local[0].to_utc; local[1].to_utc=Stamp("2027.01.01"); local[1].minutes_east=-240;
   d.kind=ICT_SESSION_NEW_YORK; d.start_minute=0; d.end_minute=4*60;
   ArrayResize(ref bars,3);
   ICTSessionFixtureBar(bars[0],Stamp("2026.03.08 05:00"),101,90);
   ICTSessionFixtureBar(bars[1],Stamp("2026.03.08 06:00"),105,91);
   ICTSessionFixtureBar(bars[2],Stamp("2026.03.08 07:00"),102,89);
   Check("spring DST changes session elapsed duration",
      ICTBuildSessionLiquidity(d,Stamp("2026.03.08"),local,broker,bars,3600,Stamp("2026.03.08 08:00"),result) &&
      result.start_utc==Stamp("2026.03.08 05:00") && result.end_utc==Stamp("2026.03.08 08:00") && result.high==105 && result.bar_count==3);
   d.start_minute=2*60+30;
   Check("spring nonexistent local boundary rejected",
      !ICTBuildSessionLiquidity(d,Stamp("2026.03.08"),local,broker,bars,1800,Stamp("2026.03.08 09:00"),result) &&
      result.status==ICT_SESSION_AMBIGUOUS_TIME);


   local[0].to_utc=Stamp("2026.11.01 06:00"); local[0].minutes_east=-240;
   local[1].from_utc=local[0].to_utc; local[1].minutes_east=-300;
   d.start_minute=0; d.end_minute=4*60;
   ArrayResize(ref bars,5);
   for(int i=0;i<5;i++) ICTSessionFixtureBar(bars[i],Stamp("2026.11.01 04:00")+i*3600,100+i,90-i);
   Check("fall DST includes repeated hour once in UTC",
      ICTBuildSessionLiquidity(d,Stamp("2026.11.01"),local,broker,bars,3600,Stamp("2026.11.01 09:00"),result) &&
      result.bar_count==5 && result.low==86 && result.end_utc==Stamp("2026.11.01 09:00"));
   d.start_minute=90;
   Check("fall repeated local boundary rejected",
      !ICTBuildSessionLiquidity(d,Stamp("2026.11.01"),local,broker,bars,1800,Stamp("2026.11.01 09:00"),result) &&
      result.status==ICT_SESSION_AMBIGUOUS_TIME);
   d.start_minute=0; ArrayResize(ref broker,2);
   broker[0].from_utc=local[0].from_utc; broker[0].to_utc=local[0].to_utc; broker[0].minutes_east=local[0].minutes_east;
   broker[1].from_utc=local[1].from_utc; broker[1].to_utc=local[1].to_utc; broker[1].minutes_east=local[1].minutes_east;
   ICTSessionFixtureBar(bars[0],Stamp("2026.11.01 01:00"),101,90);
   Check("ambiguous broker timestamp rejected",
      !ICTBuildSessionLiquidity(d,Stamp("2026.11.01"),local,broker,bars,3600,Stamp("2026.11.01 09:00"),result) &&
      result.status==ICT_SESSION_AMBIGUOUS_TIME);
   local[1].from_utc++;
   Check("schedule gap rejected",!ICTBuildSessionLiquidity(d,Stamp("2026.11.01"),local,broker,bars,3600,Stamp("2026.11.01 09:00"),result) &&
      result.status==ICT_SESSION_BAD_SCHEDULE);
  }









public static void TestICTSignalJournalLive() {
   SICTSignalResult committed=new SICTSignalResult(); SICTSignalResult current=new SICTSignalResult();
   SignalFixture(committed); ICTEvaluateSignal(committed,2);
   SignalFixture(current); ICTEvaluateSignal(current,2); current.rr=2.5;
   ICTSignalReconcileCommittedLive(committed,current);
   Check("live matching plan uses fresh RR while journal stays immutable",
      current.confirmed && current.risk_pass && current.rr==2.5 && committed.rr==3);

   SignalFixture(current); current.risk_pass=false; ICTEvaluateSignal(current,2);
   string veto=current.reason;
   ICTSignalReconcileCommittedLive(committed,current);
   Check("risk veto remains published while journal remains confirmed",
      !current.confirmed && !current.risk_pass && current.reason==veto && committed.confirmed);

   SignalFixture(current); ICTEvaluateSignal(current,2); current.entry=101;
   ICTSignalReconcileCommittedLive(committed,current);
   Check("changed live plan cannot publish historical confirmation",
      !current.confirmed && !current.risk_pass && current.state==ICT_SIGNAL_NO_TRADE && committed.entry==100);

   SignalFixture(current); ICTEvaluateSignal(current,2); current.target_pool_id="DIFFERENT_POOL";
   ICTSignalReconcileCommittedLive(committed,current);
   Check("changed target identity cannot reuse committed confirmation",!current.confirmed && committed.confirmed);

   SignalFixture(current); ICTEvaluateSignal(current,2); current.risk_pass=false;
   ICTSignalReconcileCommittedLive(committed,current);
   Check("inconsistent confirmed flags fail closed",!current.confirmed && !current.risk_pass);

   SignalFixture(current,-1); ICTEvaluateSignal(current,2);
   ICTSignalReconcileCommittedLive(committed,current);
   Check("opposite live confirmation cannot replace committed signal",!current.confirmed && committed.direction==1);
  }







public static void PositionRiskFixture(SICTPositionRiskInput p) {
   ZeroMemory(p); p.ticket=123; p.symbol="TEST"; p.direction=1; p.digits=2;
   p.volume=0.5; p.entry=100; p.stop=98; p.target=105;
   p.profit=25; p.swap=-2; p.gross_at_stop=-100; p.gross_at_target=250;
   p.stop_valued=true; p.target_valued=true;
  }

public static void TestLivePositionRisk() {
   Check("below three percent stays normal",ICTEvaluatePositionRiskLimit(true,299.99,10000)==ICT_RISK_LIMIT_NORMAL);
   Check("exactly three percent does not exceed the warning boundary",ICTEvaluatePositionRiskLimit(true,300,10000)==ICT_RISK_LIMIT_NORMAL);
   Check("over three percent warns",ICTEvaluatePositionRiskLimit(true,300.01,10000)==ICT_RISK_LIMIT_WARNING);
   Check("exactly five percent warns without crossing the close boundary",ICTEvaluatePositionRiskLimit(true,500,10000)==ICT_RISK_LIMIT_WARNING);
   Check("over five percent requests a close policy",ICTEvaluatePositionRiskLimit(true,500.01,10000)==ICT_RISK_LIMIT_CLOSE);
   Check("a gap past both thresholds goes directly to close policy",ICTEvaluatePositionRiskLimit(true,700,10000)==ICT_RISK_LIMIT_CLOSE);
   Check("unknown stop or loss metric cannot authorize a close",ICTEvaluatePositionRiskLimit(false,700,10000)==ICT_RISK_LIMIT_UNKNOWN);
   Check("zero reference capital cannot authorize a close",ICTEvaluatePositionRiskLimit(true,700,0)==ICT_RISK_LIMIT_UNKNOWN);
   Check("negative reference capital cannot authorize a close",ICTEvaluatePositionRiskLimit(true,700,-100)==ICT_RISK_LIMIT_UNKNOWN);
   Check("negative loss input is not a loss threshold",ICTEvaluatePositionRiskLimit(true,-700,10000)==ICT_RISK_LIMIT_UNKNOWN);
   Check("reversed warning and closing thresholds are rejected",ICTEvaluatePositionRiskLimit(true,700,10000,5,3)==ICT_RISK_LIMIT_UNKNOWN);
   Check("threshold policy honors a selected positive reference",ICTEvaluatePositionRiskLimit(true,500,8000)==ICT_RISK_LIMIT_CLOSE);
   SICTPositionRiskInput p=new SICTPositionRiskInput(); PositionRiskFixture(p);
   SICTPositionRisk r=new SICTPositionRisk();
   Check("position risk uses real broker money and actual volume",ICTCalculatePositionRisk(p,10000,10,r) &&
      r.valid && r.stop_valid && r.target_valid && r.costs==5 && r.risk_money==107 && r.net_at_target==243);
   Check("actual SL TP and floating percentages use the selected account capital",
      MathAbs(r.risk_percent-1.07)<1e-9 && MathAbs(r.target_percent-2.43)<1e-9 &&
      r.floating==23 && MathAbs(r.floating_percent-0.23)<1e-9);
   Check("net position RR includes swap and configured cost reserve",
      r.rr_valid && MathAbs(r.rr-243.0/107.0)<1e-9);
   ICTCalculatePositionRisk(p,8000,10,r);
   Check("equity denominator changes percent without changing risk money",
      r.risk_money==107 && MathAbs(r.risk_percent-1.3375)<1e-9);
   p.volume=0.25; p.swap=-1; p.profit=12.5; p.gross_at_stop=-50; p.gross_at_target=125;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("partial close values only remaining exposure",
      r.costs==2.5 && r.risk_money==53.5 && r.net_at_target==121.5 && r.floating==11.5);
   PositionRiskFixture(p); p.direction=-1; p.stop=102; p.target=95;
   p.volume=0.2; p.swap=1; p.gross_at_stop=-40; p.gross_at_target=120;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("sell risk uses broker valuation and positive swap",
      r.risk_money==41 && r.net_at_target==119 && MathAbs(r.risk_percent-0.41)<1e-9);
   PositionRiskFixture(p); p.stop=0;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("missing SL cannot reuse an earlier valid stop result",!r.stop_valid && r.target_valid && !r.rr_valid);
   SICTPositionRiskTotals totals=new SICTPositionRiskTotals(); ZeroMemory(totals); ICTAccumulatePositionRisk(r,totals);
   Check("a missing stop makes aggregate risk explicitly incomplete",totals.count==1 && totals.unknown_stops==1);
   PositionRiskFixture(p); p.stop_valued=false;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("failed broker stop valuation is unknown not zero risk",r.valid && !r.stop_valid && !r.rr_valid);
   PositionRiskFixture(p); p.target=0;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("missing TP preserves known stop risk but has no invented reward",
      r.stop_valid && r.risk_money==107 && !r.target_valid && !r.rr_valid);
   PositionRiskFixture(p); p.stop=101; p.gross_at_stop=20;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("profitable trailing stop reports locked money without infinite RR",
      r.stop_valid && r.risk_money==0 && r.locked_money==13 && !r.rr_valid);
   Check("a profitable SL still has additional equity giveback risk",r.floating==23 && r.remaining_risk_money==10);
   p.gross_at_stop=7; ICTCalculatePositionRisk(p,10000,10,r);
   Check("net break even after fees is distinct from a missing stop",
      r.stop_valid && r.risk_money==0 && r.locked_money==0 && !r.rr_valid);
   PositionRiskFixture(p); p.gross_at_target=3;
   ICTCalculatePositionRisk(p,10000,10,r);
   Check("a target below net break even remains a negative P L",
      r.target_valid && r.net_at_target==-4 && r.target_percent<0 && !r.rr_valid);
   PositionRiskFixture(p); ICTCalculatePositionRisk(p,0,10,r);
   Check("zero capital keeps valid money figures without claiming a valid percent",
      r.valid && !r.capital_valid && r.risk_money==107 && r.risk_percent==0);
   ICTCalculatePositionRisk(p,-100,10,r);
   Check("negative equity never divides or produces a negative risk percentage",!r.capital_valid);
   Check("negative configured fees cannot inflate projected reward",!ICTCalculatePositionRisk(p,10000,-1,r) && !r.valid);
   p.volume=0;
   Check("zero actual position volume is invalid",!ICTCalculatePositionRisk(p,10000,10,r));
   PositionRiskFixture(p); p.direction=0;
   Check("unknown position direction is invalid",!ICTCalculatePositionRisk(p,10000,10,r));
   PositionRiskFixture(p); ICTCalculatePositionRisk(p,10000,10,r);
   ZeroMemory(totals); ICTAccumulatePositionRisk(r,totals);
   p.direction=-1; p.stop=102; p.gross_at_stop=-50;
   ICTCalculatePositionRisk(p,10000,10,r); ICTAccumulatePositionRisk(r,totals);
   Check("hedged positions sum loss exposures instead of cancelling each other",
      totals.count==2 && totals.risk_money==164 && totals.unknown_stops==0);
   p.gross_at_stop=50; ICTCalculatePositionRisk(p,10000,10,r); ICTAccumulatePositionRisk(r,totals);
   Check("locked stop profit never offsets another position risk",totals.count==3 && totals.risk_money==164);
   TestLiveAccountRiskBudgets();
  }

public static void TestLiveAccountRiskBudgets() {
   Check("entry capital shrinks with equity",ICTConservativeRiskCapital(10000,9000,8000)==8000);
   Check("floating profit cannot enlarge trade capital above balance",ICTConservativeRiskCapital(10000,9000,11000)==9000);
   Check("deposits cannot enlarge a fixed protection reference",ICTConservativeRiskCapital(10000,11000,12000)==10000);
   Check("invalid current equity blocks sizing",ICTConservativeRiskCapital(10000,10000,0)==0);
   SICTPositionRiskSnapshot s=new SICTPositionRiskSnapshot(); ZeroMemory(s);
   s.balance=10000; s.equity=10000; s.capital=10000; s.connected=true; s.daily_valid=true; s.daily_opened_valid=true;
   string reason="";
   Check("automatic SL TP accepts the exact requested three percent risk",SRMPValidatePositionPlanRisk(-300,600,0,10000,3,2,ref reason));
   Check("automatic SL TP rejects more than three percent risk",!SRMPValidatePositionPlanRisk(-300.01,700,0,10000,3,2,ref reason));
   Check("automatic SL TP cannot configure a ceiling above three percent",!SRMPValidatePositionPlanRisk(-25,60,0,10000,3.01,2,ref reason));
   Check("small entry fits an empty account budget",ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   Check("exact portfolio and projected daily boundary may be reserved",ICTPositionEntryBudgetAllowed(s,100,10000,1,1,ref reason));
   Check("portfolio boundary cannot be crossed by a new SL",!ICTPositionEntryBudgetAllowed(s,100.01,10000,1,1,ref reason));
   s.totals.risk_money=80; s.totals.remaining_risk_money=80;
   Check("individually small trades cannot stack past the aggregate cap",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.totals.risk_money=65; s.totals.remaining_risk_money=65; s.pending_risk_money=10; s.pending_count=1;
   Check("pending risk reserves the same budget as open exposure",ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.pending_risk_money=10.01;
   Check("a pending order can consume the final available risk",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.pending_risk_money=10; s.totals.remaining_risk_money=80;
   Check("equity giveback also enforces the portfolio cap",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.totals.risk_money=0; s.totals.remaining_risk_money=487; s.pending_risk_money=0; s.daily_net=500;
   Check("locked SL profit cannot hide large floating-profit giveback",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.totals.remaining_risk_money=0; s.daily_net=-90;
   Check("new risk is reserved before reaching the daily stop",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason) && StringFind(reason,"Daily")>=0);
   s.daily_net=-75;
   Check("exact remaining daily budget is allowed",ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.daily_net=-100;
   Check("at the daily loss threshold no fresh entry is allowed",!ICTPositionEntryBudgetAllowed(s,1,10000,1,1,ref reason));
   s.daily_net=0; s.daily_valid=false;
   Check("missing daily history blocks a live daily budget",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   Check("daily budget cannot be disabled to bypass the user limit",!ICTPositionEntryBudgetAllowed(s,25,10000,1,0,ref reason));
   Check("daily budget cannot exceed the user six percent ceiling",!ICTPositionEntryBudgetAllowed(s,25,10000,10,6.01,ref reason));
   Check("one trade cannot exceed three percent even under a larger portfolio cap",!ICTPositionEntryBudgetAllowed(s,301,10000,10,6,ref reason));
   s.daily_valid=true;
   Check("exact user three percent per trade boundary is supported",ICTPositionEntryBudgetAllowed(s,300,10000,3,6,ref reason));
   s.daily_net=-300;
   Check("a second three percent SL can reserve the remaining six percent day budget",ICTPositionEntryBudgetAllowed(s,300,10000,3,6,ref reason));
   s.daily_net=-300.01;
   Check("a new SL cannot take the day beyond six percent",!ICTPositionEntryBudgetAllowed(s,300,10000,3,6,ref reason));
   s.daily_net=0;
   s.daily_opened_risk_money=575;
   Check("cumulative daily risk can use exactly the remaining six percent",ICTPositionEntryBudgetAllowed(s,25,10000,3,6,ref reason));
   s.daily_opened_risk_money=575.01;
   Check("cumulative daily risk cannot cross six percent",!ICTPositionEntryBudgetAllowed(s,25,10000,3,6,ref reason));
   s.daily_opened_risk_money=600; s.daily_net=1000;
   Check("a winning trade never refunds cumulative daily risk",!ICTPositionEntryBudgetAllowed(s,25,10000,3,6,ref reason));
   Check("loss-only mode still permits an explicit cumulative-risk opt-result_out",ICTPositionEntryBudgetAllowed(s,25,10000,3,6,ref reason,false));
   s.daily_opened_risk_money=0; s.daily_net=0; s.daily_opened_valid=false;
   Check("missing original SL history blocks a cumulative daily budget",!ICTPositionEntryBudgetAllowed(s,25,10000,3,6,ref reason));
   s.daily_opened_valid=true;
   s.daily_valid=true; s.unknown_pending=1;
   Check("a pending order without a valued SL blocks entry",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.unknown_pending=0; s.totals.unknown_stops=1;
   Check("a manual position without SL blocks entry",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.totals.unknown_stops=0; s.totals.unknown_floating=1;
   Check("unknown floating prevents hiding equity giveback",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.totals.unknown_floating=0; s.selection_errors=1;
   Check("an incomplete account scan blocks new risk",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.selection_errors=0; s.symbol_filter="TEST";
   Check("symbol-only data cannot authorize an account budget",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.symbol_filter=""; s.connected=false;
   Check("disconnected data cannot authorize an account budget",!ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.connected=true; s.equity=8000;
   Check("portfolio percentages use reduced current equity",!ICTPositionEntryBudgetAllowed(s,81,10000,1,1,ref reason));
   s.equity=10000;
   Check("negative aggregate risk cannot subsidize a new trade",(s.totals.risk_money=-1)<0 && !ICTPositionEntryBudgetAllowed(s,25,10000,1,1,ref reason));
   s.totals.risk_money=0;
   Check("negative policy limits do not silently disable safety",!ICTPositionEntryBudgetAllowed(s,25,10000,-1,1,ref reason));
   Check("invalid zero candidate risk is rejected",!ICTPositionEntryBudgetAllowed(s,0,10000,1,1,ref reason));
   Check("risk sum overflow fails closed",(s.pending_risk_money=DBL_MAX)>0 && !ICTPositionEntryBudgetAllowed(s,DBL_MAX,10000,1,1,ref reason));
  }

public static void TestLivePositionRiskDisplay() {
   SICTPositionRiskSnapshot s=new SICTPositionRiskSnapshot(); ZeroMemory(s); s.currency="USD"; s.currency_digits=2;
   s.capital_mode=ICT_POSITION_BALANCE; s.balance=10000; s.equity=10023; s.capital=10000;
   s.symbol_filter="TEST"; s.cost_per_lot=10; s.connected=true;
   Check("no positions shows an explicit waiting state",ICTPositionRiskStatus(s)=="CHƯA CÓ VỊ THẾ");
   SICTPositionRiskInput p=new SICTPositionRiskInput(); PositionRiskFixture(p);
   SICTPositionRisk r=new SICTPositionRisk(); ICTCalculatePositionRisk(p,s.capital,s.cost_per_lot,r);
   ArrayResize(ref s.positions,1); s.positions[0]=r; ICTAccumulatePositionRisk(r,s.totals);
   string body=ICTPositionRiskBody(s);
   Check("live risk panel shows actual ticket and money percentages",
      StringFind(body,"#123")>=0 && StringFind(body,"107.00 USD (1.07%)")>=0 &&
      StringFind(body,"+243.00 USD (2.43%)")>=0 && StringFind(body,"+23.00 USD (0.23%)")>=0);
   Check("cost treatment and actual entry basis are visible in risk panel",
      StringFind(body,"chưa trừ commission")>=0 && StringFind(body,"giá vào thực tế")>=0 && StringFind(body,"10.00 USD/lot")>=0);
   s.symbol_filter=""; s.protection_online=true; s.protection_armed=true; s.protection_healthy=true;
   Check("armed healthy protection has an explicit monitored state",ICTPositionSummaryValue(s,0,1,1)=="ĐANG GIÁM SÁT" && ICTPositionSummarySeverity(s,0,1,1)==1);
   s.protection_armed=false;
   Check("a fresh heartbeat alone does not imply automatic protection",ICTPositionSummaryValue(s,0,1,1)=="CHƯA BẬT TỰ ĐỘNG" && ICTPositionSummarySeverity(s,0,1,1)==2);
   s.protection_armed=true; s.protection_state=1;
   Check("a latched emergency overrides the healthy heartbeat",ICTPositionSummarySeverity(s,0,1,1)==3 && StringFind(ICTPositionSummaryValue(s,0,1,1),"KHÓA")>=0);
   s.protection_state=0; s.daily_valid=true; s.daily_net=23;
   Check("account pending risk is included in the compact SL total",(s.pending_risk_money=10)>0 && StringFind(ICTPositionSummaryValue(s,2,1,1),"117.00")>=0);
   s.pending_risk_money=0; s.unknown_pending=1;
   Check("unknown pending risk gets a critical text warning",StringFind(ICTPositionSummaryValue(s,2,1,1),"CHƯA ĐỦ")==0 && ICTPositionSummarySeverity(s,2,1,1)==3);
   Check("unknown pending risk never presents a known daily headroom",ICTPositionSummaryValue(s,6,1,1)=="CHƯA XÁC ĐỊNH");
   s.unknown_pending=0;
   p.stop=0; ICTCalculatePositionRisk(p,s.capital,s.cost_per_lot,r); s.positions[0]=r;
   ZeroMemory(s.totals); ICTAccumulatePositionRisk(r,s.totals); body=ICTPositionRiskBody(s);
   Check("missing SL is prominently shown as unknown with partial totals",
      StringFind(ICTPositionRiskStatus(s),"CHƯA XÁC ĐỊNH")>=0 && StringFind(body,"CHƯA ĐẶT")>=0 &&
      StringFind(body,"chưa đầy đủ")>=0 && StringFind(body,"(chưa có SL)")>=0);
   s.capital=0; body=ICTPositionRiskBody(s);
   Check("display never presents zero capital as a genuine 0 percent risk",StringFind(body,"chưa có vốn hợp lệ")>=0);
   s.connected=false; body=ICTPositionRiskBody(s);
   Check("disconnected account data is visibly labelled",StringFind(body,"MẤT KẾT NỐI")>=0);
   s.connected=true; s.capital=10000; s.selection_errors=1; ZeroMemory(s.totals);
   Check("a failed position read cannot be mistaken for an empty account",ICTPositionRiskStatus(s)=="ĐANG ĐỒNG BỘ VỊ THẾ");
  }





public static void ICTStatFixtureSamples(ref SICTStatSample[] samples) {
   ArrayResize(ref samples,1200);
   for(int i=0;i<ArraySize(samples);i++)
     {
      SICTStatSample s=new SICTStatSample(); ZeroMemory(s);
      s.label=i%3; s.asof=(long)(1000000+i*240); s.label_end=s.asof+240;
      s.x[0]=s.label==0 ? 2.0 : s.label==1 ? -2.0 : 0.0;
      s.x[1]=s.label==2 ? 1.0 : -1.0;
      for(int k=2;k<32;k++) s.x[k]=MathSin(i*0.1+k)*0.05;
      s.mask=s.label==0 ? 85 : s.label==1 ? 170 : 0;
      samples[i]=s;
     }
  }
public static void ICTStatFixtureRates(ref MqlRates[] rates) {
   ArrayResize(ref rates,120);
   for(int i=0;i<ArraySize(rates);i++)
     {
      MqlRates r=new MqlRates(); ZeroMemory(r);
      r.time=(long)(1000000+i*60); r.open=100; r.close=100;
      r.high=100.5; r.low=99.5; r.spread=0; r.tick_volume=100;
      rates[i]=r;
     }
  }
public static void ICTLiquidityFixture(SICTRangeSnapshot s,ref MqlRates[] r) {
   ICTStatFixtureRates(ref r); ZeroMemory(s);
   s.valid=true; s.schema=ICT_RANGE_SCHEMA; s.symbol="fixture"; s.ltf=PERIOD_M1;
   s.range.valid=true; s.range.id="native_range"; s.range.low=98; s.range.high=102;
   s.as_of=r[32].time+60; s.last_close=100; s.htf_bias=1; s.level_count=4;
   for(int i=0;i<4;i++)
     {
      SICTRangeLevel l=new SICTRangeLevel(); ZeroMemory(l); l.id="native_pool_"+IntegerToString(i); l.range_id=s.range.id;
      l.side=(i%2==0 ? 1 : -1); l.price=(i==0 ? 101 : i==1 ? 99 : i==2 ? 102 : 98);
      l.state=IR_UNTOUCHED; l.timeframe=(i<2 ? PERIOD_M5 : PERIOD_H1);
      l.membership=(i<2 ? IR_INTERNAL : IR_BOUNDARY); l.available_at=r[24].time;
      s.levels[i]=l;
     }
  }
public static void ICTLiquidityFixtureSamples(ref SICTStatSample[] samples) {
   ArrayResize(ref samples,600);
   for(int k=0;k<600;k++)
     {
      SICTRangeSnapshot snapshot=new SICTRangeSnapshot(); MqlRates[] r=InitArray<MqlRates>(0); ICTLiquidityFixture(snapshot,ref r);
      for(int i=0;i<ArraySize(r);i++) r[i].time=(long)((long)r[i].time+(long)k*3600);
      snapshot.as_of=r[32].time+60;
      for(int i=0;i<4;i++) snapshot.levels[i].available_at=r[24].time;
      SICTStatLiquidityPair p=new SICTStatLiquidityPair(); ICTStatLiquiditySelectPair(snapshot,r,33,p);
      p.trend_bias=(k%3==0 ? 1 : k%3==1 ? -1 : 0); p.trend_closed_at=r[20].time;
      if(k%3==0) { r[33].high=101.2; r[33].close=101; }
      if(k%3==1) { r[33].low=98.8; r[33].close=99; }
      SICTStatSample sample=new SICTStatSample(); ICTStatLiquidityFeatures(r,32,60,0.01,p,sample);
      sample.label=ICTStatLiquidityLabel(r,ArraySize(r),32,4,60,p,ref sample.label_end);
      samples[k]=sample;
     }
  }
public static void RunICTLiquidityProbabilityFixtures() {
   SICTRangeSnapshot snapshot=new SICTRangeSnapshot(); MqlRates[] r=InitArray<MqlRates>(0); ICTLiquidityFixture(snapshot,ref r);
   SICTStatLiquidityPair p=new SICTStatLiquidityPair();
   Check("LIQ selects closest untouched native pair on both sides",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==101 && p.ssl==99 && p.bsl_id=="native_pool_0");
   SICTStatLiquidityPair parity=new SICTStatLiquidityPair(); ICTStatLiquiditySelectPair(snapshot,r,33,parity);
   Check("LIQ replay parity checks frozen native identities",ICTStatLiquiditySamePair(p,parity));
   parity.bsl_id="different_native_pool";
   Check("LIQ same price cannot hide different native pool identity",!ICTStatLiquiditySamePair(p,parity));
   Check("LIQ retains native lifecycle semantics for renderer",ICTRangeLevelUntouched(snapshot.levels[0],snapshot.as_of));
   snapshot.levels[0].state=IR_APPROACHING;
   Check("LIQ near but not touched pool remains eligible",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==101);
   snapshot.levels[0].candidate=true;
   Check("LIQ pending breakout is not untouched",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==102);
   snapshot.levels[2].state=IR_CONSUMED;
   Check("LIQ does not invent a missing upper pool",!ICTStatLiquiditySelectPair(snapshot,r,33,p));
   ICTLiquidityFixture(snapshot,ref r);
   r[30].high=101;
   Check("LIQ exact wick touch excludes native-untouched pool",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==102);
   ICTLiquidityFixture(snapshot,ref r); r[35].high=120;
   Check("LIQ future wick cannot change historical pair",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==101 && p.ssl==99);
   ICTLiquidityFixture(snapshot,ref r);
   Check("LIQ respects hidden internal pool category",ICTStatLiquiditySelectPair(snapshot,r,33,p,false,true) && p.bsl==102 && p.ssl==98);
   Check("LIQ respects hidden external pool category",ICTStatLiquiditySelectPair(snapshot,r,33,p,true,false) && p.bsl==101 && p.ssl==99);
   Check("LIQ no forecast when all pool categories hidden",!ICTStatLiquiditySelectPair(snapshot,r,33,p,false,false));
   for(int i=0;i<4;i++) snapshot.levels[i].available_at=r[0].time-60;
   Check("LIQ missing pre-pool history cannot certify untouched",!ICTStatLiquiditySelectPair(snapshot,r,33,p));
   ICTLiquidityFixture(snapshot,ref r); r[28].time++;
   Check("LIQ missing intraday coverage cannot certify untouched",!ICTStatLiquiditySelectPair(snapshot,r,33,p));
   ICTLiquidityFixture(snapshot,ref r); snapshot.as_of++;
   Check("LIQ stale snapshot cannot reuse later OHLC",!ICTStatLiquiditySelectPair(snapshot,r,33,p));
   ICTLiquidityFixture(snapshot,ref r); snapshot.levels[0].available_at=snapshot.as_of;
   Check("LIQ newly confirmed pool starts its untouched clock at availability",ICTStatLiquiditySelectPair(snapshot,r,33,p) && p.bsl==101);
   ICTLiquidityFixture(snapshot,ref r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   p.trend_bias=1; p.trend_closed_at=r[20].time;
   SICTStatSample sample=new SICTStatSample(); SICTStatSample future=new SICTStatSample();
   Check("LIQ features encode barriers and known long trend",ICTStatLiquidityFeatures(r,32,60,0.01,p,sample) && sample.x[22]==0.5 && sample.x[23]==1 && sample.asof==snapshot.as_of);
   r[40].close=1; r[40].low=0.5;
   ICTStatLiquidityFeatures(r,32,60,0.01,p,future);
   bool same=true; for(int k=0;k<32;k++) if(sample.x[k]!=future.x[k]) same=false;
   Check("LIQ post-snapshot price cannot rewrite features",same);
   p.trend_closed_at=p.asof+1;
   Check("LIQ future daily trend is forbidden",!ICTStatLiquidityFeatures(r,32,60,0.01,p,sample));
   p.trend_closed_at=r[20].time; r[20].time++;
   Check("LIQ feature window rejects unclassified gaps",!ICTStatLiquidityFeatures(r,32,60,0.01,p,sample));
   ICTLiquidityFixture(snapshot,ref r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   long end=0;
   r[33].high=101.2; r[33].close=101; r[34].low=98.8; r[34].close=99;
   Check("LIQ BSL first survives later SSL hit",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==0 && end==r[33].time+60);
   ICTLiquidityFixture(snapshot,ref r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   r[33].low=98.8; r[33].close=99; r[34].high=101.2; r[34].close=101;
   Check("LIQ SSL first survives later BSL hit",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==1);
   ICTLiquidityFixture(snapshot,ref r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   r[33].high=101; r[33].low=99;
   Check("LIQ same-bar two touches stay ambiguous",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==-2);
   r[33].open=101.1; r[33].high=101.2;
   Check("LIQ observed open precedes same-bar wicks",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==0);
   r[33].open=98.9; r[33].low=98.8;
   Check("LIQ lower observed open precedes same-bar wicks",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==1);
   ICTLiquidityFixture(snapshot,ref r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   r[33].high=101;
   Check("LIQ exact equality counts as first touch",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==0);
   Check("LIQ incomplete horizon excluded despite early hit",ICTStatLiquidityLabel(r,34,32,4,60,p,ref end)==-1);
   ICTLiquidityFixture(snapshot,ref r); ICTStatLiquiditySelectPair(snapshot,r,33,p);
   Check("LIQ timeout keeps third outcome",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==2 && end==r[36].time+60);
   r[34].time+=60;
   Check("LIQ gap inside target path is censored",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==-1);
   ICTLiquidityFixture(snapshot,ref r); ICTStatLiquiditySelectPair(snapshot,r,33,p); p.bsl=0;
   Check("LIQ invalid barrier cannot become timeout",ICTStatLiquidityLabel(r,120,32,4,60,p,ref end)==-1);
   SICTStatSample geometry_sample=new SICTStatSample(); ZeroMemory(geometry_sample); geometry_sample.x[22]=0.25;
   double[] geometry=InitArray<double>(3); ICTStatLiquidityGeometry(geometry_sample,0.2,ref geometry);
   Check("LIQ distance baseline retains trained timeout prior",MathAbs(geometry[0]-0.2)<1e-9 && MathAbs(geometry[1]-0.6)<1e-9 && geometry[2]==0.2);

   SICTStatSample[] samples=InitArray<SICTStatSample>(0); ICTLiquidityFixtureSamples(ref samples);
   SICTStatConfig c=new SICTStatConfig(); ICTStatDefaultConfig(c); c.min_train=200; c.min_evaluation=50;
   SICTStatModel model=new SICTStatModel(); SICTStatSnapshot metrics=new SICTStatSnapshot(); SICTStatLiquidityAudit audit=new SICTStatLiquidityAudit(); ZeroMemory(audit);
   Check("LIQ native-feature first-touch samples prepare separately",ICTStatPrepare(c,samples,model,metrics));
   int steps=0; while(ICTStatTrainStep(model,samples,metrics) && steps++<100000) {}
   Check("LIQ trained first-touch network evaluates held-result_out labels",ICTStatFinish(model,samples,metrics) && metrics.ready);
   Check("LIQ synthetic long-trend signal beats both baselines",ICTStatLiquidityAuditModel(model,samples,metrics,audit) && audit.validation_pass);
   Check("LIQ calibration audit metrics are finite",audit.log_loss>=0 && audit.ece>=0 && audit.ece<=1 && MathIsValidNumber(audit.brier_geometry));
   SICTStatSnapshot prediction=new SICTStatSnapshot();
   Check("LIQ learned BSL-first probability comes from its own network",ICTStatPredict(model,samples[0],prediction) && prediction.dl[0]>0.75);
   Check("LIQ observed training context remains in support",ICTStatLiquidityInSupport(model,samples[0]));
   double distance=samples[0].x[20]; samples[0].x[20]+=100000;
   Check("LIQ unseen barrier geometry cannot publish clipped extrapolation",!ICTStatLiquidityInSupport(model,samples[0]));
   samples[0].x[20]=distance;
   bool calibrated=metrics.calibrated; metrics.calibrated=false;
   Check("LIQ uncalibrated model cannot publish probabilities",!ICTStatLiquidityAuditModel(model,samples,metrics,audit) && !audit.validation_pass);
   metrics.calibrated=calibrated; metrics.brier_combined=1.1;
   Check("LIQ poor first-touch model cannot pass distance baseline",!ICTStatLiquidityAuditModel(model,samples,metrics,audit));
  }

public static void RunICTStatisticalLearningFixtures() {
   SICTStatConfig c=new SICTStatConfig(); ICTStatDefaultConfig(c);
   Check("STAT default configuration",ICTStatValidConfig(c));
   c.horizon=0; Check("STAT rejects zero horizon",!ICTStatValidConfig(c)); c.horizon=4;
   MqlRates[] rates=InitArray<MqlRates>(0); ICTStatFixtureRates(ref rates);
   Check("STAT validates ordered OHLC",ICTStatValidRates(rates));
   rates[20].time=rates[19].time; Check("STAT rejects duplicate bars",!ICTStatValidRates(rates)); ICTStatFixtureRates(ref rates);
   rates[20].high=99; Check("STAT rejects malformed OHLC",!ICTStatValidRates(rates)); ICTStatFixtureRates(ref rates);
   SICTStatSample before=new SICTStatSample(); SICTStatSample after=new SICTStatSample();
   Check("STAT creates closed-prefix features",ICTStatFeatures(rates,32,0.01,before));
   rates[40].high=200; ICTStatFeatures(rates,32,0.01,after);
   bool unchanged=true; for(int k=0;k<32;k++) if(before.x[k]!=after.x[k]) unchanged=false;
   Check("STAT future bars cannot alter current features",unchanged && before.mask==after.mask);
   Check("STAT excludes immature labels",ICTStatLabel(rates,119,4,0.25,0.01)==-1);
   rates[36].close=101; rates[36].high=101.5;
   Check("STAT up label uses horizon close",ICTStatLabel(rates,32,4,0.25,0.01)==0);
   rates[36].close=99; rates[36].low=98.5;
   Check("STAT down label uses horizon close",ICTStatLabel(rates,32,4,0.25,0.01)==1);
   rates[36].close=100.1;
   Check("STAT flat label retains neutral class",ICTStatLabel(rates,32,4,0.25,0.01)==2);
   rates[36].close=100.3; rates[32].spread=10;
   Check("STAT recorded spread widens neutral band",ICTStatLabel(rates,32,4,0.25,0.01)==2);
   ICTStatFixtureRates(ref rates);
   rates[31].open=100.2; rates[31].close=99.9;
   rates[32].open=99.8; rates[32].close=100.3;
   Check("STAT bullish engulfing confirmation",(ICTStatPatternMask(rates,32) & 4)!=0);
   rates[32].low=99.2;
   Check("STAT bullish sweep reclaim confirmation",(ICTStatPatternMask(rates,32) & 1)!=0);
   rates[32].high=101; rates[32].close=100.8;
   Check("STAT breakout confirmation",(ICTStatPatternMask(rates,32) & 16)!=0);
   ICTStatFixtureRates(ref rates);
   rates[28].open=98.6; rates[28].close=98.8; rates[28].high=99; rates[28].low=98;
   rates[30].open=100.2; rates[30].close=100.4; rates[30].high=100.6; rates[30].low=100;
   rates[31].open=100.4; rates[31].close=100.3; rates[31].high=100.6; rates[31].low=100.1;
   rates[32].open=100.2; rates[32].close=100.5; rates[32].high=100.6; rates[32].low=100;
   Check("STAT first FVG retest",(ICTStatPatternMask(rates,32) & 64)!=0);
   rates[31].low=99.9;
   Check("STAT excludes consumed FVG retest",(ICTStatPatternMask(rates,32) & 64)==0);
   ICTStatFixtureRates(ref rates);
   SICTStatSample[] built=InitArray<SICTStatSample>(0);
   Check("STAT builds only mature disjoint samples",ICTStatBuildSamples(rates,0.01,c,ref built) && ArraySize(built)>0 &&
      built[0].label_end<=built[1].asof && built[ArraySize(built)-1].label_end<=rates[119].time);
   SICTStatModel model=new SICTStatModel(); SICTStatModel other=new SICTStatModel(); SICTStatSnapshot snapshot=new SICTStatSnapshot(); SICTStatSnapshot other_snapshot=new SICTStatSnapshot();
   SICTStatSample[] samples=InitArray<SICTStatSample>(0); SICTStatSample[] changed=InitArray<SICTStatSample>(0); ICTStatFixtureSamples(ref samples); ICTStatFixtureSamples(ref changed);
   Check("STAT prepares chronological partitions",ICTStatPrepare(c,samples,model,snapshot) &&
      model.train_end<model.cal_start_time && model.cal_end<model.test_start_time);
   long old_end=samples[model.train_n-1].label_end;
   samples[model.train_n-1].label_end=model.cal_start_time;
   Check("STAT purges boundary-crossing training labels",!ICTStatPrepare(c,samples,other,other_snapshot) && other_snapshot.status=="INVALID_SPLIT");
   samples[model.train_n-1].label_end=old_end;
   for(int i=model.test_start;i<ArraySize(changed);i++)
     { changed[i].x[0]+=100; changed[i].label=(changed[i].label+1)%3; }
   Check("STAT prepares changed future validation",ICTStatPrepare(c,changed,other,other_snapshot));
   Check("STAT scaler and priors fitted on train only",model.mean[0]==other.mean[0] && model.scale[0]==other.scale[0] && model.prior[0]==other.prior[0]);
   double[] initial=InitArray<double>(3); double[] trained=InitArray<double>(3); ICTStatForward(model,samples[0],true,1,ref initial);
   int steps=0;
   while(ICTStatTrainStep(model,samples,snapshot) && steps++<100000) {}
   steps=0; while(ICTStatTrainStep(other,changed,other_snapshot) && steps++<100000) {}
   ICTStatForward(model,samples[0],true,1,ref trained);
   Check("STAT neural backprop learns separable synthetic features",trained[0]>initial[0]+0.3 && trained[0]>0.8);
   bool same=true;
   for(int k=0;k<ICT_STAT_LR_WEIGHTS;k++) if(model.lr[k]!=other.lr[k]) same=false;
   for(int k=0;k<ICT_STAT_DNN_WEIGHTS;k++) if(model.deep[k]!=other.deep[k]) same=false;
   Check("STAT validation labels and features cannot train models",same);
   Check("STAT evaluates untouched later partition",ICTStatFinish(model,samples,snapshot) && snapshot.ready && snapshot.test_n==model.test_n);
   Check("STAT compares both trained models to climatology",snapshot.brier_ml<snapshot.brier_baseline*0.5 && snapshot.brier_dl<snapshot.brier_baseline*0.5 && snapshot.beats_baseline);
   Check("STAT calibration uses a separate partition",ICTStatFinish(other,changed,other_snapshot) && model.calibrated && other.calibrated &&
      model.lr_temperature==other.lr_temperature && model.deep_temperature==other.deep_temperature);
   Check("STAT reports validation pattern support only",snapshot.pattern_n[0]>0 && snapshot.pattern_n[0]<=model.test_n &&
      snapshot.pattern_hits[0]==snapshot.pattern_n[0] && snapshot.pattern_hits[1]==snapshot.pattern_n[1]);
   Check("STAT current probabilities normalize",ICTStatPredict(model,samples[0],snapshot) &&
      MathAbs(snapshot.combined[0]+snapshot.combined[1]+snapshot.combined[2]-1)<0.000001 && snapshot.combined[0]>0.8);
   double previous_up=snapshot.combined[0];
   Check("STAT current context changes the forecast",ICTStatPredict(model,samples[1],other_snapshot) &&
      other_snapshot.combined[1]>0.8 && other_snapshot.combined[0]<previous_up);
   SICTStatModel empty=new SICTStatModel(); ZeroMemory(empty);
   Check("STAT unfitted model clears readiness",!ICTStatPredict(empty,samples[0],snapshot) && !snapshot.ready);
   double low=0,high=0; ICTStatWilson(5,10,ref low,ref high);
   Check("STAT Wilson interval accounts for small support",low>0.23 && low<0.24 && high>0.76 && high<0.77);
   ICTStatWilson(0,0,ref low,ref high); Check("STAT no-support interval remains unknown",low==0 && high==1);
   double[] logits = new double[] {1000,-1000,0}; double[] probabilities=InitArray<double>(3); ICTStatSoftmax(logits,1,ref probabilities);
   Check("STAT softmax remains finite on extreme logits",MathIsValidNumber(probabilities[0]) && MathAbs(probabilities[0]+probabilities[1]+probabilities[2]-1)<0.000001);
   ArrayResize(ref samples,100);
   Check("STAT insufficient samples never expose probabilities",!ICTStatPrepare(c,samples,model,snapshot) && !snapshot.ready);
   ICTStatFixtureSamples(ref samples);
   for(int i=0;i<ArraySize(samples);i++) samples[i].label=0;
   Check("STAT one-class training is rejected",!ICTStatPrepare(c,samples,model,snapshot) && snapshot.status=="INSUFFICIENT_CLASSES");
   RunICTLiquidityProbabilityFixtures();
  }





public static void ICTFocusFixture(ref MqlRates[] r,SICTRangeLiquidityEvent e,SICTSweepFocusConfig c) {
   ArrayResize(ref r,70);
   double[] wave = new double[] {0,0.5,1,1.5,1,0.5,0,-0.5};
   for(int i=0;i<70;i++)
     {
      MqlRates b=new MqlRates(); ZeroMemory(b); b.time=(long)(1000000+i*60);
      double center=100+i*0.1+wave[i%8];
      b.open=center-0.1; b.close=center; b.high=center+0.3; b.low=center-0.3;
      r[i]=b;
     }
   r[40].open=104.5; r[40].close=104.3; r[40].high=106; r[40].low=103.8;
   r[41].open=104.4; r[41].close=101.5; r[41].high=104.5; r[41].low=101.2;
   ZeroMemory(e); e.id="focus-bsl"; e.pool_id="native-pool"; e.side=1;
   e.type=IR_EVENT_LIQUIDITY_SWEEP; e.membership=IR_BOUNDARY;
   e.source_tf=PERIOD_M5; e.event_tf=PERIOD_M1; e.sweep_number=1;
   e.bar_time=r[40].time; e.wick_time=e.bar_time; e.confirmed_at=e.bar_time+60;
   e.level=r[35].high; e.wick=r[40].high; e.close=r[40].close;
   c.left=2; c.right=2; c.max_bars=12; c.buffer_ticks=1;
   c.require_displacement=true; c.body_atr=1; c.body_fraction=0.6;
  }
public static void ICTFocusH1Fixture(ref MqlRates[] r,SICTSweepFocus v) {
   ArrayResize(ref r,124);
   double[] wave = new double[] {0,0.5,1,1.5,1,0.5,0,-0.5};
   long start=Stamp("2026.11.02");
   for(int i=0;i<124;i++)
     {
      MqlRates b=new MqlRates(); ZeroMemory(b); b.time=start+i*3600;
      double center=100+i*0.1+wave[i%8];
      b.open=center-0.1; b.close=center; b.high=center+0.3; b.low=center-0.3;
      r[i]=b;
     }
   ZeroMemory(v); v.valid=true; v.evt.side=-1;
   v.evt.confirmed_at=r[119].time+3600;
  }
public static void RunICTSweepFocusH1Fixtures() {
   MqlRates[] h1=InitArray<MqlRates>(0); SICTSweepFocus v=new SICTSweepFocus();
   ICTFocusH1Fixture(ref h1,v);
   Check("FOCUS H1 uses confirmed bullish swing structure",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_ready && v.h1_bias==1);
   Check("FOCUS SSL arrow aligns with bullish H1",ICTSweepFocusAlignedH1(v));
   Check("FOCUS H1 includes candle closing exactly at reclaim",v.h1_closed_at==v.evt.confirmed_at);
   long frozen=v.h1_closed_at;
   h1[120].high=0;
   Check("FOCUS H1 ignores malformed future OHLC",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_bias==1 && v.h1_closed_at==frozen);
   v.evt.confirmed_at+=1800;
   Check("FOCUS H1 excludes containing half-closed candle",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_closed_at==frozen);
   v.evt.side=1;
   Check("FOCUS BSL arrow opposes bullish H1",!ICTSweepFocusAlignedH1(v));
   v.evt.confirmed_at+=1800;
   Check("FOCUS H1 rejects invalid OHLC after its close",!ICTSweepFocusH1Context(h1,124,2,2,v) && !v.h1_ready && v.h1_bias==0 && v.h1_closed_at==0);
   ICTFocusH1Fixture(ref h1,v);
   Check("FOCUS H1 requires full 120-bar lookback",!ICTSweepFocusH1Context(h1,119,2,2,v) && !v.h1_ready);
   Check("FOCUS H1 rejects count beyond history",!ICTSweepFocusH1Context(h1,125,2,2,v));
   v.evt.confirmed_at+=3600;
   Check("FOCUS H1 missing latest closed hour cannot retain old bias",!ICTSweepFocusH1Context(h1,120,2,2,v) && !v.h1_ready);
   ICTFocusH1Fixture(ref h1,v);
   for(int i=0;i<124;i++)
     { h1[i].open-=i*0.1; h1[i].close-=i*0.1; h1[i].high-=i*0.1; h1[i].low-=i*0.1; }
   Check("FOCUS H1 neutral structure is not directional approval",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_ready && v.h1_bias==0 && !ICTSweepFocusAlignedH1(v));
   ICTFocusH1Fixture(ref h1,v);
   for(int i=0;i<124;i++)
     {
      double high=h1[i].high; h1[i].high=300-h1[i].low; h1[i].low=300-high;
      h1[i].open=300-h1[i].open; h1[i].close=300-h1[i].close;
     }
   v.evt.side=1;
   Check("FOCUS bearish H1 prioritizes BSL downward arrow",ICTSweepFocusH1Context(h1,124,2,2,v) && v.h1_bias==-1 && ICTSweepFocusAlignedH1(v));
   v.valid=false;
   Check("FOCUS H1 invalid evt clears old alignment",!ICTSweepFocusH1Context(h1,124,2,2,v) && !ICTSweepFocusAlignedH1(v));

   SICTSweepFocus older=new SICTSweepFocus(); SICTSweepFocus newer=new SICTSweepFocus(); ZeroMemory(older); ZeroMemory(newer);
   older.valid=true; older.h1_ready=true; older.h1_bias=1;
   older.evt.side=-1; older.evt.confirmed_at=100; older.evt.source_tf=PERIOD_M5;
   newer.valid=true; newer.h1_ready=true; newer.h1_bias=1;
   newer.evt.side=1; newer.evt.confirmed_at=200; newer.evt.source_tf=PERIOD_H4;
   Check("FOCUS aligned H1 outranks newer countertrend arrow",ICTSweepFocusPrefer(older,newer,true) && !ICTSweepFocusPrefer(newer,older,true));
   Check("FOCUS optional H1 preference restores chronological order",ICTSweepFocusPrefer(newer,older,false) && !ICTSweepFocusPrefer(older,newer,false));
   newer.h1_ready=false;
   Check("FOCUS missing H1 cannot outrank verified alignment",ICTSweepFocusPrefer(older,newer,true) && !ICTSweepFocusAlignedH1(newer));
   newer.h1_ready=true; newer.h1_bias=0;
   Check("FOCUS neutral H1 cannot outrank verified alignment",ICTSweepFocusPrefer(older,newer,true) && !ICTSweepFocusAlignedH1(newer));
   newer.h1_bias=1; newer.evt.side=-1;
   Check("FOCUS newest aligned arrow wins within aligned group",ICTSweepFocusPrefer(newer,older,true));
   newer.evt.confirmed_at=older.evt.confirmed_at;
   Check("FOCUS same-time alignment prefers higher source timeframe",ICTSweepFocusPrefer(newer,older,true) && !ICTSweepFocusPrefer(older,newer,true));
   older.h1_bias=0; newer.h1_ready=false; newer.evt.confirmed_at=200;
   Check("FOCUS no directional H1 falls back to newest arrow",ICTSweepFocusPrefer(newer,older,true));
   newer.valid=false;
   Check("FOCUS invalid evt cannot take a priority slot",!ICTSweepFocusPrefer(newer,older,true));
   older.valid=false; newer.valid=true;
   Check("FOCUS valid evt replaces empty priority slot",ICTSweepFocusPrefer(newer,older,true));
  }
public static void RunICTSweepFocusFixtures() {
   MqlRates[] r=InitArray<MqlRates>(0); SICTRangeLiquidityEvent e=new SICTRangeLiquidityEvent(); SICTSweepFocusConfig c=new SICTSweepFocusConfig();
   ICTFocusFixture(ref r,e,c); SICTSweepFocus v=new SICTSweepFocus();
   Check("FOCUS accepts only confirmed native sweep",ICTSweepFocusEligible(e,e.confirmed_at,1,PERIOD_M1,true,true));
   Check("FOCUS rejects not-yet-confirmed evt",!ICTSweepFocusEligible(e,e.confirmed_at-1,1,PERIOD_M1,true,true));
   Check("FOCUS respects chart timeframe",!ICTSweepFocusEligible(e,e.confirmed_at,1,PERIOD_M5,true,true));
   Check("FOCUS respects hidden external liquidity",!ICTSweepFocusEligible(e,e.confirmed_at,1,PERIOD_M1,true,false));
   e.type=IR_EVENT_FALSE_BREAKOUT;
   Check("FOCUS keeps false breakout distinct",!ICTSweepFocusEligible(e,e.confirmed_at,1,PERIOD_M1,true,true));
   ICTFocusFixture(ref r,e,c);
   Check("FOCUS waits at sweep close",ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v) && v.status==ICT_FOCUS_WAIT);
   Check("FOCUS freezes confirmed prior low",v.pivot_time==r[31].time && MathAbs(v.pivot_level-r[31].low)<0.000001 && v.prior_bias==1);
   double frozen=v.pivot_level;
   r[41].high=0;
   Check("FOCUS never reads future candle values",ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v) && v.status==ICT_FOCUS_WAIT && v.pivot_level==frozen);
   ICTFocusFixture(ref r,e,c);
   Check("FOCUS confirms bearish MSS after sweep",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_MSS && v.mss_time==r[41].time);
   Check("FOCUS timestamps MSS at closed candle",v.mss_confirmed_at==r[41].time+60 && v.mss_confirmed_at>e.confirmed_at);
   r[41].close=103; r[41].open=104;
   Check("FOCUS wick-only structure break is insufficient",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_WAIT);
   ICTFocusFixture(ref r,e,c); r[41].open=101.6;
   Check("FOCUS requires displacement on first close break",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_WEAK_BREAK);
   c.require_displacement=false;
   Check("FOCUS optional displacement changes explanation only",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_MSS);
   ICTFocusFixture(ref r,e,c); r[38].low=101; r[38].close=102;
   Check("FOCUS rejects pre-sweep broken swing",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_PREBROKEN);
   ICTFocusFixture(ref r,e,c); r[40].close=101.5; r[40].low=101; e.close=r[40].close;
   Check("FOCUS does not call same-candle break post-sweep MSS",ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v) && v.status==ICT_FOCUS_PREBROKEN);
   ICTFocusFixture(ref r,e,c); r[41].close=106.2; r[41].high=106.5;
   Check("FOCUS closes beyond sweep invalidate pending MSS",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_INVALIDATED);
   ICTFocusFixture(ref r,e,c); c.max_bars=2;
   for(int i=41;i<=42;i++) { r[i].open=104.5; r[i].close=104.3; r[i].high=105; r[i].low=103.8; }
   Check("FOCUS expires on trading candle count",ICTSweepFocusAnalyze(r,70,e,r[42].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_EXPIRED && v.closed_after==2);
   ICTFocusFixture(ref r,e,c);
   for(int i=0;i<40;i++) { r[i].open-=i*0.1; r[i].close-=i*0.1; r[i].high-=i*0.1; r[i].low-=i*0.1; }
   r[41].close=97; r[41].low=96;
   Check("FOCUS neutral prior structure yields break, not MSS",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_BOS && v.prior_bias==0);
   ICTFocusFixture(ref r,e,c);
   for(int i=0;i<70;i++)
     {
      double high=r[i].high; r[i].high=200-r[i].low; r[i].low=200-high;
      r[i].open=200-r[i].open; r[i].close=200-r[i].close;
     }
   e.side=-1; e.level=200-e.level; e.wick=200-e.wick; e.close=200-e.close;
   Check("FOCUS bullish SSL/MSS mirrors bearish rules",ICTSweepFocusAnalyze(r,70,e,r[41].time+60,60,0.01,c,v) && v.status==ICT_FOCUS_MSS && v.prior_bias==-1);
   ICTFocusFixture(ref r,e,c); e.wick+=0.1;
   Check("FOCUS rejects revised native wick",!ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v));
   ICTFocusFixture(ref r,e,c); c.buffer_ticks=-1;
   Check("FOCUS rejects invalid MSS configuration",!ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v));
   ICTFocusFixture(ref r,e,c); ICTSweepFocusAnalyze(r,70,e,e.confirmed_at,60,0.01,c,v);
   SICTStatModel model=new SICTStatModel(); ZeroMemory(model);
   Check("FOCUS no synthetic probability before fit",!ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v) && !v.forecast_ready);
   model.fitted=true; model.train_end=r[20].time; model.cal_end=r[30].time;
   model.lr_temperature=1; model.deep_temperature=1;
   for(int k=0;k<32;k++) model.scale[k]=1;
   model.lr[0]=0.5;
   Check("FOCUS forecasts from confirmation prefix",ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v) && v.forecast_ready && v.forecast_asof==e.confirmed_at);
   double prob=v.ml[0]; r[41].close=1; r[41].low=0.5;
   Check("FOCUS post-sweep price cannot rewrite forecast features",ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v) && v.ml[0]==prob);
   Check("FOCUS rejects other-timeframe model",!ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M5,v) && !v.forecast_ready);
   model.cal_end=e.bar_time;
   Check("FOCUS rejects calibration including evt outcomes",!ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v) && !v.forecast_ready);
   model.train_end=e.bar_time+60; model.cal_end=e.bar_time+120;
   Check("FOCUS rejects training after historical evt",!ICTSweepFocusForecast(r,70,0.01,model,PERIOD_M1,v));
   RunICTSweepFocusH1Fixtures();
  }




public static void AnalyticalFixture(SICTAnalyticalContext c,SICTAnalyticalVotes v) {
   ZeroMemory(c); ZeroMemory(v); c.symbol="TEST"; c.valid=true;
   c.ltf=PERIOD_M5; c.mtf=PERIOD_M15; c.htf=PERIOD_H1;
   c.asof=100300; c.ltf_closed=c.asof; c.mtf_closed=99900; c.htf_closed=97200;
   c.htf_bias=1; c.mtf_bias=1;
   for(int i=0;i<4;i++) v.available[i]=true;
   v.value[ICT_A_PATH]=0.8; v.value[ICT_A_CANDLE]=0.5;
  }
public static void TestAnalyticalConsensus() {
   SICTAnalyticalContext c=new SICTAnalyticalContext(); SICTAnalyticalVotes v=new SICTAnalyticalVotes(); SICTAnalyticalConfig config=new SICTAnalyticalConfig(); SICTAnalyticalResult s=new SICTAnalyticalResult();
   AnalyticalFixture(c,v); ICTAnalyticalDefaults(config);
   Check("analysis defaults are valid",ICTAnalyticalValidConfig(config));
   Check("early analysis accepts partial evidence without requiring all six groups",ICTAnalyticalEvaluate(config,c,v,s) &&
      s.signal && s.groups==4 && s.supporters==2 && !s.deep_used && MathAbs(s.score-66.25)<1e-9);
   Check("analysis does not change native context",c.htf_bias==1 && c.mtf_bias==1 && c.asof==100300);
   config.minimum_score=70;
   Check("higher analysis threshold suppresses the same candidate",!ICTAnalyticalEvaluate(config,c,v,s) && !s.signal);
   config.minimum_score=60; config.require_deep=true;
   Check("explicit deep requirement withholds technical-only signals",!ICTAnalyticalEvaluate(config,c,v,s) && !s.deep_used);
   v.available[ICT_A_DEEP]=true; v.value[ICT_A_DEEP]=0.6;
   Check("validated deep evidence participates once",ICTAnalyticalEvaluate(config,c,v,s) && s.deep_used && s.groups==5 &&
      MathAbs(s.score-69)<1e-9);
   AnalyticalFixture(c,v); ICTAnalyticalDefaults(config); v.value[ICT_A_LIQUIDITY]=-1; v.value[ICT_A_ZONES]=-1;
   Check("opposing evidence reduces mean instead of disappearing",!ICTAnalyticalEvaluate(config,c,v,s) &&
      s.opponents==2 && s.score<50);
   AnalyticalFixture(c,v); v.available[ICT_A_LIQUIDITY]=false; v.available[ICT_A_ZONES]=false;
   Check("too little coverage cannot inflate the mean",!ICTAnalyticalEvaluate(config,c,v,s) && !s.ready && s.groups==2);
   AnalyticalFixture(c,v); v.value[ICT_A_CANDLE]=0;
   Check("one strong group cannot replace the supporting quorum",!ICTAnalyticalEvaluate(config,c,v,s) && s.supporters==1);
   AnalyticalFixture(c,v); v.value[ICT_A_PATH]=0; v.value[ICT_A_CANDLE]=0;
   Check("observed neutrality stays at fifty and creates no signal",!ICTAnalyticalEvaluate(config,c,v,s) && s.score==50);
   AnalyticalFixture(c,v); v.value[ICT_A_PATH]=0.4; v.value[ICT_A_CANDLE]=0.4;
   Check("inclusive score boundary is deterministic",ICTAnalyticalEvaluate(config,c,v,s) && MathAbs(s.score-60)<1e-9);
   AnalyticalFixture(c,v); c.htf_bias=-1; c.mtf_bias=-1; v.value[ICT_A_PATH]*=-1; v.value[ICT_A_CANDLE]*=-1;
   Check("bearish analysis is symmetric",ICTAnalyticalEvaluate(config,c,v,s) && s.direction==-1 && MathAbs(s.score-66.25)<1e-9);
   c.mtf_bias=1;
   Check("lower threshold never overrides opposite MTF",!ICTAnalyticalEvaluate(config,c,v,s) && !s.ready);
   c.mtf_bias=0;
   Check("neutral MTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   c.mtf_bias=-1; c.htf_bias=0;
   Check("neutral HTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.htf_closed=c.asof+1;
   Check("future HTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.mtf_closed=0;
   Check("missing MTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.ltf_closed=c.asof-1;
   Check("stale LTF remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.mtf=c.ltf;
   Check("duplicate tiers remain blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); c.valid=false;
   Check("invalid native context remains blocked",!ICTAnalyticalEvaluate(config,c,v,s));
   AnalyticalFixture(c,v); v.value[ICT_A_PATH]=1.01;
   Check("invalid evidence cannot be renormalized into a signal",!ICTAnalyticalEvaluate(config,c,v,s) && !s.signal);
   v.value[ICT_A_PATH]=0.8; config.minimum_groups=1;
   Check("invalid coverage configuration is rejected",!ICTAnalyticalEvaluate(config,c,v,s));
   ICTAnalyticalDefaults(config); config.minimum_supporters=4;
   Check("supporting quorum cannot exceed required coverage",!ICTAnalyticalValidConfig(config));
   ICTAnalyticalDefaults(config); config.minimum_score=50;
   Check("neutral-score threshold is not an analysis preset",!ICTAnalyticalValidConfig(config));
   int loose=0,strict=0;
   for(int i=0;i<=10;i++)
     {
      AnalyticalFixture(c,v); v.value[ICT_A_PATH]=i/10.0; v.value[ICT_A_CANDLE]=i/10.0;
      ICTAnalyticalDefaults(config); if(ICTAnalyticalEvaluate(config,c,v,s)) loose++;
      config.minimum_score=70; if(ICTAnalyticalEvaluate(config,c,v,s)) strict++;
     }
   Check("lower advisory threshold increases coverage on the fixed synthetic cohort",loose==7 && strict==3);
  }
public static void TestAnalyticalCausalityAndDeep() {
   MqlRates[] bars=InitArray<MqlRates>(0); ArrayResize(ref bars,40);
   for(int i=0;i<40;i++) FixtureBar(bars[i],100000+i*300,100+i*0.2,100.5+i*0.2,99.8+i*0.2,100.3+i*0.2);
   long asof=bars[39].time+300; SICTAnalyticalVotes v=new SICTAnalyticalVotes(); ZeroMemory(v); double atr=0;
   Check("closed price path produces two bounded groups",ICTAnalyticalPriceVotes(bars,PERIOD_M5,asof,0.01,v,ref atr) &&
      v.available[ICT_A_PATH] && v.available[ICT_A_CANDLE] && MathAbs(v.value[ICT_A_PATH])<=1 && MathAbs(v.value[ICT_A_CANDLE])<=1);
   double path=v.value[ICT_A_PATH],candle=v.value[ICT_A_CANDLE];
   ArrayResize(ref bars,41); FixtureBar(bars[40],asof,1,9999,0,5000);
   Check("invalid unfinished future bar cannot change past evidence",ICTAnalyticalPriceVotes(bars,PERIOD_M5,asof,0.01,v,ref atr) &&
      MathAbs(v.value[ICT_A_PATH]-path)<1e-9 && MathAbs(v.value[ICT_A_CANDLE]-candle)<1e-9);
   Check("stale price prefix is not current analysis",!ICTAnalyticalPriceVotes(bars,PERIOD_M5,asof-1,0.01,v,ref atr));
   ICTAnalyticalPriceVotes(bars,PERIOD_M5,asof,0.01,v,ref atr);
   SICTStatModel model=new SICTStatModel(); SICTStatSnapshot stat=new SICTStatSnapshot(); ZeroMemory(model); ZeroMemory(stat);
   model.fitted=true; model.calibrated=true; model.train_end=bars[5].time; model.cal_end=bars[15].time; model.test_end=bars[30].time;
   for(int i=0;i<ICT_STAT_FEATURES;i++) model.scale[i]=100;
   stat.ready=true; stat.calibrated=true; stat.horizon=4; stat.asof=bars[39].time;
   stat.dl[0]=0.7; stat.dl[1]=0.2; stat.dl[2]=0.1; stat.brier_dl=0.4; stat.brier_baseline=0.6;
   Check("calibrated current DNN contributes its directional probability difference",
      ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v) && MathAbs(v.value[ICT_A_DEEP]-0.5)<1e-9);
   Check("DNN from a different timeframe is excluded",
      !ICTAnalyticalDeepVote(model,stat,bars,PERIOD_H1,PERIOD_M5,asof,0.01,v) && !v.available[ICT_A_DEEP]);
   stat.asof-=300;
   Check("stale DNN is excluded",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   stat.asof+=600;
   Check("future DNN is excluded",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   stat.asof=bars[39].time; model.calibrated=false;
   Check("uncalibrated DNN is excluded",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   model.calibrated=true; stat.brier_dl=0.6;
   Check("DNN must beat baseline in its own metric",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   SICTAnalyticalDeepState advisory=new SICTAnalyticalDeepState();
   Check("calibrated non-winning DNN is explicitly experimental in early mode",
      ICTAnalyticalDeepEvidence(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,advisory,v) &&
      advisory.ready && !advisory.validated && advisory.weight==0.35);
   stat.brier_dl=0.4; model.test_end=asof;
   Check("future evaluation labels cannot admit DNN",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   Check("early experimental mode still rejects future evaluation labels",
      !ICTAnalyticalDeepEvidence(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,advisory,v));
   model.test_end=bars[30].time; model.mean[0]=1000000; model.scale[0]=1;
   Check("result_out of domain features cannot admit DNN",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   Check("early domain warning is explicit and receives experimental weight",
      ICTAnalyticalDeepEvidence(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,advisory,v) && !advisory.domain_ok && !advisory.validated);
   model.mean[0]=0; model.scale[0]=100; stat.dl[2]=0.9;
   Check("invalid probability mass cannot admit DNN",!ICTAnalyticalDeepVote(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,v));
   Check("early experimental mode never accepts invalid probability mass",
      !ICTAnalyticalDeepEvidence(model,stat,bars,PERIOD_M5,PERIOD_M5,asof,0.01,advisory,v));
   SICTRangeSnapshot r=new SICTRangeSnapshot(); ZeroMemory(r); r.symbol="TEST"; r.valid=true; r.as_of=asof; r.ltf=PERIOD_M5;
   r.liquidity_event_count=1; r.liquidity_events[0].side=-1; r.liquidity_events[0].type=IR_EVENT_LIQUIDITY_SWEEP;
   r.liquidity_events[0].confirmed_at=asof;
   ZeroMemory(v); ICTAnalyticalLiquidityVote(r,"TEST",asof,PERIOD_M5,12,v);
   Check("native SSL reclaim supports bullish analysis",v.available[ICT_A_LIQUIDITY] && v.value[ICT_A_LIQUIDITY]==1);
   r.liquidity_event_count=2; r.liquidity_events[1].side=1;
   r.liquidity_events[1].type=IR_EVENT_LIQUIDITY_SWEEP; r.liquidity_events[1].confirmed_at=asof;
   ICTAnalyticalLiquidityVote(r,"TEST",asof,PERIOD_M5,12,v);
   Check("simultaneous opposing native events cancel",v.value[ICT_A_LIQUIDITY]==0);
   r.liquidity_event_count=1; r.liquidity_events[0].confirmed_at=asof+1;
   ICTAnalyticalLiquidityVote(r,"TEST",asof,PERIOD_M5,12,v);
   Check("future native evt cannot support analysis",v.value[ICT_A_LIQUIDITY]==0);
   r.as_of--; ZeroMemory(v); ICTAnalyticalLiquidityVote(r,"TEST",asof,PERIOD_M5,12,v);
   Check("stale native liquidity is missing rather than neutral",!v.available[ICT_A_LIQUIDITY]);
   r.as_of=asof; r.range.id="R"; r.zone_count=1; r.zones[0].range_id="R";
   r.zones[0].direction=1; r.zones[0].lower=bars[39].low; r.zones[0].upper=bars[39].close;
   r.zones[0].quality=80; r.zones[0].state=IR_FRESH; r.zones[0].confirmed_at=bars[38].time;
   ZeroMemory(v); ICTAnalyticalRangeZonesVote(r,"TEST",asof,bars[39],atr,v);
   Check("closed reaction to an available native zone supports analysis",v.available[ICT_A_ZONES] && v.value[ICT_A_ZONES]>0.8);
   double zone_score=v.value[ICT_A_ZONES]; r.zone_count=2;
   r.zones[1].range_id="R"; r.zones[1].direction=1; r.zones[1].lower=bars[39].low; r.zones[1].upper=bars[39].close;
   r.zones[1].quality=80; r.zones[1].state=IR_FRESH; r.zones[1].confirmed_at=bars[38].time;
   ICTAnalyticalRangeZonesVote(r,"TEST",asof,bars[39],atr,v);
   Check("duplicated zones do not multiply a family vote",MathAbs(v.value[ICT_A_ZONES]-zone_score)<1e-9);
   r.zone_count=1; r.zones[0].state=IR_ZONE_INVALIDATED; ICTAnalyticalRangeZonesVote(r,"TEST",asof,bars[39],atr,v);
   Check("invalidated zones do not support analysis",v.value[ICT_A_ZONES]==0);
   r.zones[0].state=IR_FRESH; r.zones[0].confirmed_at=asof;
   ICTAnalyticalRangeZonesVote(r,"TEST",asof,bars[39],atr,v);
   Check("zone created at the reaction close cannot be a prior retest",v.value[ICT_A_ZONES]==0);
   SICTUnifiedSnapshot u=new SICTUnifiedSnapshot(); ZeroMemory(u); u.valid=true; u.symbol="TEST"; u.asof=asof;
   u.layer_count=1; u.layers[0].last_close=asof; u.comparison1="PEER";
   u.layers[0].peers[0].comparison="PEER"; u.layers[0].peers[0].last_close=asof;
   u.layers[0].peers[0].ready=true; u.layers[0].peers[0].relation_known=true;
   u.layers[0].peers[0].state=ICT_SMT_PEER_BEARISH;
   ZeroMemory(v); ICTAnalyticalUnifiedVotes(u,bars[39],atr,v);
   Check("opposite SMT remains negative evidence",v.available[ICT_A_SMT] && v.value[ICT_A_SMT]==-1);
   u.layers[0].peers[0].ready=false; ZeroMemory(v); ICTAnalyticalUnifiedVotes(u,bars[39],atr,v);
   Check("unavailable SMT is not counted as no divergence",!v.available[ICT_A_SMT]);
  }
public static void RunICTAnalyticalFixtures() { TestAnalyticalConsensus(); TestAnalyticalCausalityAndDeep(); TestAnalyticalEarlyPolicy(); }

public static void TestAnalyticalEarlyPolicy() {
   SICTAnalyticalContext c=new SICTAnalyticalContext(); SICTAnalyticalVotes v=new SICTAnalyticalVotes(); AnalyticalFixture(c,v);
   SICTAnalyticalPolicy p=new SICTAnalyticalPolicy(); ICTAnalyticalPolicyDefaults(p); SICTAnalyticalResult result=new SICTAnalyticalResult();
   SICTAnalyticalDeepState deep=new SICTAnalyticalDeepState(); ZeroMemory(deep); deep.ready=true; deep.validated=true; deep.domain_ok=true;
   deep.weight=1; deep.direction=1; deep.probability[0]=0.6; deep.probability[1]=0.2; deep.probability[2]=0.2;
   v.available[ICT_A_DEEP]=true; v.value[ICT_A_DEEP]=0.4;
   Check("early defaults request actual DL with a lower advisory threshold",ICTAnalyticalPolicyValid(p) && p.require_deep &&
      p.minimum_score==55 && p.minimum_groups==2 && p.minimum_supporters==1);
   Check("current trained DL plus price produces analysis",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) && result.deep_used);
   c.htf_bias=0; c.mtf_bias=0;
   Check("neutral native MTF can accompany explicitly early DL",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) && !result.context_aligned);
   Check("strict native context still rejects the same neutral tiers",!ICTAnalyticalContextReady(c));
   c.htf_bias=1; c.mtf_bias=-1;
   Check("conflicting MTF is disclosed rather than preventing all DL analysis",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) &&
      !result.context_aligned && StringFind(result.reason,"chưa xác nhận")>=0);
   p.strict_context=true;
   Check("optional strict early mode keeps the original MTF veto",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   p.strict_context=false; c.mtf_closed=0; c.htf_closed=0; c.htf_bias=0; c.mtf_bias=0;
   Check("missing upper structure does not pretend alignment",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) && !result.context_aligned);
   c.htf_closed=c.asof+1;
   Check("future upper timestamps still reject early analysis",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   c.htf_closed=0; c.ltf_closed=c.asof-1;
   Check("stale LTF still rejects early analysis",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   c.ltf_closed=c.asof; deep.ready=false;
   Check("required DL cannot be replaced by technical heuristics",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   deep.ready=true; deep.direction=0;
   Check("neutral dominant DNN does not become a directional arrow",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   deep.direction=1; v.value[ICT_A_DEEP]=0.03;
   Check("nearly tied DNN directions remain a watch state",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   v.value[ICT_A_DEEP]=0.4; deep.validated=false; deep.weight=0.35;
   Check("experimental DL is explicitly identified",ICTAnalyticalEvaluateEarly(p,c,v,deep,result) && result.experimental);
   double experimental_score=result.score; deep.validated=true; deep.weight=1;
   ICTAnalyticalEvaluateEarly(p,c,v,deep,result);
   Check("experimental evidence receives a score discount",experimental_score<result.score);
   deep.validated=false; deep.weight=0.35; p.allow_experimental=false;
   Check("experimental DL can be excluded without changing native rules",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   p.allow_experimental=true; v.value[ICT_A_PATH]=-0.8; v.value[ICT_A_CANDLE]=-0.5;
   Check("price opposition still defeats a weak experimental DNN",!ICTAnalyticalEvaluateEarly(p,c,v,deep,result));
   v.value[ICT_A_PATH]=0.8; v.value[ICT_A_CANDLE]=0.5; v.value[ICT_A_LIQUIDITY]=0; v.value[ICT_A_ZONES]=0;
   ICTAnalyticalEvaluateEarly(p,c,v,deep,result); double neutral_score=result.score;
   v.available[ICT_A_LIQUIDITY]=false; v.available[ICT_A_ZONES]=false;
   ICTAnalyticalEvaluateEarly(p,c,v,deep,result);
   Check("observed no-evt groups do not dilute directional evidence",MathAbs(result.score-neutral_score)<1e-9 && result.groups==3);
   Check("early analysis never alters the original context",c.htf_bias==0 && c.mtf_bias==0 && c.asof==100300);
  }


public class SICTChartRect {
public int left;
public int top;
public int right;
public int bottom;
}

public class SICTChartZone {
public long first;
public long last;
public double low;
public double high;
}

public static bool ICTChartRectOverlap(SICTChartRect a,SICTChartRect b) { return a.left<b.right && b.left<a.right && a.top<b.bottom && b.top<a.bottom; }
public static bool ICTChartRectTooClose(SICTChartRect a,SICTChartRect b,int gap) {
   return a.left<b.right+gap && b.left<a.right+gap &&
          a.top<b.bottom+gap && b.top<a.bottom+gap;
  }
public static bool ICTChartFindLabelRect(int x,int y,int width,int height,int chart_width,int chart_height,SICTChartRect[] occupied,SICTChartRect result) {
   if(width<=0 || height<=0 || chart_width<=0 || chart_height<=0) return false;
   for(int lane=0;lane<7;lane++)
      for(int side=0;side<2;side++)
        {
         int offset=(lane==0 ? 0 : ((lane+1)/2)*(height+4)*(lane%2==1 ? -1 : 1));
         SICTChartRect candidate=new SICTChartRect();
         candidate.left=(side==0 ? x+5 : x-width-5); candidate.top=y+offset-height/2;
         candidate.right=candidate.left+width; candidate.bottom=candidate.top+height;
         if(candidate.left<2 || candidate.right>chart_width-2 ||
            candidate.top<2 || candidate.bottom>chart_height-2) continue;
         bool collision=false;
         for(int j=0;j<ArraySize(occupied);j++)
            if(ICTChartRectTooClose(candidate,occupied[j],4)) { collision=true; break; }
         if(collision) continue;
         result.left=candidate.left; result.top=candidate.top;
         result.right=candidate.right; result.bottom=candidate.bottom;
         return true;
        }
   return false;
  }
public static bool ICTChartZoneOverlap(long first,long last,double low,double high,long other_first,long other_last,double other_low,double other_high) { return first<other_last && other_first<last && low<other_high && other_low<high; }
public static int ICTChartScaledFontSize(int base_size) { return (int)MathMax(1,MathRound((double)base_size*0.75)); }
public static void ICTChartLayoutBegin(string prefix,int zone_tf,int font_size) {
   g_ict_chart_prefix=prefix; g_ict_chart_zone_tf=zone_tf; g_ict_chart_font=font_size;
   ArrayResize(ref g_ict_chart_zones,0); g_ict_chart_zone_suppressed=0; g_ict_chart_collect=true;
  }
public static bool ICTChartZoneTimeframe(int tf) { return !g_ict_chart_collect || tf==g_ict_chart_zone_tf; }
public static bool ICTChartReserveZone(int tf,long first,long last,double low,double high) {
   if(!g_ict_chart_collect) return true;
   if(tf!=g_ict_chart_zone_tf || first<=0 || last<=first || low<=0 || high<=low) return false;
   for(int i=0;i<ArraySize(g_ict_chart_zones);i++)
      if(ICTChartZoneOverlap(first,last,low,high,g_ict_chart_zones[i].first,g_ict_chart_zones[i].last,
                             g_ict_chart_zones[i].low,g_ict_chart_zones[i].high))
        { g_ict_chart_zone_suppressed++; return false; }
   int n=ArraySize(g_ict_chart_zones); ArrayResize(ref g_ict_chart_zones,n+1);
   g_ict_chart_zones[n].first=first; g_ict_chart_zones[n].last=last;
   g_ict_chart_zones[n].low=low; g_ict_chart_zones[n].high=high;
   return true;
  }
public static double ICTChartChannel(int channel) { double v=channel/255.0; return v<=0.04045 ? v/12.92 : MathPow((v+0.055)/1.055,2.4); }
public static double ICTChartLuminance(int value) {
   int c=(int)value;
   return 0.2126*ICTChartChannel(c&255)+0.7152*ICTChartChannel((c>>8)&255)+0.0722*ICTChartChannel((c>>16)&255);
  }
public static double ICTChartContrast(int a,int b) {
   double x=ICTChartLuminance(a),y=ICTChartLuminance(b);
   return (MathMax(x,y)+0.05)/(MathMin(x,y)+0.05);
  }
public static int ICTChartReadableColor(int ink,int background,bool dark) {
   int c=(int)ink,r=c&255,g=(c>>8)&255,b=(c>>16)&255;
   int result=ink;
   for(int i=0;i<20 && ICTChartContrast(result,background)<4.5;i++)
     {
      int target=dark ? 255 : 0;
      r=(int)MathRound(r+(target-r)*0.2); g=(int)MathRound(g+(target-g)*0.2); b=(int)MathRound(b+(target-b)*0.2);
      result=(int)(r|(g<<8)|(b<<16));
     }
   return result;
  }
public static string ICTDashboardText(string source) {
   if(source=="") return "--";
   if(source=="N/A" || source=="unavailable" || source=="UNAVAILABLE") return "Chưa có";
   if(source=="DISABLED") return "Đã tắt";
   if(source=="RELATION_UNKNOWN") return "Chưa rõ tương quan";
   if(source=="NO COMPARATOR") return "Chưa có mã so sánh";
   if(source=="CONFIRMED PIVOT REPLAY") return "Đã xác nhận điểm xoay";
   if(source=="CONFIRMED PIVOT") return "Đã xác nhận điểm xoay";
   if(source=="INSUFFICIENT_DATA" || source=="DATA INSUFFICIENT") return "Không đủ dữ liệu";
   if(source=="BULLISH") return "Tăng";
   if(source=="BEARISH") return "Giảm";
   if(source=="NEUTRAL" || source=="neutral") return "Trung tính";
   if(source=="UNKNOWN" || source=="Unknown") return "Chưa rõ";
   if(source=="NONE" || source=="none") return "Không có";
   if(source=="PREMIUM") return "Vùng giá cao (Premium)";
   if(source=="DISCOUNT") return "Vùng giá thấp (Discount)";
   if(source=="EQUILIBRIUM") return "Điểm cân bằng";
   if(source=="OUTSIDE") return "Ngoài vùng giá";
   if(source=="Fresh") return "Chưa chạm";
   if(source=="BREAKER") return "Breaker (vùng đảo chiều)";
   if(source=="Touched/partial") return "Đã chạm một phần";
   if(source=="Fully mitigated/expired") return "Đã lấp hết / hết hạn";
   if(source=="Invalidated") return "Đã mất hiệu lực";
   if(source=="RANGE_IDENTIFIED") return "Đã xác định vùng giá";
   if(source=="ERL_APPROACH") return "Đang tiến tới ERL";
   if(source=="ERL_SWEEP_CANDIDATE") return "Có dấu hiệu quét ERL";
   if(source=="ERL_SWEEP_CONFIRMED") return "Đã xác nhận quét ERL";
   if(source=="STRUCTURE_SHIFT_CONFIRMED") return "Đã xác nhận chuyển cấu trúc";
   if(source=="IRL_RETRACEMENT") return "Đang hồi về IRL";
   if(source=="IRL_REACTION_CONFIRMED") return "Đã xác nhận phản ứng tại IRL";
   if(source=="ERL_TARGETING") return "Đang hướng tới ERL";
   if(source=="TARGET_REACHED") return "Đã chạm mục tiêu";
   if(source=="SETUP_INVALIDATED") return "Thiết lập đã mất hiệu lực";
   if(source=="UNTOUCHED") return "Chưa chạm";
   if(source=="APPROACHING") return "Đang tiến gần";
   if(source=="SWEPT") return "Đã quét";
   if(source=="BREAKOUT") return "Đã phá vỡ";
   if(source=="CONSUMED") return "Đã sử dụng";
   if(source=="INVALIDATED") return "Đã mất hiệu lực";
   if(source=="LIQUIDITY_SWEEP") return "Quét thanh khoản";
   if(source=="BREAKOUT_CONFIRMED") return "Đã xác nhận phá vỡ";
   if(source=="FALSE_BREAKOUT") return "Phá vỡ giả";
   if(source=="RETEST_CONFIRMED") return "Đã xác nhận kiểm tra lại";
   if(source=="LIQUIDITY_SWEEP / MSS") return "Quét thanh khoản / MSS";
   if(source=="BREAKOUT_CONFIRMED / RETEST") return "Phá vỡ đã xác nhận / kiểm tra lại";
   if(source=="MTF SETUP / LTF RETEST") return "Thiết lập MTF / kiểm tra lại LTF";
   if(source=="STRONG") return "Mạnh";
   if(source=="MODERATE") return "Trung bình";
   if(source=="WEAK") return "Yếu";
   if(source=="CANDIDATE") return "Đang hình thành";
   if(source=="CONFIRMED") return "Đã xác nhận";
   if(source=="ACTIVE") return "Đang hoạt động";
   if(source=="TOUCHED") return "Đã chạm";
   if(source=="PARTIALLY MITIGATED") return "Đã lấp một phần";
   if(source=="MITIGATED") return "Đã lấp";
   if(source=="EXPIRED") return "Hết hạn";
   if(source=="Weekend") return "Cuối tuần";
   if(source=="London kill zone") return "Khung giờ trọng điểm London";
   if(source=="New York AM kill zone") return "Khung giờ trọng điểm New York sáng";
   if(source=="New York PM kill zone") return "Khung giờ trọng điểm New York chiều";
   if(source=="London/Asia transition") return "Chuyển phiên Á / London";
   if(source=="New York midday") return "Giữa phiên New York";
   if(source=="London close/NY late") return "Đóng cửa London / cuối phiên New York";
   if(source=="Asia") return "Phiên Á";

   string text=source;
   StringReplace(ref text,"DATA INSUFFICIENT: three closed timeframe tiers required","Không đủ dữ liệu: cần ba khung thời gian có nến đóng");
   StringReplace(ref text,"DATA INSUFFICIENT: three independent tiers required for confirmation","Không đủ dữ liệu: cần ba khung độc lập để xác nhận");
   StringReplace(ref text,"NO_TRADE: HTF bias / MTF setup / LTF execution direction conflict","Không giao dịch: xu hướng HTF, thiết lập MTF và hướng LTF xung đột");
   StringReplace(ref text,"NO_TRADE: HTF bias / MTF setup conflict or missing","Không giao dịch: thiếu hoặc xung đột xu hướng HTF / thiết lập MTF");
   StringReplace(ref text,"NO_TRADE: required SMT unavailable, conflicting or unaligned","Không giao dịch: SMT bắt buộc không có dữ liệu, xung đột hoặc không cùng hướng");
   StringReplace(ref text,"NO_TRADE: live plan differs from committed signal or failed recheck","Không giao dịch: kế hoạch hiện tại khác tín hiệu đã lưu hoặc không vượt kiểm tra lại");
   StringReplace(ref text,"NO_TRADE: confirmed signal journal unavailable","Không giao dịch: không đọc được nhật ký tín hiệu đã xác nhận");
   StringReplace(ref text,"WATCH: waiting for a valid closed LTF trigger","Theo dõi: chờ tín hiệu LTF hợp lệ trên nến đã đóng");
   StringReplace(ref text,"RISK FILTER FAIL: invalid plan or net RR below configured minimum","Bộ lọc rủi ro không đạt: kế hoạch không hợp lệ hoặc RR ròng dưới mức tối thiểu");
   StringReplace(ref text,"RISK FILTER FAIL on live recheck; historical ","Kiểm tra rủi ro hiện tại không đạt; tín hiệu lịch sử ");
   StringReplace(ref text," unchanged"," giữ nguyên");
   StringReplace(ref text,"BUY_CONFIRMED","MUA ĐÃ XÁC NHẬN");
   StringReplace(ref text,"SELL_CONFIRMED","BÁN ĐÃ XÁC NHẬN");
   StringReplace(ref text,"WATCH_BUY","THEO DÕI MUA");
   StringReplace(ref text,"WATCH_SELL","THEO DÕI BÁN");
   StringReplace(ref text,"NO_TRADE","KHÔNG GIAO DỊCH");
   StringReplace(ref text,"TARGET UNAVAILABLE: no fresh same-range ERL or retained LTF coverage incomplete","Chưa có mục tiêu: không có ERL mới cùng vùng hoặc lịch sử LTF chưa đủ");
   StringReplace(ref text,"TARGET UNAVAILABLE: source breakout failed; ","Chưa có mục tiêu: phá vỡ tại nguồn thất bại; ");
   StringReplace(ref text,"TARGET UNAVAILABLE","Chưa có mục tiêu");
   StringReplace(ref text,"INSUFFICIENT_DATA: one or more mapped tiers lack closed confirmed history","Không đủ dữ liệu: một hoặc nhiều khung thiếu lịch sử nến đóng đã xác nhận");
   StringReplace(ref text,"INSUFFICIENT_DATA: decision and shared snapshot timestamps differ","Không đủ dữ liệu: thời điểm quyết định và dữ liệu tổng hợp khác nhau");
   StringReplace(ref text,"INSUFFICIENT_DATA: no MTF structure closed by the LTF snapshot","Không đủ dữ liệu: chưa có cấu trúc MTF đóng tại thời điểm LTF");
   StringReplace(ref text,"INSUFFICIENT_DATA: waiting for closed history (","Đang tải lịch sử nến đóng (cần ");
   StringReplace(ref text," bars)"," nến)");
   StringReplace(ref text,"INSUFFICIENT_DATA: confirmed swings missing","Chưa đủ đỉnh/đáy đã xác nhận");
   StringReplace(ref text,"INSUFFICIENT_DATA: chart display window history missing","Không đủ dữ liệu: thiếu lịch sử trong cửa sổ biểu đồ");
   StringReplace(ref text,"INSUFFICIENT_DATA: no closed chart candle","Không đủ dữ liệu: chưa có nến biểu đồ đóng");
   StringReplace(ref text,"INSUFFICIENT_DATA: symbol tick size missing","Không đủ dữ liệu: thiếu bước giá của mã");
   StringReplace(ref text,"INSUFFICIENT_DATA: primary history","Không đủ dữ liệu lịch sử của mã chính");
   StringReplace(ref text,"INSUFFICIENT_DATA: comparator history","Không đủ dữ liệu lịch sử của mã so sánh");
   StringReplace(ref text,"INSUFFICIENT_DATA: comparator tick size","Không đủ dữ liệu bước giá của mã so sánh");
   StringReplace(ref text,"INSUFFICIENT_DATA: timestamps not aligned","Không đủ dữ liệu: thời gian hai mã chưa khớp");
   StringReplace(ref text,"N/A: comparator unavailable","Chưa có mã so sánh");
   StringReplace(ref text,"PARTIAL: unavailable peer; available peer retained","Dữ liệu một phần: giữ mã so sánh có dữ liệu");
   StringReplace(ref text,"SMT_CONFLICT: both live directions","SMT xung đột: có tín hiệu theo cả hai hướng");
   StringReplace(ref text,"NONE: no active divergence","Không có phân kỳ đang hoạt động");
   StringReplace(ref text,"UNAVAILABLE: shared snapshot invalid","Không có dữ liệu: ảnh chụp phân tích không hợp lệ");
   StringReplace(ref text,"UNKNOWN: decision direction unavailable","Chưa rõ: chưa xác định được hướng quyết định");
   StringReplace(ref text,"UNAVAILABLE: SMT analysis disabled or no timeframe","Không có dữ liệu: phân tích SMT đã tắt hoặc thiếu khung thời gian");
   StringReplace(ref text,"CONFLICT: opposing active divergences","Xung đột: có các phân kỳ ngược hướng");
   StringReplace(ref text,"ALIGNED: active divergence supports direction","Cùng hướng: phân kỳ đang ủng hộ hướng phân tích");
   StringReplace(ref text,"OPPOSITE: active divergence opposes direction","Ngược hướng: phân kỳ không ủng hộ hướng phân tích");
   StringReplace(ref text,"UNAVAILABLE: no usable comparator data","Không có dữ liệu mã so sánh sử dụng được");
   StringReplace(ref text," (some peer data unavailable)"," (thiếu dữ liệu một số mã so sánh)");
   StringReplace(ref text," | optional, no veto"," | tùy chọn, không phủ quyết");
   StringReplace(ref text," | required"," | bắt buộc");
   StringReplace(ref text,": configured comparator unavailable",": mã so sánh đã cấu hình không khả dụng");
   StringReplace(ref text,"Duplicate comparator slot disabled","Đã tắt mã so sánh trùng lặp");
   StringReplace(ref text,"SMT evt capacity reached; no candidate until history is reviewed","Đã đầy lịch sử sự kiện SMT; cần kiểm tra lịch sử trước khi xét tín hiệu mới");
   StringReplace(ref text,"OB capacity reached; no candidate until history is reviewed","Đã đầy lịch sử OB; cần kiểm tra lịch sử trước khi xét tín hiệu mới");
   StringReplace(ref text,"Invalid unified settings","Cấu hình phân tích tổng hợp không hợp lệ");
   StringReplace(ref text,"Closed as-of shared snapshot","Dữ liệu tổng hợp tại thời điểm nến đóng");
   StringReplace(ref text,"SMT payload journal corrupt/unavailable: frozen confirmation history cannot be restored","Nhật ký SMT bị lỗi hoặc không khả dụng; không thể khôi phục lịch sử xác nhận");
   StringReplace(ref text,"SMT payload journal commit failed: uncommitted history is unavailable","Không thể lưu nhật ký SMT; lịch sử chưa được lưu không khả dụng");
   StringReplace(ref text,"evt journal unavailable; history retention cannot be guaranteed","Nhật ký sự kiện không khả dụng; không thể bảo đảm lưu lịch sử");
   StringReplace(ref text,"TWO TIER CONTEXT: no HTF; MTF is upper context","Bối cảnh hai khung: không có HTF; dùng MTF làm bối cảnh lớn");
   StringReplace(ref text,"ONE TIER CONTEXT: advisory entry disabled","Bối cảnh một khung: tắt đề xuất vào lệnh");
   StringReplace(ref text,"Reduced-tier context available; waiting for a supported execution/risk plan","Chỉ có bối cảnh ít khung; chờ kế hoạch vào lệnh và rủi ro phù hợp");
   StringReplace(ref text,"Upper timeframe bias NEUTRAL","Xu hướng khung lớn trung tính");
   StringReplace(ref text,"Risk Manager veto: invalid plan or net RR below 1:2","Bộ quản lý rủi ro từ chối: kế hoạch không hợp lệ hoặc RR ròng dưới 1:2");
   StringReplace(ref text,"WAIT: legacy OB entry is not an active shared OB with valid hard gates","Chờ: vùng vào OB chưa hoạt động hoặc chưa đạt điều kiện bắt buộc");
   StringReplace(ref text,"WAIT: MTF structure neutral/counter-trend or LTF setup conflicts with HTF","Chờ: cấu trúc MTF trung tính / ngược xu hướng hoặc LTF xung đột HTF");
   StringReplace(ref text,"Waiting for two confirmed sweeps of the same active pool","Chờ hai lần quét đã xác nhận tại cùng một vùng thanh khoản");
   StringReplace(ref text,"HTF bias neutral","Xu hướng HTF trung tính");
   StringReplace(ref text,"bias missing/conflict","thiếu hoặc xung đột xu hướng");
   StringReplace(ref text,"setup missing/conflict","thiếu hoặc xung đột thiết lập");
   StringReplace(ref text,"bullish structure + valid zone","cấu trúc tăng và vùng giá hợp lệ");
   StringReplace(ref text,"bearish structure + valid zone","cấu trúc giảm và vùng giá hợp lệ");
   StringReplace(ref text,"neutral structure + valid zone","cấu trúc trung tính và vùng giá hợp lệ");
   StringReplace(ref text,"bullish bias","xu hướng tăng");
   StringReplace(ref text,"bearish bias","xu hướng giảm");
   StringReplace(ref text,"neutral bias","xu hướng trung tính");
   StringReplace(ref text,"closed zone reaction after setup displacement","nến đóng phản ứng tại vùng sau dịch chuyển giá");
   StringReplace(ref text,"closed zone reaction after MSS and displacement","nến đóng phản ứng tại vùng sau MSS và dịch chuyển giá");
   StringReplace(ref text,"closed reaction / setup chronology missing","thiếu phản ứng nến đóng hoặc trình tự thiết lập");
   StringReplace(ref text,"HTF PERIOD_","HTF ");
   StringReplace(ref text,"MTF PERIOD_","MTF ");
   StringReplace(ref text,"LTF PERIOD_","LTF ");
   StringReplace(ref text,"Insufficient confirmed evidence","Chưa đủ tín hiệu đã xác nhận");
   StringReplace(ref text,"Invalid confluence configuration","Cấu hình hợp lưu không hợp lệ");
   StringReplace(ref text,"Invalid configuration","Cấu hình không hợp lệ");
   StringReplace(ref text,"Missing, duplicate or invalid closed candles","Thiếu, trùng hoặc có nến đóng không hợp lệ");
   StringReplace(ref text,"Required D1 structure unavailable","Chưa có cấu trúc D1 bắt buộc");
   StringReplace(ref text,"Higher-timeframe structure unavailable","Chưa có cấu trúc khung thời gian lớn");
   StringReplace(ref text,"Severe D1/HTF/LTF structure conflict","Cấu trúc D1 / HTF / LTF xung đột nghiêm trọng");
   StringReplace(ref text,"HTF bias is neutral","Xu hướng HTF trung tính");
   StringReplace(ref text,"Quote unavailable, inverted, future or stale","Báo giá thiếu, giá mua / bán bị đảo, sai thời gian hoặc đã cũ");
   StringReplace(ref text,"Invalid symbol specification","Thông số mã giao dịch không hợp lệ");
   StringReplace(ref text,"No eligible DOL target","Không có mục tiêu DOL phù hợp");
   StringReplace(ref text,"Liquidity history unavailable","Chưa có lịch sử thanh khoản");
   StringReplace(ref text,"Incomplete sweep history","Lịch sử quét thanh khoản chưa đầy đủ");
   StringReplace(ref text,"Awaiting aligned confirmed liquidity sweep","Chờ quét thanh khoản đã xác nhận và cùng hướng");
   StringReplace(ref text,"Sweep expired","Tín hiệu quét đã hết hạn");
   StringReplace(ref text,"Awaiting post-sweep MSS","Chờ MSS sau khi quét thanh khoản");
   StringReplace(ref text,"ATR unavailable","Chưa có ATR");
   StringReplace(ref text,"Awaiting post-MSS active FVG or Order Block","Chờ FVG hoặc OB còn hiệu lực sau MSS");
   StringReplace(ref text,"Awaiting post-MSS active Order Block","Chờ OB còn hiệu lực sau MSS");
   StringReplace(ref text,"Entry zone expired","Vùng vào lệnh đã hết hạn");
   StringReplace(ref text,"OB displacement not confirmed","Chưa xác nhận dịch chuyển giá của OB");
   StringReplace(ref text,"Displacement not confirmed","Chưa xác nhận dịch chuyển giá");
   StringReplace(ref text,"FVG outside discount/premium","FVG nằm ngoài vùng giá cao / thấp phù hợp");
   StringReplace(ref text,"Awaiting FVG retest","Chờ giá kiểm tra lại FVG");
   StringReplace(ref text,"Awaiting Order Block retest","Chờ giá kiểm tra lại OB");
   StringReplace(ref text,"Entry/stop/target geometry invalid","Vị trí vào lệnh / dừng lỗ / mục tiêu không hợp lệ");
   StringReplace(ref text,"Matching account position is active","Đã có vị thế tương ứng trên tài khoản");
   StringReplace(ref text,"Protection offline, unhealthy, disabled or locked","Bảo vệ đang ngoại tuyến, gặp lỗi, bị tắt hoặc khóa");
   StringReplace(ref text,"Protection offline, unhealthy or locked","Bảo vệ đang ngoại tuyến, gặp lỗi hoặc bị khóa");
   StringReplace(ref text,"Spread exceeds limit","Chênh lệch giá vượt giới hạn");
   StringReplace(ref text,"Daily loss limit or account history unavailable","Vượt giới hạn lỗ ngày hoặc không có lịch sử tài khoản");
   StringReplace(ref text,"Daily loss gate or deal history unavailable","Điều kiện lỗ ngày không đạt hoặc không có lịch sử giao dịch");
   StringReplace(ref text,"Confirmed sweep, MSS, displacement, entry-zone retest, DOL and risk gates","Đã xác nhận quét, MSS, dịch chuyển giá, kiểm tra lại vùng vào, DOL và rủi ro");
   StringReplace(ref text,"Mandatory SMT/session evidence missing","Thiếu xác nhận SMT / phiên giao dịch bắt buộc");
   StringReplace(ref text,"Missing required evidence, score threshold or directional conflict","Thiếu xác nhận, chưa đạt điểm tối thiểu hoặc có xung đột hướng");
   StringReplace(ref text,"Optional SMT absent/unavailable/unaligned; no SMT points","SMT tùy chọn không có hoặc không cùng hướng; không cộng điểm SMT");
   StringReplace(ref text,"SMT absent/unavailable/unaligned; no SMT points awarded","SMT không có hoặc không cùng hướng; không cộng điểm SMT");
   StringReplace(ref text,"Closed chronological HTF/MTF/LTF range snapshot","Dữ liệu vùng HTF / MTF / LTF theo thứ tự nến đóng");
   StringReplace(ref text,"Closed-bar inputs available; session uses explicit UTC conversion in Tester","Đã có dữ liệu nến đóng; phiên giao dịch dùng chuyển đổi UTC trong Tester");
   StringReplace(ref text,"Missing or invalid inputs; see reason and evidence masks","Dữ liệu đầu vào thiếu hoặc không hợp lệ; xem lý do và bằng chứng");
   StringReplace(ref text,"Invalid range settings/tick","Cấu hình vùng giá hoặc bước giá không hợp lệ");
   StringReplace(ref text,"Missing or malformed chronological closed data","Thiếu dữ liệu nến đóng hoặc thứ tự dữ liệu không hợp lệ");
   StringReplace(ref text,"No confirmed HTF range at this LTF close","Chưa có vùng HTF được xác nhận tại thời điểm nến LTF đóng");
   StringReplace(ref text,"Boundary pivot confirmation follows its range confirmation","Điểm xoay biên được xác nhận sau thời điểm xác nhận vùng giá");
   StringReplace(ref text,"Range endpoints moved backward; reinitialize required","Mốc biên vùng giá lùi về trước; cần khởi tạo lại");
   StringReplace(ref text,"Confirmed range revised; reset required","Vùng giá đã xác nhận bị sửa đổi; cần khởi tạo lại");
   StringReplace(ref text,"Invalid tick, ATR or historical spread for liquidity tolerance","Bước giá, ATR hoặc chênh lệch giá lịch sử không hợp lệ để tính ngưỡng thanh khoản");
   StringReplace(ref text,"IRL/ERL disabled","Phân tích IRL / ERL đã tắt");
   StringReplace(ref text,"Invalid IRL/ERL configuration","Cấu hình IRL / ERL không hợp lệ");
   StringReplace(ref text,"Closed history revised; reinitialize and audit replay","Lịch sử nến đóng đã sửa đổi; cần khởi tạo lại và kiểm tra phân tích");
   StringReplace(ref text,"Incomplete closed HTF/MTF/LTF history","Lịch sử nến đóng HTF / MTF / LTF chưa đầy đủ");
   StringReplace(ref text,"Broker revised observed closed candles; reset required","Sàn đã sửa dữ liệu nến đóng; cần khởi tạo lại");
   StringReplace(ref text,"Replay gap exceeds retained history; reinitialize required","Khoảng trống phân tích vượt lịch sử lưu giữ; cần khởi tạo lại");
   StringReplace(ref text,"Invalid symbol point for historical spread","Đơn vị điểm của mã không hợp lệ để tính chênh lệch giá lịch sử");
   StringReplace(ref text,"Broker revised observed liquidity history; reset required","Sàn đã sửa lịch sử thanh khoản; cần khởi tạo lại");
   StringReplace(ref text,"Confirmed structural leg unavailable in retained history","Không có nhịp cấu trúc đã xác nhận trong lịch sử lưu giữ");
   StringReplace(ref text,"Prior D/W/M liquidity history unavailable","Không có lịch sử thanh khoản ngày / tuần / tháng trước");
   StringReplace(ref text,"Invalid SYMBOL_TRADE_TICK_SIZE","Bước giá giao dịch của mã không hợp lệ");
   StringReplace(ref text,"Closed LTF candle time unavailable","Chưa có thời điểm nến LTF đóng");
   StringReplace(ref text,"Broker quote time unavailable; waiting for connection/data","Chưa có thời gian báo giá của sàn; chờ kết nối / dữ liệu");
   StringReplace(ref text,"LTF close is ahead of broker quote time","Thời điểm đóng nến LTF nằm sau thời gian báo giá của sàn");
   StringReplace(ref text,"Stale LTF history; waiting for synchronized candles","Lịch sử LTF đã cũ; đang chờ nến đồng bộ");
   StringReplace(ref text," close="," nến đóng=");
   StringReplace(ref text," broker="," thời gian sàn=");
   StringReplace(ref text,"Range plan geometry or gross RR below minimum; costs can only reduce RR further","Vị trí giá hoặc RR gộp của kế hoạch chưa đạt; chi phí chỉ làm RR giảm thêm");
   StringReplace(ref text,"Missing/stale/inverted market quote","Báo giá thiếu, đã cũ hoặc bị đảo");
   StringReplace(ref text,"Required range evidence missing or wrong owner","Thiếu bằng chứng của vùng hoặc bằng chứng không thuộc vùng hiện tại");
   StringReplace(ref text,"Live quote crossed scenario stop after the closed reaction","Báo giá hiện tại đã vượt dừng lỗ sau nến phản ứng");
   StringReplace(ref text,"Live exit quote already reached or crossed the scenario target","Báo giá thoát hiện tại đã chạm hoặc vượt mục tiêu kịch bản");
   StringReplace(ref text,"Spread or symbol point invalid","Chênh lệch giá hoặc đơn vị điểm của mã không hợp lệ");
   StringReplace(ref text,"Invalid risk configuration: RR >=2 and maximum risk <=2% required","Cấu hình rủi ro không hợp lệ: cần RR từ 2 và rủi ro tối đa không quá 2%");
   StringReplace(ref text,"Confirmed IRL/ERL advisory plan; proposed zone entry is not a fill or order","Kế hoạch IRL / ERL tham khảo đã xác nhận; giá đề xuất chưa phải lệnh hoặc giá khớp");
   StringReplace(ref text,"Confluence below configured threshold","Điểm hợp lưu dưới ngưỡng đã đặt");
   StringReplace(ref text,"Risk gate: ","Điều kiện rủi ro: ");
   StringReplace(ref text,"Calculation unavailable","Chưa tính được rủi ro");
   StringReplace(ref text,"Symbol unavailable","Mã giao dịch không khả dụng");
   StringReplace(ref text,"Invalid broker symbol specification","Thông số mã của sàn không hợp lệ");
   StringReplace(ref text,"Invalid risk inputs","Thông số rủi ro không hợp lệ");
   StringReplace(ref text,"Invalid price","Giá không hợp lệ");
   StringReplace(ref text,"SL/TP on wrong side of entry","SL / TP nằm sai phía giá vào lệnh");
   StringReplace(ref text,"Price is off the symbol tick grid","Giá không khớp bước giá của mã");
   StringReplace(ref text,"SL/TP inside broker stop/freeze distance","SL / TP nằm trong khoảng dừng hoặc đóng băng của sàn");
   StringReplace(ref text,"Terminal disconnected","MT5 mất kết nối");
   StringReplace(ref text,"Valid bid/ask unavailable","Chưa có giá mua / bán hợp lệ");
   StringReplace(ref text,"Market quote is stale","Báo giá đã cũ");
   StringReplace(ref text,"OrderCalcProfit failed","Không tính được lãi / lỗ");
   StringReplace(ref text,"Nonpositive loss or reward estimate","Ước tính lỗ hoặc lợi nhuận không dương");
   StringReplace(ref text,"Minimum lot exceeds risk budget","Khối lượng tối thiểu vượt ngân sách rủi ro");
   StringReplace(ref text,"No lot fits risk budget","Không có khối lượng phù hợp ngân sách rủi ro");
   StringReplace(ref text,"OrderCalcMargin failed","Không tính được ký quỹ");
   StringReplace(ref text,"Insufficient free margin","Ký quỹ khả dụng không đủ");
   StringReplace(ref text,"RR below minimum","RR dưới mức tối thiểu");
   StringReplace(ref text,"SAFE preview (no order sent)","Kết quả tham khảo an toàn (chưa gửi lệnh)");
   StringReplace(ref text,"Continuation: displacement+BOS+HTF aligned","Tiếp diễn: dịch chuyển giá + BOS cùng hướng HTF");
   StringReplace(ref text,"Reversal: sweep+displacement+MSS/BOS","Đảo chiều: quét + dịch chuyển giá + MSS / BOS");
   StringReplace(ref text,"Missing candidate/displacement/structure/sweep or continuation HTF/FVG gate","Thiếu điều kiện OB, dịch chuyển giá, cấu trúc, quét hoặc điều kiện HTF / FVG");
   StringReplace(ref text,"Closed beyond invalidation boundary","Nến đóng vượt ngưỡng mất hiệu lực");
   StringReplace(ref text,"Wick beyond invalidation boundary","Râu nến vượt ngưỡng mất hiệu lực");
   StringReplace(ref text,"Configured closed-bar age reached","Đã đạt giới hạn số nến đóng");
   StringReplace(ref text,"New evt starts a separate setup","Sự kiện mới bắt đầu một thiết lập riêng");
   StringReplace(ref text,"New confirmed structural leg","Đã xác nhận nhịp cấu trúc mới");
   StringReplace(ref text,"Confirmed HTF structural leg; bounded replay","Đã xác nhận nhịp cấu trúc HTF trong lịch sử phân tích");
   StringReplace(ref text,"Excursion candidate; no reversal confirmation","Có dấu hiệu vượt vùng; chưa xác nhận đảo chiều");
   StringReplace(ref text,"Price near external pool","Giá đang gần vùng thanh khoản ngoài");
   StringReplace(ref text,"Both external sides swept on one candle","Cả hai phía thanh khoản ngoài bị quét trong một nến");
   StringReplace(ref text,"Sweep setup exceeded equivalent MTF age in closed LTF bars","Thiết lập quét đã vượt thời hạn MTF tính theo số nến LTF đóng");
   StringReplace(ref text,"Closed excursion observed","Đã ghi nhận nến đóng vượt vùng");
   StringReplace(ref text,"Closed external reclaim; ","Nến đóng trở lại sau khi quét ngoài; ");
   StringReplace(ref text,"; awaiting structure","; chờ cấu trúc");
   StringReplace(ref text,"Closed internal sweep and reclaim in HTF direction; awaiting later structure","Nến đóng trở lại sau quét nội bộ cùng hướng HTF; chờ cấu trúc tiếp theo");
   StringReplace(ref text,"Continuation invalidated the sweep thesis","Chuyển động tiếp diễn làm giả thuyết quét mất hiệu lực");
   StringReplace(ref text,"Closed beyond sweep invalidation","Nến đóng vượt ngưỡng mất hiệu lực của lần quét");
   StringReplace(ref text,"Aligned closed structure and displacement","Cấu trúc nến đóng và dịch chuyển giá cùng hướng");
   StringReplace(ref text,"Opposite confirmed MTF break","Phá cấu trúc MTF ngược hướng đã xác nhận");
   StringReplace(ref text,"Neutral/opposing HTF structure; no actionable rotation","Cấu trúc HTF trung tính / ngược hướng; chưa có kịch bản hành động");
   StringReplace(ref text,"Awaiting aligned post-evt MTF structure/displacement","Chờ cấu trúc / dịch chuyển MTF cùng hướng sau sự kiện");
   StringReplace(ref text,"No eligible same-range internal PD array","Không có vùng giá nội bộ phù hợp trong cùng khoảng giá");
   StringReplace(ref text,"Entry array expired, fully mitigated or invalidated","Vùng vào lệnh hết hạn, đã lấp hết hoặc mất hiệu lực");
   StringReplace(ref text,"Closed retracement into selected internal PD array","Nến đóng hồi về vùng giá nội bộ đã chọn");
   StringReplace(ref text,"Closed directional rejection after IRL touch","Nến đóng phản ứng theo hướng sau khi chạm IRL");
   StringReplace(ref text,"Target touched during reaction candle; intrabar order is unknown","Mục tiêu bị chạm trong nến phản ứng; chưa rõ trình tự trong nến");
   StringReplace(ref text,"Confirmed later closed bar reached scenario target","Nến đóng sau đó đã chạm mục tiêu kịch bản");
   StringReplace(ref text,"Confirmed rotation; proposed zone entry awaits risk/score gates","Đã xác nhận chuyển động; vùng vào đề xuất chờ kiểm tra rủi ro / điểm");
   StringReplace(ref text,"Scenario target consumed/unavailable","Mục tiêu kịch bản đã dùng hoặc không còn khả dụng");
   StringReplace(ref text,"Awaiting closed IRL reaction and eligible ERL target","Chờ nến đóng phản ứng tại IRL và mục tiêu ERL phù hợp");
   StringReplace(ref text,"Nearest unconsumed same-range ERL: ","ERL gần nhất chưa dùng trong cùng vùng: ");
   StringReplace(ref text,"; conditional, not a forecast","; có điều kiện, không phải dự báo");
   if(text==source) return "Chi tiết gốc: "+source;
   return text;
  }
public static string ICTPositionMoney(double value,SICTPositionRiskSnapshot s,bool signed_value=false) {
   if(!MathIsValidNumber(value)) return "Chưa xác định";
   return (signed_value && value>0.0 ? "+" : "")+DoubleToString(value,s.currency_digits)+" "+s.currency;
  }
public static string ICTPositionMoneyPercent(double value,SICTPositionRiskSnapshot s,bool signed_value=false) {
   string pct=(ICTPositionCapitalValid(s.capital) ? DoubleToString(ICTPositionPercent(value,s.capital),2)+"%" : "chưa có vốn hợp lệ");
   return ICTPositionMoney(value,s,signed_value)+" ("+pct+")";
  }
public static string ICTPositionRiskStatus(SICTPositionRiskSnapshot s,double portfolio_limit=3.0) {
   if(!s.connected) return "MẤT KẾT NỐI — KIỂM TRA TÀI KHOẢN";
   if(s.selection_errors>0) return "ĐANG ĐỒNG BỘ VỊ THẾ";
   if(!ICTPositionCapitalValid(s.capital)) return "VỐN KHÔNG HỢP LỆ";
   if(s.totals.unknown_stops>0) return "RỦI RO CHƯA XÁC ĐỊNH ĐỦ";
   if(s.unknown_pending>0) return "LỆNH CHỜ THIẾU SL / ĐỊNH GIÁ";
   if(s.totals.count==0 && s.pending_count==0) return "CHƯA CÓ VỊ THẾ";
   double exposure=MathMax(s.totals.risk_money,s.totals.remaining_risk_money)+s.pending_risk_money;
   if(portfolio_limit>0.0 && ICTPositionPercent(exposure,s.capital)>portfolio_limit)
      return "VƯỢT NGÂN SÁCH RỦI RO";
   return "RỦI RO SL: "+ICTPositionMoneyPercent(s.totals.risk_money,s);
  }
public static string ICTPositionRiskBody(SICTPositionRiskSnapshot s) {
   string body="[TỔNG QUAN VỊ THẾ]\nPhạm vi: "+(s.symbol_filter=="" ? "Toàn tài khoản" : s.symbol_filter)+
      " | "+IntegerToString(s.totals.count)+" vị thế\n";
   body+="Vốn tính %: "+(s.capital_mode==ICT_POSITION_EQUITY ? "Equity " :
      s.capital_mode==ICT_POSITION_CONSERVATIVE ? "min(Balance, Equity) " : "Balance ")+ICTPositionMoney(s.capital,s)+"\n";
   body+="Balance "+ICTPositionMoney(s.balance,s)+" | Equity "+ICTPositionMoney(s.equity,s)+"\n";
   if(!s.connected) body+="MẤT KẾT NỐI: giá/vị thế có thể chưa cập nhật\n";
   if(s.selection_errors>0) body+="Đang đồng bộ vị thế: chưa đọc được "+IntegerToString(s.selection_errors)+" mục\n";
   body+="Lệnh chờ: "+IntegerToString(s.pending_count)+" | rủi ro đã tính "+ICTPositionMoney(s.pending_risk_money,s)+
      (s.unknown_pending>0 ? " (chưa đầy đủ; thiếu SL/định giá)" : "")+"\n";
   if(s.totals.count==0 && s.pending_count==0)
      return body+"Bảng tự cập nhật sau khi mở lệnh thủ công hoặc bằng EA.\n";
   body+=(s.totals.unknown_stops>0 || s.selection_errors>0 ? "Rủi ro SL đã tính (chưa đầy đủ): " : "Tổng rủi ro tới SL: ")+
      ICTPositionMoneyPercent(s.totals.risk_money,s)+"\n";
   if(s.totals.unknown_stops>0) body+="Chưa xác định SL: "+IntegerToString(s.totals.unknown_stops)+" vị thế; không tính thành 0%\n";
   body+=(s.totals.unknown_targets>0 || s.selection_errors>0 ? "P/L tại TP đã tính (chưa đầy đủ): " : "Tổng P/L dự kiến tại TP: ")+
      ICTPositionMoneyPercent(s.totals.target_money,s,true)+"\n";
   if(s.totals.unknown_targets>0) body+="Chưa xác định TP: "+IntegerToString(s.totals.unknown_targets)+" vị thế\n";
   body+="Lãi/lỗ thả nổi: "+ICTPositionMoneyPercent(s.totals.floating,s,true)+
      (s.totals.unknown_floating>0 || s.selection_errors>0 ? " (chưa đầy đủ)" : "")+"\n";
   body+="Thả nổi gồm swap, chưa trừ commission.\n";
   body+="Có thể giảm thêm tới SL: "+ICTPositionMoneyPercent(s.totals.remaining_risk_money,s)+
      (s.totals.unknown_stops>0 || s.totals.unknown_floating>0 || s.selection_errors>0 ? " (chưa đầy đủ)" : "")+"\n";
   body+="P/L ngày TK = deal BUY/SELL hôm nay (gồm phí) + floating hiện tại: "+
      (s.daily_valid ? ICTPositionMoneyPercent(s.daily_net,s,true) : "CHƯA XÁC ĐỊNH")+"\n";
   body+="P/L tại SL/TP tính từ giá vào thực tế.\n";
   body+="SL/TP dự kiến gồm swap, trừ phí + dự phòng "+ICTPositionMoney(s.cost_per_lot,s)+"/lot.\n";
   body+="Chỉ tính khối lượng còn mở; không cộng phần đã chốt.\n";
   for(int i=0;i<ArraySize(s.positions);i++)
     {
      SICTPositionRisk r=s.positions[i]; SICTPositionRiskInput p=r.position;
      body+="[VỊ THẾ #"+IntegerToString((long)p.ticket)+" | "+p.symbol+"]\n";
      body+=(p.direction>0 ? "BUY " : p.direction<0 ? "SELL " : "Hướng chưa rõ ")+DoubleToString(p.volume,4)+
         " lot | Vào "+DoubleToString(p.entry,p.digits)+"\n";
      if(!r.valid) { body+="Không đọc được dữ liệu/chi phí hợp lệ; rủi ro chưa xác định.\n"; continue; }
      body+="SL "+(p.stop>0.0 ? DoubleToString(p.stop,p.digits) : "CHƯA ĐẶT")+
         " | TP "+(p.target>0.0 ? DoubleToString(p.target,p.digits) : "CHƯA ĐẶT")+"\n";
      if(!r.stop_valid) body+="Rủi ro SL: CHƯA XÁC ĐỊNH"+(p.stop>0.0 ? " (broker chưa định giá được)" : " (chưa có SL)")+"\n";
      else if(r.locked_money>0.0) body+="Khóa lời tại SL: "+ICTPositionMoneyPercent(r.locked_money,s,true)+" | rủi ro mất vốn 0%\n";
      else body+="Rủi ro tới SL: "+ICTPositionMoneyPercent(r.risk_money,s)+"\n";
      body+="P/L dự kiến tại TP: "+(r.target_valid ? ICTPositionMoneyPercent(r.net_at_target,s,true) : "CHƯA XÁC ĐỊNH")+"\n";
      body+="Lãi/lỗ thả nổi: "+(r.floating_valid ? ICTPositionMoneyPercent(r.floating,s,true) : "CHƯA XÁC ĐỊNH")+"\n";
      body+="R:R dự kiến "+(r.rr_valid ? "1:"+DoubleToString(r.rr,2) : "--")+"\n";
     }
   return body;
  }
public static string ICTPositionCompactMoney(double money,SICTPositionRiskSnapshot s,bool signed_value=false) {
   if(!MathIsValidNumber(money)) return "CHƯA XÁC ĐỊNH";
   return (ICTPositionCapitalValid(s.capital) ? DoubleToString(ICTPositionPercent(money,s.capital),2)+"% | " : "--% | ")+
      (signed_value && money>0.0 ? "+" : "")+DoubleToString(money,s.currency_digits);
  }
public static int ICTPositionWorstIndex(SICTPositionRiskSnapshot s) {
   int worst=-1; double largest=-1.0;
   for(int i=0;i<ArraySize(s.positions);i++)
     {
      SICTPositionRisk r=s.positions[i];
      if(!r.valid || !r.stop_valid || !r.floating_valid) return i;
      double amount=MathMax(r.risk_money,r.remaining_risk_money);
      if(amount>largest) { largest=amount; worst=i; }
     }
   return worst;
  }
public static string ICTPositionSummaryLabel(int row) {
   switch(row)
     {
      case 0: return "Bảo vệ tự động";
      case 1: return "P/L đang mở";
      case 2: return "Rủi ro SL + chờ";
      case 3: return "Có thể giảm thêm";
      case 4: return "P/L ngày TK*";
      case 5: return "Risk ngày + chờ";
      case 6: return "Dư địa sau SL*";
      case 7: return "Margin / Equity";
      case 8: return "Balance / Equity";
      case 9: return "Vị thế / lệnh chờ";
      case 10: return "Vị thế rủi ro nhất";
      case 11: return "Trần lệnh / ngày";
     }
   return "";
  }
public static string ICTPositionSummaryValue(SICTPositionRiskSnapshot s,int row,double portfolio_limit,double daily_limit,double per_trade_limit=3.0,bool cumulative=true) {
   bool incomplete=s.selection_errors>0 || s.totals.unknown_stops>0 || s.unknown_pending>0;
   switch(row)
     {
      case 0:
         if(!s.connected) return "MẤT KẾT NỐI";
         if(!s.protection_online) return "OFFLINE";
         if(s.protection_state!=0) return "ĐÃ KHÓA TÀI KHOẢN";
         if(!s.protection_armed) return "CHƯA BẬT TỰ ĐỘNG";
         return s.protection_healthy ? "ĐANG GIÁM SÁT" : "LỖI / THIẾU QUYỀN";
      case 1: return (s.selection_errors>0 || s.totals.unknown_floating>0 ? "CHƯA ĐỦ | " : "")+
         ICTPositionCompactMoney(s.totals.floating,s,true);
      case 2: return (incomplete ? "CHƯA ĐỦ | " : "")+
         ICTPositionCompactMoney(s.totals.risk_money+s.pending_risk_money,s);
      case 3: return (incomplete || s.totals.unknown_floating>0 ? "CHƯA ĐỦ | " : "")+
         ICTPositionCompactMoney(s.totals.remaining_risk_money+s.pending_risk_money,s);
      case 4: return s.daily_valid ? ICTPositionCompactMoney(s.daily_net,s,true) : "CHƯA ĐỦ LỊCH SỬ";
      case 5:
         return !s.daily_opened_valid ? "CHƯA ĐỦ SL BAN ĐẦU" :
            (s.selection_errors>0 || s.unknown_pending>0 ? "CHƯA ĐỦ | " : "")+
            ICTPositionCompactMoney(s.daily_opened_risk_money+s.pending_risk_money,s);
      case 6:
         if(daily_limit<=0.0) return "GIỚI HẠN NGÀY ĐANG TẮT";
         if(s.symbol_filter!="") return "CẦN XEM TOÀN TÀI KHOẢN";
         if(incomplete || s.totals.unknown_floating>0 || !s.daily_valid || !ICTPositionCapitalValid(s.capital) ||
            (cumulative && !s.daily_opened_valid))
            return "CHƯA XÁC ĐỊNH";
         return ICTPositionCompactMoney(MathMax(0.0,MathMin(s.capital*daily_limit/100.0+s.daily_net-
            s.totals.remaining_risk_money-s.pending_risk_money,cumulative ?
            s.capital*daily_limit/100.0-s.daily_opened_risk_money-s.pending_risk_money : DBL_MAX)),s);
      case 7: return s.margin_valid && ICTPositionCapitalValid(s.equity) ?
         DoubleToString(ICTPositionPercent(s.margin,s.equity),1)+"% | trống "+DoubleToString(s.free_margin,s.currency_digits) : "CHƯA XÁC ĐỊNH";
      case 8: return DoubleToString(s.balance,s.currency_digits)+" / "+DoubleToString(s.equity,s.currency_digits);
      case 9: return IntegerToString(s.totals.count)+" / "+IntegerToString(s.pending_count)+
         (s.symbol_filter=="" ? " | toàn TK" : " | "+s.symbol_filter);
      case 10:
        {
         int index=ICTPositionWorstIndex(s);
         if(index<0) return "--";
         SICTPositionRisk r=s.positions[index];
         return r.position.symbol+" #"+IntegerToString((long)r.position.ticket)+
            (!r.stop_valid || !r.floating_valid || !r.valid ? " | THIẾU SL / DỮ LIỆU" : " | "+
            (ICTPositionCapitalValid(s.capital) ? DoubleToString(ICTPositionPercent(MathMax(r.risk_money,r.remaining_risk_money),s.capital),2)+"%" : "--%"));
        }
      case 11: return (per_trade_limit>0.0 ? DoubleToString(per_trade_limit,2)+"%" : "TẮT")+" / "+
         (daily_limit>0.0 ? DoubleToString(daily_limit,2)+"%" : "TẮT");
     }
   return "";
  }
public static int ICTPositionSummarySeverity(SICTPositionRiskSnapshot s,int row,double portfolio_limit,double daily_limit,bool cumulative=true) {
   bool incomplete=!s.connected || s.selection_errors>0 || !ICTPositionCapitalValid(s.capital) ||
      !MathIsValidNumber(s.totals.risk_money) || !MathIsValidNumber(s.totals.remaining_risk_money) ||
      !MathIsValidNumber(s.pending_risk_money);
   if(row==0) return (!s.connected || !s.protection_online || s.protection_state!=0 ||
      (s.protection_armed && !s.protection_healthy) ? 3 : s.protection_armed ? 1 : 2);
   if(row==1) return incomplete || s.totals.unknown_floating>0 ? 3 : s.totals.floating<0.0 ? 3 : s.totals.floating>0.0 ? 1 : 0;
   if(row==2 || row==3)
     {
      if(incomplete || s.totals.unknown_stops>0 || s.unknown_pending>0 || (row==3 && s.totals.unknown_floating>0)) return 3;
      double amount=(row==2 ? s.totals.risk_money : s.totals.remaining_risk_money)+s.pending_risk_money;
      double used=ICTPositionPercent(amount,s.capital);
      return portfolio_limit<=0.0 ? 2 : used>portfolio_limit ? 3 : used>=portfolio_limit*0.8 ? 2 : 0;
     }
   if(row==4) return incomplete || !s.daily_valid ? 3 : s.daily_net<0.0 ? 3 : s.daily_net>0.0 ? 1 : 0;
   if(row==5)
     {
      if(incomplete || !s.daily_opened_valid || s.unknown_pending>0) return cumulative ? 3 : 2;
      double spent=ICTPositionPercent(s.daily_opened_risk_money+s.pending_risk_money,s.capital);
      return spent>=daily_limit ? 3 : spent>=daily_limit*0.8 ? 2 : 0;
     }
   if(row==6)
     {
      if(incomplete || !s.daily_valid || s.totals.unknown_stops>0 || s.unknown_pending>0 || s.totals.unknown_floating>0 ||
         (cumulative && !s.daily_opened_valid)) return 3;
      if(daily_limit<=0.0 || s.symbol_filter!="") return 2;
      double room=s.capital*daily_limit/100.0+s.daily_net-s.totals.remaining_risk_money-s.pending_risk_money;
      if(cumulative) room=MathMin(room,s.capital*daily_limit/100.0-s.daily_opened_risk_money-s.pending_risk_money);
      return room<=0.0 ? 3 : room<s.capital*daily_limit/100.0*0.25 ? 2 : 0;
     }
   if(row==7) return !s.margin_valid || !ICTPositionCapitalValid(s.equity) ? 3 :
      s.margin/s.equity>=1.0/3.0 ? 3 : s.margin/s.equity>=0.20 ? 2 : 0;
   if(row==10)
     {
      int index=ICTPositionWorstIndex(s);
      if(index>=0 && (!s.positions[index].valid || !s.positions[index].stop_valid || !s.positions[index].floating_valid)) return 3;
      if(index>=0 && ICTPositionPercent(MathMax(s.positions[index].risk_money,s.positions[index].remaining_risk_money),s.capital)>3.0) return 3;
     }
   if(row==11 && (portfolio_limit<=0.0 || daily_limit<=0.0)) return 2;
   return 0;
  }
public static string ICTUnifiedTF(int tf) { if(tf==PERIOD_CURRENT) return "--"; string value=EnumToString(tf); StringReplace(ref value,"PERIOD_",""); return value; }
public static string ICTUnifiedBias(SICTTierSnapshot tier) {
   if(tier.timeframe==PERIOD_CURRENT) return "Chưa có";
   if(tier.status==ICT_CONTEXT_INSUFFICIENT) return "Không đủ dữ liệu";
   return tier.status==ICT_CONTEXT_BULLISH ? "Tăng" : tier.status==ICT_CONTEXT_BEARISH ? "Giảm" : "Trung tính";
  }
public static string ICTUnifiedStructureText(int state) {
   string[] names = new string[] {"Không đủ dữ liệu","Cùng hướng","Ngược xu hướng","Chuyển tiếp","Trung tính"};
   return (int)state>=0 && (int)state<5 ? names[(int)state] : "Không đủ dữ liệu";
  }
public static string ICTDashboardSignalState(int state) {
   if(state==ICT_SIGNAL_BUY_CONFIRMED) return "MUA ĐÃ XÁC NHẬN";
   if(state==ICT_SIGNAL_SELL_CONFIRMED) return "BÁN ĐÃ XÁC NHẬN";
   if(state==ICT_SIGNAL_WATCH_BUY) return "THEO DÕI MUA";
   if(state==ICT_SIGNAL_WATCH_SELL) return "THEO DÕI BÁN";
   return "KHÔNG GIAO DỊCH";
  }
public static string ICTStrongOBDetails(SICTStrongOrderBlock z) {
   return ICTUnifiedTF(z.timeframe)+" "+(z.ob.direction>0 ? "TĂNG " : "GIẢM ")+ICTDashboardText(ICTOBGradeText(z.grade))+" "+
      IntegerToString(z.confirmation_score)+"/100 | "+ICTDashboardText(ICTOBLifeText(z.life))+
      "\nVùng "+DoubleToString(z.ob.lower,_Digits)+" - "+DoubleToString(z.ob.upper,_Digits)+
      " | số lần chạm "+IntegerToString(z.touch_count)+" | độ lấp "+DoubleToString(z.mitigation_depth*100,1)+"%"+
      "\nQuét "+IntegerToString(z.sweep_points)+" Dịch chuyển "+IntegerToString(z.displacement_points)+
      " Cấu trúc "+IntegerToString(z.structure_points)+" FVG "+IntegerToString(z.fvg_points)+
      " Xu hướng "+IntegerToString(z.bias_points)+" PD "+IntegerToString(z.pd_points)+" Mới "+IntegerToString(z.freshness_points)+
      "\n"+ICTDashboardText(z.gate_reason)+(z.invalidation_reason!="" ? " | "+ICTDashboardText(z.invalidation_reason) : "");
  }
public static string ICTUnifiedDashboardBody(SICTUnifiedSnapshot s,string decision,string plan,string reason,string research_advisory="") {
   string body="[BỐI CẢNH ĐA KHUNG]\nChế độ: "+(s.frames.mode==ICT_MTF_AUTO ? "Tự động" : "Thủ công")+
      " | "+(s.frames.status==ICT_MTF_FULL ? "3 khung" : s.frames.status==ICT_MTF_TWO_TIER ? "2 khung" : "1 khung")+"\n";
   body+="Khung hiển thị vùng: "+ICTUnifiedTF(g_ict_chart_zone_tf)+" | số vùng trùng đã ẩn: "+
         IntegerToString(g_ict_chart_zone_suppressed)+"\n";
   string[] tier_names = new string[] {"LTF","MTF","HTF"};
   for(int i=0;i<3;i++)
     {
      body+=tier_names[i]+" "+ICTUnifiedTF(s.tiers[i].timeframe)+" "+ICTUnifiedBias(s.tiers[i]);
      if(s.tiers[i].closed_at>0) body+=" | đóng lúc "+TimeToString(s.tiers[i].closed_at,TIME_DATE|TIME_MINUTES);
      else if(s.tiers[i].reason!="") body+=" | "+ICTDashboardText(s.tiers[i].reason);
      body+="\n";
     }
   body+="MTF: "+ICTUnifiedStructureText(s.mtf_state)+"\n"+ICTDashboardText(s.reason)+"\n";
   body+=research_advisory+"[QUYẾT ĐỊNH HTF / MTF / LTF]\n";
   SICTSignalResult signal=s.signal;
   bool shared=signal.symbol==s.symbol && signal.asof==s.asof && signal.asof>0;
   if(shared)
     {
      body+=ICTDashboardSignalState(signal.state)+" | "+TimeToString(signal.asof,TIME_DATE|TIME_MINUTES)+"\n";


      bool data_gate=signal.data_ready && signal.frames.status==ICT_MTF_FULL;
      bool context_gate=data_gate && (signal.direction==1 || signal.direction==-1) && signal.htf_pass && signal.mtf_pass;
      bool trigger_gate=context_gate && signal.ltf_pass && signal.trigger_bar>0 &&
         signal.asof>signal.trigger_bar && signal.source_event_time<=signal.asof;
      bool smt_gate=trigger_gate && (!signal.smt_required || signal.smt_pass);
      bool target_gate=smt_gate && signal.tp1>0 && signal.target_pool_id!="";
      string risk_gate=(!target_gate ? "Chưa đánh giá" : signal.confirmed ? "Đạt" :
         StringFind(signal.reason,"RISK FILTER FAIL")==0 ? "Không đạt" : "Chưa rõ");
      body+="Dữ liệu: "+(data_gate ? "Đạt" : "Không đủ")+"\n";
      body+="HTF "+(!data_gate ? "Chưa đánh giá" : signal.htf_pass ? "Đạt" : "Không đạt")+
         " / MTF "+(!data_gate ? "Chưa đánh giá" : signal.mtf_pass ? "Đạt" : "Không đạt")+"\n";
      body+="Tín hiệu LTF: "+(!context_gate ? "Chưa đánh giá" : trigger_gate ? "Đạt" : "Chờ")+"\n";
      body+="Điều kiện SMT: "+(!trigger_gate ? "Chưa đánh giá" : !signal.smt_required ? "Tùy chọn" : signal.smt_pass ? "Đạt" : "Không đạt")+"\n";
      body+="Mục tiêu "+(!smt_gate ? "Chưa đánh giá" : target_gate ? "Đạt" : "Chưa có")+
         " / Rủi ro "+risk_gate+"\n";
      body+="Điểm chất lượng "+IntegerToString(signal.score)+"/100 (điểm bằng chứng, không phải xác suất)\n";
      if(data_gate) body+=ICTDashboardText(signal.htf_reason)+"\n"+ICTDashboardText(signal.mtf_reason)+"\n";
      if(context_gate) body+=ICTDashboardText(signal.ltf_reason)+"\n";
      body+="Quyết định: "+ICTDashboardText(signal.reason)+"\n";
      if(signal.id!="") body+="ID "+signal.id+"\n";
     }
   else body+=decision+"\n"+ICTDashboardText(reason)+"\n";
   body+="[PHÂN TÍCH SMT]\n";
   body+="SMT 1: "+(s.comparison1=="" ? "Đã tắt / chưa có" : s.comparison1)+
      " | SMT 2: "+(s.comparison2=="" ? "Đã tắt / chưa có" : s.comparison2)+"\n";
   if(s.comparator_reason!="") body+=ICTDashboardText(s.comparator_reason)+"\n";
   body+="Biểu đồ "+ICTUnifiedTF(s.chart_tf)+" | phát hiện: "+IntegerToString(s.detection_bars)+" nến mỗi khung | hiển thị: "+IntegerToString(s.display_bars)+" nến biểu đồ\n";
   for(int layer=0;layer<s.layer_count;layer++)
     {
      SICTSMTLayer l=s.layers[layer];
      body+=ICTUnifiedTF(l.timeframe)+(l.timeframe==s.chart_tf ? " (khung biểu đồ)" : "")+" phát hiện "+IntegerToString(l.detected)+" | đang hiển thị "+IntegerToString(l.displayed)+
         " | tăng / giảm còn hiệu lực "+IntegerToString(l.bullish)+"/"+IntegerToString(l.bearish)+" | "+ICTDashboardText(l.reason)+"\n";
      for(int peer=0;peer<2;peer++)
        {
         SICTSMTPeerSnapshot p=l.peers[peer];
         body+="Mã so sánh "+IntegerToString(peer+1)+" "+(p.comparison=="" ? "--" : p.comparison)+" | "+
            (p.relation_known ? (p.relation>0 ? "+ Cùng chiều" : "- Ngược chiều") : "Chưa rõ tương quan")+
            " | "+(p.reason=="DISABLED" ? "Đã tắt" : p.conflict ? "Xung đột" :
                   p.state==ICT_SMT_PEER_NA ? "Chưa có dữ liệu" : ICTDashboardText(ICTSMTPeerStateText(p.state)))+"\n";
         if(p.primary_pivot_time>0)
            body+="Điểm xoay "+DoubleToString(p.primary_pivot,_Digits)+" lúc "+TimeToString(p.primary_pivot_time,TIME_DATE|TIME_MINUTES)+
               " | xác nhận "+TimeToString(p.confirmation_time,TIME_DATE|TIME_MINUTES)+"\n";
         body+=ICTDashboardText(p.reason)+"\n";
        }
     }
   if(shared) body+=ICTDashboardText(signal.smt_reason)+"\n";
   body+="[THANH KHOẢN VÀ PHÁ VỠ]\n";
   if(shared)
     {
      body+="Nguồn thanh khoản: "+(signal.source_pool_id=="" ? "Chưa có" : signal.source_pool_id)+"\n";
      body+="Sự kiện quét / phá vỡ: "+ICTDashboardText(signal.liquidity_event)+" "+(signal.source_event_time>0 ? TimeToString(signal.source_event_time,TIME_DATE|TIME_MINUTES) : "--")+"\n";
      body+="Vùng thanh khoản mục tiêu: "+(signal.target_pool_id=="" ? "Chưa có mục tiêu" : signal.target_pool_id)+"\n";
      body+="Khoảng cách đến thanh khoản: "+(signal.tp1>0 && signal.entry>0 ? DoubleToString(MathAbs(signal.tp1-signal.entry),_Digits) : "Chưa có")+"\n";
     }
   else body+="Chưa có quyết định hoặc kế hoạch thanh khoản chung\n";
   body+="BSL / SSL là vùng thanh khoản suy ra từ cấu trúc; OB / FVG / BPR là vùng giá mục tiêu.\n[KHỐI LỆNH OB]\n";
   double price=SymbolInfoDouble(s.symbol,SYMBOL_BID),point=SymbolInfoDouble(s.symbol,SYMBOL_POINT);
   int nearest=ICTNearestActiveOB(s,price),bull=-1,bear=-1;
   for(int i=0;i<s.ob_count;i++)
     {
      if(!ICTOBActive(s.zones[i])) continue;
      if(s.zones[i].ob.direction>0 && (bull<0 || s.zones[i].confirmation_score>s.zones[bull].confirmation_score)) bull=i;
      if(s.zones[i].ob.direction<0 && (bear<0 || s.zones[i].confirmation_score>s.zones[bear].confirmation_score)) bear=i;
     }
   if(nearest>=0)
     { body+="Gần nhất: "+ICTStrongOBDetails(s.zones[nearest])+"\n";
       if(price>0 && point>0) body+="Khoảng cách đến trung điểm "+DoubleToString(MathAbs(s.zones[nearest].ob.midpoint-price)/point,1)+" điểm giá\n"; }
   else body+="Không có OB đang hoạt động đạt điều kiện bắt buộc\n";
   if(bull>=0 && bull!=nearest) body+="OB tăng mạnh nhất: "+ICTStrongOBDetails(s.zones[bull])+"\n";
   if(bear>=0 && bear!=nearest) body+="OB giảm mạnh nhất: "+ICTStrongOBDetails(s.zones[bear])+"\n";
   body+="[KẾ HOẠCH VÀ RỦI RO]\n";
   if(shared)
     {
      body+="Giá vào "+(signal.entry>0 ? DoubleToString(signal.entry,_Digits) : "--")+
         " / SL "+(signal.stop>0 ? DoubleToString(signal.stop,_Digits) : "--")+"\n";
      body+="TP1 "+(signal.tp1>0 ? DoubleToString(signal.tp1,_Digits) : "Chưa có mục tiêu")+
         " / TP2 "+(signal.tp2>0 ? DoubleToString(signal.tp2,_Digits) : "--")+
         " / RR ròng "+(signal.rr>0 ? DoubleToString(signal.rr,2) : "--")+"\n";
      if(signal.confirmed && reason!=signal.reason) body+="Kiểm tra hiện tại: "+ICTDashboardText(reason)+"\n";
     }
   else body+=plan+"\n";
   body+="Thời điểm dữ liệu "+TimeToString(s.asof,TIME_DATE|TIME_SECONDS)+" | độ trễ "+IntegerToString((long)MathMax(0,TimeCurrent()-s.asof))+" giây\n";
   body+="Điểm chỉ phản ánh bằng chứng, không phải xác suất thắng. Chỉ mang tính tham khảo.";
   body+=ICTChartLegend();
   return body;
  }



public static void TestSMTJournalCursorCompatibility() {
   SICTSMTJournalCursor cursor=new SICTSMTJournalCursor(); ZeroMemory(cursor);
   Check("empty SMT slot restores without a comparator",ICTNormalizeSMTJournalCursor(PERIOD_H4,100300,cursor));
   int[] legacy_frames = new int[] {PERIOD_H4,PERIOD_D1,PERIOD_W1};
   for(int i=0;i<3;i++)
     {
      cursor.comparison=""; cursor.timeframe=legacy_frames[i]; cursor.through=100000;
      Check("legacy empty comparator cursor migrates without a fabricated peer",
         ICTNormalizeSMTJournalCursor(legacy_frames[i],100300,cursor) &&
         cursor.comparison=="" && cursor.timeframe==PERIOD_CURRENT && cursor.through==0);
     }
   cursor.comparison="GBPUSD"; cursor.timeframe=PERIOD_H4; cursor.through=100000;
   Check("identified SMT cursor retains its frozen replay boundary",
      ICTNormalizeSMTJournalCursor(PERIOD_H4,100300,cursor) && cursor.comparison=="GBPUSD" && cursor.through==100000);
   Check("SMT cursor from a different mapped frame remains rejected",
      !ICTNormalizeSMTJournalCursor(PERIOD_D1,100300,cursor));
   cursor.comparison="";
   Check("legacy empty cursor cannot conceal a different timeframe",
      !ICTNormalizeSMTJournalCursor(PERIOD_D1,100300,cursor));
   cursor.through=100301;
   Check("legacy empty cursor cannot conceal future history",
      !ICTNormalizeSMTJournalCursor(PERIOD_H4,100300,cursor));
   cursor.timeframe=PERIOD_CURRENT; cursor.through=100000;
   Check("empty cursor without a source frame cannot advance history",
      !ICTNormalizeSMTJournalCursor(PERIOD_H4,100300,cursor));
   cursor.timeframe=PERIOD_H4; cursor.through=100000;
   Check("unused SMT layer cannot import a legacy replay cursor",
      !ICTNormalizeSMTJournalCursor(PERIOD_CURRENT,100300,cursor));
  }

public static void TestIndependentChartContext() {
   SICTUnifiedSnapshot s=new SICTUnifiedSnapshot(); ZeroMemory(s);
   s.symbol="USTEC"; s.asof=100300;
   s.tiers[0].timeframe=PERIOD_H4; s.tiers[0].status=ICT_CONTEXT_BULLISH; s.tiers[0].closed_at=100000;
   s.tiers[1].timeframe=PERIOD_D1;
   s.tiers[1].reason="INSUFFICIENT_DATA: waiting for closed history (60 bars)";
   s.tiers[2].timeframe=PERIOD_W1;
   s.tiers[2].reason="INSUFFICIENT_DATA: confirmed swings missing";
   s.reason="SMT payload journal corrupt/unavailable: frozen confirmation history cannot be restored";
   Check("SMT persistence failure retains independently closed price context",
      ICTUnifiedTierAvailable(s,PERIOD_H4) && !s.valid && !ICTUnifiedSMTAligned(s,1));
   Check("missing MTF or absent tier cannot create chart analysis",
      !ICTUnifiedTierAvailable(s,PERIOD_D1) && !ICTUnifiedTierAvailable(s,PERIOD_CURRENT));
   s.tiers[0].closed_at=s.asof+1;
   Check("unfinished future context cannot be drawn",!ICTUnifiedTierAvailable(s,PERIOD_H4));
   s.tiers[0].closed_at=100000; s.tiers[0].status=ICT_CONTEXT_INSUFFICIENT;
   Check("incomplete structure cannot be drawn as confirmed",!ICTUnifiedTierAvailable(s,PERIOD_H4));
   string body=ICTUnifiedDashboardBody(s,"","",s.reason);
   Check("missing tiers identify the frame and the specific history requirement",
      StringFind(body,"MTF "+ICTUnifiedTF(PERIOD_D1))>=0 && StringFind(body,"Đang tải lịch sử nến đóng (cần 60 nến)")>=0 &&
      StringFind(body,"HTF "+ICTUnifiedTF(PERIOD_W1))>=0 && StringFind(body,"Chưa đủ đỉnh/đáy đã xác nhận")>=0);
  }

public static void RunUnifiedDiagnosticFixtures() {
   TestSMTJournalCursorCompatibility();
   TestIndependentChartContext();
   SICTUnifiedSnapshot s=new SICTUnifiedSnapshot(); ZeroMemory(s);
   s.valid=true; s.symbol="TEST"; s.asof=100300; s.layer_count=1;
   s.comparison1="PEER1"; s.layers[0].last_close=s.asof;
   s.layers[0].peers[0].comparison="PEER1";
   s.layers[0].peers[1].reason="DISABLED";
   Check("missing data is unavailable",StringFind(ICTUnifiedSMTDiagnostic(s,1),"UNAVAILABLE")==0);
   Check("unknown direction remains unknown",StringFind(ICTUnifiedSMTDiagnostic(s,0),"UNKNOWN:")==0);
   s.layers[0].peers[0].ready=true; s.layers[0].peers[0].relation_known=true;
   s.layers[0].peers[0].last_close=s.asof; s.layers[0].peers[0].state=ICT_SMT_PEER_NONE;
   Check("valid no-divergence is none",StringFind(ICTUnifiedSMTDiagnostic(s,1),"NONE:")==0);
   s.layers[0].peers[0].state=ICT_SMT_PEER_BULLISH;
   Check("aligned is reported and passes existing gate",StringFind(ICTUnifiedSMTDiagnostic(s,1),"ALIGNED:")==0 && ICTUnifiedSMTAligned(s,1));
   Check("opposite is reported and fails existing gate",StringFind(ICTUnifiedSMTDiagnostic(s,-1),"OPPOSITE:")==0 && !ICTUnifiedSMTAligned(s,-1));
   s.layers[0].peers[0].conflict=true;
   Check("peer conflict remains vetoed",StringFind(ICTUnifiedSMTDiagnostic(s,1),"CONFLICT:")==0 && !ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[0].conflict=false;
   s.comparison2="PEER2"; s.layers[0].peers[1].comparison="PEER2"; s.layers[0].peers[1].reason="INSUFFICIENT_DATA";
   Check("partial data reported without changing aligned gate",StringFind(ICTUnifiedSMTDiagnostic(s,1),"some peer data unavailable")>=0 && ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[1].ready=true; s.layers[0].peers[1].relation_known=true;
   s.layers[0].peers[1].last_close=s.asof; s.layers[0].peers[1].state=ICT_SMT_PEER_BEARISH;
   Check("opposite peers conflict and remain vetoed",StringFind(ICTUnifiedSMTDiagnostic(s,1),"CONFLICT:")==0 && !ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[1].state=ICT_SMT_PEER_NONE;
   Check("none on another peer retains aligned result",StringFind(ICTUnifiedSMTDiagnostic(s,1),"ALIGNED:")==0 && ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[0].last_close=s.asof-1;
   Check("stale peer does not become aligned",StringFind(ICTUnifiedSMTDiagnostic(s,1),"NONE:")==0 &&
      StringFind(ICTUnifiedSMTDiagnostic(s,1),"some peer data unavailable")>=0 && !ICTUnifiedSMTAligned(s,1));
   s.layers[0].peers[1].relation_known=false;
   Check("unknown relation is unavailable",StringFind(ICTUnifiedSMTDiagnostic(s,1),"UNAVAILABLE:")==0 && !ICTUnifiedSMTAligned(s,1));
   s.signal.symbol=s.symbol; s.signal.asof=s.asof; s.signal.frames.status=ICT_MTF_FULL;
   s.signal.reason="DATA INSUFFICIENT";
   string body=ICTUnifiedDashboardBody(s,"","","");
   string ordered=ICTUnifiedDashboardBody(s,"","","","[ANALYSIS]\n");
   Check("multi timeframe context precedes research even when signal data is missing",
      StringFind(ordered,"[BỐI CẢNH ĐA KHUNG]")==0 && StringFind(ordered,"[ANALYSIS]")>0 &&
      StringFind(ordered,"[ANALYSIS]")<StringFind(ordered,"[QUYẾT ĐỊNH HTF / MTF / LTF]"));
   Check("downstream gates not labeled failed on missing data",StringFind(body,"HTF Chưa đánh giá / MTF Chưa đánh giá")>=0 &&
      StringFind(body,"Tín hiệu LTF: Chưa đánh giá")>=0 && StringFind(body,"Rủi ro Chưa đánh giá")>=0);
   s.signal.data_ready=true; s.signal.direction=1; s.signal.htf_pass=true; s.signal.mtf_pass=false;
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("failed MTF leaves trigger unevaluated",StringFind(body,"HTF Đạt / MTF Không đạt")>=0 &&
      StringFind(body,"Tín hiệu LTF: Chưa đánh giá")>=0);
   s.signal.mtf_pass=true; s.signal.trigger_bar=s.asof-300; s.signal.ltf_pass=false;
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("missing trigger is wait and leaves SMT unevaluated",StringFind(body,"Tín hiệu LTF: Chờ")>=0 &&
      StringFind(body,"Điều kiện SMT: Chưa đánh giá")>=0);
   s.signal.ltf_pass=true; s.signal.smt_required=true;
   s.signal.reason="NO_TRADE: required SMT unavailable, conflicting or unaligned";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("required SMT veto precedes target and risk",StringFind(body,"Điều kiện SMT: Không đạt")>=0 &&
      StringFind(body,"Mục tiêu Chưa đánh giá / Rủi ro Chưa đánh giá")>=0);
   s.signal.smt_required=false; s.signal.reason="TARGET UNAVAILABLE";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("missing target precedes risk",StringFind(body,"Điều kiện SMT: Tùy chọn")>=0 &&
      StringFind(body,"Mục tiêu Chưa có / Rủi ro Chưa đánh giá")>=0);
   s.signal.tp1=105; s.signal.target_pool_id="POOL";
   s.signal.reason="RISK FILTER FAIL: invalid plan";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("risk failure only after target",StringFind(body,"Điều kiện SMT: Tùy chọn")>=0 &&
      StringFind(body,"Mục tiêu Đạt / Rủi ro Không đạt")>=0);
   s.signal.reason="RISK FILTER FAIL: invalid plan or net RR below configured minimum";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("dashboard displays the Vietnamese risk cause while retaining the original signal",
      StringFind(body,"Bộ lọc rủi ro không đạt")>=0 &&
      s.signal.reason=="RISK FILTER FAIL: invalid plan or net RR below configured minimum");
   s.signal.confirmed=true; s.signal.reason="confirmed";
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("confirmed result shows risk pass",StringFind(body,"Mục tiêu Đạt / Rủi ro Đạt")>=0);


   s.signal.entry=100; s.signal.stop=100; s.signal.tp1=103; s.signal.rr=3;
   s.signal.risk_pass=true; s.signal.smt_required=false;
   bool result=ICTEvaluateSignal(s.signal,2);
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("invalid geometry is reported as risk failure despite precheck",!result &&
      StringFind(body,"Mục tiêu Đạt / Rủi ro Không đạt")>=0);
   s.signal.stop=99;
   result=ICTEvaluateSignal(s.signal,2);
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("valid optional-SMT setup stays confirmed",result && StringFind(body,"Điều kiện SMT: Tùy chọn")>=0 &&
      StringFind(body,"Mục tiêu Đạt / Rủi ro Đạt")>=0);
   s.signal.smt_required=true; s.signal.smt_pass=false;
   result=ICTEvaluateSignal(s.signal,2);
   body=ICTUnifiedDashboardBody(s,"","","");
   Check("same setup retains required SMT veto",!result && StringFind(body,"Điều kiện SMT: Không đạt")>=0 &&
      StringFind(body,"Mục tiêu Chưa đánh giá / Rủi ro Chưa đánh giá")>=0);
  }


public static void TestChartLayout() {
   Check("default chart font is 75 percent rounded",ICTChartScaledFontSize(10)==8);
   Check("custom chart fonts use 75 percent",ICTChartScaledFontSize(8)==6 && ICTChartScaledFontSize(12)==9 && ICTChartScaledFontSize(16)==12);
   Check("odd chart font sizes round to the nearest point",ICTChartScaledFontSize(9)==7);
   Check("scaled chart font stays positive",ICTChartScaledFontSize(1)==1);
   SICTChartRect first=new SICTChartRect();
   SICTChartRect adjacent=new SICTChartRect();
   SICTChartRect overlap=new SICTChartRect();
   first.left=10; first.top=10; first.right=50; first.bottom=30;
   adjacent.left=50; adjacent.top=10; adjacent.right=80; adjacent.bottom=30;
   overlap.left=49; overlap.top=29; overlap.right=80; overlap.bottom=40;
   Check("chart labels can touch without overlapping",!ICTChartRectOverlap(first,adjacent));
   Check("chart labels detect pixel collisions",ICTChartRectOverlap(first,overlap));
   Check("chart labels require a visible gap",ICTChartRectTooClose(first,adjacent,4));
   SICTChartRect[] slots=InitArray<SICTChartRect>(0);
   int placed=0,hidden=0; bool separated=true;
   for(int i=0;i<20;i++)
     {
      SICTChartRect slot=new SICTChartRect();
      if(!ICTChartFindLabelRect(300,160,110,20,600,320,slots,slot)) { hidden++; continue; }
      for(int j=0;j<ArraySize(slots);j++)
         if(ICTChartRectTooClose(slot,slots[j],4)) separated=false;
      ArrayResize(ref slots,placed+1); slots[placed]=slot; placed++;
     }
   Check("dense annotations use separate pixel rows with padding",separated && placed==14 && hidden==6);
   SICTChartRect[] panel_slots=InitArray<SICTChartRect>(0); ArrayResize(ref panel_slots,1);
   panel_slots[0].left=0; panel_slots[0].top=0;
   panel_slots[0].right=250; panel_slots[0].bottom=320;
   SICTChartRect blocked=new SICTChartRect();
   Check("annotations stay result_out of the dashboard and chart edge",
      !ICTChartFindLabelRect(300,160,110,20,350,320,panel_slots,blocked));
   ICTChartLayoutBegin("test_",PERIOD_M5,10);
   Check("chart zones use only the selected timeframe",!ICTChartReserveZone(PERIOD_H1,100,200,10,20));
   Check("chart accepts a valid selected-timeframe zone",ICTChartReserveZone(PERIOD_M5,100,200,10,20));
   Check("chart rejects overlapping price and time",!ICTChartReserveZone(PERIOD_M5,150,250,15,25));
   Check("chart counts only hidden overlaps",g_ict_chart_zone_suppressed==1);
   Check("chart accepts touching price boundaries",ICTChartReserveZone(PERIOD_M5,100,200,20,25));
   Check("chart accepts non-overlapping time spans",ICTChartReserveZone(PERIOD_M5,200,300,10,20));
   Check("chart rejects invalid zones",!ICTChartReserveZone(PERIOD_M5,100,100,10,20));
   Check("other timeframe and invalid zones do not inflate overlap count",g_ict_chart_zone_suppressed==1);
   int dark=2497816,light=16448250;
   Check("dark chart label contrast",ICTChartContrast(ICTChartReadableColor(clrMaroon,dark,true),dark)>=4.5);
   Check("light chart label contrast",ICTChartContrast(ICTChartReadableColor(clrYellow,light,false),light)>=4.5);
   int medium=8421504;
   Check("medium chart background chooses a readable text int",
      ICTChartContrast(ICTChartReadableColor(clrYellow,medium,ICTChartLuminance(medium)<0.179),medium)>=4.5);
   g_ict_chart_collect=false;
  }
public static void TestDashboardVietnamese() {
   string risk="RISK FILTER FAIL: invalid plan or net RR below configured minimum";
   string translated=ICTDashboardText(risk);
   Check("dashboard translates the risk veto",StringFind(translated,"rủi ro không đạt")>=0 && StringFind(translated,"RR ròng")>=0);
   Check("dashboard translation does not mutate the engine reason",risk=="RISK FILTER FAIL: invalid plan or net RR below configured minimum");
   string context="HTF PERIOD_H4 bullish bias / MTF PERIOD_M15 bearish structure + valid zone";
   translated=ICTDashboardText(context);
   Check("dashboard translates compound timeframe context",StringFind(translated,"HTF H4 xu hướng tăng")>=0 &&
      StringFind(translated,"MTF M15 cấu trúc giảm và vùng giá hợp lệ")>=0);
   Check("dashboard keeps unknown diagnostics visible",ICTDashboardText("UNMAPPED_CODE|EURUSD") == "Chi tiết gốc: UNMAPPED_CODE|EURUSD");
   Check("dashboard translates risk detail without discarding it",
      ICTDashboardText("Risk gate: Insufficient free margin")=="Điều kiện rủi ro: Ký quỹ khả dụng không đủ");
  }

public static void TestSignalBridge() {
   SICTUnifiedSnapshot source=new SICTUnifiedSnapshot(); ZeroMemory(source); source.schema=ICT_UNIFIED_SCHEMA;
   SignalFixture(source.signal); ICTEvaluateSignal(source.signal,2);
   source.symbol=source.signal.symbol; source.frames=source.signal.frames; source.asof=source.signal.asof; source.chart_tf=PERIOD_M5;
   source.valid=true; source.capacity_ok=true; source.display_start=100000;
   source.comparison1="PEER1"; source.comparison2="PEER2";
   int[] frames = new int[] {PERIOD_M5,PERIOD_H1,PERIOD_D1};
   long[] opens = new long[] {100000,96000,1000};
   for(int i=0;i<3;i++)
     {
      source.tiers[i].timeframe=frames[i]; source.tiers[i].status=ICT_CONTEXT_BULLISH;
      FixtureBar(source.tiers[i].last_bar,opens[i],99,102,98,101);
      source.tiers[i].closed_at=ICTBarClose(frames[i],opens[i]);
     }
   source.tiers[0].displacement_up=true;
   source.layer_count=1; source.layers[0].timeframe=PERIOD_M5; source.layers[0].last_close=source.asof;
   source.layers[0].peers[0].comparison="PEER1"; source.layers[0].peers[0].ready=true;
   source.layers[0].peers[0].relation_known=true; source.layers[0].peers[0].relation=1;
   source.layers[0].peers[0].state=ICT_SMT_PEER_BULLISH; source.layers[0].peers[0].last_close=source.asof;
   source.layers[0].peers[1].comparison="PEER2"; source.layers[0].peers[1].reason="DATA INSUFFICIENT";
   double[] values=InitArray<double>(0); string[] texts=InitArray<string>(0); SICTUnifiedSnapshot decoded=new SICTUnifiedSnapshot();
   Check("central signal packs",ICTUnifiedPack(source,ref values,ref texts));
   Check("central signal bridge roundtrip",ICTUnifiedUnpack(values,texts,decoded) && decoded.signal.id==source.signal.id &&
      decoded.signal.entry==source.signal.entry && decoded.signal.confirmation_time==source.signal.confirmation_time &&
      decoded.tiers[0].last_bar.time==source.tiers[0].last_bar.time && decoded.tiers[0].displacement_up && decoded.chart_tf==PERIOD_M5);
   Check("bridge retains independent unavailable peer",decoded.layers[0].peers[0].state==ICT_SMT_PEER_BULLISH &&
      decoded.layers[0].peers[1].state==ICT_SMT_PEER_NA && decoded.layers[0].peers[1].reason=="DATA INSUFFICIENT");
   source.signal.ltf_pass=false; ICTUnifiedPack(source,ref values,ref texts);
   Check("bridge refuses confirmed label without LTF gate",!ICTUnifiedUnpack(values,texts,decoded));
   source.signal.ltf_pass=true; source.signal.asof++; ICTUnifiedPack(source,ref values,ref texts);
   Check("bridge refuses decision-context timestamp mismatch",!ICTUnifiedUnpack(values,texts,decoded));
   source.signal.asof--; ICTUnifiedPack(source,ref values,ref texts); ArrayResize(ref values,ArraySize(values)-1);
   Check("bridge rejects truncated snapshot",!ICTUnifiedUnpack(values,texts,decoded));
   SICTSMTEvent original=new SICTSMTEvent(); ZeroMemory(original); original.signal.comparison="PEER1";
   original.signal.timeframe=PERIOD_M5; original.signal.direction=1; original.signal.relation=1;
   original.signal.state=SRMP_SMT_BULLISH;
   original.signal.primary_prior_time=99000; original.signal.primary_pivot_time=99300;
   original.signal.comparison_prior_time=99000; original.signal.comparison_pivot_time=99600;
   original.signal.primary_prior=100; original.signal.primary_recent=95;
   original.signal.comparison_prior=100; original.signal.comparison_recent=101;
   original.signal.pivot_confirmation_time=100000; original.signal.confirmation_time=100300;
   original.signal.event_id="TEST|PEER1|"+IntegerToString((int)PERIOD_M5)+"|1|1|99000|99300|99000|99600";
   original.life=ICT_SMT_CONFIRMED; original.changed_at=100300;
   SICTSMTEvent restored=new SICTSMTEvent(); ICTPackSMTPayload(original,ref values);
   Check("SMT journal payload preserves original confirmation",ICTUnpackSMTPayload("TEST","PEER1",original.signal.event_id,values,100300,restored) &&
      restored.signal.confirmation_time==original.signal.confirmation_time && restored.signal.primary_pivot_time==99300 &&
      restored.signal.comparison_pivot_time==99600 && restored.signal.primary_recent==95);
   Check("SMT journal rejects identity corruption",!ICTUnpackSMTPayload("TEST","PEER1","BAD_ID",values,100300,restored));
   values[12]=100600;
   Check("SMT journal rejects future confirmation",!ICTUnpackSMTPayload("TEST","PEER1",original.signal.event_id,values,100300,restored));
   ICTPackSMTPayload(original,ref values); ArrayResize(ref values,ArraySize(values)-1);
   Check("SMT journal rejects truncated payload",!ICTUnpackSMTPayload("TEST","PEER1",original.signal.event_id,values,100300,restored));
  }

}