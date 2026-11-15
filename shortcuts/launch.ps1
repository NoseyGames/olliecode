# Windows PowerShell 5.1+. No npm modules or administrator privileges required.
[CmdletBinding()]
param(
    [string]$Directory,
    [string]$Executable,
    [switch]$Continue,
    [switch]$Standalone
)

function Resolve-WorkingFolder([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Working folder does not exist: $Path"
    }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.PSProvider.Name -ne 'FileSystem') { throw 'Choose a filesystem folder.' }
    return $item.FullName
}

function Get-LauncherStatePath {
    if (-not $env:LOCALAPPDATA) { throw 'LOCALAPPDATA is unavailable.' }
    return Join-Path $env:LOCALAPPDATA 'olliEcode\launcher\folder.txt'
}

function Read-LastFolder([string]$StatePath) {
    try {
        if (Test-Path -LiteralPath $StatePath -PathType Leaf) {
            return Resolve-WorkingFolder ([IO.File]::ReadAllText($StatePath))
        }
    } catch { Write-Warning 'The remembered folder is unavailable. Choose another folder.' }
    return $null
}

function Save-LastFolder([string]$StatePath, [string]$Folder) {
    $temporary = "$StatePath.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($StatePath)) | Out-Null
        [IO.File]::WriteAllText($temporary, $Folder)
        # Same-directory rename keeps readers from observing a partially written path.
        if ([IO.File]::Exists($StatePath)) { [IO.File]::Replace($temporary, $StatePath, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $StatePath) }
    } catch { Write-Warning "Could not remember the folder: $($_.Exception.Message)" }
    finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}

function Select-WorkingFolder([string]$StatePath) {
    while ($true) {
        $last = Read-LastFolder $StatePath
        Write-Host "`n[1] Last used folder: $last"
        Write-Host "[2] Current folder: $((Get-Location).Path)"
        Write-Host '[3] Choose a folder'
        Write-Host '[4] Quit'
        switch (Read-Host 'Folder') {
            '1' { if ($last) { return $last } }
            '2' { return Resolve-WorkingFolder (Get-Location).Path }
            '3' {
                Add-Type -AssemblyName System.Windows.Forms
                $picker = New-Object System.Windows.Forms.FolderBrowserDialog
                try {
                    $picker.Description = 'Choose an olliEcode working folder'
                    if ($last) { $picker.SelectedPath = $last }
                    if ($picker.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                        return Resolve-WorkingFolder $picker.SelectedPath
                    }
                } finally { $picker.Dispose() }
            }
            '4' { return $null }
            default { Write-Host 'Choose 1, 2, 3 or 4.' }
        }
    }
}

function Resolve-LauncherExecutable([string]$Requested) {
    $names = if ($Requested) { @($Requested) } else { @('olliecode', 'opencode') }
    foreach ($name in $names) {
        $command = Get-Command -Name $name -CommandType Application,ExternalScript -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($command) { return $command.Source }
    }
    throw 'CLI not found. Install olliEcode/OpenCode or pass -Executable with the path to your built executable.'
}

function Start-Launcher([string]$Folder, [string]$Program, [bool]$Resume, [bool]$PrivateServer) {
    $arguments = @()
    if ($Resume) { $arguments += '--continue' }
    if ($PrivateServer) { $arguments += '--standalone' }
    Push-Location -LiteralPath $Folder
    try {
        # No command-string evaluation: spaces and shell metacharacters remain literal folder names.
        $global:LASTEXITCODE = 0
        & $Program @arguments | Out-Host
        return $LASTEXITCODE
    } finally { Pop-Location }
}

# Dot-sourcing loads functions for tests without opening a picker or starting a process.
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $statePath = Get-LauncherStatePath
        $folder = if ($Directory) { Resolve-WorkingFolder $Directory } else { Select-WorkingFolder $statePath }
        if (-not $folder) { exit 0 }
        $program = Resolve-LauncherExecutable $Executable
        $resume = $Continue.IsPresent
        if (-not $Directory -and -not $Continue) {
            $choice = Read-Host '[1] Continue last session [2] New session [3] Quit'
            if ($choice -eq '3') { exit 0 }
            if ($choice -ne '1' -and $choice -ne '2') { throw 'Choose 1, 2 or 3.' }
            $resume = $choice -eq '1'
        }
        Save-LastFolder $statePath $folder
        exit (Start-Launcher $folder $program $resume $Standalone.IsPresent)
    } catch {
        Write-Error $_ -ErrorAction Continue
        exit 1
    }
}
