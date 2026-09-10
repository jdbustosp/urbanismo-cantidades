# E2E con AutoCAD/Civil 3D completo (ActiveX real).
$ErrorActionPreference = 'Stop'
$Lab = "C:\Users\juanbusper\Documents\URBANISMO\work\claude_20260910_bloques"
$Repo = "C:\Users\juanbusper\Streaming de Google Drive\Mi unidad\VARIOS\CLAUDE\proyectos\URBANISMO EXTERNO"
$result = Join-Path $Lab "rampav.txt"
if (Test-Path $result) { Remove-Item $result }
$dwg = Join-Path $Lab 'e2erv.dwg'
Copy-Item -LiteralPath "C:\Users\juanbusper\Documents\URBANISMO\work\claude_20260908_anden_contenedor\fixture.dwg" -Destination $dwg -Force
Remove-Item "$dwg.dwl","$dwg.dwl2" -Force -ErrorAction SilentlyContinue

$scr = Join-Path $Lab 'e2erv.scr'
Set-Content -LiteralPath $scr -Encoding ASCII -Value @(
  "(setenv `"URB_TEST_LAB`" `"$($Lab.Replace('\','/'))`")",
  "(setenv `"URB_REPO`" `"$($Repo.Replace('\','/'))`")",
  '(load (strcat (getenv "URB_TEST_LAB") "/e2e_rampav.lsp"))',
  '(command "_.QUIT" "_Y")'
)

$p = Start-Process -FilePath "C:\Program Files\Autodesk\AutoCAD 2023\acad.exe" `
  -ArgumentList @("`"$dwg`"", '/ld', '"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"', '/p', '"<<C3D_Metric>>"', '/product', 'C3D', '/language', 'en-US', '/b', "`"$scr`"") `
  -WindowStyle Minimized -PassThru
Write-Output "AutoCAD headless PID=$($p.Id)"
Start-Process -FilePath "powershell" -WindowStyle Hidden `
  -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',
    "C:\Users\juanbusper\Documents\URBANISMO\work\audit_mt\domar_dialogos.ps1",'-DuracionSeg','240')

$t0 = Get-Date
while (((Get-Date) - $t0).TotalSeconds -lt 240) {
  if ((Test-Path $result) -and (Select-String -Path $result -Pattern "DONE" -Quiet)) { break }
  if ($p.HasExited) { Start-Sleep -Seconds 3; break }
  Start-Sleep -Seconds 5
}
if (-not $p.HasExited) {
  Write-Output "cerrando el PID de prueba $($p.Id)"
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}
Remove-Item "$dwg.dwl","$dwg.dwl2" -Force -ErrorAction SilentlyContinue
if (Test-Path $result) { Get-Content $result } else { Write-Output "SIN RESULTADO" }
