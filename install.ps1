#requires -Version 5.1
<##
Install the public source build for the current Windows user.
Run: powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
##>
[CmdletBinding()]
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\olliEcode-Source",
    [switch]$Resume,
    [switch]$NoLaunch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Invoke-Checked {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$File failed (exit $LASTEXITCODE)." }
}

function Update-ProcessPath {
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('PATH', 'User') + ';' + $env:PATH
}

function Require-Tool {
    param([string]$Name, [string]$Package)
    Update-ProcessPath
    Find-InstalledTool $Name
    if (Get-Command $Name -ErrorAction SilentlyContinue) { return }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "Install $Package and rerun this script. Automatic setup requires winget (App Installer)."
    }
    & winget.exe @('install', '--id', $Package, '--exact', '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    $installExitCode = $LASTEXITCODE
    Update-ProcessPath
    Find-InstalledTool $Name
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is still unavailable after Winget (exit $installExitCode). Install $Package or add its installation directory to PATH, then rerun with -Resume."
    }
}

function Find-InstalledTool {
    param([string]$Name)
    if (Get-Command $Name -ErrorAction SilentlyContinue) { return }
    # Installers can omit PATH registration, or the invoking shell can have an old PATH.
    $relativePaths = switch ($Name) {
        'git.exe' { 'Git\cmd'; 'Programs\Git\cmd' }
        'node.exe' { 'nodejs'; 'Programs\nodejs' }
        default { return }
    }
    foreach ($root in @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
        if (-not $root) { continue }
        foreach ($relative in $relativePaths) {
            $directory = Join-Path $root $relative
            if (Test-Path -LiteralPath (Join-Path $directory $Name) -PathType Leaf) {
                $env:PATH = $directory + ';' + $env:PATH
                return
            }
        }
    }
}

$oldPath = $env:PATH
$oldChannel = $env:OPENCODE_CHANNEL
$oldTarget = $env:OPENCODE_TARGET
$oldElectronMode = $env:ELECTRON_RUN_AS_NODE
$work = $null
$pushed = $false
try {
    if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem) {
        throw 'This installer requires 64-bit Windows.'
    }
    $InstallDir = [IO.Path]::GetFullPath($InstallDir)
    # Never merge a fresh build into an existing source or installation directory.
    if ((Test-Path -LiteralPath $InstallDir) -and -not $Resume) {
        throw "Destination already exists: $InstallDir. Use -Resume to retry this installation."
    }
    if ($Resume -and -not (Test-Path -LiteralPath (Join-Path $InstallDir 'source\.git'))) {
        throw 'Resume requires an existing source checkout. Use a new -InstallDir for a fresh installation.'
    }
    Require-Tool git.exe Git.Git
    Require-Tool node.exe OpenJS.NodeJS.LTS
    $work = Join-Path ([IO.Path]::GetTempPath()) ('olliecode-install-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $source = Join-Path $InstallDir 'source'
    if ($Resume -and (Test-Path -LiteralPath $source)) {
        if (-not (Test-Path -LiteralPath (Join-Path $source '.git'))) { throw 'Resume requires an existing Git checkout.' }
        $remote = & git.exe -C $source remote get-url origin
        if ($LASTEXITCODE -ne 0 -or $remote -ne 'https://github.com/NoseyGames/olliecode.git') {
            throw 'Resume requires the original NoseyGames/olliecode checkout.'
        }
        Invoke-Checked git.exe @('-C', $source, 'diff', '--quiet')
        Invoke-Checked git.exe @('-C', $source, 'diff', '--cached', '--quiet')
        $branch = & git.exe -C $source branch --show-current
        if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw 'Resume requires the main branch.' }
        Write-Host 'Updating the existing source checkout...'
        Invoke-Checked git.exe @('-C', $source, 'pull', '--ff-only', 'origin', 'main')
    } else {
        Write-Host 'Downloading olliEcode source...'
        Invoke-Checked git.exe @('clone', '--depth', '1', '--branch', 'main', 'https://github.com/NoseyGames/olliecode.git', $source)
    }

    $manifest = Get-Content -LiteralPath (Join-Path $source 'package.json') -Raw | ConvertFrom-Json
    if ($manifest.packageManager -notmatch '^bun@(\d+\.\d+\.\d+)$') {
        throw 'The repository does not specify a supported Bun version.'
    }
    $bunVersion = $Matches[1]
    $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { 'aarch64' } else { 'x64-baseline' }
    $bunArchiveName = "bun-windows-$architecture"
    $bunZip = Join-Path $work 'bun.zip'
    Write-Host "Downloading Bun $bunVersion..."
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/oven-sh/bun/releases/download/bun-v$bunVersion/$bunArchiveName.zip" -OutFile $bunZip
    $toolsDir = Join-Path $InstallDir 'tools'
    Expand-Archive -LiteralPath $bunZip -DestinationPath $toolsDir -Force
    $bun = Join-Path $toolsDir "$bunArchiveName\bun.exe"
    if (-not (Test-Path -LiteralPath $bun)) { throw 'The Bun archive did not contain bun.exe.' }
    # Bun selects its package-runner mode when invoked as bunx.exe.
    Copy-Item -LiteralPath $bun -Destination (Join-Path (Split-Path $bun) 'bunx.exe') -Force
    $env:PATH = (Split-Path $bun) + ';' + $env:PATH
    $env:OPENCODE_CHANNEL = 'local'
    $env:OPENCODE_TARGET = $null
    $env:ELECTRON_RUN_AS_NODE = $null
    Push-Location $source
    $pushed = $true
    Write-Host 'Installing dependencies (this can take several minutes)...'
    Invoke-Checked $bun @('install', '--frozen-lockfile')
    Write-Host 'Building the Windows CLI and desktop app...'
    Invoke-Checked $bun @('run', '--cwd', 'packages/cli', 'build', '--single', '--baseline', '--skip-install')
    $cliPackage = if ($architecture -eq 'aarch64') { 'cli-windows-arm64' } else { 'cli-windows-x64-baseline' }
    if (-not (Test-Path -LiteralPath "packages/cli/dist/$cliPackage/bin/opencode.exe")) {
        throw 'The local CLI build is missing; refusing to substitute a downloaded upstream CLI.'
    }
    Invoke-Checked $bun @('run', '--cwd', 'packages/desktop', 'build')
    $desktop = Join-Path $source 'packages\desktop'
    if (-not (Test-Path -LiteralPath (Join-Path $desktop 'out\main\index.js'))) {
        throw 'The desktop build did not produce its entry point.'
    }
    # Resolve through the desktop package so Bun workspace hoisting is supported.
    Push-Location $desktop
    try {
        # First resolution may download Electron and print progress to stdout.
        Invoke-Checked node.exe @('-e', "require('electron')")
        $electron = & node.exe -p "require('electron')"
        if ($LASTEXITCODE -ne 0) { throw 'Electron runtime resolution failed.' }
        $electron = ($electron | Out-String).Trim()
    } finally { Pop-Location }
    if (-not (Test-Path -LiteralPath $electron -PathType Leaf)) { throw "Electron runtime is missing: $electron" }
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'olliEcode Source.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $electron
    $shortcut.Arguments = '"' + $desktop + '"'
    $shortcut.WorkingDirectory = $desktop
    $shortcut.Description = 'olliEcode local source build'
    $shortcut.Save()
    Write-Host "Installed: $InstallDir"
    Write-Host "Start Menu shortcut: $shortcutPath"
    if (-not $NoLaunch) {
        Start-Process -FilePath $electron -ArgumentList ('"' + $desktop + '"') -WorkingDirectory $desktop -WindowStyle Hidden
    }
} catch {
    Write-Error "Installation stopped: $($_.Exception.Message) Files were retained at $InstallDir for inspection. Rerun with -Resume after resolving the error." -ErrorAction Continue
    exit 1
} finally {
    if ($pushed) { Pop-Location }
    $env:PATH = $oldPath
    $env:OPENCODE_CHANNEL = $oldChannel
    $env:OPENCODE_TARGET = $oldTarget
    $env:ELECTRON_RUN_AS_NODE = $oldElectronMode
    if ($work -and (Test-Path -LiteralPath $work)) {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        $resolvedWork = [IO.Path]::GetFullPath($work)
        if ($resolvedWork.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedWork -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
