$ErrorActionPreference='Stop'
$lab='C:\Users\juanbusper\Documents\URBANISMO\work\anden5717'
if (Test-Path "$lab\final-native.txt") { throw 'Preserve evidence' }
$timer=[Diagnostics.Stopwatch]::StartNew()
$proc=Start-Process 'C:\Program Files\Autodesk\AutoCAD 2023\acad.exe' -WindowStyle Hidden -PassThru -ArgumentList @("`"$lab\fixture.dwg`"",'/ld','"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"','/p','<<C3D_Metric>>','/product','C3D','/language','en-US','/b',"`"$PSScriptRoot\final-native.scr`"")
"PID=$($proc.Id)"
while (-not $proc.HasExited -and $timer.Elapsed.TotalSeconds -lt 90) { Start-Sleep -Seconds 2; $proc.Refresh() }
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; 'TIMEOUT owned PID only' }
"Seconds=$($timer.Elapsed.TotalSeconds)"
Get-Content "$lab\final-native.txt" -ErrorAction SilentlyContinue
