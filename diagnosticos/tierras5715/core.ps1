$ErrorActionPreference = 'Stop'
$lab = 'C:\Users\juanbusper\Documents\URBANISMO\work\tierras5715'
if (Test-Path -LiteralPath "$lab\core.txt") { throw 'Preserve existing evidence.' }
$proc = Start-Process 'C:\Program Files\Autodesk\AutoCAD 2023\accoreconsole.exe' -WindowStyle Hidden -PassThru -ArgumentList @('/i', "`"$lab\fixture.dwg`"", '/s', "`"$PSScriptRoot\core.scr`"", '/l', 'en-US') -RedirectStandardOutput "$lab\core-console.txt" -RedirectStandardError "$lab\core-stderr.txt"
"PID=$($proc.Id)"
$deadline = (Get-Date).AddSeconds(60)
while (-not $proc.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2; $proc.Refresh() }
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; 'TIMEOUT owned Core Console only' }
if (Test-Path -LiteralPath "$lab\core.txt") { Get-Content -LiteralPath "$lab\core.txt" }
