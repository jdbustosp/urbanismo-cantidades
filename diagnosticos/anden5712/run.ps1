param([switch]$SavedOnly)
$ErrorActionPreference = 'Stop'
$lab = 'C:\Users\juanbusper\Documents\URBANISMO\work\anden5712'
$fixture = Join-Path $lab 'fixture.dwg'
if (-not (Test-Path -LiteralPath $fixture)) { throw 'Missing local fixture.' }
$result = Join-Path $lab 'result.txt'
if (Test-Path -LiteralPath $result) { throw 'Result already exists; preserve evidence.' }
$scr = Join-Path $PSScriptRoot $(if ($SavedOnly) { 'saved.scr' } else { 'run.scr' })
$proc = Start-Process 'C:\Program Files\Autodesk\AutoCAD 2023\acad.exe' -WindowStyle Hidden -PassThru -ArgumentList @("`"$fixture`"", '/ld', '"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"', '/p', '<<C3D_Metric>>', '/product', 'C3D', '/language', 'en-US', '/b', "`"$scr`"")
"PID=$($proc.Id)"
$deadline = (Get-Date).AddSeconds(90)
while (-not $proc.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2; $proc.Refresh() }
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; 'TIMEOUT: owned test process only.' }
if (Test-Path -LiteralPath $result) { Get-Content -LiteralPath $result }
if (-not (Test-Path -LiteralPath $result) -or -not (Select-String -LiteralPath $result -SimpleMatch 'FINISHED' -Quiet)) { throw 'Incomplete or failed test.' }
