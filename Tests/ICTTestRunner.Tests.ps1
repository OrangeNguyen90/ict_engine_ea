. (Join-Path $PSScriptRoot 'ICTTestRunner.Common.ps1')

Describe 'Isolated tester configuration' {
    $configuration=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ict_decision.ini') -Raw

    It 'resolves the expert from the real decision config' {
        Get-ICTTesterExpert $configuration | Should Be 'ICTDecisionTests'
    }
    It 'accepts every checked-in ict tester config' {
        foreach ($file in (Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'ict_*.ini' -File)) {
            Get-ICTTesterExpert (Get-Content -LiteralPath $file.FullName -Raw) | Should Not BeNullOrEmpty
        }
    }
    It 'rejects an enabled override following a disabled setting' {
        { Get-ICTTesterExpert ($configuration.Replace('Enabled=0',"Enabled=0`nEnabled=1")) } | Should Throw
    }
    It 'does not accept a safety setting in the wrong section' {
        { Get-ICTTesterExpert ($configuration.Replace('Enabled=0','').Replace('KeepPrivate=1',"KeepPrivate=1`nEnabled=0")) } | Should Throw
    }
    It 'rejects repeated sections' {
        { Get-ICTTesterExpert ($configuration+"`n[Experts]`nEnabled=1") } | Should Throw
    }
    It 'rejects account credentials' {
        { Get-ICTTesterExpert ($configuration.Replace('KeepPrivate=1',"KeepPrivate=1`nLogin=123")) } | Should Throw
    }
    It 'rejects expert input overrides' {
        { Get-ICTTesterExpert ($configuration.Replace('Optimization=0',"Optimization=0`nExpertParameters=override.set")) } | Should Throw
    }
    It 'rejects a different expert path' {
        { Get-ICTTesterExpert ($configuration.Replace('ICTWorkspace\Tests\ICTDecisionTests','Other\Expert')) } | Should Throw
    }
    It 'rejects remote agents' {
        { Get-ICTTesterExpert ($configuration.Replace('UseRemote=0','UseRemote=1')) } | Should Throw
    }
}

Describe 'Expert and config selection' {
    It 'resolves a matching default config for every supported expert' {
        foreach($entry in (Get-ICTTestCatalogue)) {
            $selection=Resolve-ICTTestSelection $PSScriptRoot $entry.Expert '' $true
            $selection.Expert | Should Be $entry.Expert
            $selection.Config | Should Be $entry.Config
        }
    }
    It 'uses an explicitly selected config when the expert is not specified' {
        $selection=Resolve-ICTTestSelection $PSScriptRoot 'ICTDecisionTests' 'ict_range.ini' $false
        $selection.Expert | Should Be 'ICTRangeTests'
    }
    It 'rejects an explicit expert/config mismatch' {
        { Resolve-ICTTestSelection $PSScriptRoot 'ICTRangeTests' 'ict_decision.ini' $true } | Should Throw 'does not match'
    }
    It 'rejects configs outside the tests directory' {
        { Resolve-ICTTestSelection $PSScriptRoot 'ICTDecisionTests' '..\ict_decision.ini' $false } | Should Throw
    }
    It 'reports a missing config before starting any compiler or terminal' {
        { Resolve-ICTTestSelection $PSScriptRoot 'ICTDecisionTests' 'ict_missing.ini' $false } | Should Throw 'does not exist'
    }
}

Describe 'Fresh Strategy Tester evidence' {
    $pass="ICTDecisionTests RESULT assertions=600 failures=0`r`nTester test passed in 0:00:01"
    It 'accepts assertions only with tester completion and a clean exit' {
        { Assert-ICTTesterResult 'ICTDecisionTests' $pass 0 } | Should Not Throw
    }
    It 'fails when MT5 exits successfully without starting the tester' {
        { Assert-ICTTesterResult 'ICTDecisionTests' 'tester not started because the account is not specified' 0 } | Should Throw 'requires an account'
    }
    It 'fails on an empty log even with a zero exit code' {
        { Assert-ICTTesterResult 'ICTDecisionTests' '' 0 } | Should Throw
    }
    It 'rejects a nonzero terminal exit code' {
        { Assert-ICTTesterResult 'ICTDecisionTests' $pass 1 } | Should Throw
    }
    It 'rejects completion without assertions' {
        { Assert-ICTTesterResult 'ICTDecisionTests' 'test passed in 0:00:01' 0 } | Should Throw
    }
    It 'rejects assertions without completion' {
        { Assert-ICTTesterResult 'ICTDecisionTests' 'ICTDecisionTests RESULT assertions=600 failures=0' 0 } | Should Throw
    }
    It 'rejects a summary with no executed assertions' {
        { Assert-ICTTesterResult 'ICTDecisionTests' ($pass.Replace('assertions=600','assertions=0')) 0 } | Should Throw 'count is missing or zero'
    }
    It 'requires a positive count for detector fixtures too' {
        { Assert-ICTTesterResult 'ICTDetectorTests' "ICTDetectorTests RESULT failures=0`ntest passed" 0 } | Should Throw 'count is missing or zero'
    }
    It 'accepts executed detector assertions with a positive count' {
        { Assert-ICTTesterResult 'ICTDetectorTests' "ICTDetectorTests RESULT checks=50 failures=0`ntest passed" 0 } | Should Not Throw
    }
    It 'rejects failed assertions even if a later result has zero failures' {
        { Assert-ICTTesterResult 'ICTDecisionTests' ("ICTDecisionTests RESULT failures=1`n"+$pass) 0 } | Should Throw
    }
    It 'does not confuse zero with a nonzero failure count' {
        { Assert-ICTTesterResult 'ICTDecisionTests' ($pass.Replace('failures=0','failures=10')) 0 } | Should Throw
    }
    It 'does not accept another suite result' {
        { Assert-ICTTesterResult 'ICTRangeTests' $pass 0 } | Should Throw
    }
    It 'accepts the tester-only auto trader regression' {
        { Assert-ICTTesterResult 'ICTAutoTraderTesterTests' "ICT AUTO TESTER REGRESSION: PASS; analysis=WAIT`ntest passed" 0 } | Should Not Throw
    }
    It 'does not accept an auto trader failure followed by a pass' {
        { Assert-ICTTesterResult 'ICTAutoTraderTesterTests' "ICT AUTO TESTER REGRESSION: FAIL`nICT AUTO TESTER REGRESSION: PASS`ntest passed" 0 } | Should Throw
    }
    It 'rejects a probe with an unobserved requirement' {
        { Assert-ICTTesterResult 'Phase3ProbeEA' "PHASE3_PROBE SUMMARY bars=10 exposure_observations=0 A01=1 A02=0 A08=1`ntest passed" 0 } | Should Throw
    }
    It 'accepts a completed probe with all its requirements' {
        { Assert-ICTTesterResult 'Phase3ProbeEA' "PHASE3_PROBE SUMMARY bars=10 exposure_observations=0 A01=1 A02=1 A08=1`ntest passed" 0 } | Should Not Throw
    }
    It 'rejects a replay that did not process bars' {
        { Assert-ICTTesterResult 'ICTRangeReplayEA' "ICTRangeReplay RESULT bars=0 real_order_observations=0`ntest passed" 0 } | Should Throw
    }
    It 'rejects a replay with real order observations' {
        { Assert-ICTTesterResult 'ICTRangeReplayEA' "ICTRangeReplay RESULT bars=10 real_order_observations=1`ntest passed" 0 } | Should Throw
    }
    It 'reports a paper replay without claiming strategy acceptance' {
        Assert-ICTTesterResult 'ICTRangeReplayEA' "ICTRangeReplay RESULT bars=10 real_order_observations=0`ntest passed" 0 | Should Match '^COMPLETED: paper replay'
    }
}

Describe 'Journal isolation' {
    It 'reads only new UTF-16 log content and ignores compiler logs' {
        $runtime=Join-Path $TestDrive 'utf16'
        $logs=Join-Path $runtime 'logs'
        New-Item -ItemType Directory -Path $logs -Force | Out-Null
        $journal=Join-Path $logs '20261109.log'
        [IO.File]::WriteAllText($journal,"OLD PASS`r`n",[Text.Encoding]::Unicode)
        $offsets=Get-ICTLogOffsets $runtime
        [IO.File]::AppendAllText($journal,"NEW account missing`r`n",[Text.Encoding]::Unicode)
        [IO.File]::WriteAllText((Join-Path $logs 'metaeditor.log'),'STALE COMPILER PASS')
        $fresh=Read-ICTNewLogs $runtime $offsets
        $fresh | Should Match 'NEW account missing'
        $fresh | Should Not Match 'OLD PASS|STALE COMPILER'
    }
    It 'reads a newly created agent log, not just the terminal journal' {
        $runtime=Join-Path $TestDrive 'agent'
        $offsets=Get-ICTLogOffsets $runtime
        $agent=Join-Path $runtime 'Tester\Agent-127.0.0.1-3000\logs'
        New-Item -ItemType Directory -Path $agent -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $agent '20261109.log'),'NEW AGENT assertions')
        Read-ICTNewLogs $runtime $offsets | Should Match 'NEW AGENT assertions'
    }
    It 'handles a truncated journal' {
        $runtime=Join-Path $TestDrive 'truncated'
        $logs=Join-Path $runtime 'logs'
        New-Item -ItemType Directory -Path $logs -Force | Out-Null
        $journal=Join-Path $logs '20261109.log'
        [IO.File]::WriteAllText($journal,('OLD PASS'*20))
        $offsets=Get-ICTLogOffsets $runtime
        [IO.File]::WriteAllText($journal,'NEW FAILURE')
        Read-ICTNewLogs $runtime $offsets | Should Match 'NEW FAILURE'
    }
}

Describe 'Optional market cache copies' {
    BeforeEach {
        $cacheRoot=Join-Path $TestDrive ([Guid]::NewGuid().ToString('N'))
        $sourceDirectory=Join-Path $cacheRoot 'source'
        $destinationDirectory=Join-Path $cacheRoot 'isolated'
        New-Item -ItemType Directory -Path $sourceDirectory,$destinationDirectory -Force | Out-Null
        $source=Join-Path $sourceDirectory '2026.hcc'
        $destination=Join-Path $destinationDirectory '2026.hcc'
        [IO.File]::WriteAllText($source,'fresh market cache')
        [IO.File]::WriteAllText($destination,'stale market cache')
    }

    It 'replaces stale data with a complete available cache copy' {
        $result=Copy-ICTMarketCacheFile -Source $source -Destination $destination
        $result.Status | Should Be 'Copied'
        [IO.File]::ReadAllText($destination) | Should Be 'fresh market cache'
        [IO.File]::ReadAllText($source) | Should Be 'fresh market cache'
        @(Get-ChildItem -LiteralPath $destinationDirectory -Filter '*.partial' -File).Count | Should Be 0
    }
    It 'warns and records an unavailable exclusively locked source without retaining stale data' {
        $locked=[IO.File]::Open($source,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        try {
            $warnings=@()
            $result=Copy-ICTMarketCacheFile -Source $source -Destination $destination -WarningVariable warnings
            $result.Status | Should Be 'Unavailable'
            $result.Reason | Should Be 'SharingViolation'
            ($warnings -join "`n") | Should Match 'Market cache unavailable.*2026\.hcc'
            ($warnings -join "`n") | Should Match 'NOT VERIFIED'
            Test-Path -LiteralPath $destination | Should Be $false
            @(Get-ChildItem -LiteralPath $destinationDirectory -File).Count | Should Be 0
            $locked.CanRead | Should Be $true
        } finally { $locked.Dispose() }
    }
    It 'removes the previous isolated copy when the optional source is missing' {
        Remove-Item -LiteralPath $source
        $result=Copy-ICTMarketCacheFile -Source $source -Destination $destination
        $result.Status | Should Be 'Unavailable'
        $result.Reason | Should Be 'Missing'
        Test-Path -LiteralPath $destination | Should Be $false
    }
    It 'recognizes a wrapped Win32 byte-range lock violation' {
        $locked=[IO.IOException]::new('byte-range lock',-2147024863)
        Test-ICTMarketCacheSharingViolation ([Exception]::new('wrapped',$locked)) | Should Be $true
    }
    It 'propagates permission failures instead of reporting an optional cache lock' {
        Mock Copy-Item { throw [UnauthorizedAccessException]::new('Simulated permission failure') }
        { Copy-ICTMarketCacheFile -Source $source -Destination $destination } | Should Throw 'Simulated permission failure'
        Test-Path -LiteralPath $destination | Should Be $false
        @(Get-ChildItem -LiteralPath $destinationDirectory -File).Count | Should Be 0
    }
    It 'propagates disk failures and removes a partial copy' {
        Mock Copy-Item {
            [IO.File]::WriteAllText($Destination,'partial market cache')
            throw [IO.IOException]::new('Simulated disk full',-2147024784)
        }
        { Copy-ICTMarketCacheFile -Source $source -Destination $destination } | Should Throw 'Simulated disk full'
        Test-Path -LiteralPath $destination | Should Be $false
        @(Get-ChildItem -LiteralPath $destinationDirectory -File).Count | Should Be 0
    }
    It 'rejects a destination equal to the source without deleting installed data' {
        { Copy-ICTMarketCacheFile -Source $source -Destination $source } | Should Throw 'must differ'
        [IO.File]::ReadAllText($source) | Should Be 'fresh market cache'
    }
}

Describe 'Prepare runtime with optional market history' {
    BeforeEach {
        $prepareRoot=Join-Path $TestDrive ([Guid]::NewGuid().ToString('N'))
        $tests=Join-Path $prepareRoot 'Tests'
        $installed=Join-Path $prepareRoot 'installed'
        $cache=Join-Path $prepareRoot 'cache'
        $runtime=Join-Path $tests '.terminal'
        $history=Join-Path $runtime 'bases\Exness-MT5Trial6\history'
        $symbols=Join-Path $runtime 'bases\Exness-MT5Trial6\symbols'
        New-Item -ItemType Directory -Path $tests,$installed,$symbols,(Join-Path $cache 'history\GBPUSD'),(Join-Path $cache 'history\EURUSD'),(Join-Path $cache 'symbols'),(Join-Path $history 'GBPUSD'),(Join-Path $history 'EURUSD') -Force | Out-Null
        foreach($file in @('RunICTTests.ps1','ICTTestRunner.Common.ps1')) {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $tests
        }
        foreach($binary in @('terminal64.exe','metatester64.exe','MetaEditor64.exe')) {
            [IO.File]::WriteAllText((Join-Path $installed $binary),'placeholder binary')
        }
        [IO.File]::WriteAllText((Join-Path $cache 'history\EURUSD\2025.hcc'),'available history')
        $lockedSource=Join-Path $cache 'history\GBPUSD\2026.hcc'
        [IO.File]::WriteAllText($lockedSource,'locked history')
        [IO.File]::WriteAllText((Join-Path $cache 'symbols\symbols-public.dat'),'public symbols')
        [IO.File]::WriteAllText((Join-Path $history 'GBPUSD\2026.hcc'),'stale locked history')
        [IO.File]::WriteAllText((Join-Path $history 'EURUSD\2026.hcc'),'stale missing history')
        [IO.File]::WriteAllText((Join-Path $symbols 'symbols-old.dat'),'stale symbols')
        # Sentinels outside the existing public-cache allowlist must not be copied.
        foreach($directory in @($installed,$cache)) {
            New-Item -ItemType Directory -Path (Join-Path $directory 'Config') -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $directory 'Config\accounts.dat'),'private account sentinel')
        }
        [IO.File]::WriteAllText((Join-Path $cache 'symbols\accounts.dat'),'private account sentinel')
        Mock Start-Process { throw 'Prepare must not launch an executable' }
        Mock Stop-Process { throw 'Prepare must not stop any terminal' }
    }

    It 'keeps default cache copying and succeeds with a locked GBPUSD cache without launching or closing terminals' {
        $locked=[IO.File]::Open($lockedSource,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        try {
            $warnings=@()
            $output=& (Join-Path $tests 'RunICTTests.ps1') -TerminalInstallPath $installed -MarketCachePath $cache -WarningVariable warnings
            ($output -join "`n") | Should Match 'copied=2; unavailable=10; market history NOT VERIFIED'
            ($warnings -join "`n") | Should Match 'GBPUSD\\2026\.hcc'
            $locked.CanRead | Should Be $true
        } finally { $locked.Dispose() }
        foreach($binary in @('terminal64.exe','metatester64.exe','MetaEditor64.exe')) {
            [IO.File]::ReadAllText((Join-Path $runtime $binary)) | Should Be 'placeholder binary'
        }
        [IO.File]::ReadAllText((Join-Path $history 'EURUSD\2025.hcc')) | Should Be 'available history'
        [IO.File]::ReadAllText((Join-Path $symbols 'symbols-public.dat')) | Should Be 'public symbols'
        Test-Path -LiteralPath (Join-Path $history 'GBPUSD\2026.hcc') | Should Be $false
        Test-Path -LiteralPath (Join-Path $history 'EURUSD\2026.hcc') | Should Be $false
        Test-Path -LiteralPath (Join-Path $symbols 'symbols-old.dat') | Should Be $false
        @(Get-ChildItem -LiteralPath $runtime -Recurse -File | Where-Object { $_.Name -eq 'accounts.dat' -or $_.Name -like '*.partial' }).Count | Should Be 0
        Test-Path -LiteralPath (Join-Path $runtime 'Config') | Should Be $false
        [IO.File]::ReadAllText((Join-Path $installed 'Config\accounts.dat')) | Should Be 'private account sentinel'
        Assert-MockCalled Start-Process -Times 0 -Exactly
        Assert-MockCalled Stop-Process -Times 0 -Exactly
    }
    It 'records the locked cache warning in a successful verification preparation step' {
        $locked=[IO.File]::Open($lockedSource,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        try {
            $shell=(Get-Process -Id $PID).Path
            $arguments=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $tests 'RunICTTests.ps1'),'-Mode','Prepare','-TerminalInstallPath',$installed,'-MarketCachePath',$cache)
            $result=Invoke-ICTVerificationStep 'PrepareRuntime' $shell $arguments 10
            $result.Status | Should Be 'Passed'
            $result.ExitCode | Should Be 0
            $result.Output | Should Match 'Market cache unavailable'
            $result.Output | Should Match 'GBPUSD'
            $result.Output | Should Match '2026\.hcc'
            $result.Output | Should Match 'copied=2; unavailable=10; market history NOT VERIFIED'
            Test-Path -LiteralPath (Join-Path $history 'GBPUSD\2026.hcc') | Should Be $false
            $locked.CanRead | Should Be $true
        } finally { $locked.Dispose() }
    }
    It 'prepares binaries only and clears stale allowlisted cache files when the cache root is missing' {
        $warnings=@()
        $output=& (Join-Path $tests 'RunICTTests.ps1') -Mode Prepare -TerminalInstallPath $installed -MarketCachePath (Join-Path $prepareRoot 'missing-cache') -WarningVariable warnings
        ($output -join "`n") | Should Match 'market history unavailable; copied=0; unavailable=11'
        ($warnings -join "`n") | Should Match 'Market cache unavailable'
        @(Get-ChildItem -LiteralPath (Join-Path $runtime 'bases') -Recurse -File).Count | Should Be 0
        Assert-MockCalled Start-Process -Times 0 -Exactly
        Assert-MockCalled Stop-Process -Times 0 -Exactly
    }
}

Describe 'Compiler freshness and fixture regressions' {
    Mock Start-Process { return New-Object PSObject | Add-Member ScriptMethod WaitForExit { param($timeout) return $true } -PassThru }

    It 'rejects a stale success log from an earlier compilation' {
        $runtime=Join-Path $TestDrive 'stale-log'
        New-Item -ItemType Directory -Path $runtime -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $runtime 'MetaEditor64.exe'),'placeholder')
        $log=Join-Path $runtime 'compile.log'
        [IO.File]::WriteAllText($log,'Result: 0 errors, 0 warnings')
        (Get-Item -LiteralPath $log).LastWriteTimeUtc=[DateTime]::UtcNow.AddHours(-1)
        { Invoke-ICTCompilation $runtime (Join-Path $runtime 'Suite.mq5') $log 10 } | Should Throw 'fresh log'
    }
    It 'rejects a stale binary even when the log is fresh' {
        $runtime=Join-Path $TestDrive 'stale-binary'
        New-Item -ItemType Directory -Path $runtime -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $runtime 'MetaEditor64.exe'),'placeholder')
        $log=Join-Path $runtime 'compile.log'
        $binary=Join-Path $runtime 'Suite.ex5'
        [IO.File]::WriteAllText($binary,'old binary')
        (Get-Item -LiteralPath $binary).LastWriteTimeUtc=[DateTime]::UtcNow.AddHours(-1)
        Mock Start-Process {
            [IO.File]::WriteAllText($log,'Result: 0 errors, 0 warnings')
            return New-Object PSObject | Add-Member ScriptMethod WaitForExit { param($timeout) return $true } -PassThru
        }
        { Invoke-ICTCompilation $runtime (Join-Path $runtime 'Suite.mq5') $log 10 } | Should Throw 'fresh binary'
    }
    It 'rejects compiler warnings instead of treating them as a clean build' {
        $runtime=Join-Path $TestDrive 'compiler-warnings'
        New-Item -ItemType Directory -Path $runtime -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $runtime 'MetaEditor64.exe'),'placeholder')
        $log=Join-Path $runtime 'compile.log'
        Mock Start-Process {
            [IO.File]::WriteAllText($log,'Result: 0 errors, 1 warnings')
            return New-Object PSObject | Add-Member ScriptMethod WaitForExit { param($timeout) return $true } -PassThru
        }
        { Invoke-ICTCompilation $runtime (Join-Path $runtime 'Suite.mq5') $log 10 } | Should Throw 'Compilation did not succeed'
    }
    It 'rejects a successful result mixed with a later failed compilation' {
        $runtime=Join-Path $TestDrive 'ambiguous-log'
        New-Item -ItemType Directory -Path $runtime -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $runtime 'MetaEditor64.exe'),'placeholder')
        $log=Join-Path $runtime 'compile.log'
        Mock Start-Process {
            [IO.File]::WriteAllText($log,"Result: 0 errors, 0 warnings`r`nResult: 1 errors, 0 warnings")
            return New-Object PSObject | Add-Member ScriptMethod WaitForExit { param($timeout) return $true } -PassThru
        }
        { Invoke-ICTCompilation $runtime (Join-Path $runtime 'Suite.mq5') $log 10 } | Should Throw 'ambiguous'
    }
    It 'fails on compiler timeout even if an older successful log exists' {
        $runtime=Join-Path $TestDrive 'compiler-timeout'
        New-Item -ItemType Directory -Path $runtime -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $runtime 'MetaEditor64.exe'),'placeholder')
        $log=Join-Path $runtime 'compile.log'
        [IO.File]::WriteAllText($log,'Result: 0 errors, 0 warnings')
        Mock Start-Process {
            $fake=New-Object PSObject -Property @{Id=123}
            $fake | Add-Member ScriptMethod WaitForExit { param($timeout) return $false }
            $fake | Add-Member ScriptMethod CloseMainWindow { return $true }
            return $fake
        }
        { Invoke-ICTCompilation $runtime (Join-Path $runtime 'Suite.mq5') $log 10 } | Should Throw 'Compiler timeout'
    }
    It 'uses the actual Range suite failure counter' {
        $source=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ICTRangeTests.mq5') -Raw
        Get-ICTFixtureSource $source 'ICTRangeTests' 'range.unique.csv' | Should Match 'int fixture_failures=g_failures;'
    }
    It 'does not discard a failed fixture initialization' {
        $source=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ICTUnifiedTests.mq5') -Raw
        Get-ICTFixtureSource $source 'ICTUnifiedTests' 'unified.unique.csv' | Should Match 'fixture_status!=INIT_SUCCEEDED && fixture_failures==0'
    }
}

Describe 'Verification subprocess execution' {
    $shell=(Get-Process -Id $PID).Path
    It 'captures output and the real nonzero exit code' {
        $result=Invoke-ICTVerificationStep 'failure' $shell @('-NoProfile','-NonInteractive','-Command',"Write-Output 'message with spaces'; exit 7") 10
        $result.Status | Should Be 'Failed'
        $result.ExitCode | Should Be 7
        $result.Output | Should Match 'message with spaces'
    }
    It 'preserves quotes and trailing backslashes in native arguments' {
        $command="Write-Output 'quoted `"text`" C:\folder with spaces\'; exit 0"
        $result=Invoke-ICTVerificationStep 'quoting' $shell @('-NoProfile','-NonInteractive','-Command',$command) 10
        $result.Status | Should Be 'Passed'
        $result.Output | Should Match 'quoted "text" C:\\folder with spaces\\'
    }
    It 'records a launch failure as failure' {
        $result=Invoke-ICTVerificationStep 'launch' (Join-Path $TestDrive 'missing.exe') @() 10
        $result.Status | Should Be 'Failed'
        $result.ExitCode | Should BeNullOrEmpty
    }
    It 'does not report a timed-out verification process as passed' {
        $result=Invoke-ICTVerificationStep 'timeout' $shell @('-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 20') 1
        $result.Status | Should Be 'Failed'
        $result.Output | Should Match 'timed out'
    }
}
