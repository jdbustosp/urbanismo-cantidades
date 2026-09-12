param([string]$libro, [switch]$Actualizar)
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
  $pR = Retry { $ws.PivotTables("ResumenEtapas") }
  if ($Actualizar) {
    Retry { $pD.PivotCache().Refresh() }
    Retry { $pR.PivotCache().Refresh() }
    Start-Sleep -Seconds 3
    $xl.CalculateFullRebuild(); Start-Sleep -Seconds 4
    "== ESTADO TRAS ACTUALIZAR =="
  } else {
    "== ESTADO AL ABRIR, SIN ACTUALIZAR (lo que ve el usuario) =="
  }

  # ---------- DinamicaPpto ----------
  $r1 = $pD.TableRange2.Row
  $rn = $r1 + $pD.TableRange2.Rows.Count - 1
  "DinamicaPpto " + $pD.TableRange2.Address()
  $lab = Retry { $ws.Range("G" + ($r1 + 1) + ":G" + $rn).Value2 }
  $muestras = @{}
  for ($i = 1; $i -le ($rn - $r1); $i++) {
    # un rango de una sola columna puede volver como arreglo de 1 o 2
    # dimensiones segun como lo entregue Excel
    $t = ""
    if ($lab -is [array]) {
      if ($lab.Rank -eq 2) { $t = [string]($lab.GetValue($i, 1)) }
      else { $t = [string]($lab.GetValue($i - 1)) }
    }
    $fila = $r1 + $i
    if ($t -eq "") { continue }
    $puntos = ($t -split ' ')[0]
    $np = ([regex]::Matches($puntos, '\.')).Count
    if ($puntos -match '^\d+(\.\d+)*$') {
      $niv = $np + 1
      if (-not $muestras[$niv]) { $muestras[$niv] = @{ Fila = $fila; Texto = $t } }
    }
  }
  foreach ($k in 1..5) {
    if (-not $muestras[$k]) { "   nivel $k : sin muestra"; continue }
    $f = $muestras[$k].Fila
    $col = @()
    foreach ($c in 7..11) { $col += (Retry { $ws.Cells.Item($f, $c).DisplayFormat.Interior.Color }) }
    $txt = $muestras[$k].Texto
    if ($txt.Length -gt 40) { $txt = $txt.Substring(0, 40) }
    $iguales = (($col | Select-Object -Unique).Count -eq 1)
    "   nivel $k f$f '" + $txt + "'"
    "        G..K = " + ($col -join " , ") + "   -> " + $(if ($iguales) { "TODAS IGUALES" } else { "*** SOLO LA PRIMERA ***" })
    "        CANT='" + (Retry { $ws.Cells.Item($f, 8).Text }) + "' VU='" + (Retry { $ws.Cells.Item($f, 9).Text }) + "'"
  }
  $col = @()
  foreach ($c in 7..11) { $col += (Retry { $ws.Cells.Item($rn, $c).DisplayFormat.Interior.Color }) }
  "   total general f$rn = " + ($col -join " , ") + " CANT='" + (Retry { $ws.Cells.Item($rn, 8).Text }) + "'"

  # ---------- ResumenEtapas ----------
  $s1 = $pR.TableRange2.Row
  $sn = $s1 + $pR.TableRange2.Rows.Count - 1
  "ResumenEtapas " + $pR.TableRange2.Address()
  foreach ($f in ($s1 + 1)..($s1 + 6)) {
    $a = Retry { $ws.Cells.Item($f, 1).DisplayFormat.Interior.Color }
    $b = Retry { $ws.Cells.Item($f, 2).DisplayFormat.Interior.Color }
    $t = Retry { $ws.Cells.Item($f, 1).Text }
    if ($t.Length -gt 38) { $t = $t.Substring(0, 38) }
    "   f$f '" + $t + "'  A=$a B=$b " + $(if ($a -eq $b) { "IGUALES" } else { "*** DISTINTAS ***" })
  }
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
