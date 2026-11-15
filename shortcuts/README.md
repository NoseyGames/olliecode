# Windows CLI launcher

Double-click `launch.cmd`. Choose the last folder, the current folder, or a native
Windows folder picker; then choose a new session or continue the previous one.
Canceling the picker returns to the menu. The last folder is stored in
`%LOCALAPPDATA%\olliEcode\launcher\folder.txt`.

Requires Windows PowerShell 5.1 and an installed `olliecode` or `opencode` CLI.
The launcher adds no npm packages and requires no administrator access.
It does not install or replace the CLI automatically.

```powershell
.\shortcuts\launch.ps1 -Directory 'C:\Projects\my app' -Continue
.\shortcuts\launch.ps1 -Executable 'C:\Tools\opencode.exe' -Standalone
```

`-Standalone` uses the CLI's private server mode when a managed service is having
port problems. It does not terminate other running sessions or services.
Session history stays in the CLI's normal storage. Usage reporting and provider
configuration are unchanged. Child exit codes propagate to the caller.

The `.cmd` entry point sets execution policy for its own PowerShell process only;
it does not change the machine or user policy. Organization-enforced policies still apply.

Run the dependency-free launcher checks with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\shortcuts\launch.test.ps1
```
