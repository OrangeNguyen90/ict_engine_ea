<# Account-free verification only. This script never launches terminal64.exe. #>
[CmdletBinding()]
param(
    [string]$Expert='',
    [ValidateRange(10,600)][int]$TimeoutSeconds=60,
    [string]$TerminalInstallPath='C:\Program Files\MetaTrader 5',
    [string]$MarketCachePath='',
    [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ICTTestRunner.Common.ps1')
$catalogue=@(Get-ICTTestCatalogue)
if($Expert) {
    $catalogue=@($catalogue | Where-Object Expert -eq $Expert)
    if(!$catalogue.Count) { throw "Unknown test expert: $Expert" }
}
if(!$ReportPath) { $ReportPath=Join-Path $PSScriptRoot 'Reports\ICT_VERIFICATION.json' }
$ReportPath=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportPath)
if([IO.Path]::GetExtension($ReportPath) -ne '.json') { throw 'Verification report must use a .json extension' }
New-Item -ItemType Directory -Path (Split-Path $ReportPath -Parent) -Force | Out-Null
$started=[DateTime]::UtcNow
$steps=[Collections.Generic.List[object]]::new()
$powerShell=(Get-Process -Id $PID).Path
$baseArguments=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass')
$runner=Join-Path $PSScriptRoot 'RunICTTests.ps1'

function Add-VerificationStep([string]$Name,[string[]]$CommandArguments) {
    Write-Host "VERIFY: $Name"
    $result=Invoke-ICTVerificationStep -Name $Name -PowerShell $powerShell -Arguments ($baseArguments+$CommandArguments) -TimeoutSeconds ([Math]::Max(90,$TimeoutSeconds+30))
    $steps.Add($result)
    Write-Host "$($result.Status): $Name ($($result.DurationSeconds)s)"
    if($result.Status -ne 'Passed') { Write-Host $result.Output }
    return $result
}

try {
    $testFile=(Join-Path $PSScriptRoot 'ICTTestRunner.Tests.ps1').Replace("'","''")
    $testCommand="`$result=Invoke-Pester -Script '$testFile' -PassThru; if (`$result.FailedCount -gt 0 -or `$result.PassedCount -lt 1) { exit 1 }"
    $null=Add-VerificationStep 'RunnerRegressions' @('-Command',$testCommand)
    $null=Add-VerificationStep 'CoreAlgorithms' @('-File',$runner,'-Mode','CoreFixtures')
    $prepare=@('-File',$runner,'-Mode','Prepare','-TerminalInstallPath',$TerminalInstallPath)
    if($MarketCachePath) { $prepare+=@('-MarketCachePath',$MarketCachePath) }
    $prepared=Add-VerificationStep 'PrepareRuntime' $prepare
    if($prepared.Status -eq 'Passed') {
        foreach($entry in $catalogue) {
            $null=Add-VerificationStep "Compile:$($entry.Expert)" @('-File',$runner,'-Mode','Compile','-Expert',$entry.Expert,'-TimeoutSeconds',"$TimeoutSeconds")
        }
        foreach($entry in ($catalogue | Where-Object OfflineFixture)) {
            $null=Add-VerificationStep "CompileFixture:$($entry.Expert)" @('-File',(Join-Path $PSScriptRoot 'RunICTFixtures.ps1'),'-Suite',$entry.Expert,'-CompileOnly','-TimeoutSeconds',"$TimeoutSeconds")
        }
    } else {
        foreach($entry in $catalogue) {
            $steps.Add([pscustomobject]@{Name="Compile:$($entry.Expert)"; Status='Skipped'; ExitCode=$null; Output='Runtime preparation failed'})
            if($entry.OfflineFixture) {
                $steps.Add([pscustomobject]@{Name="CompileFixture:$($entry.Expert)"; Status='Skipped'; ExitCode=$null; Output='Runtime preparation failed'})
            }
        }
    }
} catch {
    $steps.Add([pscustomobject]@{Name='VerificationWorkflow'; Status='Failed'; ExitCode=$null; Output=$_.Exception.Message})
} finally {
    $failed=@($steps | Where-Object Status -ne 'Passed')
    $status=if($steps.Count -gt 0 -and $failed.Count -eq 0) { 'Passed' } else { 'Failed' }
    $report=[ordered]@{
        SchemaVersion=1
        Scope='AccountFreeVerification'
        Status=$status
        StartedUtc=$started.ToString('o')
        CompletedUtc=[DateTime]::UtcNow.ToString('o')
        SelectedExperts=@($catalogue | ForEach-Object Expert)
        MetaTraderRuntime='NotRun'
        MarketBacktest='NotRun'
        BrokerExecution='NotRun'
        Steps=$steps.ToArray()
    }
    [IO.File]::WriteAllText($ReportPath,($report | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    Write-Host "Verification report: $ReportPath"
}
if($status -ne 'Passed') { throw "Account-free verification failed; see $ReportPath" }
Write-Output "PASS: account-free verification ($($steps.Count) steps). MT5 runtime/backtests were NOT run."
