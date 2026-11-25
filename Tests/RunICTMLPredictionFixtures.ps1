<# Execute the production pure MQL parser through a mechanical C# adapter.
   No MetaTrader process, file-reading wrapper, account or order API is used. #>
[CmdletBinding()]
param([string]$WireFile='')
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$header=Get-Content -LiteralPath (Join-Path $project 'Include\ICTMLPrediction.mqh') -Raw -Encoding UTF8
$boundary=$header.IndexOf('bool ICTMLReadPrediction(')
$dashboard=$header.IndexOf('string ICTMLDashboardBody(')
if($boundary -lt 0 -or $dashboard -lt $boundary) { throw 'Pure parser/file wrapper boundaries were not found' }
$source=$header.Substring(0,$boundary)+"`n"+$header.Substring($dashboard)
$fixtures=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ICTMLPredictionTests.mq5') -Raw -Encoding UTF8
$fixtureEnd=$fixtures.IndexOf('int OnInit()')
if($fixtureEnd -lt 0) { throw 'ML fixture entry point was not found' }
$source+="`n"+$fixtures.Substring(0,$fixtureEnd)
if($source -match '\b(FileOpen|FileReadArray|OrderSend|TimeGMT|AccountInfoInteger)\s*\(') {
    throw 'The account-free parser adapter unexpectedly includes a terminal API'
}
$source=[regex]::Replace($source,'(?m)^#[^\r\n]*','')
$source=$source -replace '\bdatetime\b','long' -replace '\bENUM_TIMEFRAMES\b','int' -replace '\bout\b','result_out'
$source=[regex]::Replace($source,'struct\s+(\w+)\s*\{([^}]+)\}\s*;',{
    param($match)
    $fields=''
    foreach($declaration in $match.Groups[2].Value.Split(';')) {
        $declaration=$declaration.Trim()
        if(!$declaration) { continue }
        $fieldMatch=[regex]::Match($declaration,'^(\w+)\s+(.+)$')
        if(!$fieldMatch.Success) { throw "Unsupported ML field declaration: $declaration" }
        $type=$fieldMatch.Groups[1].Value
        foreach($field in $fieldMatch.Groups[2].Value.Split(',')) {
            $initializer=if($type -eq 'string') { '=string.Empty' } else { '' }
            $fields+="public $type $($field.Trim())$initializer;`n"
        }
    }
    return "public class $($match.Groups[1].Value) {`n$fields}`n"
})
$source=[regex]::Replace($source,'(?m)^(bool|int|string|void)\s+(\w+)\s*\(([^{}]*?)\)\s*\{',{
    param($match)
    $parameters=foreach($parameter in $match.Groups[3].Value.Split(',')) {
        $parameter=$parameter.Trim()
        if(!$parameter) { continue }
        $parameter=$parameter -replace '\bconst\s+',''
        if($parameter -match '^(bool|long|double|string)\s*&') {
            $parameter='ref '+($parameter -replace '&','')
        } else { $parameter=$parameter -replace '&','' }
        $parameter.Trim()
    }
    return "public static $($match.Groups[1].Value) $($match.Groups[2].Value)($($parameters -join ',')) {"
})
$source=$source -replace '\bstring\s+(\w+)\[\]\s*;','string[] $1=new string[0];'
$source=$source -replace '\bSICTMLPrediction\s+(\w+)\s*;','SICTMLPrediction $1=new SICTMLPrediction();'
$source=$source -replace '(?m)^int checks=0,failures=0;','public static int checks=0,failures=0;'
# These production functions take primitive output arguments by reference.
# All current call-site outputs are simple local variable names. Fail closed
# in the C# compiler if a later source change needs a richer syntax adapter.
$source=[regex]::Replace($source,'\b(ICTMLNumber|ICTMLUnsigned)\(([^,\r\n]+),\s*(\w+)\)','$1($2,ref $3)')
$source=[regex]::Replace($source,'\bICTMLOptionalNumber\(([^,\r\n]+),\s*(\w+),\s*(\w+)\)','ICTMLOptionalNumber($1,ref $2,ref $3)')
$source=[regex]::Replace($source,"\bStringSplit\(([^,\r\n]+),\s*('[^']'),\s*(\w+)\)",'StringSplit($1,$2,ref $3)')
$runtimeName='ICTMLParserRuntime_'+[Guid]::NewGuid().ToString('N')
$helpers=@'
using System;
using System.Globalization;
using System.Reflection;
using System.Text;
public static class ICTMLParserRuntime {
 public const int PERIOD_M1=1,PERIOD_M5=5,PERIOD_M15=15,PERIOD_H1=16385,PERIOD_H4=16388,PERIOD_D1=16408;
 public const int TIME_DATE=1,TIME_SECONDS=4;
 static StringBuilder log=new StringBuilder();
 public static int StringLen(string value){return value.Length;}
 public static int StringGetCharacter(string value,int index){return value[index];}
 public static string StringSubstr(string value,int start,int length=-1){return length<0?value.Substring(start):value.Substring(start,length);}
 public static int StringFind(string value,string find){return value.IndexOf(find,StringComparison.Ordinal);}
 public static int StringSplit(string value,char delimiter,ref string[] fields){fields=value.Split(new char[]{delimiter});return fields.Length;}
 public static double StringToDouble(string value){double number;return double.TryParse(value,NumberStyles.Float,CultureInfo.InvariantCulture,out number)?number:double.NaN;}
 public static bool MathIsValidNumber(double value){return !double.IsNaN(value) && !double.IsInfinity(value);}
 public static double MathAbs(double value){return Math.Abs(value);}
 public static string DoubleToString(double value,int digits){return value.ToString("F"+digits,CultureInfo.InvariantCulture);}
 public static string IntegerToString(long value){return value.ToString(CultureInfo.InvariantCulture);}
 public static string TimeToString(long value,int mode){return value.ToString(CultureInfo.InvariantCulture);}
 public static void Print(params object[] values){foreach(object value in values)log.Append(value);log.AppendLine();}
 public static void ZeroMemory(object value){foreach(FieldInfo field in value.GetType().GetFields(BindingFlags.Public|BindingFlags.Instance)){field.SetValue(value,field.FieldType==typeof(string)?(object)string.Empty:Activator.CreateInstance(field.FieldType));}}
 public static string Run(){checks=0;failures=0;log.Length=0;RunICTMLPredictionFixtures();log.AppendLine("ICTMLPredictionFixtures RESULT checks="+checks+" failures="+failures);return log.ToString();}
 public static string CheckWire(string line){SICTMLPrediction snapshot=new SICTMLPrediction();bool valid=ICTMLParsePrediction(line,ICTMLFixtureModel(),"TEST","M15",1700000000,1700000050,snapshot);return valid?"WIRE PASS":("WIRE FAIL "+snapshot.status+": "+snapshot.reason);}
'@
$helpers=$helpers.Replace('public static class ICTMLParserRuntime {',"public static class $runtimeName {")
$code=$helpers+"`n"+$source+"`n}"
$output=Join-Path $PSScriptRoot '.core-fixtures'
New-Item -ItemType Directory -Path $output -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $output 'ICTMLParserRuntime.cs'),$code,[Text.UTF8Encoding]::new($false))
$types=Add-Type -TypeDefinition $code -Language CSharp -PassThru
$runtime=$types | Where-Object Name -eq $runtimeName
$result=$runtime.GetMethod('Run').Invoke($null,@())
Write-Output $result
if($result -notmatch 'failures=0\s*$') { throw 'Production MQL prediction parser fixture failed' }
if($WireFile) {
    $bytes=[IO.File]::ReadAllBytes($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WireFile))
    if($bytes.Length -gt 8192 -or @($bytes | Where-Object { $_ -gt 127 }).Count) { throw 'Cross-language wire fixture must contain at most 8192 ASCII bytes' }
    $wire=[Text.Encoding]::ASCII.GetString($bytes)
    $wireResult=$runtime.GetMethod('CheckWire').Invoke($null,@($wire))
    Write-Output $wireResult
    if($wireResult -ne 'WIRE PASS') { throw 'Cross-language wire fixture was rejected by the production MQL parser' }
}
Write-Output 'PASS: production pure MQL protocol parser through mechanical C# adaptation. MT5 runtime, file wrapper and broker execution were NOT run.'
