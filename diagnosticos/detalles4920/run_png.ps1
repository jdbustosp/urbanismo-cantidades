# PNG de ventanas del plano de detalles con AutoCAD COMPLETO (PNGOUT necesita
# vista grafica). Abre una COPIA; el original no se toca.
$ErrorActionPreference = 'Stop'
$Lab = "C:\Users\juanbusper\Documents\URBANISMO\work\claude_20260910_detalles"
$Src = "C:\Users\juanbusper\Streaming de Google Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\MEMORIAS\V3\PROYECTO_URBANISMO_GENERAL\10_RECORD\6. Andenes\Detalles_Rampas.dwg"
if ($env:URB_SRC_DWG) { $Src = $env:URB_SRC_DWG }
$lsp = if ($env:URB_PNG_LSP) { $env:URB_PNG_LSP } else { 'png.lsp' }
$dwg = Join-Path $Lab 'png_copia.dwg'
$result = Join-Path $Lab 'png_log.txt'
if (Test-Path $result) { Remove-Item $result }
Copy-Item -LiteralPath $Src -Destination $dwg -Force
Remove-Item "$dwg.dwl","$dwg.dwl2" -Force -ErrorAction SilentlyContinue
$scr = Join-Path $Lab 'png.scr'
Set-Content -LiteralPath $scr -Encoding ASCII -Value @(
  "(setenv `"URB_TEST_LAB`" `"$($Lab.Replace('\','/'))`")",
  "(load (strcat (getenv `"URB_TEST_LAB`") `"/$lsp`"))",
  '(command "_.QUIT" "_N")'
)
$p = Start-Process -FilePath "C:\Program Files\Autodesk\AutoCAD 2023\acad.exe" `
  -ArgumentList @("`"$dwg`"", '/ld', '"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"', '/p', '"<<C3D_Metric>>"', '/product', 'C3D', '/language', 'en-US', '/b', "`"$scr`"") `
  -PassThru
Start-Process -FilePath "powershell" -WindowStyle Hidden `
  -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',
    "C:\Users\juanbusper\Documents\URBANISMO\work\audit_mt\domar_dialogos.ps1",'-DuracionSeg','200')
$t0 = Get-Date
while (((Get-Date) - $t0).TotalSeconds -lt 200) {
  if ((Test-Path $result) -and (Select-String -Path $result -Pattern "DONE" -Quiet)) { break }
  if ($p.HasExited) { Start-Sleep -Seconds 3; break }
  Start-Sleep -Seconds 4
}
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
Remove-Item "$dwg.dwl","$dwg.dwl2" -Force -ErrorAction SilentlyContinue
if (Test-Path $result) { Get-Content $result } else { "SIN RESULTADO" }
