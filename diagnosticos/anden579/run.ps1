param(
  [ValidateSet('road', 'verify')]
  [string]$Case = 'verify'
)

$ErrorActionPreference = 'Stop'
$lab = 'C:\Users\juanbusper\Documents\URBANISMO\work\anden579_20260921'
$fixture = Join-Path $lab 'fixture.dwg'
$root = 'C:\Users\juanbusper\Streaming de Google Drive\Mi unidad\VARIOS\CLAUDE\proyectos\URBANISMO EXTERNO\diagnosticos\anden579'
if ($Case -eq 'road') {
  $scriptName = 'run_road.scr'
  $sentinelName = 'runroad579.txt'
} else {
  $scriptName = 'run_verify.scr'
  $sentinelName = 'verify579.txt'
}
$script = Join-Path $root $scriptName
$sentinel = Join-Path $lab $sentinelName

if (-not (Test-Path -LiteralPath $fixture)) { throw "No existe fixture: $fixture" }
if (Test-Path -LiteralPath $sentinel) { Remove-Item -LiteralPath $sentinel -Force }

$process = Start-Process -FilePath 'C:\Program Files\Autodesk\AutoCAD 2023\acad.exe' `
  -ArgumentList @("`"$fixture`"", '/ld', '"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"', '/p', '<<C3D_Metric>>', '/product', 'C3D', '/language', 'en-US', '/b', "`"$script`"") `
  -WindowStyle Hidden -PassThru

"PID=$($process.Id) CASE=$Case"
$deadline = (Get-Date).AddMinutes(8)
while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 2
  $process.Refresh()
}
if (-not $process.HasExited) {
  Stop-Process -Id $process.Id -Force
  throw "La instancia de prueba excedio ocho minutos; se cerro solo PID $($process.Id)."
}
if (-not (Test-Path -LiteralPath $sentinel)) { throw "Civil 3D no produjo $sentinel" }
Get-Content -LiteralPath $sentinel
if ($Case -eq 'road') {
  $detail = Join-Path $lab 'road579.txt'
  if (-not (Test-Path -LiteralPath $detail)) { throw 'Falta road579.txt' }
  Get-Content -LiteralPath $detail
} elseif (-not (Select-String -LiteralPath $sentinel -SimpleMatch 'FINISHED' -Quiet)) {
  throw 'La verificacion focal no termino correctamente.'
}
