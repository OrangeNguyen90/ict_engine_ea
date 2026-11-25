<# Compile only the advisory integration and its native fixtures in the isolated
   runtime. No terminal is started and no expert is attached to a chart. #>
[CmdletBinding()]
param([ValidateRange(10,600)][int]$TimeoutSeconds=90)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$runtime=Join-Path $PSScriptRoot '.terminal'
. (Join-Path $PSScriptRoot 'ICTTestRunner.Common.ps1')
Assert-ICTRuntimeIdle $runtime
$package=Join-Path $runtime 'MQL5\Experts\ICTWorkspace'
foreach($directory in @('Include','Experts','Tests')) {
    $destination=Join-Path $package $directory
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $project $directory) -File |
        Where-Object Extension -in '.mq5','.mqh' | Copy-Item -Destination $destination -Force
}
$logs=Join-Path $PSScriptRoot 'Reports\ml-prediction-compile'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$sources=@('Experts\ICTDecisionSupportEA.mq5','Experts\ICTSmartDecisionEngineEA.mq5','Tests\ICTMLPredictionTests.mq5','Tests\ICTStatisticalLearningTests.mq5')
foreach($relative in $sources) {
    $source=Join-Path $package $relative
    $log=Join-Path $logs (([IO.Path]::GetFileNameWithoutExtension($relative))+'.log')
    $result=Invoke-ICTCompilation -Runtime $runtime -Source $source -Log $log -TimeoutSeconds $TimeoutSeconds
    Write-Output "$relative`: $result"
}
Write-Output 'Advisory integration compiled; no MT5 runtime, account or market backtest was run.'
