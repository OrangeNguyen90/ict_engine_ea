<#
.SYNOPSIS
Prepare, compile and verify ICT tests using an isolated MT5 runtime.
.DESCRIPTION
The default Prepare mode only copies binaries and public market-history caches.
CoreFixtures executes the shared pure-algorithm fixtures through the existing
C# adapter without MT5 or an account. Fixtures executes an MQL script in MT5;
it still needs an initialized chart. Run compiles the current sources first and
requires actual Tester completion and fresh expert assertions, not just terminal
exit. Verify runs the account-free validation workflow and writes a JSON report;
it does not start Strategy Tester. See README.md for commands.
#>
[CmdletBinding()]
param(
    [ValidateSet('Prepare','Compile','Run','Fixtures','CoreFixtures','Verify')][string]$Mode='Prepare',
    [ValidateSet('ICTDecisionTests','ICTDetectorTests','ICTRangeTests','ICTRangeReplayEA','Phase3ProbeEA','ICTAutoTraderTesterTests','ICTUnifiedTests')][string]$Expert='ICTDecisionTests',
    [string]$Config='',
    [ValidateRange(10,600)][int]$TimeoutSeconds=60,
    [string]$TerminalInstallPath='C:\Program Files\MetaTrader 5',
    [string]$MarketCachePath='',
    [string]$ReportPath=''
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ICTTestRunner.Common.ps1')
$TerminalInstallPath=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TerminalInstallPath)
if($MarketCachePath) { $MarketCachePath=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($MarketCachePath) }
if($ReportPath) { $ReportPath=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportPath) }
if($Mode -eq 'Verify') {
    $parameters=@{TimeoutSeconds=$TimeoutSeconds; TerminalInstallPath=$TerminalInstallPath; MarketCachePath=$MarketCachePath; ReportPath=$ReportPath}
    if($PSBoundParameters.ContainsKey('Expert') -or $Config) {
        $selection=Resolve-ICTTestSelection $PSScriptRoot $Expert $Config ($PSBoundParameters.ContainsKey('Expert'))
        $parameters.Expert=$selection.Expert
    }
    & (Join-Path $PSScriptRoot 'RunICTVerification.ps1') @parameters
    return
}
if($Mode -eq 'CoreFixtures') {
    & (Join-Path $PSScriptRoot 'RunICTCoreFixtures.ps1')
    return
}
if($Mode -eq 'Fixtures') {
    & (Join-Path $PSScriptRoot 'RunICTFixtures.ps1') -Suite $Expert -TimeoutSeconds $TimeoutSeconds
    return
}
if($Mode -in @('Compile','Run')) {
    $selection=Resolve-ICTTestSelection $PSScriptRoot $Expert $Config ($PSBoundParameters.ContainsKey('Expert'))
    $Expert=$selection.Expert
    $Config=$selection.Config
}
$root=Split-Path $PSScriptRoot -Parent
$runtime=Join-Path $PSScriptRoot '.terminal'
$installed=$TerminalInstallPath
$cache=$MarketCachePath
if(!$cache) { $cache=Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\bases\Exness-MT5Trial6' }
# Never read/copy Config, accounts, trades, profiles, or run the installed terminal.
Assert-ICTRuntimeIdle $runtime
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
if($Mode -eq 'Prepare') {
    foreach($binary in @('terminal64.exe','metatester64.exe','MetaEditor64.exe')) {
        if(!(Test-Path -LiteralPath (Join-Path $installed $binary) -PathType Leaf)) { throw "Missing $binary; set -TerminalInstallPath to an MT5 installation directory" }
    }
    foreach($binary in @('terminal64.exe','metatester64.exe','MetaEditor64.exe')) {
        Copy-Item -LiteralPath (Join-Path $installed $binary) -Destination $runtime
    }
    if(!(Test-Path -LiteralPath $cache -PathType Container)) {
        Write-Warning 'Market cache unavailable; preparing binaries only. Set -MarketCachePath for market-history tests.'
    }
    $cacheResults=[Collections.Generic.List[object]]::new()
    foreach($symbol in @('EURUSD','GBPUSD','XAUUSD','US30','USTEC')) {
        $destination=Join-Path $runtime "bases\Exness-MT5Trial6\history\$symbol"
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        foreach($year in @(2025,2026)) {
            $source=Join-Path $cache "history\$symbol\$year.hcc"
            $cacheResults.Add((Copy-ICTMarketCacheFile -Source $source -Destination (Join-Path $destination "$year.hcc")))
        }
    }
    $destination=Join-Path $runtime 'bases\Exness-MT5Trial6\symbols'
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $sourceSymbols=Join-Path $cache 'symbols'
    $symbolFiles=@{}
    if(Test-Path -LiteralPath $sourceSymbols -PathType Container) {
        foreach($file in (Get-ChildItem -LiteralPath $sourceSymbols -Filter 'symbols-*.dat' -File)) { $symbolFiles[$file.Name]=$true }
    }
    # Include old symbol filenames so missing source files cannot retain stale data.
    foreach($file in (Get-ChildItem -LiteralPath $destination -Filter 'symbols-*.dat' -File)) { $symbolFiles[$file.Name]=$true }
    foreach($name in $symbolFiles.Keys) {
        $cacheResults.Add((Copy-ICTMarketCacheFile -Source (Join-Path $sourceSymbols $name) -Destination (Join-Path $destination $name)))
    }
    $copied=@($cacheResults | Where-Object Status -eq 'Copied').Count
    $unavailable=@($cacheResults | Where-Object Status -eq 'Unavailable').Count
    $cacheSummary=if($copied) { 'cached market history only' } else { 'market history unavailable' }
    Write-Output "Prepared isolated runtime: $runtime (no credentials/config copied; $cacheSummary; copied=$copied; unavailable=$unavailable; market history NOT VERIFIED)."
    return
}
if($Mode -in @('Compile','Run')) {
    $package=Join-Path $runtime 'MQL5\Experts\ICTWorkspace'
    New-Item -ItemType Directory -Path "$package\Tests","$package\Include" -Force | Out-Null
    Copy-Item -Path "$root\Include\*.mqh" -Destination "$package\Include"
    Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.mqh' -File | Copy-Item -Destination "$package\Tests"
    if($Expert -eq 'ICTAutoTraderTesterTests') {
        New-Item -ItemType Directory -Path "$package\Experts" -Force | Out-Null
        Copy-Item -LiteralPath "$root\Experts\ICTAutoTraderEA.mq5" -Destination "$package\Experts"
    }
    $source=Join-Path $PSScriptRoot "$Expert.mq5"
    if(!(Test-Path $source)) { throw "Test source not yet available: $source" }
    Copy-Item -LiteralPath $source -Destination "$package\Tests"
    $log=Join-Path $runtime "$Expert.compile.log"
    Invoke-ICTCompilation -Runtime $runtime -Source "$package\Tests\$Expert.mq5" -Log $log -TimeoutSeconds $TimeoutSeconds
    if($Mode -eq 'Compile') { return }
}
$configPath=$selection.Path
$configuredExpert=$selection.Expert
if(!(Test-Path -LiteralPath "$runtime\terminal64.exe" -PathType Leaf)) { throw 'Prepare isolated runtime with -Mode Prepare first' }
Assert-ICTRuntimeIdle $runtime
$offsets=Get-ICTLogOffsets $runtime
$started=Get-Date
$process=Start-Process -FilePath "$runtime\terminal64.exe" -ArgumentList @('/portable',"/config:`"$configPath`"") -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
Write-Output "Isolated terminal PID=$($process.Id); started=$($started.ToString('o')); config=$Config"
$completed=$process.WaitForExit($TimeoutSeconds*1000)
if(!$completed) {
    $null=$process.CloseMainWindow()
    Write-Warning "Tester timed out. Requested graceful close of isolated PID $($process.Id); no process was forcibly terminated."
}
$freshLogs=Read-ICTNewLogs -Runtime $runtime -Offsets $offsets
Write-Output $freshLogs
if(!$completed) { throw "NOT VERIFIED: Strategy Tester timed out after $TimeoutSeconds seconds" }
Assert-ICTTesterResult -Expert $configuredExpert -LogText $freshLogs -ExitCode $process.ExitCode
