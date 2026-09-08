# Verificacion post-cambios 2026-09-08 (solo lectura, cierra sin guardar)
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = $wb.Worksheets.Item("POR EJECUTAR")
  Write-Output "=== POR EJECUTAR: bloque de preliminares (filas 7-16) ==="
  for ($r = 5; $r -le 17; $r++) {
    $niv = $ws.Cells.Item($r,1).Value2
    $cod = $ws.Cells.Item($r,3).Text
    $d = $ws.Cells.Item($r,4).Value2
    $um = $ws.Cells.Item($r,5).Value2
    $cant = $ws.Cells.Item($r,40).Text
    $vu = $ws.Cells.Item($r,41).Text
    $vt = $ws.Cells.Item($r,42).Text
    Write-Output ("[{0}] n{1} {2,-12} {3,-42} {4,-3} | CANT={5,-8} | VU={6,-18} | VT={7}" -f $r,$niv,$cod,$d,$um,$cant,$vu,$vt)
  }
  Write-Output ""
  Write-Output "=== formulas de control ==="
  Write-Output ("VU preliminares ETAPA 01 (AO7): " + $ws.Cells.Item(7,41).Formula)
  Write-Output ("VU preliminares GENERAL  (AO16): " + $ws.Cells.Item(16,41).Formula)
  # PGU etapa 01
  $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
  $de = $ws.Range("D3:D$last").Value2
  for ($i = 1; $i -le $de.GetLength(0); $i++) {
    $d = [string]$de[$i,1]
    if ($d -match 'PLAN DE GESTION URBANA \(PGU\) ETAPA 01' -or $d -match 'ESTUDIOS Y DISE.OS GENERAL') {
      $r = $i + 2
      Write-Output ("VU " + $d + " (fila " + $r + "): " + $ws.Cells.Item($r,41).Formula)
      Write-Output ("     CANT=" + $ws.Cells.Item($r,40).Text + " VU=" + $ws.Cells.Item($r,41).Text + " VT=" + $ws.Cells.Item($r,42).Text)
    }
  }
  Write-Output ""
  Write-Output "=== totales de control ==="
  Write-Output ("ultima fila: " + $last)
  $nv = $ws.Range("A3:A$last").Value2
  for ($i = 1; $i -le $nv.GetLength(0); $i++) {
    $niv = if ($nv[$i,1] -ne $null) { [int]$nv[$i,1] } else { 0 }
    if ($niv -eq 1) {
      $r = $i + 2
      Write-Output ("  [" + $r + "] " + $ws.Cells.Item($r,4).Value2 + " = " + $ws.Cells.Item($r,42).Text)
    }
  }

  Write-Output ""
  Write-Output "=== DINAMICA: muestra de filas (formato y color) ==="
  $wsD = $wb.Worksheets.Item("DINAMICA")
  $pt = $wsD.PivotTables("DinamicaPpto")
  $rngC = $pt.PivotFields("Suma CANTIDAD").DataRange
  $ini = $rngC.Row
  for ($k = 0; $k -lt [math]::Min(20, $rngC.Rows.Count); $k++) {
    $r = $ini + $k
    $niv = 0
    try { $niv = $wsD.Cells.Item($r, $rngC.Column).PivotCell.RowItems.Count } catch {}
    $fmt = $wsD.Cells.Item($r, $rngC.Column).NumberFormat
    $col = $wsD.Cells.Item($r, 1).Interior.Color
    Write-Output ("  fila {0} n{1} color={2,-9} fmtCANT='{3}' | CANT='{4}' VU='{5}' VT='{6}' | {7}" -f $r,$niv,$col,$fmt,$wsD.Cells.Item($r,2).Text,$wsD.Cells.Item($r,3).Text,$wsD.Cells.Item($r,4).Text,$wsD.Cells.Item($r,1).Text)
  }
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}