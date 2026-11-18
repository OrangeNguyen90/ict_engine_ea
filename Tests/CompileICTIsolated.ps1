[CmdletBinding()]
param([ValidateRange(10,600)][int]$TimeoutSeconds=90)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$runtime=Join-Path $PSScriptRoot '.terminal'
. (Join-Path $PSScriptRoot 'ICTTestRunner.Common.ps1')
Assert-ICTRuntimeIdle $runtime
$package=Join-Path $runtime 'MQL5\Experts\ICTWorkspace'
foreach($directory in @('Include','Experts','Indicators','Tests')) {
    $destination=Join-Path $package $directory
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $root $directory) -File |
        Where-Object Extension -in '.mq5','.mqh' | Copy-Item -Destination $destination -Force
}
$manifest=Get-ChildItem -LiteralPath $package -Recurse -File |
    Where-Object Extension -in '.mq5','.mqh' |
    ForEach-Object { [pscustomobject]@{Path=$_.FullName.Substring($package.Length+1); SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} }
$manifest | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'Reports\ICT_CONTINUATION_SOURCE_MANIFEST.csv') -NoTypeInformation -Encoding UTF8
$results=@()
$logs=Join-Path $PSScriptRoot 'Reports\isolated-compile'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
foreach($directory in @('Experts','Indicators','Tests')) {
    foreach($source in Get-ChildItem -LiteralPath (Join-Path $package $directory) -Filter '*.mq5' -File) {
        $log=Join-Path $logs "$directory-$($source.BaseName).log"
        try {
            $summary=Invoke-ICTCompilation -Runtime $runtime -Source $source.FullName -Log $log -TimeoutSeconds $TimeoutSeconds
            $results+=[pscustomobject]@{Program="$directory/$($source.Name)"; Result=$summary; SourceSHA256=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash}
            Write-Output "$directory/$($source.Name): $summary"
        } catch {
            $results+=[pscustomobject]@{Program="$directory/$($source.Name)"; Result=$_.Exception.Message; SourceSHA256=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash}
            Write-Output "$directory/$($source.Name): FAILED $($_.Exception.Message)"
        }
    }
}
$results | Export-Csv -LiteralPath (Join-Path $PSScriptRoot 'Reports\ICT_CONTINUATION_BUILD_20261113.csv') -NoTypeInformation -Encoding UTF8
$failed=@($results | Where-Object { $_.Result -notmatch '^Result: 0 errors, 0 warnings' })
if($failed.Count) { throw "$($failed.Count) MQL compilation(s) failed; see isolated compile report" }
Write-Output "All $($results.Count) MQL programs compiled without errors or warnings in the isolated runtime."
