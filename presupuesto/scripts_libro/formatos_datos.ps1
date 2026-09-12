param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 25) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 1200 } }
}
# El formato de numero de un campo de datos aplica a TODA su columna,
# subtotales y total general incluidos. Ponerlo aqui (y no como formato de
# celdas) es lo que hace que los subtotales de VALOR_TOTAL y VR DESEM.
# salgan como moneda y no en "General".
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$ok = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pD = Retry { $ws.PivotTables("DinamicaPpto") }
  $pR = Retry { $ws.PivotTables("ResumenEtapas") }
  $fmt = @{
    "Suma CANTIDAD"    = "#.##0,00###"
    "V. UNITARIO PROM" = "`$ #.##0"
    "Suma VALOR_TOTAL" = "`$ #.##0"
    "VR DESEM. FOVIS"  = "`$ #.##0"
  }
  $df = $pD.DataFields()
  for ($i = 1; $i -le $df.Count; $i++) {
    $f = $df.Item($i)
    if ($fmt.ContainsKey($f.Name)) {
      Retry { $f.NumberFormat = $fmt[$f.Name] }
      "  " + $f.Name + " -> " + $fmt[$f.Name]
    }
  }
  $dr = $pR.DataFields()
  for ($i = 1; $i -le $dr.Count; $i++) {
    $f = $dr.Item($i)
    Retry { $f.NumberFormat = "`$ #.##0" }
    "  (resumen) " + $f.Name + " -> `$ #.##0"
  }
  # que no salgan ##### por ancho
  foreach ($p in @(@(1, 44), @(2, 22), @(7, 60), @(8, 16), @(9, 20), @(10, 22), @(11, 22))) {
    Retry { $ws.Columns.Item($p[0]).ColumnWidth = $p[1] }
  }
  "anchos ajustados"
  # El formato de CELDA manda sobre el del campo de datos, asi que se
  # aplica a TODO el cuerpo (subtotales y total general incluidos). Antes
  # solo estaba puesto en las filas de nivel 5 y por eso los subtotales
  # salian en "General" (1,58873E+11). El ocultamiento de CANTIDAD y
  # V.UNITARIO en los subtotales lo hace aparte el formato condicional.
  $r1 = $pD.TableRange2.Row
  $rn = $r1 + $pD.TableRange2.Rows.Count - 1
  Retry { $ws.Range($ws.Cells.Item($r1 + 1, 8), $ws.Cells.Item($rn, 8)).NumberFormat = "#.##0,00###" }
  Retry { $ws.Range($ws.Cells.Item($r1 + 1, 9), $ws.Cells.Item($rn, 11)).NumberFormat = "`$ #.##0" }
  $s1 = $pR.TableRange2.Row
  $sn = $s1 + $pR.TableRange2.Rows.Count - 1
  Retry { $ws.Range($ws.Cells.Item($s1 + 1, 2), $ws.Cells.Item($sn, 2)).NumberFormat = "`$ #.##0" }
  "formato de moneda aplicado a TODO el cuerpo de las dos dinamicas"
  $wb.Save()
  $ok = $true
  "guardado"
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
