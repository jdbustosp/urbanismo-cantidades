$ErrorActionPreference='Stop'
$lab='C:\Users\juanbusper\Documents\URBANISMO\work\anden5717'
New-Item -ItemType Directory -Path $lab -Force | Out-Null
if (Test-Path "$lab\fixture.dwg") { throw 'Preserve evidence' }
Copy-Item -LiteralPath 'C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\Memorias\URB_MASTER_GENERAL.dwg' -Destination "$lab\fixture.dwg"
$timer=[Diagnostics.Stopwatch]::StartNew()
$proc=Start-Process 'C:\Program Files\Autodesk\AutoCAD 2023\acad.exe' -WindowStyle Hidden -PassThru -ArgumentList @("`"$lab\fixture.dwg`"",'/ld','"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"','/p','<<C3D_Metric>>','/product','C3D','/language','en-US','/b',"`"$PSScriptRoot\probe.scr`"")
"PID=$($proc.Id)"
while (-not $proc.HasExited -and $timer.Elapsed.TotalSeconds -lt 90) { Start-Sleep -Seconds 2; $proc.Refresh() }
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; 'TIMEOUT owned PID only' }
"Seconds=$($timer.Elapsed.TotalSeconds)"
Get-Content "$lab\probe.txt" -ErrorAction SilentlyContinue
