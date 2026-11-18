# Shared checks for the isolated MT5 test runners. Dot-sourcing does not run MT5.
function Get-ICTTestCatalogue {
    @(
        [pscustomobject]@{Expert='ICTDecisionTests'; Config='ict_decision.ini'; OfflineFixture=$true}
        [pscustomobject]@{Expert='ICTDetectorTests'; Config='ict_detector.ini'; OfflineFixture=$true}
        [pscustomobject]@{Expert='ICTRangeTests'; Config='ict_range.ini'; OfflineFixture=$true}
        [pscustomobject]@{Expert='ICTRangeReplayEA'; Config='ict_range_EURUSD_09.ini'; OfflineFixture=$false}
        [pscustomobject]@{Expert='Phase3ProbeEA'; Config='ict_probe_eurusd_sep.ini'; OfflineFixture=$false}
        [pscustomobject]@{Expert='ICTAutoTraderTesterTests'; Config='ict_autotrader.ini'; OfflineFixture=$false}
        [pscustomobject]@{Expert='ICTUnifiedTests'; Config='ict_unified.ini'; OfflineFixture=$true}
    )
}

function Resolve-ICTTestSelection([string]$TestsPath,[string]$Expert,[string]$Config,[bool]$ExpertSpecified) {
    $entry=Get-ICTTestCatalogue | Where-Object Expert -eq $Expert
    if (!$entry) { throw "Unknown test expert: $Expert" }
    if (!$Config) { $Config=$entry.Config }
    if ([IO.Path]::GetFileName($Config) -ne $Config -or $Config -notmatch '^ict_[^\\/]+\.ini$') {
        throw 'Only Tests/ict_*.ini configs are allowed'
    }
    $path=Join-Path $TestsPath $Config
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Test config does not exist: $path" }
    $configured=Get-ICTTesterExpert (Get-Content -LiteralPath $path -Raw)
    if ($ExpertSpecified -and $Expert -ne $configured) { throw "Expert $Expert does not match config expert $configured" }
    return [pscustomobject]@{Expert=$configured; Config=$Config; Path=$path}
}

function Assert-ICTRuntimeIdle([string]$Runtime) {
    if (Test-Path -LiteralPath $Runtime) {
        if ((Get-Item -LiteralPath $Runtime).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'Runtime must not be a junction/symlink'
        }
    }
    foreach ($name in @('terminal64','MetaEditor64','metatester64')) {
        $binary=Join-Path $Runtime "$name.exe"
        $running=Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object Path -eq $binary
        if ($running) { throw "Isolated $name is already running; wait for it to exit before starting another operation" }
    }
}

function Test-ICTMarketCacheSharingViolation([Exception]$Exception) {
    while ($Exception) {
        # Only Win32 ERROR_SHARING_VIOLATION / ERROR_LOCK_VIOLATION are optional.
        if ($Exception -is [IO.IOException] -and $Exception.HResult -in @(-2147024864,-2147024863)) { return $true }
        $Exception=$Exception.InnerException
    }
    return $false
}

function Copy-ICTMarketCacheFile {
    [CmdletBinding()]
    param([string]$Source,[string]$Destination)
    $Source=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Source)
    $Destination=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
    if ($Source -eq $Destination) { throw 'Market cache source and isolated destination must differ' }
    # A missing/locked source must never leave a previous isolated copy usable.
    if (Test-Path -LiteralPath $Destination -ErrorAction Stop) { [IO.File]::Delete($Destination) }
    $result=[ordered]@{Source=$Source; Destination=$Destination; Status='Unavailable'; Reason='Missing'}
    if (!(Test-Path -LiteralPath $Source -PathType Leaf -ErrorAction Stop)) { return [pscustomobject]$result }
    $temporary="$Destination.$([Guid]::NewGuid().ToString('N')).partial"
    $sourceLock=$null
    try {
        try {
            # Hold a read-only sharing lease so an active writer cannot produce
            # a changing snapshot. Never open the installed cache for writing.
            $sourceLock=[IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
            Copy-Item -LiteralPath $Source -Destination $temporary -ErrorAction Stop
        } catch {
            if (!(Test-ICTMarketCacheSharingViolation $_.Exception)) { throw }
            $result.Reason='SharingViolation'
            Write-Warning "Market cache unavailable (sharing/lock violation): $Source. Isolated cached copy removed; market history NOT VERIFIED."
            return [pscustomobject]$result
        } finally {
            if ($sourceLock) { $sourceLock.Dispose() }
        }
        # Publish only a complete copy, never a partially overwritten .hcc/.dat.
        [IO.File]::Move($temporary,$Destination)
        $result.Status='Copied'
        $result.Reason=''
        return [pscustomobject]$result
    } finally {
        if (Test-Path -LiteralPath $temporary -ErrorAction Stop) { Remove-Item -LiteralPath $temporary -Force -ErrorAction Stop }
    }
}

function Invoke-ICTCompilation([string]$Runtime,[string]$Source,[string]$Log,[int]$TimeoutSeconds) {
    $editor=Join-Path $Runtime 'MetaEditor64.exe'
    if (!(Test-Path -LiteralPath $editor)) { throw 'Prepare isolated runtime with RunICTTests.ps1 -Mode Prepare first' }
    $started=[DateTime]::UtcNow
    $process=Start-Process -FilePath $editor -ArgumentList @('/portable',"/compile:`"$Source`"","/log:`"$Log`"") -WorkingDirectory $Runtime -WindowStyle Hidden -PassThru
    if (!$process.WaitForExit($TimeoutSeconds*1000)) {
        $null=$process.CloseMainWindow()
        throw "Compiler timeout; graceful close requested for isolated PID $($process.Id)"
    }
    $binary=[IO.Path]::ChangeExtension($Source,'.ex5')
    if (!(Test-Path -LiteralPath $Log) -or (Get-Item -LiteralPath $Log).LastWriteTimeUtc -lt $started) {
        throw "Compiler did not produce a fresh log: $Log"
    }
    $result=Get-Content -LiteralPath $Log -Raw
    $summaries=[regex]::Matches($result,'(?m)^Result: [^\r\n]+')
    if ($summaries.Count -ne 1 -or $summaries[0].Value -notmatch '^Result: 0 errors, 0 warnings(?:,|\s*$)') {
        throw "Compilation did not succeed or the log is ambiguous:`n$result"
    }
    if (!(Test-Path -LiteralPath $binary) -or (Get-Item -LiteralPath $binary).LastWriteTimeUtc -lt $started) {
        throw "Compiler did not produce a fresh binary: $binary"
    }
    Write-Output $summaries[0].Value
}

function Invoke-ICTVerificationStep([string]$Name,[string]$PowerShell,[string[]]$Arguments,[int]$TimeoutSeconds=90) {
    $started=[DateTime]::UtcNow
    $result=[ordered]@{Name=$Name; Status='Failed'; ExitCode=$null; StartedUtc=$started.ToString('o'); DurationSeconds=0; Output=''}
    $process=[Diagnostics.Process]::new()
    try {
        $info=[Diagnostics.ProcessStartInfo]::new()
        $info.FileName=$PowerShell
        $info.WorkingDirectory=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.')
        # Windows native argument quoting, including embedded quotes and trailing
        # backslashes. No command string is evaluated by a parent shell.
        $quoted=foreach ($argument in $Arguments) {
            $escaped=[regex]::Replace($argument,'(\\*)"','$1$1\"')
            $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
            '"'+$escaped+'"'
        }
        $info.Arguments=$quoted -join ' '
        $info.UseShellExecute=$false
        $info.CreateNoWindow=$true
        $info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
        $info.RedirectStandardOutput=$true
        $info.RedirectStandardError=$true
        $process.StartInfo=$info
        $null=$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync()
        $stderr=$process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit($TimeoutSeconds*1000)) {
            # Cancel only the child PowerShell we created, never an MT5 process.
            $process.Kill()
            $process.WaitForExit()
            throw "Verification step timed out after $TimeoutSeconds seconds"
        }
        $result.ExitCode=$process.ExitCode
        $result.Output=($stdout.GetAwaiter().GetResult()+"`r`n"+$stderr.GetAwaiter().GetResult()).Trim()
        if ($process.ExitCode -eq 0) { $result.Status='Passed' }
    } catch {
        $result.Output=$_.Exception.Message
    } finally {
        $result.DurationSeconds=[Math]::Round(([DateTime]::UtcNow-$started).TotalSeconds,3)
        $process.Dispose()
    }
    return [pscustomobject]$result
}

function Get-ICTTesterExpert([string]$Configuration) {
    # Parse by section: a disabled value in the wrong section or an overridden
    # duplicate must not satisfy the safety checks.
    $sections=@{}; $section=''
    foreach ($line in ($Configuration -split '\r?\n')) {
        $line=$line.Trim()
        if (!$line -or $line.StartsWith(';') -or $line.StartsWith('#')) { continue }
        if ($line -match '^\[([^\]]+)\]$') {
            $section=$Matches[1]
            if ($section -notin @('Common','Experts','Tester')) { throw "Unsupported config section: $section" }
            if ($sections.ContainsKey($section)) { throw "Duplicate config section: $section" }
            $sections[$section]=@{}
        } elseif ($line -match '^([^=]+)=(.*)$' -and $section) {
            $key=$Matches[1].Trim(); $value=$Matches[2].Trim()
            if ($key -in @('Login','Password','Script','ExpertParameters')) { throw 'Account/startup script/parameter overrides are forbidden' }
            if ($sections[$section].ContainsKey($key)) { throw "Duplicate config key: [$section] $key" }
            $sections[$section][$key]=$value
        } else { throw "Invalid tester configuration line: $line" }
    }
    $required=@{
        Experts=@{AllowLiveTrading='0'; Enabled='0'; AllowDllImport='0'}
        Tester=@{UseLocal='1'; UseRemote='0'; UseCloud='0'; ShutdownTerminal='1'; Optimization='0'}
    }
    foreach ($name in $required.Keys) {
        foreach ($key in $required[$name].Keys) {
            if (!$sections.ContainsKey($name) -or $sections[$name][$key] -ne $required[$name][$key]) {
                throw "Missing safety setting: [$name] $key=$($required[$name][$key])"
            }
        }
    }
    $expert=$sections['Tester']['Expert']
    if ($expert -notmatch '^ICTWorkspace\\Tests\\(ICTDecisionTests|ICTDetectorTests|ICTRangeTests|ICTRangeReplayEA|Phase3ProbeEA|ICTAutoTraderTesterTests|ICTUnifiedTests)$') {
        throw 'Expert is not an approved test expert'
    }
    return $Matches[1]
}

function Get-ICTFixtureSource([string]$Source,[string]$Suite,[string]$ResultName) {
    $counters=@{ICTDecisionTests='failures'; ICTDetectorTests='failures'; ICTRangeTests='g_failures'; ICTUnifiedTests='failures'}
    if (!$counters.ContainsKey($Suite)) { throw "No offline fixture adapter for $Suite" }
    if ($ResultName -notmatch '^[a-zA-Z0-9_.-]+$') { throw 'Invalid fixture result filename' }
    if ([regex]::Matches($Source,'\bint OnInit\s*\(').Count -ne 1) { throw 'Expected exactly one fixture OnInit handler' }
    $Source=[regex]::Replace($Source,'(?m)^#property[^\r\n]*','')
    $Source=$Source -replace '\bint OnInit\s*\(', 'int RunFixtures('
    $tester=[regex]::Match($Source,'\bdouble OnTester\s*\(')
    if ($tester.Success) { $Source=$Source.Substring(0,$tester.Index) }
    $Source=[regex]::Replace($Source,'\bvoid OnTick\s*\(\s*\)\s*\{\s*\}','')
    $Source+="`r`nvoid OnStart()`r`n{`r`n int fixture_status=RunFixtures();`r`n int fixture_failures=$($counters[$Suite]);`r`n if(fixture_status!=INIT_SUCCEEDED && fixture_failures==0) fixture_failures=1;`r`n int result=FileOpen(`"$ResultName`",FILE_WRITE|FILE_CSV|FILE_ANSI,',');`r`n if(result==INVALID_HANDLE) { Print(`"Fixture result file could not be opened`",GetLastError()); return; }`r`n FileWrite(result,`"$Suite`",fixture_failures);`r`n FileFlush(result); FileClose(result);`r`n}`r`n"
    return $Source
}

function Get-ICTRuntimeLogs([string]$Runtime) {
    foreach ($directory in @((Join-Path $Runtime 'logs'),(Join-Path $Runtime 'Tester'))) {
        if (Test-Path -LiteralPath $directory) {
            Get-ChildItem -LiteralPath $directory -Filter '*.log' -File -Recurse |
                Where-Object Name -Match '^\d{8}\.log$'
        }
    }
}

function Get-ICTLogOffsets([string]$Runtime) {
    $offsets=@{}
    foreach ($file in (Get-ICTRuntimeLogs $Runtime)) { $offsets[$file.FullName]=$file.Length }
    return $offsets
}

function Read-ICTNewLogs([string]$Runtime,[hashtable]$Offsets) {
    $chunks=@()
    foreach ($file in (Get-ICTRuntimeLogs $Runtime)) {
        $offset=0L
        if ($Offsets.ContainsKey($file.FullName) -and $file.Length -ge $Offsets[$file.FullName]) { $offset=$Offsets[$file.FullName] }
        if ($file.Length -eq $offset) { continue }
        $stream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
        $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true)
        try {
            # Detect the BOM before seeking; MT5 journals can be UTF-16.
            $null=$reader.Peek()
            $reader.DiscardBufferedData()
            $stream.Position=$offset
            $text=$reader.ReadToEnd().TrimStart([char]0xFEFF)
            if ($text) { $chunks+="LOG: $($file.FullName)`r`n$text" }
        } finally { $reader.Dispose(); $stream.Dispose() }
    }
    return $chunks -join "`r`n"
}

function Assert-ICTTesterResult([string]$Expert,[string]$LogText,[int]$ExitCode) {
    if ($LogText -match '(?i)tester not started because the account is not specified') {
        throw 'NOT VERIFIED: Strategy Tester requires an account in the isolated runtime. No account was copied. Use -Mode CoreFixtures for account-free algorithm checks.'
    }
    if ($LogText -match "(?i)tester not started|tester didn't start") { throw 'NOT VERIFIED: Strategy Tester did not start; see the fresh journal above' }
    if ($ExitCode -ne 0) { throw "NOT VERIFIED: isolated terminal exited with code $ExitCode" }
    if ($LogText -notmatch '(?im)\btest passed\b|\btesting (?:of [^\r\n]+ )?(?:finished|completed)\b') {
        throw 'NOT VERIFIED: no fresh Strategy Tester completion marker'
    }
    if ($Expert -in @('ICTDecisionTests','ICTDetectorTests','ICTRangeTests','ICTUnifiedTests')) {
        $results=[regex]::Matches($LogText,"\b$([regex]::Escape($Expert)) RESULT\b[^\r\n]*?\bfailures=(\d+)\b")
        if ($results.Count -eq 0) { throw "NOT VERIFIED: no fresh assertions for $Expert" }
        foreach ($result in $results) {
            if ([int]$result.Groups[1].Value -ne 0) { throw "Fixture failures: $($result.Value)" }
            if ($result.Value -notmatch '\b(?:checks|assertions)=[1-9]\d*\b') {
                throw "NOT VERIFIED: assertion count is missing or zero for $Expert"
            }
        }
        Write-Output "PASS: $Expert assertions and Strategy Tester completion verified."
    } elseif ($Expert -eq 'ICTAutoTraderTesterTests') {
        if ($LogText -match 'ICT AUTO TESTER REGRESSION: FAIL' -or $LogText -notmatch 'ICT AUTO TESTER REGRESSION: PASS') {
            throw 'NOT VERIFIED: auto trader regression did not pass'
        }
        Write-Output 'PASS: tester-only auto trader regression completed; not an order-execution acceptance test.'
    } elseif ($Expert -eq 'Phase3ProbeEA') {
        $results=[regex]::Matches($LogText,'PHASE3_PROBE SUMMARY[^\r\n]*')
        if ($results.Count -eq 0) { throw 'NOT VERIFIED: no fresh probe summary' }
        foreach ($result in $results) {
            foreach ($gate in @('bars=[1-9]\d*\b','exposure_observations=0\b','A01=1\b','A02=1\b','A08=1\b')) {
                if ($result.Value -notmatch $gate) { throw "Probe requirement not observed: $($result.Value)" }
            }
        }
        Write-Output 'PASS: Phase 3 probe assertions completed; not full strategy acceptance.'
    } elseif ($Expert -eq 'ICTRangeReplayEA') {
        $results=[regex]::Matches($LogText,'ICTRangeReplay RESULT[^\r\n]*')
        if ($results.Count -eq 0) { throw 'NOT VERIFIED: no fresh replay summary' }
        foreach ($result in $results) {
            if ($result.Value -notmatch '\bbars=[1-9]\d*\b' -or $result.Value -notmatch '\breal_order_observations=0\b') {
                throw "Replay incomplete or unexpected order observation: $($result.Value)"
            }
        }
        Write-Output 'COMPLETED: paper replay with bars and no real orders; review data gaps and paper metrics separately.'
    } else { throw "No result contract for $Expert" }
}
