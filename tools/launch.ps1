param([ValidateSet('play', 'verify', 'check')][string]$Mode = 'play')

$script:EngineVersion = '4.7.2'
$script:EngineFile = 'Godot_v4.7.2-stable_win64.exe'
$script:EngineUrl = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip'
$script:EngineHash = '83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993'

function Test-SystemRequirements {
    if ($PSVersionTable.PSVersion -lt [version]'5.1') {
        throw 'Windows PowerShell 5.1 or newer is required. Update Windows before playing.'
    }
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw 'This launcher requires 64-bit Windows 10 or Windows 11.'
    }
    $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    if ($build -lt 10240) { throw 'Windows 10 or newer is required.' }
    $architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    if ($architecture -ne 'AMD64') {
        throw 'Automatic setup currently supports x64 PCs only. Use a suitable native Godot build on other architectures.'
    }
}

function Test-ProjectFiles([string]$Project) {
    $required = @('project.godot', 'main.tscn', 'main.gd', 'levels.gd', 'character.gd', 'hazard_art.gd', 'art/Alegreya.ttf')
    foreach ($name in @('arcade', 'pendulum', 'mirror', 'shaft', 'belfry', 'escape')) { $required += "art/$name.png" }
    foreach ($name in @('music_base', 'music_high', 'rain', 'ring', 'jump', 'land', 'collect', 'fail', 'start', 'finish', 'reject', 'bronze', 'echo', 'glass', 'stone', 'menu')) { $required += "audio/$name.wav" }
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Project $_) -PathType Leaf) })
    if ($missing.Count) { throw ('Incomplete game folder. Extract all game files. Missing: ' + ($missing -join ', ')) }
}

function Test-ProjectWritable([string]$Project) {
    $probe = Join-Path $Project ('.launch-check-' + [guid]::NewGuid().ToString('N'))
    try { [IO.File]::WriteAllText($probe, '') }
    catch { throw 'Godot needs to import assets into this folder. Extract the game to a writable folder, such as Documents, then retry.' }
    finally { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe } }
}

function Invoke-EngineProcess([string]$Executable, [string]$Arguments, [string]$Directory, [int]$TimeoutSeconds = 15) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $info.Arguments = $Arguments
    $info.WorkingDirectory = $Directory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "Godot did not respond within $TimeoutSeconds seconds."
        }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.Result + $stderr.Result }
    }
    finally { $process.Dispose() }
}

function Test-CompatibleEngine([string]$Executable) {
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { return $false }
    try {
        $result = Invoke-EngineProcess $Executable '--version' (Split-Path -Parent $Executable)
        return $result.ExitCode -eq 0 -and $result.Output.Trim() -match '^4\.7\.2\.stable(?:\.|$)' -and $result.Output -notmatch '\.mono\.'
    }
    catch { return $false }
}

function Get-EngineCandidates([string]$Project, [string]$InstallDirectory) {
    if ($env:GODOT_EXE) { $env:GODOT_EXE }
    Join-Path $InstallDirectory $script:EngineFile
    foreach ($directory in @($Project, (Join-Path $Project 'Godot'))) {
        if (Test-Path -LiteralPath $directory -PathType Container) {
            Get-ChildItem -LiteralPath $directory -Filter 'Godot*.exe' -File | Sort-Object Name -Descending | ForEach-Object { $_.FullName }
        }
    }
    foreach ($name in @('godot.exe', 'godot4.exe', $script:EngineFile, 'Godot_v4.7.2-stable_win64_console.exe')) {
        Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object { $_.Source }
    }
    $roots = @((Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'), (Join-Path $env:ProgramFiles 'WinGet\Packages'))
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($package in @(Get-ChildItem -LiteralPath $root -Directory -Filter 'GodotEngine.GodotEngine_*')) {
            Get-ChildItem -LiteralPath $package.FullName -Filter 'Godot*.exe' -File -Recurse | Sort-Object Name -Descending | ForEach-Object { $_.FullName }
        }
    }
}

function Find-Engine([string]$Project, [string]$InstallDirectory) {
    $seen = @{}
    foreach ($candidate in @(Get-EngineCandidates $Project $InstallDirectory)) {
        if ($seen.ContainsKey($candidate)) { continue }
        $seen[$candidate] = $true
        if (Test-CompatibleEngine $candidate) { return $candidate }
    }
    return $null
}

function Request-InstallConsent([string]$InstallDirectory) {
    Write-Host "Godot $script:EngineVersion (standard edition) was not found."
    Write-Host 'The game does not need Python, Git, WinGet, or the .NET SDK.'
    Write-Host 'Setup can download Godot from its official GitHub release and verify its SHA-512 checksum.'
    Write-Host "It will be stored in: $InstallDirectory"
    Write-Host 'No administrator access is required. Existing Godot versions will not be changed.'
    $answer = Read-Host 'Download and install Godot, then continue? [y/N]'
    return $answer -match '^(?i:y|yes)$'
}

function Receive-EngineArchive([string]$Destination) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri $script:EngineUrl -OutFile $Destination -TimeoutSec 300 -ErrorAction Stop
}

function Install-Engine([string]$InstallDirectory) {
    $parent = Split-Path -Parent $InstallDirectory
    [void][IO.Directory]::CreateDirectory($parent)
    $staging = Join-Path $parent ('setup-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($staging)
    try {
        $archive = Join-Path $staging 'godot.zip'
        Write-Host 'Downloading Godot. This may take a few minutes...'
        Receive-EngineArchive $archive
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash -ne $script:EngineHash) {
            throw 'Download verification failed. Nothing from the download was executed. Please retry on a trusted connection.'
        }
        $unpacked = Join-Path $staging 'unpacked'
        Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
        $executable = Join-Path $unpacked $script:EngineFile
        if (-not (Test-CompatibleEngine $executable)) { throw 'The downloaded Godot engine could not run on this PC.' }
        if (Test-Path -LiteralPath $InstallDirectory) {
            throw "The private engine folder already exists but could not be used: $InstallDirectory. Move it aside manually and retry; setup will not overwrite it."
        }
        Move-Item -LiteralPath $unpacked -Destination $InstallDirectory
        Write-Host 'Godot installation complete.'
        return (Join-Path $InstallDirectory $script:EngineFile)
    }
    finally {
        $resolvedStaging = [IO.Path]::GetFullPath($staging)
        $resolvedParent = [IO.Path]::GetFullPath($parent).TrimEnd('\') + '\'
        if ($resolvedStaging.StartsWith($resolvedParent, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolvedStaging) -match '^setup-[0-9a-f]{32}$' -and (Test-Path -LiteralPath $resolvedStaging)) {
            Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
        }
    }
}

function Resolve-Engine([string]$Project, [string]$InstallDirectory, [bool]$Interactive) {
    $engine = Find-Engine $Project $InstallDirectory
    if ($engine) { return $engine }
    if (-not $Interactive) { throw "Godot $script:EngineVersion is missing. Run PLAY.cmd without options to approve setup, or set GODOT_EXE to the engine executable." }
    if (-not (Request-InstallConsent $InstallDirectory)) { return $null }
    return (Install-Engine $InstallDirectory)
}

function Import-Game([string]$Engine, [string]$Project, [string]$LogDirectory) {
    Write-Host 'Checking scripts and importing assets...'
    $log = Join-Path $LogDirectory 'import.log'
    $result = Invoke-EngineProcess $Engine '--headless --editor --path . --import --quit' $Project 180
    [IO.File]::WriteAllText($log, $result.Output)
    if ($result.ExitCode -ne 0 -or $result.Output -match '(?im)^\s*(SCRIPT ERROR:|ERROR:)') {
        throw "Asset import failed. Details: $log. Check that the full game folder was extracted."
    }
    Write-Host 'Asset import succeeded.'
}

function Start-Game([string]$Engine, [string]$Project, [string]$LogDirectory) {
    $guiEngine = $Engine -replace '_console\.exe$', '.exe'
    if (-not (Test-Path -LiteralPath $guiEngine)) { $guiEngine = $Engine }
    $log = Join-Path $LogDirectory 'game.log'
    $process = Start-Process -FilePath $guiEngine -ArgumentList ('--path . --log-file "' + $log + '"') -WorkingDirectory $Project -PassThru
    try {
        $exited = $process.WaitForExit(3000)
        $errors = (Test-Path -LiteralPath $log) -and (Select-String -LiteralPath $log -Pattern '^\s*(SCRIPT ERROR:|ERROR:)' -Quiet)
        if (($exited -and $process.ExitCode -ne 0) -or $errors) {
            throw "Godot could not start the game cleanly. See $log. A graphics error may require an updated GPU driver with OpenGL 3.3 support; drivers are never installed automatically."
        }
        if (-not $exited) { Write-Host 'Game launched.' }
    }
    finally { $process.Dispose() }
}

function Invoke-Launcher([string]$Project, [string]$LaunchMode) {
    Test-SystemRequirements
    Test-ProjectFiles $Project
    $privateRoot = Join-Path $env:LOCALAPPDATA 'Resonance'
    $installDirectory = Join-Path $privateRoot ('Godot\' + $script:EngineVersion)
    if ($LaunchMode -ne 'check') { Test-ProjectWritable $Project }
    $engine = Resolve-Engine $Project $installDirectory ($LaunchMode -eq 'play')
    if (-not $engine) {
        Write-Host 'Setup cancelled. Nothing was installed.'
        return 0
    }
    Write-Host "Using Godot: $engine"
    if ($LaunchMode -eq 'check') { Write-Host 'Prerequisite checks passed.'; return 0 }
    $logDirectory = Join-Path $privateRoot 'logs'
    [void][IO.Directory]::CreateDirectory($logDirectory)
    Import-Game $engine $Project $logDirectory
    if ($LaunchMode -eq 'play') { Start-Game $engine $Project $logDirectory }
    return 0
}

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    try { exit (Invoke-Launcher (Split-Path -Parent $PSScriptRoot) $Mode) }
    catch {
        Write-Host ('Could not launch Resonance: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host 'For download errors, check your internet connection and retry. You can also obtain the standard Godot 4.7.2 build from https://godotengine.org/download/archive/4.7.2-stable/ and set GODOT_EXE to its executable.'
        exit 1
    }
}
