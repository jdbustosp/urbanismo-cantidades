# Corre la sonda probe.scr sobre cada DWG copiado, en serie, con accoreconsole
# (headless nativo, sin dialogos). Log de consola por archivo en probe_<n>.log.
$ErrorActionPreference = "Continue"
$work = "C:\Users\jdbus\Documents\URBANISMO\work\lote_redes"
$core = "C:\Program Files\Autodesk\AutoCAD 2025\accoreconsole.exe"
$files = @("SRC_ACUEDUCTO.dwg", "SRC_PLUVIAL.dwg", "SRC_SERIE1.dwg", "SRC_SERIE6.dwg", "SRC_MASTER.dwg")
foreach ($f in $files) {
  $dwg = Join-Path $work $f
  $log = Join-Path $work ("corelog_" + $f.Replace(".dwg", ".txt"))
  Write-Output ("--- $f ---")
  # limpiar locks de corridas previas
  Get-ChildItem $work -Filter ($f.Replace(".dwg", ".dwl*")) -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  & $core /i $dwg /s (Join-Path $work "probe.scr") /l en-US > $log 2>&1
  Write-Output ("exit=" + $LASTEXITCODE)
}
Write-Output "PROBES-TERMINADOS"
