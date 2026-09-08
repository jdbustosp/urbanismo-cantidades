# Arreglo de FORMATOS NUMERICOS (2026-09-08). Este Excel es es-CO y
# interpreta las cadenas de formato en ESPANOL (coma = decimal, punto =
# miles), tanto en Range.NumberFormat como en PivotField.NumberFormat:
# poner "0.00%" produjo "004%" y "$ #,##0" dejo el VT sin separadores.
# Aqui se DETECTA la convencion con una celda de prueba y se aplican las
# cadenas correctas a: filas de porcentaje de POR EJECUTAR y a los tres
# campos de valor de la dinamica. Ademas se ensanchan las columnas.
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (400 * $t) }
  }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null; $ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $xl.Calculation = -4135
  $ws = $wb.Worksheets.Item("POR EJECUTAR")

  # ---------- 1) detectar la convencion con una celda de prueba ----------
  $t = $ws.Cells.Item(2000, 50)
  $t.Value2 = 1234.5
  $t.NumberFormat = "#,##0.00"
  $txtUS = $t.Text
  $t.NumberFormat = "#.##0,00"
  $txtES = $t.Text
  $t.Clear() | Out-Null
  Write-Output ("prueba 1234,5 -> con cadena US '#,##0.00': '" + $txtUS + "' | con cadena ES '#.##0,00': '" + $txtES + "'")
  $usaES = ($txtES -match '1\.234,50')
  Write-Output ("convencion de NumberFormat en este Excel: " + $(if ($usaES) { "ESPANOL" } else { "INGLES" }))
  $fPct   = if ($usaES) { "0,00%" }     else { "0.00%" }
  $fMoney = if ($usaES) { "`$ #.##0" }  else { "`$ #,##0" }
  $fCant  = if ($usaES) { "#.##0,00###" } else { "#,##0.00###" }

  # ---------- 2) POR EJECUTAR: filas de porcentaje ----------
  $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
  $nivArr = $ws.Range("A3:A$last").Value2
  $desArr = $ws.Range("D3:D$last").Value2
  $umArr  = $ws.Range("E3:E$last").Value2
  $patron = '^(Obras preliminares generales|PLAN DE GESTION URBANA \(PGU\)|COSTOS GESTION AMBIENTAL \(CAR\)|PMT - ETAPA|ADMIN DELEGAD \+ HON \+ REEMB|INTERVENTORIA \+ HON \+ REEMB|ESTUDIOS Y DISE)'
  $n = 0
  for ($i = 1; $i -le $nivArr.GetLength(0); $i++) {
    $r = $i + 2
    $niv = if ($nivArr[$i,1] -ne $null) { [int]$nivArr[$i,1] } else { 0 }
    if ($niv -ne 5) { continue }
    $d = [string]$desArr[$i,1]
    if ($d -notmatch $patron -and [string]$umArr[$i,1] -ne "%") { continue }
    Retry { $ws.Range("F$r" + ":AM$r").NumberFormat = $fPct }    # subetapas
    Retry { $ws.Cells.Item($r, 40).NumberFormat = $fPct }        # CANTIDAD = %
    Retry { $ws.Cells.Item($r, 41).NumberFormat = $fMoney }      # VU = subtotal
    Retry { $ws.Cells.Item($r, 42).NumberFormat = $fMoney }      # VT
    $n++
  }
  Write-Output ("POR EJECUTAR: filas de porcentaje reformateadas: " + $n)

  # ---------- 3) DINAMICA: campos de valor + anchos ----------
  $wsD = $wb.Worksheets.Item("DINAMICA")
  $pt = $wsD.PivotTables("DinamicaPpto")
  Retry { $pt.PivotFields("Suma CANTIDAD").NumberFormat = $fCant }
  Retry { $pt.PivotFields("V. UNITARIO PROM").NumberFormat = $fMoney }
  Retry { $pt.PivotFields("Suma VALOR_TOTAL").NumberFormat = $fMoney }
  # el formato por campo pisa el ";;;" de los capitulos -> re-ocultar
  $rngC = $pt.PivotFields("Suma CANTIDAD").DataRange
  $filaIni = $rngC.Row; $nFilas = $rngC.Rows.Count; $colC = $rngC.Column
  $ocultos = 0; $i = 0
  $niveles = New-Object 'int[]' $nFilas
  for ($k = 0; $k -lt $nFilas; $k++) {
    $niv = 0
    try { $niv = $wsD.Cells.Item(($filaIni + $k), $colC).PivotCell.RowItems.Count } catch { $niv = 0 }
    $niveles[$k] = $niv
  }
  while ($i -lt $nFilas) {
    $niv = $niveles[$i]; $j = $i
    while (($j + 1) -lt $nFilas -and $niveles[$j + 1] -eq $niv) { $j++ }
    $r1 = $filaIni + $i; $r2 = $filaIni + $j
    if ($niv -ne 5) {
      Retry { $wsD.Range($wsD.Cells.Item($r1, $colC), $wsD.Cells.Item($r2, $colC + 1)).NumberFormat = ";;;" }
      $ocultos += ($j - $i + 1)
    }
    $i = $j + 1
  }
  Write-Output ("DINAMICA: filas de capitulo con CANT/VU ocultos: " + $ocultos)
  Retry { $wsD.Columns("A").ColumnWidth = 78 }
  Retry { $wsD.Columns("B").ColumnWidth = 16 }
  Retry { $wsD.Columns("C").ColumnWidth = 18 }
  Retry { $wsD.Columns("D").ColumnWidth = 22 }

  # ---------- 4) verificacion ----------
  $xl.Calculation = -4105
  try { $xl.CalculateFull() } catch {}
  Write-Output "--- control POR EJECUTAR (bloque preliminares) ---"
  for ($r = 7; $r -le 9; $r++) {
    Write-Output ("  [" + $r + "] " + $ws.Cells.Item($r,4).Value2 + " | CANT=" + $ws.Cells.Item($r,40).Text + " | VU=" + $ws.Cells.Item($r,41).Text + " | VT=" + $ws.Cells.Item($r,42).Text)
  }
  Write-Output "--- control DINAMICA (primeras filas) ---"
  for ($k = 0; $k -lt 6; $k++) {
    $r = $filaIni + $k
    Write-Output ("  fila $r n" + $niveles[$k] + " | CANT='" + $wsD.Cells.Item($r,2).Text + "' VU='" + $wsD.Cells.Item($r,3).Text + "' VT='" + $wsD.Cells.Item($r,4).Text + "' | " + $wsD.Cells.Item($r,1).Text)
  }
  # una fila de detalle (nivel 5) para comprobar que SI se ve
  for ($k = 0; $k -lt $nFilas; $k++) {
    if ($niveles[$k] -eq 5) {
      $r = $filaIni + $k
      Write-Output ("  DETALLE fila $r | CANT='" + $wsD.Cells.Item($r,2).Text + "' VU='" + $wsD.Cells.Item($r,3).Text + "' VT='" + $wsD.Cells.Item($r,4).Text + "' | " + $wsD.Cells.Item($r,1).Text)
      break
    }
  }
  Retry { $wb.Save() }
  $ok = $true
  Write-Output "GUARDADO formatos"
} finally {
  if ($wb) { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO" }