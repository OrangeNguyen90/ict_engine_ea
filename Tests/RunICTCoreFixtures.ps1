[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$output=Join-Path $PSScriptRoot '.core-fixtures'
New-Item -ItemType Directory -Path $output -Force | Out-Null

# Execute the production pure functions through a mechanical MQL -> C# syntax
# adapter using the Windows .NET compiler. No market API is stubbed as success:
# functions that access MT5 history/files are excluded. Dashboard diagnostics
# use fixed clock and zero price stubs only to check text and gate ordering.
# This proves algorithm fixtures, not MT5 rendering, broker behavior or backtests.
function Remove-MqlFunction([string]$source,[string]$name) {
    $match=[regex]::Match($source,"(?m)^(?:bool|int|uint|void|datetime|double|string)\s+$name\s*\(")
    if(!$match.Success) { return $source }
    $brace=$source.IndexOf('{',$match.Index)
    $depth=0
    for($i=$brace;$i -lt $source.Length;$i++) {
        if($source[$i] -eq '{') { $depth++ }
        if($source[$i] -eq '}') { $depth--; if($depth -eq 0) { return $source.Remove($match.Index,$i-$match.Index+1) } }
    }
    throw "Unterminated function $name"
}
function Get-MqlFunction([string]$source,[string]$name) {
    $match=[regex]::Match($source,"(?m)^(?:bool|int|void|double|color|string)\s+$name\s*\(")
    if(!$match.Success) { throw "Missing pure chart function $name" }
    $brace=$source.IndexOf('{',$match.Index)
    $depth=0
    for($i=$brace;$i -lt $source.Length;$i++) {
        if($source[$i] -eq '{') { $depth++ }
        if($source[$i] -eq '}') { $depth--; if($depth -eq 0) { return $source.Substring($match.Index,$i-$match.Index+1) } }
    }
    throw "Unterminated function $name"
}
$modules=@(
 'ICTTimeframeMapper.mqh','ICTSignalResult.mqh','MarketStructure.mqh','ICTBarSnapshot.mqh','ICTSessionLiquidity.mqh',
 'SymbolCorrelationEngine.mqh','SMTSignalValidator.mqh','SMTDivergenceDetector.mqh',
 'FVGDetector.mqh','OrderBlockDetector.mqh','OrderBlockScoring.mqh',
 'ICTSweepSequence.mqh','ICTStrongOrderBlock.mqh','ICTDynamicSMT.mqh','ICTRangeTypes.mqh','ICTRangeEngine.mqh',
 'ICTBalancedPriceRange.mqh','ICTUnifiedAnalysis.mqh','ICTUnifiedBridge.mqh','ICTPositionRisk.mqh')
$source=''
foreach($module in $modules) {
    $part=Get-Content -LiteralPath (Join-Path $project "Include\$module") -Raw -Encoding UTF8
    if($module -eq 'ICTRangeEngine.mqh') { $part=$part.Substring(0,$part.IndexOf('class CICTRangeEngine')) }
    if($module -eq 'ICTUnifiedAnalysis.mqh') { $part=$part.Substring(0,$part.IndexOf('class CICTUnifiedAnalysis')) }
    if($module -eq 'ICTPositionRisk.mqh') { $part=$part.Substring(0,$part.IndexOf('bool ICTReadPositionRisk(')) }
    if($module -eq 'ICTUnifiedBridge.mqh') {
        $part=$part.Substring(0,$part.IndexOf('string ICTUnifiedFile'))
        # Expand the production numeric/string wire macros without importing any
        # file, terminal, account or GlobalVariable functions from the bridge.
        $part=[regex]::Replace($part,'\bU_P\(([^)]+)\)','v[n++]=ICTNumber($1)')
        $part=[regex]::Replace($part,'\bU_T\(([^)]+)\)','t[k++]=$1')
        $part=$part -replace '\bU_G\(bool\)','(ICTUTake(v,n,ok)!=0)'
        $part=[regex]::Replace($part,'\bU_G\((\w+)\)','($1)ICTUTake(v,n,ok)')
        $part=[regex]::Replace($part,'\bU_E\((\w+)\)','($1)ICTUEnumTake(v,n,ok)')
        $part=$part -replace '\bU_S\b','ICTUText(t,k,ok)'
    }
    foreach($name in @('SRMPAnalyzeStructureAsymmetric','SRMPAnalyzeStructure','ICTCopyClosedAsOf',
       'SRMPCalculateCorrelation','SRMPValidateComparisonSymbol','SRMPSMTPivotConfirmation','SRMPFindSMT',
       'SRMPFindFVG','SRMPFindOrderBlock','ICTResolveBrokerSymbol','ICTResolveSMTComparators',
       'ICTRangeCSV','ICTRangeHistoryError','ICTRangeDetectZones','ICTRangeEvidence','ICTRangeSourceExplanation','ICTUnifiedSignature')) {
        $part=Remove-MqlFunction $part $name
    }
    $source+="`n$part"
}
$diagnostic=Get-Content -LiteralPath (Join-Path $project 'Include\ICTUnifiedDecisionAdapter.mqh') -Raw -Encoding UTF8
$diagnosticStart=$diagnostic.IndexOf('string ICTUnifiedSMTDiagnostic(')
$diagnosticEnd=$diagnostic.IndexOf('// The final result', $diagnosticStart)
if($diagnosticStart -lt 0 -or $diagnosticEnd -lt 0) { throw 'SMT diagnostic function not found' }
$source+="`n"+$diagnostic.Substring($diagnosticStart,$diagnosticEnd-$diagnosticStart)
$source+="`n"+(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ICTUnifiedCoreFixtures.mqh') -Raw -Encoding UTF8)
foreach($fixture in @('ICTConfluenceLifecycleFixtures.mqh','ICTSessionLiquidityFixtures.mqh','ICTSignalJournalLiveFixtures.mqh','ICTPositionRiskFixtures.mqh')) {
    $source+="`n"+(Get-Content -LiteralPath (Join-Path $PSScriptRoot $fixture) -Raw -Encoding UTF8)
}
$bridgeFixtures=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ICTUnifiedTests.mq5') -Raw -Encoding UTF8
$layout=Get-Content -LiteralPath (Join-Path $project 'Include\ICTChartLayout.mqh') -Raw -Encoding UTF8
foreach($name in @('SICTChartRect','SICTChartZone')) {
    $match=[regex]::Match($layout,"struct\s+$name\s*\{[^}]+\};")
    if(!$match.Success) { throw "Missing chart type $name" }
    $source+="`n"+$match.Value
}
foreach($name in @('ICTChartRectOverlap','ICTChartRectTooClose','ICTChartFindLabelRect','ICTChartZoneOverlap','ICTChartScaledFontSize','ICTChartLayoutBegin','ICTChartZoneTimeframe',
                    'ICTChartReserveZone','ICTChartChannel','ICTChartLuminance','ICTChartContrast','ICTChartReadableColor')) {
    $source+="`n"+(Get-MqlFunction $layout $name)
}
$localization=Get-Content -LiteralPath (Join-Path $project 'Include\ICTDashboardVietnamese.mqh') -Raw -Encoding UTF8
$source+="`n"+(Get-MqlFunction $localization 'ICTDashboardText')
$renderer=Get-Content -LiteralPath (Join-Path $project 'Include\ICTUnifiedRenderer.mqh') -Raw -Encoding UTF8
$positionRenderer=Get-Content -LiteralPath (Join-Path $project 'Include\ICTPositionRiskRenderer.mqh') -Raw -Encoding UTF8
foreach($name in @('ICTPositionMoney','ICTPositionMoneyPercent','ICTPositionRiskStatus','ICTPositionRiskBody')) {
    $source+="`n"+(Get-MqlFunction $positionRenderer $name)
}
foreach($name in @('ICTUnifiedTF','ICTUnifiedBias','ICTUnifiedStructureText','ICTDashboardSignalState',
                    'ICTStrongOBDetails','ICTUnifiedDashboardBody')) {
    $source+="`n"+(Get-MqlFunction $renderer $name)
}
$source+="`n"+(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ICTUnifiedDiagnosticFixtures.mqh') -Raw -Encoding UTF8)
$layoutStart=$bridgeFixtures.IndexOf('void TestChartLayout()')
$bridgeStart=$bridgeFixtures.IndexOf('void TestSignalBridge()')
$bridgeEnd=$bridgeFixtures.IndexOf('int OnInit()')
$source+="`n"+$bridgeFixtures.Substring($layoutStart,$bridgeStart-$layoutStart)
$source+="`n"+$bridgeFixtures.Substring($bridgeStart,$bridgeEnd-$bridgeStart)
$source=[regex]::Replace($source,"C'(\d+),(\d+),(\d+)'",{
    param($m)
    return ([int]$m.Groups[1].Value -bor ([int]$m.Groups[2].Value -shl 8) -bor ([int]$m.Groups[3].Value -shl 16)).ToString()
})
$source=$source -replace '\bcolor\b','int'
$source=[regex]::Replace($source,'/\*[\s\S]*?\*/','')
$source=[regex]::Replace($source,'(?m)//[^\r\n]*','')
$constants=''
foreach($define in [regex]::Matches($source,'(?m)^#define\s+(\w+)\s+(\d+)\s*$')) {
    $constants+="public const int $($define.Groups[1].Value)=$($define.Groups[2].Value);`n"
}
$source=[regex]::Replace($source,'(?m)^#[^\r\n]*','')
# MQL permits implicit bool-to-number payload fields and numeric-to-bool casts.
$source=$source -replace 'v\[4\]=s\.comparator_extreme','v[4]=(s.comparator_extreme ? 1 : 0)'
$source=$source -replace 'v\[19\]=e\.seed_context','v[19]=(e.seed_context ? 1 : 0)'
$source=[regex]::Replace($source,'\(bool\)(v\[\d+\])','($1!=0)')
$script:enumNames=[System.Collections.Generic.List[string]]::new()
$source=[regex]::Replace($source,'enum\s+(\w+)\s*\{([^}]+)\}\s*;',{
    param($match)
    $script:enumNames.Add($match.Groups[1].Value)
    $value=0; $text=''
    foreach($member in $match.Groups[2].Value.Split(',')) {
        if([string]::IsNullOrWhiteSpace($member)) { continue }
        $pair=$member.Trim().Split('=')
        if($pair.Count -gt 1) { $value=[int]$pair[1].Trim() }
        $text+="public const int $($pair[0].Trim())=$value;`n"; $value++
    }
    return $text
})
foreach($name in $script:enumNames) { $source=$source -replace "\b$name\b",'int' }
$source=$source -replace '\bENUM_TIMEFRAMES\b','int'
$source=$source -replace '\bdatetime\b','long'
$source=$source -replace '\bout\b','result_out'
$source=$source -replace '\bevent\b','evt'
$source=[regex]::Replace($source,"D'([^']+)'",{param($m) 'Stamp("'+$m.Groups[1].Value+'")'})
$classNames=@('MqlRates','MqlDateTime')+@([regex]::Matches($source,'struct\s+(\w+)') | ForEach-Object {$_.Groups[1].Value})
$refSignatures=@{ ArrayResize=@($true,$false); ArrayCopy=@($true,$false,$false,$false,$false); StringReplace=@($true,$false,$false) }
$source=[regex]::Replace($source,'(?m)^(bool|int|uint|long|double|string|void)\s+(\w+)\s*\(([^{}]*?)\)\s*\{',{
    param($m)
    $parameters=@(); $flags=@()
    foreach($part in $m.Groups[3].Value.Split(',')) {
        $p=$part.Trim(); if($p -eq '') {continue}
        $array=$p -match '\[\]'; $constant=$p -match '\bconst\b'
        $type=[regex]::Match($p,'(?:const\s+)?(\w+)').Groups[1].Value
        $byref= !$constant -and $p.Contains('&') -and ($array -or $type -in @('int','uint','long','double','bool','string'))
        $p=$p -replace '\bconst\s+','' -replace '&',''
        if($array) { $p=$p -replace '^(\w+)\s+(\w+)\[\]','$1[] $2' }
        if($byref) { $p='ref '+$p.Trim() }
        $flags+= $byref; $parameters+=$p.Trim()
    }
    $refSignatures[$m.Groups[2].Value]=$flags
    return "public static $($m.Groups[1].Value) $($m.Groups[2].Value)($($parameters -join ',')) {"
})
$source=[regex]::Replace($source,'struct\s+(\w+)\s*\{([^}]+)\}\s*;',{
    param($m)
    $fields=''
    foreach($declaration in $m.Groups[2].Value.Split(';')) {
        $d=$declaration.Trim(); if($d -eq '') {continue}
        $match=[regex]::Match($d,'^(\w+)\s+([\s\S]+)$')
        if(!$match.Success) {throw "Unsupported field: $d"}
        $type=$match.Groups[1].Value
        foreach($field in $match.Groups[2].Value.Split(',')) {
            $f=$field.Trim(); $array=[regex]::Match($f,'^(\w+)\[([^\]]*)\]$')
            if($array.Success) {
                $size=$array.Groups[2].Value; if($size -eq '') {$size='0'}
                $fields+="public $type[] $($array.Groups[1].Value)=InitArray<$type>($size);`n"
            } elseif($type -eq 'string') { $fields+="public string $f=string.Empty;`n" }
            elseif($type -in $classNames) { $fields+="public $type $f=new $type();`n" }
            else { $fields+="public $type $f;`n" }
        }
    }
    return "public class $($m.Groups[1].Value) {`n$fields}`n"
})
$types='(?:int|uint|long|double|bool|string|'+(($classNames | ForEach-Object {[regex]::Escape($_)}) -join '|')+')'
# Array locals, including comma-separated dynamic declarations.
$source=[regex]::Replace($source,"\b($types)\s+(\w+\[\](?:\s*,\s*\w+\[\])+);",{
    param($m)
    $type=$m.Groups[1].Value
    return (($m.Groups[2].Value.Split(',') | ForEach-Object { "$type[] $($_.Trim().Replace('[]',''))=InitArray<$type>(0);" }) -join ' ')
})
$source=[regex]::Replace($source,"\b($types)\s+(\w+)\[\d*\]\s*=\s*\{",'$1[] $2 = new $1[] {')
$source=[regex]::Replace($source,"\b($types)\s+(\w+)\[([^\]]*)\]\s*;",{
    param($m)
    $type=$m.Groups[1].Value; $size=$m.Groups[3].Value; if($size -eq '') {$size='0'}
    return "$type[] $($m.Groups[2].Value)=InitArray<$type>($size);"
})
foreach($type in $classNames) {
    $source=[regex]::Replace($source,"\b$type\s+(\w+)\s*;",{param($m) "$type $($m.Groups[1].Value)=new $type();"})
}
$source=$source -replace '(?<!public )\bconst\s+',''

# Insert C# ref at call sites from the original MQL signatures. Split only
# top-level arguments so array subscripts/nested calls retain their semantics.
foreach($name in @($refSignatures.Keys)) {
    $flags=$refSignatures[$name]; if($flags -notcontains $true) {continue}
    $matches=@([regex]::Matches($source,"\b$([regex]::Escape($name))\s*\("))
    for($q=$matches.Count-1;$q -ge 0;$q--) {
        $m=$matches[$q]; $open=$source.IndexOf('(',$m.Index); $depth=0; $quote=[char]0; $close=-1
        for($j=$open;$j -lt $source.Length;$j++) {
            $ch=$source[$j]
            if($quote -ne [char]0) { if($ch -eq $quote -and ($j -eq 0 -or $source[$j-1] -ne '\')) {$quote=[char]0}; continue }
            if($ch -eq '"' -or $ch -eq "'") {$quote=$ch;continue}
            if($ch -eq '(') {$depth++}; if($ch -eq ')') {$depth--;if($depth -eq 0){$close=$j;break}}
        }
        if($close -lt 0) {throw "Unclosed call $name"}
        $after=$source.Substring($close+1).TrimStart()
        if($after.StartsWith('{')) {continue}
        $args=$source.Substring($open+1,$close-$open-1)
        $parts=[System.Collections.Generic.List[string]]::new(); $start=0;$nested=0;$quote=[char]0
        for($j=0;$j -lt $args.Length;$j++) {
            $ch=$args[$j]
            if($quote -ne [char]0) {if($ch -eq $quote -and ($j -eq 0 -or $args[$j-1] -ne '\')){$quote=[char]0};continue}
            if($ch -eq '"' -or $ch -eq "'"){$quote=$ch;continue}
            if($ch -eq '(' -or $ch -eq '['){$nested++};if($ch -eq ')' -or $ch -eq ']'){$nested--}
            if($ch -eq ',' -and $nested -eq 0){$parts.Add($args.Substring($start,$j-$start));$start=$j+1}
        }
        $parts.Add($args.Substring($start))
        for($j=0;$j -lt $parts.Count -and $j -lt $flags.Count;$j++) {
            if($flags[$j] -and $parts[$j].Trim() -notmatch '^ref\s') {$parts[$j]='ref '+$parts[$j].Trim()}
        }
        $source=$source.Remove($open+1,$close-$open-1).Insert($open+1,($parts -join ','))
    }
}
$helpers=@'
using System;
using System.Reflection;
using System.Text;
public static class ICTCoreRuntime {
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
 public class MqlRates { public long time; public double open,high,low,close; }
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
 public static double MathLog(double x){return Math.Log(x);} public static double MathSqrt(double x){return Math.Sqrt(x);} public static double MathSin(double x){return Math.Sin(x);}
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
 public static string Run(){failures=0;checks=0;log.Length=0;RunUnifiedCoreFixtures();RunUnifiedDiagnosticFixtures();TestChartLayout();TestDashboardVietnamese();TestSignalBridge();log.AppendLine("ICTCoreFixtures RESULT checks="+checks+" failures="+failures);return log.ToString();}
'@
$runtimeTypeName='ICTCoreRuntime_'+[Guid]::NewGuid().ToString('N')
$helpers=$helpers.Replace('public static class ICTCoreRuntime {',"public static class $runtimeTypeName {")
$code=$helpers+"`n"+$constants+"`n"+$source+"`n}"
[IO.File]::WriteAllText((Join-Path $output 'ICTCoreRuntime.cs'),$code,[Text.UTF8Encoding]::new($false))
$compiledTypes=Add-Type -TypeDefinition $code -Language CSharp -PassThru
$runtimeType=$compiledTypes | Where-Object Name -eq $runtimeTypeName
$result=$runtimeType.GetMethod('Run').Invoke($null,@())
$report=Join-Path $PSScriptRoot 'Reports\ICT_UNIFIED_CORE_FIXTURES.txt'
New-Item -ItemType Directory -Path (Split-Path $report -Parent) -Force | Out-Null
$header="Production pure MQL algorithms and dashboard diagnostics executed through mechanical C# syntax adaptation (fixed clock, zero chart prices).`r`nNOT a MetaTrader runtime test or market backtest.`r`nUTC: $([DateTime]::UtcNow.ToString('o'))`r`n"
foreach($module in $modules) { $hash=(Get-FileHash -LiteralPath (Join-Path $project "Include\$module") -Algorithm SHA256).Hash; $header+="$module SHA256=$hash`r`n" }
$hash=(Get-FileHash -LiteralPath (Join-Path $project 'Include\ICTChartLayout.mqh') -Algorithm SHA256).Hash
$header+="ICTChartLayout.mqh SHA256=$hash`r`n"
$hash=(Get-FileHash -LiteralPath (Join-Path $project 'Include\ICTDashboardVietnamese.mqh') -Algorithm SHA256).Hash
$header+="ICTDashboardVietnamese.mqh SHA256=$hash`r`n"
$hash=(Get-FileHash -LiteralPath (Join-Path $project 'Include\ICTUnifiedRenderer.mqh') -Algorithm SHA256).Hash
$header+="ICTUnifiedRenderer.mqh SHA256=$hash`r`n"
[IO.File]::WriteAllText($report,$header+"`r`n"+$result,[Text.UTF8Encoding]::new($false))
$result -split "`r?`n" | Where-Object { $_ -match ' FAIL$|RESULT' } | Write-Output
if($result -notmatch 'failures=0\s*$') {throw "Core assertion failure; see $report"}
