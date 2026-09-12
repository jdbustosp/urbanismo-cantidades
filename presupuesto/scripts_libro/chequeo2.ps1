param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 20) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 1500 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pD = Retry { $ws.PivotTables("DinamicaPpto") }
  Retry { $pD.PivotCache().Refresh() }
  Start-Sleep -Seconds 3
  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 4
  $ultima = $pD.TableRange2.Row + $pD.TableRange2.Rows.Count - 1
  "pivot " + $pD.TableRange2.Address() + " (ultima fila $ultima)"
  # lectura en bloque de la columna de rotulos
  $lab = Retry { $ws.Range("G4:G" + $ultima).Value2 }
  $filas = @{}
  for ($i = 1; $i -le ($ultima - 3); $i++) {
    $t = [string]$lab[$i, 1]
    $fila = $i + 3
    if (-not $filas[1] -and $t -eq "2 ACTIVIDADES POR EJECUTAR") { $filas[1] = $fila }
    if (-not $filas[2] -and $t -eq "2.1 PRELIMINARES") { $filas[2] = $fila }
    if (-not $filas[3] -and $t -eq "2.1.1 OBRAS PRELIMINARES") { $filas[3] = $fila }
    if (-not $filas[4] -and $t -eq "2.1.1.1 OBRAS PRELIMINARES GENERALES") { $filas[4] = $fila }
    if (-not $filas[5] -and $t -like "2.1.1.1.1 *") { $filas[5] = $fila }
  }
  foreach ($k in 1..5) {
    $r = $filas[$k]
    if (-not $r) { "nivel $k : no encontrado"; continue }
    $c = @()
    foreach ($col in 7..11) { $c += (Retry { $ws.Cells.Item($r, $col).DisplayFormat.Interior.Color }) }
    $cant = Retry { $ws.Cells.Item($r, 8).Text }
    $vu = Retry { $ws.Cells.Item($r, 9).Text }
    $val = Retry { $ws.Cells.Item($r, 10).Text }
    "nivel $k f$r '" + [string]$lab[($r - 3), 1] + "'"
    "     colores G..K = " + ($c -join " , ")
    "     CANTIDAD='$cant' V.UNIT='$vu' VALOR='$val'"
  }
  $c = @()
  foreach ($col in 7..11) { $c += (Retry { $ws.Cells.Item($ultima, $col).DisplayFormat.Interior.Color }) }
  "total general f$ultima colores=" + ($c -join " , ") + " CANTIDAD='" + (Retry { $ws.Cells.Item($ultima, 8).Text }) + "'"
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
