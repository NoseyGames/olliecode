$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\launch.ps1"

function Assert($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('ollie-launch-' + [Guid]::NewGuid().ToString('N'))
$original = (Get-Location).Path
$oldOutput = $env:OLLIE_TEST_OUTPUT
try {
    $folder = Join-Path $testRoot 'space & [literal] folder'
    [IO.Directory]::CreateDirectory($folder) | Out-Null
    $state = Join-Path $testRoot 'state\folder.txt'
    Assert ($null -eq (Read-LastFolder $state)) 'Missing state must be allowed.'
    Save-LastFolder $state $folder
    Assert ((Read-LastFolder $state) -eq $folder) 'Folder names must round-trip literally.'
    Save-LastFolder $state $testRoot
    Assert ((Read-LastFolder $state) -eq $testRoot) 'Existing state must be replaced.'
    $failed = $false
    try { Resolve-WorkingFolder (Join-Path $testRoot 'missing') } catch { $failed = $true }
    Assert $failed 'Missing folders must fail.'
    $failed = $false
    try { Resolve-LauncherExecutable (Join-Path $testRoot 'missing.exe') } catch { $failed = $true }
    Assert $failed 'Missing executables must fail.'
    $program = Join-Path $testRoot 'fake cli.ps1'
    $env:OLLIE_TEST_OUTPUT = Join-Path $testRoot 'result.json'
    [IO.File]::WriteAllText($program, @'
@{ folder = (Get-Location).Path; arguments = @($args) } | ConvertTo-Json | Set-Content -LiteralPath $env:OLLIE_TEST_OUTPUT
$global:LASTEXITCODE = 17
'@)
    $resolved = Resolve-LauncherExecutable $program
    Assert ($resolved -eq $program) 'Explicit executable paths must resolve.'
    Assert ((Start-Launcher $folder $resolved $true $true) -eq 17) 'Child exit codes must propagate.'
    $result = Get-Content -Raw -LiteralPath $env:OLLIE_TEST_OUTPUT | ConvertFrom-Json
    Assert ($result.folder -eq $folder) 'CLI must start in the selected folder.'
    Assert (($result.arguments -join ',') -eq '--continue,--standalone') 'Session and server flags must arrive intact.'
    Assert ((Get-Location).Path -eq $original) 'Working directory must be restored.'
    $null = Start-Launcher $folder $resolved $false $false
    $result = Get-Content -Raw -LiteralPath $env:OLLIE_TEST_OUTPUT | ConvertFrom-Json
    Assert ($result.arguments.Count -eq 0) 'New sessions must not receive continuation flags.'
    [IO.File]::WriteAllText($program, "throw 'launch failed'")
    $failed = $false
    try { Start-Launcher $folder $program $false $false } catch { $failed = $true }
    Assert $failed 'Launch failures must propagate.'
    Assert ((Get-Location).Path -eq $original) 'Failed launches must restore the working directory.'
    Write-Host 'PASS: launcher state, literal paths, flags, exit codes, failures and directory cleanup'
} finally {
    $env:OLLIE_TEST_OUTPUT = $oldOutput
    # Delete only the unique directory created by this test under the system temporary directory.
    $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedRoot).StartsWith('ollie-launch-')) {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    }
}
