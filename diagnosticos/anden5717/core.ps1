param([string]$Name='apply-baseline')
$ErrorActionPreference='Stop'
$lab='C:\Users\juanbusper\Documents\URBANISMO\work\anden5717'
if (Test-Path "$lab\$Name.txt") { throw 'Preserve evidence' }
$timer=[Diagnostics.Stopwatch]::StartNew()
$fixture = if ($Name -eq 'verify') { "$lab\fixture.dwg" } else { 'C:\Users\juanbusper\Documents\URBANISMO\work\tierras5715\fixture.dwg' }
$proc=Start-Process 'C:\Program Files\Autodesk\AutoCAD 2023\accoreconsole.exe' -WindowStyle Hidden -PassThru -ArgumentList @('/i',"`"$fixture`"",'/s',"`"$PSScriptRoot\$Name.scr`"",'/l','en-US') -RedirectStandardOutput "$lab\$Name-console.txt" -RedirectStandardError "$lab\$Name-stderr.txt"
while (-not $proc.HasExited -and $timer.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Seconds 2; $proc.Refresh() }
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; 'TIMEOUT owned PID only' }
"Seconds=$($timer.Elapsed.TotalSeconds)"
Get-Content "$lab\$Name.txt" -ErrorAction SilentlyContinue
