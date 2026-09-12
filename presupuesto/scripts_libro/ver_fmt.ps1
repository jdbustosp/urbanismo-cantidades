param([string]$libro, [int]$Veces = 3)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  "abre sin reparar | hojas=" + $wb.Worksheets.Count + " queries=" + $wb.Queries.Count
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pD = $ws.PivotTables("DinamicaPpto")
  $pR = $ws.PivotTables("ResumenEtapas")
  for ($v = 1; $v -le $Veces; $v++) {
    Retry { $pD.PivotCache().Refresh() }
    Retry { $pR.PivotCache().Refresh() }
    Start-Sleep -Seconds 2
  }
  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 3
  "actualizado $Veces veces | DinamicaPpto " + $pD.TableRange2.Address() + " | ResumenEtapas " + $pR.TableRange2.Address()
  "fila 3: " + $ws.Range("G3").Text + " | " + $ws.Range("H3").Text + " | " + $ws.Range("I3").Text +
    " | " + $ws.Range("J3").Text + " | " + $ws.Range("K3").Text
  $f = @{}
  for ($r = 4; $r -le 1700; $r++) {
    $t = $ws.Cells.Item($r, 7).Text
    if (-not $f[1] -and $t -match '^2 ') { $f[1] = $r }
    if (-not $f[2] -and $t -match '^2\.\d+ ') { $f[2] = $r }
    if (-not $f[3] -and $t -match '^2\.\d+\.\d+ ') { $f[3] = $r }
    if (-not $f[4] -and $t -match '^2\.\d+\.\d+\.\d+ ') { $f[4] = $r }
    if (-not $f[5] -and $t -match '^2\.\d+\.\d+\.\d+\.\d+ ') { $f[5] = $r }
  }
  "=== DinamicaPpto"
  foreach ($k in 1..5) {
    $r = $f[$k]
    if (-not $r) { continue }
    $cols = ""
    foreach ($c in 7..11) { $cols += ("" + $ws.Cells.Item($r, $c).DisplayFormat.Interior.Color + " ") }
    "  nivel $k f$r '" + $ws.Cells.Item($r, 7).Text.PadRight(44).Substring(0, 44) + "'"
    "      colores: $cols"
    "      CANT='" + $ws.Cells.Item($r, 8).Text + "' VU='" + $ws.Cells.Item($r, 9).Text +
      "' VALOR='" + $ws.Cells.Item($r, 10).Text + "'"
  }
  $ultima = $pD.TableRange2.Row + $pD.TableRange2.Rows.Count - 1
  "  total general f$ultima '" + $ws.Cells.Item($ultima, 7).Text + "' CANT='" +
    $ws.Cells.Item($ultima, 8).Text + "' VALOR='" + $ws.Cells.Item($ultima, 10).Text + "'"
  "=== ResumenEtapas"
  foreach ($r in 4..9) {
    "  f$r '" + $ws.Cells.Item($r, 1).Text.PadRight(38).Substring(0, 38) + "' A=" +
      $ws.Cells.Item($r, 1).DisplayFormat.Interior.Color + " B=" +
      $ws.Cells.Item($r, 2).DisplayFormat.Interior.Color
  }
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }