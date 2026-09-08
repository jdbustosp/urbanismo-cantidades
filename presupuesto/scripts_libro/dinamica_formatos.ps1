# DINAMICA: formatos por NIVEL (2026-09-08, pedido del usuario)
#  1) CANTIDAD y V.UNITARIO VISIBLES SOLO en las filas de NIVEL 5 (las
#     de detalle, sin relleno). En capitulos (N1..N4) y en el total
#     general se ocultan con formato ";;;" -- ahi solo debe verse el
#     VALOR_TOTAL. (El intento anterior uso PivotSelect '[All]', que
#     selecciona TODAS las celdas del campo, no solo los subtotales:
#     por eso quedaron invisibles tambien las del nivel 5.)
#  2) COLOR POR NIVEL explicito (el estilo de tabla dinamica repetia el
#     color del nivel 2 en el nivel 4): N1 gris/blanco negrita, N2
#     amarillo, N3 azul claro, N4 durazno -- mismo criterio que la hoja
#     POR EJECUTAR. N5 sin relleno.
# El nivel de cada fila se detecta con PivotCell.RowItems.Count (5 =
# hoja de detalle), no por el texto de la etiqueta.
# Se expande TODO antes de formatear para que las filas hoy colapsadas
# ya queden formateadas al desplegarlas.
# OJO COM: Range("B5,C5,B9,...") con muchas areas revienta con
# 0x800A03EC -> se agrupan FILAS CONTIGUAS y se aplica por rango simple.
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (400 * $t) }
  }
}
function LetraC([int]$n) {
  $s = ""
  while ($n -gt 0) { $m = ($n - 1) % 26; $s = [char](65 + $m) + $s; $n = [math]::Floor(($n - 1) / 26) }
  $s
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null; $ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $xl.ScreenUpdating = $false

  # ---------- refrescar la BD (la hoja cambio: +9 filas de preliminares) ----------
  $wsB = $wb.Worksheets.Item("BD")
  $loB = $wsB.ListObjects.Item("BD_CONSOL")
  Retry { $loB.QueryTable.BackgroundQuery = $false }
  Retry { $loB.QueryTable.Refresh($false) | Out-Null }
  Write-Output ("BD_CONSOL: " + $loB.DataBodyRange.Rows.Count + " filas")

  $wsD = $wb.Worksheets.Item("DINAMICA")
  $pt = $wsD.PivotTables("DinamicaPpto")
  Retry { $pt.PreserveFormatting = $true }
  Retry { $pt.PivotCache().Refresh() | Out-Null }
  foreach ($fn in @("N1","N2","N3","N4")) {
    try { $pt.PivotFields($fn).ShowDetail = $true } catch { Write-Output ("  (no pude expandir " + $fn + ")") }
  }
  Write-Output ("pivot expandida: " + $pt.TableRange1.Address())

  Retry { $pt.PivotFields("Suma CANTIDAD").NumberFormat = "#.##0,00###" }
  Retry { $pt.PivotFields("V. UNITARIO PROM").NumberFormat = "`$ #.##0" }
  try { $pt.PivotFields("Suma VALOR_TOTAL").NumberFormat = "`$ #.##0" } catch {}

  # ---------- nivel de cada fila ----------
  $rngC = $pt.PivotFields("Suma CANTIDAD").DataRange
  $filaIni = $rngC.Row
  $nFilas = $rngC.Rows.Count
  $colC = $rngC.Column
  $LC = LetraC $colC              # CANTIDAD
  $LV = LetraC ($colC + 1)        # V. UNITARIO PROM
  $LT = LetraC ($colC + 2)        # VALOR_TOTAL
  $niveles = New-Object 'int[]' $nFilas
  for ($i = 0; $i -lt $nFilas; $i++) {
    $r = $filaIni + $i
    $niv = 0
    try { $niv = $wsD.Cells.Item($r, $colC).PivotCell.RowItems.Count } catch { $niv = 0 }
    $niveles[$i] = $niv
  }
  $cuenta = @{}
  foreach ($v in $niveles) { if ($cuenta.ContainsKey($v)) { $cuenta[$v]++ } else { $cuenta[$v] = 1 } }
  Write-Output ("filas " + $nFilas + " | por nivel: " + (($cuenta.Keys | Sort-Object | ForEach-Object { "n$_=" + $cuenta[$_] }) -join " "))

  # ---------- aplicar por RACHAS contiguas ----------
  $colores = @{1 = 0x808080; 2 = 0x99FFFF; 3 = 0xF7DCC4; 4 = 0xD1E8FF }
  $i = 0; $bloques = 0
  while ($i -lt $nFilas) {
    $niv = $niveles[$i]
    $j = $i
    while (($j + 1) -lt $nFilas -and $niveles[$j + 1] -eq $niv) { $j++ }
    $r1 = $filaIni + $i; $r2 = $filaIni + $j
    $rngFila = $wsD.Range("A$r1" + ":" + $LT + $r2)
    $rngCV = $wsD.Range($LC + $r1 + ":" + $LV + $r2)
    if ($niv -eq 5) {
      Retry { $rngCV.NumberFormat = "General" }
      Retry { $wsD.Range($LC + $r1 + ":" + $LC + $r2).NumberFormat = "#.##0,00###" }
      Retry { $wsD.Range($LV + $r1 + ":" + $LV + $r2).NumberFormat = "`$ #.##0" }
      # actividades cuya UM es % (preliminares, PGU, CAR, PMT,
      # interventoria, estudios, imprevistos): la CANTIDAD se muestra
      # como porcentaje -- la etiqueta de nivel 5 termina en "(%)"
      for ($q = $r1; $q -le $r2; $q++) {
        if ($wsD.Cells.Item($q, 1).Text -match '\(%\)\s*$') {
          Retry { $wsD.Cells.Item($q, $colC).NumberFormat = "0,00%" }
        }
      }
      Retry { $rngFila.Interior.ColorIndex = -4142 }
      Retry { $rngFila.Font.Bold = $false }
      Retry { $rngFila.Font.Color = 0 }
    } else {
      Retry { $rngCV.NumberFormat = ";;;" }
      if ($niv -ge 1 -and $niv -le 4) {
        Retry { $rngFila.Interior.Color = $colores[$niv] }
        Retry { $rngFila.Font.Bold = $true }
        if ($niv -eq 1) { Retry { $rngFila.Font.Color = 0xFFFFFF } }
        else { Retry { $rngFila.Font.Color = 0 } }
      }
    }
    $bloques++
    $i = $j + 1
  }
  Write-Output ("bloques formateados: " + $bloques)

  # ---------- volver a un despliegue comodo (colapsar bajo N3) ----------
  try { $pt.PivotFields("N3").ShowDetail = $false } catch {}
  $xl.ScreenUpdating = $true
  Retry { $wb.Save() }
  $ok = $true
  Write-Output "GUARDADO dinamica"
} finally {
  if ($wb) { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO" }