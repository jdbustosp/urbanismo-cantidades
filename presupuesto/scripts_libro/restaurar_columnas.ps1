param([string]$libro)
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
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pD = $ws.PivotTables("DinamicaPpto")

  # 1) fuera las columnas de formula: vuelven a la dinamica
  Retry { $ws.Range("J1:L4000").Clear() | Out-Null }
  Retry { $ws.Range("J1:L4000").FormatConditions.Delete() }
  "columnas J:L limpias"

  # 2) CANTIDAD y V. UNITARIO de vuelta al area de valores, en su orden
  $cant = $pD.PivotFields("CANTIDAD")
  Retry { $cant.Orientation = 4 }          # xlDataField
  Retry { $cant.Function = -4157 }         # xlSum
  Retry { $cant.Name = "Suma CANTIDAD" }
  Retry { $cant.NumberFormat = "#.##0,00###" }
  $vu = $pD.PivotFields("VR_UNITARIO")
  Retry { $vu.Orientation = 4 }
  Retry { $vu.Function = -4106 }           # xlAverage
  Retry { $vu.Name = "V. UNITARIO PROM" }
  Retry { $vu.NumberFormat = "$ #.##0" }
  # orden: CANTIDAD, V. UNITARIO, VALOR_TOTAL, VR DESEM. FOVIS
  Retry { $pD.DataFields("Suma CANTIDAD").Position = 1 }
  Retry { $pD.DataFields("V. UNITARIO PROM").Position = 2 }
  Retry { $pD.DataFields("Suma VALOR_TOTAL").Position = 3 }
  Retry { $pD.DataFields("VR DESEM. FOVIS").Position = 4 }
  Start-Sleep -Seconds 2
  $df = $pD.DataFields()
  $t = ""
  for ($i = 1; $i -le $df.Count; $i++) { $t += ($i.ToString() + "=" + $df.Item($i).Name + "  ") }
  "valores: $t"
  "rango: " + $pD.TableRange2.Address()
  "fila 3: " + $ws.Range("G3").Text + " | " + $ws.Range("H3").Text + " | " + $ws.Range("I3").Text +
    " | " + $ws.Range("J3").Text + " | " + $ws.Range("K3").Text
  # 3) que la pivot conserve sus formatos al actualizar
  foreach ($p in @($pD, $ws.PivotTables("ResumenEtapas"))) {
    Retry { $p.PreserveFormatting = $true }
    Retry { $p.HasAutoFormat = $false }
  }
  $wb.Save()
  $ok = $true
  "guardado"
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}