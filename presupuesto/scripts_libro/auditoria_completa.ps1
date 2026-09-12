param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 25) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 1500 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$fallos = 0
function Chk($nombre, $ok, $detalle) {
  if ($ok) { "OK    $nombre | $detalle" } else { $script:fallos++; "FALLO $nombre | $detalle" }
}
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  Chk "abre sin reparar" ($wb.Worksheets.Count -ge 12) ($wb.Worksheets.Count.ToString() + " hojas, " + $wb.Queries.Count + " queries")
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pD = Retry { $ws.PivotTables("DinamicaPpto") }
  $pR = Retry { $ws.PivotTables("ResumenEtapas") }

  # orden de las columnas
  $cab = @()
  foreach ($c in 7..11) { $cab += (Retry { $ws.Cells.Item(3, $c).Text }) }
  Chk "columnas en su orden" (($cab[1] -like "*CANTIDAD*") -and ($cab[2] -like "*UNITARIO*") -and
    ($cab[3] -like "*VALOR*") -and ($cab[4] -like "*DESEM*")) ($cab -join " | ")

  # muestras: 3 filas por nivel
  $r1 = $pD.TableRange2.Row
  $rn = $r1 + $pD.TableRange2.Rows.Count - 1
  $porNivel = @{}
  for ($f = $r1 + 1; $f -lt $rn; $f++) {
    $t = Retry { $ws.Cells.Item($f, 7).Text }
    if ($t -eq "") { continue }
    $niv = [int](Retry { $ws.Cells.Item($f, 7).IndentLevel }) + 1
    if (-not $porNivel.ContainsKey($niv)) { $porNivel[$niv] = @() }
    if ($porNivel[$niv].Count -lt 3) { $porNivel[$niv] += $f }
    $listos = $true
    foreach ($k in 1..5) { if (-not $porNivel.ContainsKey($k) -or $porNivel[$k].Count -lt 3) { $listos = $false } }
    if ($listos) { break }
  }
  foreach ($k in 1..5) {
    foreach ($f in $porNivel[$k]) {
      $col = @()
      foreach ($c in 7..11) { $col += (Retry { $ws.Cells.Item($f, $c).DisplayFormat.Interior.Color }) }
      $iguales = (($col | Select-Object -Unique).Count -eq 1)
      $cant = Retry { $ws.Cells.Item($f, 8).Text }
      $t = Retry { $ws.Cells.Item($f, 7).Text }
      if ($t.Length -gt 34) { $t = $t.Substring(0, 34) }
      if ($k -lt 5) {
        Chk "n$k f$f color en las 5 columnas" $iguales ($t + " -> " + ($col[0]))
        Chk "n$k f$f cantidad oculta" ($cant -eq "") ("'" + $cant + "'")
      } else {
        Chk "n5 f$f sin color" (($col | Select-Object -Unique).Count -eq 1 -and $col[0] -eq 16777215) $t
        Chk "n5 f$f cantidad visible" ($cant -ne "") ("'" + $cant + "'")
      }
    }
  }
  # que los 4 niveles tengan colores DISTINTOS entre si
  $cn = @()
  foreach ($k in 1..4) { $cn += (Retry { $ws.Cells.Item($porNivel[$k][0], 9).DisplayFormat.Interior.Color }) }
  Chk "los 4 niveles con color distinto en la columna de valor" (($cn | Select-Object -Unique).Count -eq 4) ($cn -join ",")
  # total general
  $col = @()
  foreach ($c in 7..11) { $col += (Retry { $ws.Cells.Item($rn, $c).DisplayFormat.Interior.Color }) }
  Chk "total general sin color" (($col | Select-Object -Unique).Count -eq 1 -and $col[0] -eq 16777215) ($col[0])
  Chk "total general con cantidad oculta" ((Retry { $ws.Cells.Item($rn, 8).Text }) -eq "") "ok"

  # ResumenEtapas
  $s1 = $pR.TableRange2.Row
  $sn = $s1 + $pR.TableRange2.Rows.Count - 1
  $porNivelR = @{}
  for ($f = $s1 + 1; $f -lt $sn; $f++) {
    $t = Retry { $ws.Cells.Item($f, 1).Text }
    if ($t -eq "") { continue }
    $niv = [int](Retry { $ws.Cells.Item($f, 1).IndentLevel }) + 1
    if (-not $porNivelR.ContainsKey($niv)) { $porNivelR[$niv] = @() }
    if ($porNivelR[$niv].Count -lt 2) { $porNivelR[$niv] += $f }
    $listos = $true
    foreach ($k in 1..4) { if (-not $porNivelR.ContainsKey($k) -or $porNivelR[$k].Count -lt 2) { $listos = $false } }
    if ($listos) { break }
  }
  foreach ($k in 1..4) {
    foreach ($f in $porNivelR[$k]) {
      $a = Retry { $ws.Cells.Item($f, 1).DisplayFormat.Interior.Color }
      $b = Retry { $ws.Cells.Item($f, 2).DisplayFormat.Interior.Color }
      $t = Retry { $ws.Cells.Item($f, 1).Text }
      if ($k -lt 4) {
        Chk "resumen n$k f$f color en A y B" ($a -eq $b -and $a -ne 16777215) ($t + " -> " + $a)
      } else {
        Chk "resumen n4 f$f SIN color" ($a -eq 16777215 -and $b -eq 16777215) $t
      }
    }
  }
  # hoja nueva y columna ORIGEN
  $hay = $false
  for ($k = 1; $k -le $wb.Worksheets.Count; $k++) { if ($wb.Worksheets.Item($k).Name -eq "PPTOS EXTERNOS") { $hay = $true } }
  Chk "hoja PPTOS EXTERNOS presente" $hay "ok"
  $wsP = Retry { $wb.Worksheets.Item("POR EJECUTAR") }
  Chk "columna ORIGEN en AQ" ((Retry { $wsP.Cells.Item(2, 43).Text }) -eq "ORIGEN") "ok"
  "RESULTADO: $fallos FALLOS"
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
