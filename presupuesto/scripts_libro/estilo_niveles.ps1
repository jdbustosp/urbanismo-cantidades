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
  $pR = $ws.PivotTables("ResumenEtapas")
  $pD = $ws.PivotTables("DinamicaPpto")
  "estilo actual DinamicaPpto : " + $pD.TableStyle2
  "estilo actual ResumenEtapas: " + $pR.TableStyle2

  $nombre = "URB_NIVELES"
  try { $wb.TableStyles.Item($nombre).Delete() } catch {}
  # se DUPLICA el estilo que ya tenia para no perder bordes ni encabezado
  $base = $pD.TableStyle2
  $st = $null
  if ($base -and $base -ne "") {
    try { $st = $wb.TableStyles.Item($base).Duplicate($nombre) } catch { $st = $null }
  }
  if (-not $st) { $st = $wb.TableStyles.Add($nombre) }
  "estilo nuevo: " + $st.Name + " (duplicado de '" + $base + "')"

  # colores por nivel, los mismos de siempre
  $gris = 8421504; $amarillo = 10092543; $azul = 16243908
  # 23=SubtotalRow1 (nivel 1) 24=SubtotalRow2 (niveles 2 y 4) 25=SubtotalRow3 (nivel 3)
  # 11/12/13 = RowSubheading1/2/3 (la celda del rotulo en formato compacto)
  $mapa = @{ 23 = $gris; 24 = $amarillo; 25 = $azul; 11 = $gris; 12 = $amarillo; 13 = $azul }
  foreach ($k in @(23, 24, 25, 11, 12, 13)) {
    Retry { $st.TableStyleElements.Item([int]$k).Interior.Color = $mapa[$k] }
    Retry { $st.TableStyleElements.Item([int]$k).Font.Bold = $true }
  }
  "elementos de nivel pintados"

  foreach ($p in @($pD, $pR)) {
    Retry { $p.TableStyle2 = $nombre }
    Retry { $p.PreserveFormatting = $false }
    Retry { $p.HasAutoFormat = $false }
  }
  "estilo aplicado a las dos dinamicas"

  for ($v = 1; $v -le 3; $v++) {
    Retry { $pD.PivotCache().Refresh() }
    Retry { $pR.PivotCache().Refresh() }
    Start-Sleep -Seconds 2
  }
  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 3
  "actualizado 3 veces"

  # buscar una fila de subtotal del POR EJECUTAR para ver cantidad y color
  $fila2 = 0; $fila3 = 0; $fila4 = 0; $fila5 = 0
  for ($r = 4; $r -le 1609; $r++) {
    $t = $ws.Cells.Item($r, 7).Text
    if ($fila2 -eq 0 -and $t -match '^2\.\d+ ') { $fila2 = $r }
    if ($fila3 -eq 0 -and $t -match '^2\.\d+\.\d+ ') { $fila3 = $r }
    if ($fila4 -eq 0 -and $t -match '^2\.\d+\.\d+\.\d+ ') { $fila4 = $r }
    if ($fila5 -eq 0 -and $t -match '^2\.\d+\.\d+\.\d+\.\d+ ') { $fila5 = $r }
    if ($fila2 -and $fila3 -and $fila4 -and $fila5) { break }
  }
  "=== filas de muestra del POR EJECUTAR: N2=$fila2 N3=$fila3 N4=$fila4 N5=$fila5"
  foreach ($r in @($fila2, $fila3, $fila4, $fila5)) {
    if ($r -eq 0) { continue }
    $cols = ""
    foreach ($c in 7..11) { $cols += ("" + $ws.Cells.Item($r, $c).DisplayFormat.Interior.Color + " ") }
    "  fila $r '" + $ws.Cells.Item($r, 7).Text + "'"
    "      colores G..K: $cols"
    "      CANTIDAD='" + $ws.Cells.Item($r, 8).Text + "'  V.UNIT='" + $ws.Cells.Item($r, 9).Text +
      "'  VALOR='" + $ws.Cells.Item($r, 10).Text + "'"
  }
  $wb.Save()
  $ok = $true
  "guardado"
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
