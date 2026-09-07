# Precios para la desagregacion pluvial (2026-09-07). Criterio ALTO:
#  - Instalacion concreto = 2x la instalacion PVC flexible del mismo
#    diametro (equipo pesado); PVC 20"/27" interpolada de la serie 3.558/pulg.
#  - Suministro = (65% del APU Hex banda mas superficial - instalacion) x 6 m
#    (el APU Hex incluia la zanja completa; 65% > el 46% que da la
#    descomposicion real del sanitario => queda deliberadamente alto).
#  - PVC flexible 20"/27" suministro interpolado de la serie 18-24-30 y
#    redondeado hacia arriba.
# Incluye BACKUP del libro antes de tocarlo. Idempotente (no duplica).
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$bkdir = "C:\Users\juanbusper\Streaming de Google Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\MEMORIAS\V3\PROYECTO_URBANISMO_GENERAL\BACKUPS"
$bk = Join-Path $bkdir "urbanismo maipore_backup_antes_pluvial42_20260907.xlsx"
if (-not (Test-Path $bk)) { Copy-Item $libro $bk }
Write-Output ("backup: " + $bk)

$catPLU = "RED DE ALCANTARILLADO PLUVIAL"
$catCON = "SUMINISTRO E INSTALACIÓN RED DE ALCANTARILLADO CONCRETO"
$nuevos = @(
  @($catPLU, 'Suministro tubería PVC flexible Ø20"', "UN", 2900000),
  @($catPLU, 'Suministro tubería PVC flexible Ø27"', "UN", 5000000),
  @($catPLU, 'Instalación tubería PVC flexible Ø20"', "ML", 72000),
  @($catPLU, 'Instalación tubería PVC flexible Ø27"', "ML", 97000),
  @($catCON, 'Suministro tubería en concreto CSR Ø12"', "UN", 1220000),
  @($catCON, 'Suministro tubería en concreto CSR Ø14"', "UN", 1370000),
  @($catCON, 'Suministro tubería en concreto CSR Ø18"', "UN", 2900000),
  @($catCON, 'Suministro tubería en concreto CSR Ø20"', "UN", 3120000),
  @($catCON, 'Suministro tubería en concreto CSR Ø24"', "UN", 3700000),
  @($catCON, 'Suministro tubería en concreto CCR Ø24"', "UN", 3030000),
  @($catCON, 'Suministro tubería en concreto CCR Ø27"', "UN", 4720000),
  @($catCON, 'Suministro tubería en concreto CCR Ø30"', "UN", 4960000),
  @($catCON, 'Suministro tubería en concreto CCR Ø36"', "UN", 6470000),
  @($catCON, 'Suministro tubería en concreto CCR Ø40"', "UN", 7620000),
  @($catCON, 'Suministro tubería en concreto CER Ø12"', "UN", 2060000),
  @($catCON, 'Suministro tubería en concreto CER Ø18"', "UN", 3050000),
  @($catCON, 'Instalación tubería en concreto CSR Ø12"', "ML", 86000),
  @($catCON, 'Instalación tubería en concreto CSR Ø14"', "ML", 100000),
  @($catCON, 'Instalación tubería en concreto CSR Ø18"', "ML", 129000),
  @($catCON, 'Instalación tubería en concreto CSR Ø20"', "ML", 143000),
  @($catCON, 'Instalación tubería en concreto CSR Ø24"', "ML", 171000),
  @($catCON, 'Instalación tubería en concreto CCR Ø24"', "ML", 171000),
  @($catCON, 'Instalación tubería en concreto CCR Ø27"', "ML", 193000),
  @($catCON, 'Instalación tubería en concreto CCR Ø30"', "ML", 214000),
  @($catCON, 'Instalación tubería en concreto CCR Ø36"', "ML", 257000),
  @($catCON, 'Instalación tubería en concreto CCR Ø40"', "ML", 285000),
  @($catCON, 'Instalación tubería en concreto CER Ø12"', "ML", 86000),
  @($catCON, 'Instalación tubería en concreto CER Ø18"', "ML", 129000)
)
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (300 * $t) }
  }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $xl.Calculation = -4135
  $ws = $wb.Worksheets.Item("PRECIOS_UNITARIOS")
  $last = $ws.Cells.Item($ws.Rows.Count, 2).End(-4162).Row
  Write-Output ("PU ultima fila: " + $last)
  $desc = $ws.Range("B2:B$last").Value2
  $ya = @{}
  for ($i = 1; $i -le $desc.GetLength(0); $i++) { $v = $desc[$i, 1]; if ($v) { $ya[[string]$v] = $true } }
  $agregados = 0
  $r = $last
  foreach ($n in $nuevos) {
    if ($ya.ContainsKey([string]$n[1])) { Write-Output ("  ya existe: " + $n[1]); continue }
    $r++
    Retry { $ws.Cells.Item($r, 1).Value2 = $n[0] }
    Retry { $ws.Cells.Item($r, 2).Value2 = $n[1] }
    Retry { $ws.Cells.Item($r, 3).Value2 = $n[2] }
    Retry { $ws.Cells.Item($r, 4).Value2 = [double]$n[3] }
    $agregados++
  }
  Write-Output ("precios agregados: " + $agregados + " (filas " + ($last + 1) + ".." + $r + ")")
  $xl.Calculation = -4105
  Retry { $wb.Save() }
  Write-Output "GUARDADO precios"
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}