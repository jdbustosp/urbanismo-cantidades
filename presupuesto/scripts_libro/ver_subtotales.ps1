param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 25) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 1500 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pD = Retry { $ws.PivotTables("DinamicaPpto") }
  $r1 = $pD.TableRange2.Row
  $rn = $r1 + $pD.TableRange2.Rows.Count - 1
  "encabezados: H='" + (Retry { $ws.Cells.Item(3, 8).Text }) + "' I='" + (Retry { $ws.Cells.Item(3, 9).Text }) +
    "' J='" + (Retry { $ws.Cells.Item(3, 10).Text }) + "' K='" + (Retry { $ws.Cells.Item(3, 11).Text }) + "'"
  $porNivel = @{}
  for ($f = $r1 + 1; $f -lt $rn; $f++) {
    $t = Retry { $ws.Cells.Item($f, 7).Text }
    if ($t -eq "") { continue }
    $niv = [int](Retry { $ws.Cells.Item($f, 7).IndentLevel }) + 1
    if (-not $porNivel.ContainsKey($niv)) { $porNivel[$niv] = $f }
    $listos = $true
    foreach ($k in 1..5) { if (-not $porNivel.ContainsKey($k)) { $listos = $false } }
    if ($listos) { break }
  }
  "=== texto de cada columna de valor por nivel (lo que se VE)"
  foreach ($k in 1..5) {
    $f = $porNivel[$k]
    if (-not $f) { continue }
    $t = Retry { $ws.Cells.Item($f, 7).Text }
    if ($t.Length -gt 36) { $t = $t.Substring(0, 36) }
    "  nivel $k f$f '" + $t + "'"
    foreach ($c in 8..11) {
      $txt = Retry { $ws.Cells.Item($f, $c).Text }
      $v = Retry { $ws.Cells.Item($f, $c).Value2 }
      $nf = Retry { $ws.Cells.Item($f, $c).DisplayFormat.NumberFormat }
      $enc = Retry { $ws.Cells.Item(3, $c).Text }
      "        " + $enc.PadRight(20).Substring(0, 20) + " texto='" + $txt + "'  valor=" +
        $(if ($null -eq $v) { "(nulo)" } else { [string]$v }) + "  formato='" + $nf + "'"
    }
  }
  $t = Retry { $ws.Cells.Item($rn, 7).Text }
  "  total general f$rn '$t'"
  foreach ($c in 8..11) {
    "        " + (Retry { $ws.Cells.Item(3, $c).Text }).PadRight(20).Substring(0, 20) +
      " texto='" + (Retry { $ws.Cells.Item($rn, $c).Text }) + "'"
  }
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
