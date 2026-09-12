param([string]$libro, [int]$Veces = 3, [switch]$Guardar)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$ok = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  "abre sin reparar | hojas=" + $wb.Worksheets.Count + " queries=" + $wb.Queries.Count
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pR = $ws.PivotTables("ResumenEtapas")
  $pD = $ws.PivotTables("DinamicaPpto")
  for ($v = 1; $v -le $Veces; $v++) {
    Retry { $pD.PivotCache().Refresh() }
    Retry { $pR.PivotCache().Refresh() }
    Start-Sleep -Seconds 2
  }
  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 3
  "actualizado $Veces veces"
  "ResumenEtapas " + $pR.TableRange2.Address() + " | DinamicaPpto " + $pD.TableRange2.Address()
  "columnas visibles fila 3: " + $ws.Range("A3").Text + " | " + $ws.Range("B3").Text +
    " || " + $ws.Range("G3").Text + " | " + $ws.Range("H3").Text + " | " + $ws.Range("I3").Text +
    " | " + $ws.Range("J3").Text + " | " + $ws.Range("K3").Text
  # muestras por nivel en el POR EJECUTAR
  $f = @{}
  for ($r = 4; $r -le 1700; $r++) {
    $t = $ws.Cells.Item($r, 7).Text
    if (-not $f[1] -and $t -match '^2 ') { $f[1] = $r }
    if (-not $f[2] -and $t -match '^2\.\d+ ') { $f[2] = $r }
    if (-not $f[3] -and $t -match '^2\.\d+\.\d+ ') { $f[3] = $r }
    if (-not $f[4] -and $t -match '^2\.\d+\.\d+\.\d+ ') { $f[4] = $r }
    if (-not $f[5] -and $t -match '^2\.\d+\.\d+\.\d+\.\d+ ') { $f[5] = $r }
  }
  "=== DinamicaPpto por nivel"
  foreach ($k in 1..5) {
    $r = $f[$k]
    if (-not $r) { continue }
    $cols = ""
    foreach ($c in 7..11) { $cols += ("" + $ws.Cells.Item($r, $c).DisplayFormat.Interior.Color + " ") }
    "  nivel $k (fila $r) '" + $ws.Cells.Item($r, 7).Text + "'"
    "      colores G..K: $cols"
    "      CANTIDAD='" + $ws.Cells.Item($r, 10).Text + "'  V.UNIT='" + $ws.Cells.Item($r, 11).Text +
      "'  VALOR='" + $ws.Cells.Item($r, 8).Text + "'"
  }
  "=== ResumenEtapas (4 niveles)"
  foreach ($r in 4..9) {
    "  fila $r '" + $ws.Cells.Item($r, 1).Text + "' colores A,B: " +
      $ws.Cells.Item($r, 1).DisplayFormat.Interior.Color + " " +
      $ws.Cells.Item($r, 2).DisplayFormat.Interior.Color + "  VT=" + $ws.Cells.Item($r, 2).Text
  }
  "=== columnas auxiliares"
  "  C:F vacias = " + [string]($ws.Range("C1:F6000").Cells.Count -eq
    ($ws.Range("C1:F6000").SpecialCells(4).Cells.Count))
  "  L:M vacias = " + [string]($ws.Application.WorksheetFunction.CountA($ws.Range("L1:M6000")) -eq 0)
  "  ninguna columna oculta: " + [string](-not ($ws.Columns.Item(3).Hidden -or $ws.Columns.Item(4).Hidden -or
     $ws.Columns.Item(5).Hidden -or $ws.Columns.Item(6).Hidden -or $ws.Columns.Item(12).Hidden -or
     $ws.Columns.Item(13).Hidden))
  if ($Guardar) { $wb.Save(); $ok = $true; "guardado" }
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
