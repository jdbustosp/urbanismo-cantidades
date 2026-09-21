$ErrorActionPreference = 'Stop'

$lab = 'C:\Users\juanbusper\Documents\URBANISMO\work\anden578_20260921'
$fixture = Join-Path $lab 'fixture.dwg'
$script = 'C:\Users\juanbusper\Streaming de Google Drive\Mi unidad\VARIOS\CLAUDE\proyectos\URBANISMO EXTERNO\diagnosticos\anden578\run.scr'
$result = Join-Path $lab 'verify578.txt'

if (-not (Test-Path -LiteralPath $fixture)) { throw "No existe fixture: $fixture" }
if (Test-Path -LiteralPath $result) { Remove-Item -LiteralPath $result -Force }

$process = Start-Process -FilePath 'C:\Program Files\Autodesk\AutoCAD 2023\acad.exe' `
  -ArgumentList @("`"$fixture`"", '/ld', '"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"', '/p', '<<C3D_Metric>>', '/product', 'C3D', '/language', 'en-US', '/b', "`"$script`"") `
  -WindowStyle Hidden -PassThru

"PID=$($process.Id)"
$deadline = (Get-Date).AddMinutes(6)
while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 2
  $process.Refresh()
}
if (-not $process.HasExited) {
  Stop-Process -Id $process.Id -Force
  throw "La instancia de prueba excedio seis minutos; se cerro solo PID $($process.Id)."
}
if (-not (Test-Path -LiteralPath $result)) { throw 'Civil 3D no produjo verify578.txt' }
Get-Content -LiteralPath $result
if (-not (Select-String -LiteralPath $result -SimpleMatch 'FINISHED' -Quiet)) {
  throw 'La verificacion focal no termino correctamente.'
}
