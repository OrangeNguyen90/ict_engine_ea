[CmdletBinding()]
param([ValidateRange(10,600)][int]$TimeoutSeconds=60,
      [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$LogTag='smart')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$runtime=Join-Path $PSScriptRoot '.terminal'
. (Join-Path $PSScriptRoot 'ICTTestRunner.Common.ps1')
Assert-ICTRuntimeIdle $runtime
$editor=Join-Path $runtime 'MetaEditor64.exe'
if(!(Test-Path -LiteralPath $editor)) { throw 'Prepare isolated runtime with RunICTTests.ps1 -Mode Prepare first' }
$package=Join-Path $runtime 'MQL5\Experts\ICTWorkspace'
foreach($directory in @('Include','Experts','Indicators','Tests')) {
    $destination=Join-Path $package $directory
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $root $directory) -File |
        Where-Object Extension -in '.mq5','.mqh' | Copy-Item -Destination $destination
}
$failed=@()
foreach($directory in @('Experts','Indicators','Tests')) {
    foreach($source in Get-ChildItem -LiteralPath (Join-Path $package $directory) -Filter '*.mq5' -File) {
        $log=Join-Path $root "docs\$($source.BaseName).$LogTag.compile.log"
        try {
            $summary=Invoke-ICTCompilation -Runtime $runtime -Source $source.FullName -Log $log -TimeoutSeconds $TimeoutSeconds
            Write-Output "$($source.Name): $summary"
            Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($source.FullName,'.ex5')) -Destination (Join-Path $root "$directory\$($source.BaseName).ex5")
        } catch {
            Write-Output "$($source.Name): $($_.Exception.Message)"
            $failed+=$source.Name
        }
    }
}
if($failed.Count) { throw "Compile failures/warnings: $($failed -join ', ')" }
Write-Output 'All MQL5 sources compiled with zero errors and warnings; no expert was attached or executed.'
