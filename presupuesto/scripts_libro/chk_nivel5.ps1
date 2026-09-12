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
  # tres filas de nivel 5 del ramo POR EJECUTAR (rotulo con codigo 2.x.x.x.x)
  # y tres del ramo EJECUTADO (rotulo sin codigo), para ver la diferencia
  $pe = @(); $ej = @()
  for ($f = $r1 + 1; $f -lt $rn; $f++) {
    $t = Retry { $ws.Cells.Item($f, 7).Text }
    if ($t -eq "") { continue }
    $niv = [int](Retry { $ws.Cells.Item($f, 7).IndentLevel }) + 1
    if ($niv -ne 5) { continue }
    if ($t -match '^\d+\.\d+\.\d+\.\d+\.\d+ ') { if ($pe.Count -lt 3) { $pe += $f } }
    else { if ($ej.Count -lt 3) { $ej += $f } }
    if ($pe.Count -ge 3 -and $ej.Count -ge 3) { break }
  }
  "=== nivel 5 del ramo POR EJECUTAR (tiene que mostrar cantidad)"
  foreach ($f in $pe) {
    "  f$f '" + (Retry { $ws.Cells.Item($f, 7).Text }).Substring(0, 40) + "'"
    "      CANT='" + (Retry { $ws.Cells.Item($f, 8).Text }) + "'  VU='" +
      (Retry { $ws.Cells.Item($f, 9).Text }) + "'  VALOR='" + (Retry { $ws.Cells.Item($f, 10).Text }) + "'"
  }
  "=== nivel 5 del ramo EJECUTADO (en la fuente no hay cantidad)"
  foreach ($f in $ej) {
    $vc = Retry { $ws.Cells.Item($f, 8).Value2 }
    "  f$f '" + (Retry { $ws.Cells.Item($f, 7).Text }) + "'  valor crudo de CANTIDAD = " +
      $(if ($null -eq $vc) { "(vacio en la fuente)" } else { [string]$vc }) +
      "  VALOR='" + (Retry { $ws.Cells.Item($f, 10).Text }) + "'"
  }
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
