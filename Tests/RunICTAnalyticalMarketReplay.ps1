[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DataPath,
      [ValidateSet('M5','M15','H1')][string]$Timeframe='M5',
      [ValidateRange(16,240)][int]$ReplayBars=64)
$ErrorActionPreference='Stop'
$datasetPath=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DataPath)
. (Join-Path $PSScriptRoot 'RunICTCoreFixtures.ps1')
$marketManifest=Get-Content -LiteralPath (Join-Path $datasetPath 'market_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$marketResults=@()
function New-ICTCoreValue([string]$Name) { [Activator]::CreateInstance($runtimeType.GetNestedType($Name)) }
function Invoke-ICTCoreValue([string]$Name,[object[]]$Arguments) { $runtimeType.GetMethod($Name).Invoke($null,$Arguments) }
function Read-ICTMarketRates([string]$Path) {
    $records=@(Import-Csv -LiteralPath $Path)
    $array=[Array]::CreateInstance($runtimeType.GetNestedType('MqlRates'),$records.Count)
    for($index=0;$index -lt $records.Count;$index++) {
        $record=$records[$index]; $bar=New-ICTCoreValue 'MqlRates'; $bar.time=[long]$record.time
        foreach($field in @('open','high','low','close')) { $bar.$field=[double]::Parse($record.$field,[Globalization.CultureInfo]::InvariantCulture) }
        $bar.spread=[int]$record.spread; $bar.tick_volume=[long]$record.tick_volume; $bar.real_volume=[long]$record.real_volume
        $array.SetValue($bar,$index)
    }
    return ,$array
}
foreach($series in $marketManifest.series | Where-Object { $_.timeframe -eq $Timeframe -and $_.count -gt 1000 }) {
    $csvPath=Join-Path $datasetPath $series.file
    if((Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $series.sha256) { throw 'Captured data hash changed' }
    $rows=@(Import-Csv -LiteralPath $csvPath)
    $rates=[Array]::CreateInstance($runtimeType.GetNestedType('MqlRates'),$rows.Count)
    for($at=0;$at -lt $rows.Count;$at++) {
        $bar=New-ICTCoreValue 'MqlRates'; $row=$rows[$at]
        $bar.time=[long]$row.time; $bar.open=[double]::Parse($row.open,[Globalization.CultureInfo]::InvariantCulture)
        $bar.high=[double]::Parse($row.high,[Globalization.CultureInfo]::InvariantCulture); $bar.low=[double]::Parse($row.low,[Globalization.CultureInfo]::InvariantCulture)
        $bar.close=[double]::Parse($row.close,[Globalization.CultureInfo]::InvariantCulture); $bar.spread=[int]$row.spread
        $bar.tick_volume=[long]$row.tick_volume; $bar.real_volume=[long]$row.real_volume; $rates.SetValue($bar,$at)
    }
    $fitCount=$rates.Length-$ReplayBars
    $training=[Array]::CreateInstance($runtimeType.GetNestedType('MqlRates'),$fitCount)
    [Array]::Copy($rates,$training,$fitCount)
    $configuration=New-ICTCoreValue 'SICTStatConfig'
    $null=Invoke-ICTCoreValue 'ICTStatDefaultConfig' @($configuration)
    $model=New-ICTCoreValue 'SICTStatModel'; $snapshot=New-ICTCoreValue 'SICTStatSnapshot'
    $samples=[Array]::CreateInstance($runtimeType.GetNestedType('SICTStatSample'),0)
    $arguments=[object[]]::new(4); $arguments[0]=$training; $arguments[1]=[double]$series.point; $arguments[2]=$configuration; $arguments[3]=$samples
    $built=$runtimeType.GetMethod('ICTStatBuildSamples').Invoke($null,$arguments); $samples=$arguments[3]
    $prepared=$false; $finished=$false
    if($built) { $prepared=Invoke-ICTCoreValue 'ICTStatPrepare' @($configuration,$samples,$model,$snapshot) }
    if($prepared) {
        $steps=0
        while((Invoke-ICTCoreValue 'ICTStatTrainStep' @($model,$samples,$snapshot))) { $steps++; if($steps -gt 20000) { throw 'Unexpected training loop' } }
        $finished=Invoke-ICTCoreValue 'ICTStatFinish' @($model,$samples,$snapshot)
    }
    $tfValue=switch($Timeframe) { 'M5' {5} 'M15' {15} 'H1' {16385} }
    $seconds=switch($Timeframe) { 'M5' {300} 'M15' {900} 'H1' {3600} }
    $middleName=if($Timeframe -eq 'H1') {'H4'} else {'H1'}
    $middleTF=if($Timeframe -eq 'H1') {16388} else {16385}
    $middle=Read-ICTMarketRates (Join-Path $datasetPath ($series.symbol+'_'+$middleName+'.csv'))
    $upper=Read-ICTMarketRates (Join-Path $datasetPath ($series.symbol+'_D1.csv'))
    $newSignals=0; $oldSignals=0; $experimentalSignals=0; $alignedBars=0; $signalRows=@()
    $deepEligible=0; $deepDirectional=0; $predictions=0; $lastProbabilities=@(); $maximumMargin=0.0
    if($finished) {
        for($at=$fitCount;$at -lt $rates.Length;$at++) {
            $sample=New-ICTCoreValue 'SICTStatSample'
            if(!(Invoke-ICTCoreValue 'ICTStatFeatures' @($rates,[int]$at,[double]$series.point,$sample))) { continue }
            if(!(Invoke-ICTCoreValue 'ICTStatPredict' @($model,$sample,$snapshot))) { continue }
            $predictions++; $lastProbabilities=@($snapshot.dl)
            $margin=[Math]::Abs($snapshot.dl[0]-$snapshot.dl[1]); $maximumMargin=[Math]::Max($maximumMargin,$margin)
            if([Math]::Max($snapshot.dl[0],$snapshot.dl[1]) -gt $snapshot.dl[2] -and $margin -ge 0.04) { $deepDirectional++ }
            $votes=New-ICTCoreValue 'SICTAnalyticalVotes'
            $asof=[long]($rates[$at].time+$seconds)
            $strictDeep=Invoke-ICTCoreValue 'ICTAnalyticalDeepVote' @($model,$snapshot,$rates,[int]$tfValue,[int]$tfValue,$asof,[double]$series.point,$votes)
            if($strictDeep) { $deepEligible++ }
            $priceArgs=[object[]]::new(6); $priceArgs[0]=$rates; $priceArgs[1]=[int]$tfValue; $priceArgs[2]=$asof
            $priceArgs[3]=[double]$series.point; $priceArgs[4]=$votes; $priceArgs[5]=[double]0
            if(!$runtimeType.GetMethod('ICTAnalyticalPriceVotes').Invoke($null,$priceArgs)) { continue }
            $context=New-ICTCoreValue 'SICTAnalyticalContext'; $context.symbol=$series.symbol; $context.valid=$true
            $context.ltf=$tfValue; $context.mtf=$middleTF; $context.htf=16408; $context.asof=$asof; $context.ltf_closed=$asof
            foreach($tier in @('middle','upper')) {
                $structure=New-ICTCoreValue 'SMarketStructure'
                $structureArgs=[object[]]::new(8)
                if($tier -eq 'middle') { $structureArgs[0]=$middle } else { $structureArgs[0]=$upper }
                $structureArgs[1]=if($tier -eq 'middle') {[int]$middleTF} else {[int]16408}
                $structureArgs[2]=$asof; $structureArgs[3]=[int]60; $structureArgs[4]=[int]2; $structureArgs[5]=[int]2
                $structureArgs[6]=$structure; $structureArgs[7]=[long]0
                $null=$runtimeType.GetMethod('ICTAnalyticalStructureAt').Invoke($null,$structureArgs)
                if($tier -eq 'middle') { $context.mtf_bias=$structure.bias; $context.mtf_closed=$structureArgs[7] }
                else { $context.htf_bias=$structure.bias; $context.htf_closed=$structureArgs[7] }
            }
            if(Invoke-ICTCoreValue 'ICTAnalyticalContextReady' @($context)) { $alignedBars++ }
            $oldConfig=New-ICTCoreValue 'SICTAnalyticalConfig'; $null=Invoke-ICTCoreValue 'ICTAnalyticalDefaults' @($oldConfig)
            $oldResult=New-ICTCoreValue 'SICTAnalyticalResult'; $votes.available[5]=$strictDeep
            if(Invoke-ICTCoreValue 'ICTAnalyticalEvaluate' @($oldConfig,$context,$votes,$oldResult)) { $oldSignals++ }
            $deep=New-ICTCoreValue 'SICTAnalyticalDeepState'
            $null=Invoke-ICTCoreValue 'ICTAnalyticalDeepEvidence' @($model,$snapshot,$rates,[int]$tfValue,[int]$tfValue,$asof,[double]$series.point,$deep,$votes)
            $policy=New-ICTCoreValue 'SICTAnalyticalPolicy'; $null=Invoke-ICTCoreValue 'ICTAnalyticalPolicyDefaults' @($policy)
            $newResult=New-ICTCoreValue 'SICTAnalyticalResult'
            if(Invoke-ICTCoreValue 'ICTAnalyticalEvaluateEarly' @($policy,$context,$votes,$deep,$newResult)) {
                $newSignals++; if($newResult.experimental) { $experimentalSignals++ }
                $signalRows+=[pscustomobject]@{AsOf=$asof;Direction=$newResult.direction;Score=$newResult.score;Experimental=$newResult.experimental;Aligned=$newResult.context_aligned}
            }
        }
    }
    $result=[pscustomobject]@{Symbol=$series.symbol;Timeframe=$Timeframe;ClosedBars=$rates.Length;FitBars=$fitCount;ReplayBars=$ReplayBars;
        Prepared=$prepared;Fitted=$finished;Calibrated=$model.calibrated;Train=$snapshot.train_n;Calibration=$snapshot.cal_n;Test=$snapshot.test_n;
        Status=$snapshot.status;Reason=$snapshot.reason;BrierDNN=$snapshot.brier_dl;BrierPrior=$snapshot.brier_baseline;
        Predictions=$predictions;OldDeepEligible=$deepEligible;DirectionalDNN=$deepDirectional;LastProbabilities=$lastProbabilities;MaximumMargin=$maximumMargin;
        StrictMTFAlignedBars=$alignedBars;OldCommonFactorSignals=$oldSignals;NewCommonFactorSignals=$newSignals;ExperimentalSignals=$experimentalSignals;Signals=$signalRows}
    $marketResults+=$result; $result | ConvertTo-Json -Compress | Write-Output
}
$marketReport=Join-Path $datasetPath ("market-model-$Timeframe.json")
$marketResults | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $marketReport -Encoding UTF8
Write-Output "Diagnostic model replay saved: $marketReport. No P&L or live chart rendering claim."
