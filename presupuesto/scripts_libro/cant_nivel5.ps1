param([string]$libro)
$ErrorActionPreference = "Stop"
$ci = [System.Globalization.CultureInfo]::InvariantCulture
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$ok = $false
$FIN = 4000
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pD = $ws.PivotTables("DinamicaPpto")

  # --- 1) sacar CANTIDAD y V. UNITARIO del area de valores de la pivot ---
  $df = $pD.DataFields()
  $quitar = @()
  for ($i = 1; $i -le $df.Count; $i++) {
    $f = $df.Item($i)
    if ($f.SourceName -eq "CANTIDAD" -or $f.SourceName -eq "VR_UNITARIO") { $quitar += $f.Name }
  }
  foreach ($nm in $quitar) {
    Retry { $pD.DataFields($nm).Orientation = 0 }   # xlHidden
    "  quitado del area de valores: $nm"
  }
  Start-Sleep -Seconds 2
  "rango de la pivot ahora: " + $pD.TableRange2.Address()
  $df = $pD.DataFields()
  $s = ""
  for ($i = 1; $i -le $df.Count; $i++) { $s += ($df.Item($i).Name + " | ") }
  "valores que quedan: $s"

  # --- 2) CANTIDAD y V. UNITARIO como columnas propias, solo nivel 5 ---
  # Van FUERA de la pivot: ahi Excel no recorta el formato ni los borra al
  # actualizar. El nivel 5 se reconoce porque el rotulo existe en la
  # columna N5 de la tabla BD (la fuente de la dinamica).
  Retry { $ws.Range("J1:L" + $FIN).Clear() | Out-Null }
  Retry { $ws.Range("J3").Value2 = "CANTIDAD" }
  Retry { $ws.Range("K3").Value2 = "V. UNITARIO" }
  $fK = '=IF($G4="","",IF(SUMIF(BD!$E$2:$E$4000,$G4,BD!$I$2:$I$4000)=0,"",' +
        'SUMIF(BD!$E$2:$E$4000,$G4,BD!$I$2:$I$4000)))'
  $fL = '=IF($J4="","",AVERAGEIF(BD!$E$2:$E$4000,$G4,BD!$J$2:$J$4000))'
  Retry { $ws.Range("J4").Formula = $fK }
  Retry { $ws.Range("K4").Formula = $fL }
  Retry { $ws.Range("J4:K4").Copy($ws.Range("J5:K" + $FIN)) | Out-Null }
  Retry { $ws.Range("J4:J" + $FIN).NumberFormat = "#.##0,00###" }
  Retry { $ws.Range("K4:K" + $FIN).NumberFormat = "$ #.##0" }
  Retry { $ws.Range("J3:K3").Font.Bold = $true }
  $ws.Columns.Item(10).ColumnWidth = 16
  $ws.Columns.Item(11).ColumnWidth = 16
  "columnas J (CANTIDAD) y K (V. UNITARIO) armadas hasta la fila $FIN"

  # NOTA: J y K quedan sin relleno de nivel a proposito: en las filas de
  # subtotal van vacias, y asi se lee de una que la cantidad y el valor
  # unitario SOLO existen en el nivel 5.

  # --- 4) prueba: 3 actualizaciones ---
  for ($v = 1; $v -le 3; $v++) {
    Retry { $pD.PivotCache().Refresh() }
    Start-Sleep -Seconds 2
  }
  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 3
  "actualizado 3 veces"

  $fila2 = 0; $fila5 = 0
  for ($r = 4; $r -le 2000; $r++) {
    $t = $ws.Cells.Item($r, 7).Text
    if ($fila2 -eq 0 -and $t -match '^2\.\d+ ') { $fila2 = $r }
    if ($fila5 -eq 0 -and $t -match '^2\.\d+\.\d+\.\d+\.\d+ ') { $fila5 = $r }
    if ($fila2 -and $fila5) { break }
  }
  foreach ($r in @(4, $fila2, $fila2 + 1, $fila5)) {
    if ($r -eq 0) { continue }
    "  fila $r '" + $ws.Cells.Item($r, 7).Text + "'"
    "      VALOR='" + $ws.Cells.Item($r, 8).Text + "' DESEM='" + $ws.Cells.Item($r, 9).Text +
      "' CANTIDAD='" + $ws.Cells.Item($r, 11).Text + "' V.UNIT='" + $ws.Cells.Item($r, 12).Text + "'"
    $cols = ""
    foreach ($c in 7..11) { $cols += ("" + $ws.Cells.Item($r, $c).DisplayFormat.Interior.Color + " ") }
    "      colores G..K: $cols"
  }
  "reglas CF vivas en la hoja: " + $ws.Cells.FormatConditions.Count
  $wb.Save()
  $ok = $true
  "guardado"
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
