[CmdletBinding()]
param([ValidateSet('ICTUnifiedTests','ICTDetectorTests','ICTRangeTests','ICTDecisionTests')][string]$Suite='ICTUnifiedTests',
      [ValidateRange(10,600)][int]$TimeoutSeconds=30,
      [switch]$CompileOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'ICTTestRunner.Common.ps1')
$project=Split-Path $PSScriptRoot -Parent
$runtime=Join-Path $PSScriptRoot '.terminal'
Assert-ICTRuntimeIdle $runtime
$terminal=Join-Path $runtime 'terminal64.exe'
if(!(Test-Path -LiteralPath $terminal)) { throw 'Prepare isolated runtime with RunICTTests.ps1 -Mode Prepare first' }
$package=Join-Path $runtime 'MQL5\Scripts\ICTFixtureWorkspace'
foreach($folder in @('Include','Tests')) { New-Item -ItemType Directory -Path (Join-Path $package $folder) -Force | Out-Null }
Get-ChildItem -LiteralPath (Join-Path $project 'Include') -Filter '*.mqh' -File | Copy-Item -Destination (Join-Path $package 'Include')
Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.mqh' -File | Copy-Item -Destination (Join-Path $package 'Tests')
$source=Get-Content -LiteralPath (Join-Path $PSScriptRoot "$Suite.mq5") -Raw -Encoding UTF8
# These suites contain deterministic assertions and no trade requests. Compile
# the same fixture functions as an offline script, not a Strategy Tester run.
$runId=[Guid]::NewGuid().ToString('N')
$resultName="$Suite.$runId.fixtures.csv"
$source=Get-ICTFixtureSource -Source $source -Suite $Suite -ResultName $resultName
$script=Join-Path $package "Tests\$Suite.mq5"
[IO.File]::WriteAllText($script,$source,[Text.UTF8Encoding]::new($false))
$log=Join-Path $runtime "$Suite.fixture.compile.log"
Invoke-ICTCompilation -Runtime $runtime -Source $script -Log $log -TimeoutSeconds $TimeoutSeconds
if($CompileOnly) { return }
$configuration="[Common]`r`nServer=Exness-MT5Trial6`r`nKeepPrivate=1`r`nNewsEnable=0`r`n[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n[StartUp]`r`nSymbol=EURUSD`r`nPeriod=M5`r`nScript=ICTFixtureWorkspace\Tests\$Suite`r`nShutdownTerminal=1`r`n"
$config=Join-Path $runtime "$Suite.$runId.fixtures.ini"
[IO.File]::WriteAllText($config,$configuration,[Text.Encoding]::ASCII)
Assert-ICTRuntimeIdle $runtime
$offsets=Get-ICTLogOffsets $runtime
$started=Get-Date
$process=Start-Process -FilePath $terminal -ArgumentList @('/portable',"/config:`"$config`"") -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
$completed=$process.WaitForExit($TimeoutSeconds*1000)
if(!$completed) {
    $null=$process.CloseMainWindow()
    Write-Warning 'Offline fixture script did not finish; graceful close requested for isolated terminal only.'
}
$freshLogs=Read-ICTNewLogs -Runtime $runtime -Offsets $offsets
if($freshLogs) { Write-Output $freshLogs }
if(!$completed) { throw "NOT VERIFIED: offline MQL script timed out after $TimeoutSeconds seconds. Use RunICTTests.ps1 -Mode CoreFixtures for account-free algorithm checks." }
if($process.ExitCode -ne 0) { throw "NOT VERIFIED: isolated terminal exited with code $($process.ExitCode)" }
$resultFile=Join-Path $runtime "MQL5\Files\$resultName"
if(!(Test-Path -LiteralPath $resultFile) -or (Get-Item -LiteralPath $resultFile).LastWriteTime -lt $started) {
    throw 'NOT VERIFIED: no assertion result for this run; terminal may require an initialized chart/account. Use RunICTTests.ps1 -Mode CoreFixtures for account-free algorithm checks.'
}
$result=(Get-Content -LiteralPath $resultFile -Raw).Trim()
Write-Output $result
if($result -ne "$Suite,0") { throw "Fixture failures: $result" }
Write-Output 'PASS: actual MQL offline fixture execution; this is not a market backtest or broker execution test.'
