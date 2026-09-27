$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'launch.ps1')
$project = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('resonance-launcher-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$script:passed = 0

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    $message = ''
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert ($message -match $Pattern) "Expected '$Pattern', got '$message'."
}

function Test-Case([string]$Name, [scriptblock]$Action) {
    & $Action
    $script:passed++
    Write-Host "PASS: $Name"
}

try {
    Test-Case 'Complete project and write access' {
        Test-ProjectFiles $project
        Test-ProjectWritable $testRoot
        Expect-Failure { Test-ProjectFiles $testRoot } 'Incomplete game folder'
    }
    Test-Case 'Only explicit yes grants permission' {
        foreach ($reply in @('', 'n', 'no', 'maybe', 'y', 'YES')) {
            function Read-Host { return $reply }
            Assert ((Request-InstallConsent $testRoot) -eq ($reply -in @('y', 'YES'))) "Wrong consent result: '$reply'."
        }
    }
    Test-Case 'Existing Godot never prompts or downloads' {
        function Find-Engine { 'existing.exe' }
        function Request-InstallConsent { throw 'Unexpected prompt' }
        function Install-Engine { throw 'Unexpected installation' }
        Assert ((Resolve-Engine $project $testRoot $true) -eq 'existing.exe') 'Did not reuse engine.'
    }
    Test-Case 'Declining setup never installs' {
        function Find-Engine { $null }
        function Request-InstallConsent { $false }
        function Install-Engine { throw 'Unexpected installation' }
        Assert ($null -eq (Resolve-Engine $project $testRoot $true)) 'Cancellation was not respected.'
    }
    Test-Case 'Noninteractive checks never prompt or install' {
        function Find-Engine { $null }
        function Request-InstallConsent { throw 'Unexpected prompt' }
        function Install-Engine { throw 'Unexpected installation' }
        Expect-Failure { Resolve-Engine $project $testRoot $false } 'Godot 4.7.2 is missing'
    }
    Test-Case 'Approving setup returns the installed engine' {
        function Find-Engine { $null }
        function Request-InstallConsent { $true }
        function Install-Engine { 'new.exe' }
        Assert ((Resolve-Engine $project $testRoot $true) -eq 'new.exe') 'Approved installation was not used.'
    }
    Test-Case 'Wrong versions, prereleases and .NET builds are rejected' {
        foreach ($version in @('4.3.stable.official', '4.7.2.rc1.official', '4.7.2.stable.mono.official', '5.0.stable.official', '4.7.2.stable.official.399a20b')) {
            function Invoke-EngineProcess { [pscustomobject]@{ ExitCode = 0; Output = $version } }
            Assert ((Test-CompatibleEngine (Join-Path $project 'PLAY.cmd')) -eq ($version -eq '4.7.2.stable.official.399a20b')) "Wrong version decision: $version."
        }
    }
    Test-Case 'Corrupt downloads are never extracted or executed' {
        function Receive-EngineArchive([string]$Destination) { Copy-Item -LiteralPath (Join-Path $project 'README.md') -Destination $Destination }
        function Test-CompatibleEngine { throw 'Unverified download executed' }
        $target = Join-Path $testRoot 'corrupt/4.7.2'
        Expect-Failure { Install-Engine $target } 'verification failed'
        Assert (-not (Test-Path -LiteralPath $target)) 'Corrupt engine was installed.'
        Assert (@(Get-ChildItem -LiteralPath (Split-Path $target) -Filter 'setup-*').Count -eq 0) 'Staging files were left behind.'
    }
    Test-Case 'Network failures stop setup' {
        function Receive-EngineArchive { throw 'Network unavailable' }
        $target = Join-Path $testRoot 'offline/4.7.2'
        Expect-Failure { Install-Engine $target } 'Network unavailable'
        Assert (-not (Test-Path -LiteralPath $target)) 'Offline setup installed something.'
    }
    Test-Case 'Verified archive installs without overwriting existing folders' {
        $fixture = Join-Path $testRoot 'fixture'
        [void][IO.Directory]::CreateDirectory($fixture)
        Copy-Item -LiteralPath (Join-Path $project 'README.md') -Destination (Join-Path $fixture $script:EngineFile)
        $fixtureZip = Join-Path $testRoot 'fixture.zip'
        Compress-Archive -LiteralPath (Join-Path $fixture $script:EngineFile) -DestinationPath $fixtureZip
        $previousHash = $script:EngineHash
        try {
            $script:EngineHash = (Get-FileHash -LiteralPath $fixtureZip -Algorithm SHA512).Hash
            function Receive-EngineArchive([string]$Destination) { Copy-Item -LiteralPath $fixtureZip -Destination $Destination }
            function Test-CompatibleEngine { $true }
            $target = Join-Path $testRoot 'installed/4.7.2'
            $engine = Install-Engine $target
            Assert (Test-Path -LiteralPath $engine) 'Engine was not installed.'
            $hash = (Get-FileHash -LiteralPath $engine).Hash
            Expect-Failure { Install-Engine $target } 'will not overwrite'
            Assert ((Get-FileHash -LiteralPath $engine).Hash -eq $hash) 'Existing engine changed.'
        }
        finally { $script:EngineHash = $previousHash }
    }
    Test-Case 'Import failure and zero-exit script errors stop launch' {
        foreach ($case in @(@(1, 'Import failed'), @(0, 'SCRIPT ERROR: Parse Error'), @(0, 'ERROR: Missing resource'))) {
            function Invoke-EngineProcess { [pscustomobject]@{ ExitCode = $case[0]; Output = $case[1] } }
            Expect-Failure { Import-Game 'fake.exe' $project $testRoot } 'Asset import failed'
        }
    }
    Test-Case 'Successful import uses a relative project path' {
        function Invoke-EngineProcess($Executable, $Arguments, $Directory, $TimeoutSeconds) {
            Assert ($Arguments -eq '--headless --editor --path . --import --quit') 'Unsafe import arguments.'
            Assert ($Directory -eq $project) 'Wrong working directory.'
            [pscustomobject]@{ ExitCode = 0; Output = 'Import complete' }
        }
        Import-Game 'fake.exe' $project $testRoot
    }
    Test-Case 'Process wrapper captures output and exit status' {
        $result = Invoke-EngineProcess $env:ComSpec '/d /c "echo process-check & exit /b 7"' $testRoot
        Assert ($result.ExitCode -eq 7 -and $result.Output -match 'process-check') 'Incorrect process result.'
    }
    Test-Case 'Play imports before launching; check and verify never launch' {
        function Test-SystemRequirements {}
        function Test-ProjectFiles {}
        function Test-ProjectWritable {}
        function Resolve-Engine { 'ready.exe' }
        function Import-Game { $steps.Add('import') }
        function Start-Game { $steps.Add('launch') }
        $originalLocalAppData = $env:LOCALAPPDATA
        try {
            $env:LOCALAPPDATA = $testRoot
            foreach ($launchMode in @('play', 'verify', 'check')) {
                $steps = New-Object 'Collections.Generic.List[string]'
                Assert ((Invoke-Launcher $project $launchMode) -eq 0) 'Launcher failed.'
                $expected = switch ($launchMode) { 'play' { 'import,launch' } 'verify' { 'import' } 'check' { '' } }
                Assert (($steps -join ',') -eq $expected) "Wrong sequence in $launchMode."
            }
        }
        finally { $env:LOCALAPPDATA = $originalLocalAppData }
    }
    Write-Host "$script:passed LAUNCHER CHECKS PASSED"
}
finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -match '^resonance-launcher-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
