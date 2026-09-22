param([switch]$Native)
$ErrorActionPreference = 'Stop'
$lab = 'C:\Users\juanbusper\Documents\URBANISMO\work\bloques5716'
$name = if ($Native) { 'native' } else { 'core' }
New-Item -ItemType Directory -Path $lab -Force | Out-Null
if (Test-Path -LiteralPath "$lab\$name.txt") { throw 'Preserve existing evidence.' }
if (-not (Test-Path -LiteralPath "$lab\fixture.dwg")) {
  Copy-Item -LiteralPath 'C:\Users\juanbusper\Documents\URBANISMO\work\tierras5715\fixture.dwg' -Destination "$lab\fixture.dwg"
}
$exe = 'C:\Program Files\Autodesk\AutoCAD 2023\accoreconsole.exe'
$argsList = @('/i', "`"$lab\fixture.dwg`"", '/s', "`"$PSScriptRoot\core.scr`"", '/l', 'en-US')
$limit = 60
if ($Native) {
  $exe = 'C:\Program Files\Autodesk\AutoCAD 2023\acad.exe'
  $argsList = @("`"$lab\fixture.dwg`"", '/ld', '"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"', '/p', '<<C3D_Metric>>', '/product', 'C3D', '/language', 'en-US', '/b', "`"$PSScriptRoot\native.scr`"")
  $limit = 90
}
$timer = [Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process $exe -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput "$lab\$name-console.txt" -RedirectStandardError "$lab\$name-stderr.txt"
"PID=$($proc.Id)"
while (-not $proc.HasExited -and $timer.Elapsed.TotalSeconds -lt $limit) { Start-Sleep -Seconds 2; $proc.Refresh() }
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; 'TIMEOUT owned test process only' }
"Elapsed=$($timer.Elapsed.TotalSeconds)"
if (Test-Path -LiteralPath "$lab\$name.txt") { Get-Content -LiteralPath "$lab\$name.txt" }
if (-not (Test-Path -LiteralPath "$lab\$name.txt") -or -not (Select-String -LiteralPath "$lab\$name.txt" -SimpleMatch 'FINISHED' -Quiet)) { throw 'Test incomplete or failed.' }
