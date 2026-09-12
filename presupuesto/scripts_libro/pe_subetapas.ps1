# POR EJECUTAR: los capitulos por PORCENTAJE pasan de una fila por ETAPA a
# una fila por SUBETAPA, y se agrega IMPREVISTOS (5%) al nivel ACTIVIDADES
# POR EJECUTAR (2026-09-11, pedido del usuario).
#   - cada fila nueva lleva el MISMO % en la columna de SU subetapa y el VU
#     vivo = SUMPRODUCT del costo directo de esa subetapa (mismo criterio de
#     ajustar_porcentajes.ps1, pero por columna y no por etapa).
#   - IMPREVISTOS nuevo: 5% sobre el costo directo de cada subetapa del grupo
#     2, EXCLUYENDO las filas de imprevistos que ya existen (parques y Muna)
#     para no calcular imprevisto sobre imprevisto. El % vive en una sola
#     celda: las demas filas la referencian.
#   - ademas mueve el pago de 6.000 M de COINVER de la 1440 a la 1423 en la
#     hoja EJECUTADO (nota del archivo de actas).
# Verifica los totales de cada capitulo antes de guardar.
param(
  [string]$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx",
  [double]$pctImprev = 0.05
)
$ErrorActionPreference = "Stop"
$logf = Join-Path $PSScriptRoot "pe_subetapas.log"
function Log($m) { [System.IO.File]::AppendAllText($logf, ((Get-Date).ToString("HH:mm:ss") + "  " + $m + [Environment]::NewLine)); Write-Output $m }
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 6; $t++) { try { return (& $__sb) } catch { if ($t -eq 6) { throw }; Start-Sleep -Milliseconds (500 * $t) } }
}
function LetraC([int]$n) { $s = ""; while ($n -gt 0) { $m = ($n - 1) % 26; $s = [char](65 + $m) + $s; $n = [math]::Floor(($n - 1) / 26) }; $s }
$colsEtapa = @{
  "01" = @(6); "02" = @(7); "03" = @(8,9,10); "04" = @(11,12,13,14,15,16,17)
  "05" = @(18,19,20,21,22,23,24,25); "06" = @(26); "07" = @(27); "08" = @(28,29,30,31,32)
  "09" = @(33,34,35,36,37,38); "GENERAL" = @(39) }
# VU vivo de UNA columna de subetapa
function FormulaVU([int]$col, [int]$r1, [int]$r2, [bool]$sinImprev) {
  $f = '=SUMPRODUCT(--(R' + $r1 + 'C1:R' + $r2 + 'C1=5),'
  if ($sinImprev) { $f += '--(LEFT(R' + $r1 + 'C4:R' + $r2 + 'C4,11)<>"IMPREVISTOS"),' }
  $f += 'R' + $r1 + 'C' + $col + ':R' + $r2 + 'C' + $col + ',R' + $r1 + 'C41:R' + $r2 + 'C41)'
  return $f
}
$fC = '=IF(RC1<=2,RC3,LOOKUP(2,1/(R2C1:R[-1]C1=RC1-1),R2C3:R[-1]C3)&"."&COUNTIF(INDEX(C1,LOOKUP(2,1/(R2C1:R[-1]C1=RC1-1),ROW(R2C1:R[-1]C1))):RC1,RC1))'

$bloques = @(
  @{ pat = '^ESTUDIOS Y DISE'; pre = 'ESTUDIOS Y DISEÑOS '; base = 'GRUPO2' },
  @{ pat = '^INTERVENTORIA \+ HON \+ REEMB'; pre = 'INTERVENTORIA + HON + REEMB '; base = 'GRUPO2' },
  @{ pat = '^ADMIN DELEGAD \+ HON \+ REEMB'; pre = 'ADMIN DELEGAD + HON + REEMB '; base = 'GRUPO2' },
  @{ pat = '^PMT - '; pre = 'PMT - '; base = 'GRUPO2' },
  @{ pat = '^COSTOS GESTION AMBIENTAL \(CAR\)'; pre = 'COSTOS GESTION AMBIENTAL (CAR) '; base = 'GRUPO2' },
  @{ pat = '^PLAN DE GESTION URBANA \(PGU\)'; pre = 'PLAN DE GESTION URBANA (PGU) '; base = 'GRUPO2' },
  @{ pat = '^Obras preliminares generales'; pre = 'Obras preliminares generales '; base = 'POSTPRE' }
)
$esperado = @{
  'Obras preliminares generales ' = 4926342804.92; 'PLAN DE GESTION URBANA (PGU) ' = 117121240.6
  'COSTOS GESTION AMBIENTAL (CAR) ' = 1079902832.6; 'PMT - ' = 292803102.6
  'ADMIN DELEGAD + HON + REEMB ' = 7199352218.0; 'INTERVENTORIA + HON + REEMB ' = 5039546552.6
  'ESTUDIOS Y DISEÑOS ' = 1439870443.6 }

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null; $ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  if ($wb.ReadOnly) { throw "el libro abrio en SOLO LECTURA" }
  $xl.Calculation = -4135; $xl.ScreenUpdating = $false; $xl.EnableEvents = $false
  $ws = $null
  for ($t = 1; $t -le 6 -and -not $ws; $t++) {
    try { for ($k = 1; $k -le $wb.Worksheets.Count; $k++) { $w = $wb.Worksheets.Item($k); if ($w.Name -like 'POR EJEC*') { $ws = $w } } } catch {}
    if (-not $ws) { Start-Sleep -Seconds 2 }
  }
  if (-not $ws) { throw "no pude tomar la hoja POR EJECUTAR" }

  # ---------- subetapas del encabezado ----------
  $codigo = @{}
  for ($c = 6; $c -le 39; $c++) { $codigo[$c] = [string]$ws.Cells.Item(2, $c).Value2 }
  # ---------- limites del grupo 2 ----------
  $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
  $A = $ws.Range("A3:E$last").Value2
  $ini2 = 0; $fin2 = 0
  for ($i = 1; $i -le $A.GetLength(0); $i++) {
    $r = $i + 2; $niv = if ($A[$i,1] -ne $null) { [int]$A[$i,1] } else { 0 }; $d = [string]$A[$i,4]
    if ($niv -eq 1) { if ($d -match '^ACTIVIDADES POR EJECUTAR') { $ini2 = $r } elseif ($ini2 -gt 0 -and $fin2 -eq 0) { $fin2 = $r - 1 } }
  }
  if ($fin2 -eq 0) { $fin2 = $last }
  Log ("grupo 2: $ini2..$fin2 | ultima fila $last")

  # ---------- localizar los bloques de % ----------
  foreach ($b in $bloques) {
    $filas = @(); $pct = 0.0; $etapas = @()
    for ($i = 1; $i -le $A.GetLength(0); $i++) {
      $r = $i + 2; $niv = if ($A[$i,1] -ne $null) { [int]$A[$i,1] } else { 0 }; $d = [string]$A[$i,4]
      if ($niv -ne 5 -or $d -notmatch $b.pat) { continue }
      $filas += $r
      $e = $null
      if ($d -match 'ETAPA\s*0?(\d)') { $e = "0" + $Matches[1] } elseif ($d -match 'GENERAL') { $e = "GENERAL" }
      if ($e) { $etapas += $e }
    }
    $b.filas = $filas; $b.etapas = $etapas
    if ($filas.Count -gt 0) {
      $r0 = $filas[0]
      for ($c = 6; $c -le 39; $c++) { $v = $ws.Cells.Item($r0, $c).Value2; if ($v -ne $null -and [double]$v -ne 0) { $pct = [double]$v } }
    }
    $b.pct = $pct
    Log ("bloque " + $b.pre + ": filas " + ($filas -join ',') + " | etapas " + ($etapas -join ',') + " | pct " + $pct)
  }

  # ---------- reescribir cada bloque por SUBETAPA (de abajo hacia arriba) ----------
  foreach ($b in ($bloques | Sort-Object { -$_.filas[0] })) {
    $r0 = [int]($b.filas[0]); $nOld = @($b.filas).Count; $pctv = [double]$b.pct; $prev = [string]$b.pre; $basev = [string]$b.base
    $entradas = @()
    foreach ($e in @($b.etapas)) { foreach ($c in $colsEtapa[$e]) { $entradas += @{ col = [int]$c; cod = [string]$codigo[$c] } } }
    $nNew = $entradas.Count
    if ($nNew -lt $nOld) { throw ("el bloque " + $prev + " tendria menos filas que antes") }
    if ($nNew -gt $nOld) { Retry { $ws.Rows(($r0 + 1).ToString() + ":" + ($r0 + $nNew - $nOld).ToString()).Insert(-4121, 0) | Out-Null } }
    $delta = $nNew - $nOld
    # las filas insertadas heredan celdas COMBINADAS de la fila de capitulo
    # de arriba: hay que descombinarlas antes de escribir el %
    Retry { $ws.Range("A$r0" + ":AP" + ($r0 + $nNew - 1)).UnMerge() } | Out-Null
    # rangos de base (ya con el corrimiento de este bloque)
    $f2 = if ($r0 -lt $fin2) { $fin2 + $delta } else { $fin2 }
    $b1 = if ($basev -eq 'POSTPRE') { $r0 + $nNew } else { $ini2 }
    for ($k = 0; $k -lt $nNew; $k++) {
      $r = $r0 + $k; $en = $entradas[$k]; $cc = [int]$en.col
      $suf = if ([string]$en.cod -eq 'GEN') { 'GENERAL' } else { 'SUBETAPA ' + [string]$en.cod }
      Retry { $ws.Cells.Item($r, 1).Value2 = 5.0 }
      Retry { $ws.Cells.Item($r, 3).FormulaR1C1 = $fC }
      Retry { $ws.Cells.Item($r, 4).Value2 = $prev + $suf }
      Retry { $ws.Cells.Item($r, 5).Value2 = "%" }
      Retry { $ws.Range("F$r" + ":AM$r").ClearContents() }
      Retry { $ws.Cells.Item($r, $cc).NumberFormat = "0,00%" }
      if ($false) { Log ("  DIAG r=" + $r + " (" + $r.GetType().Name + ") cc=" + $cc + " (" + $cc.GetType().Name + ") pct=" + $pctv + " (" + $pctv.GetType().Name + ") cod=[" + $en.cod + "]") }
      # el % se escribe por FORMULA con punto decimal (invariante): en este
      # libro/Excel es-CO, Value2 con un Double sobre una celda en formato
      # porcentaje revienta con "Double -> String" (medido: 6 reintentos de
      # 8 s por fila, era lo que colgaba el script)
      $cel = (LetraC $cc) + $r
      Retry { $ws.Range($cel).Formula = $pctv.ToString([System.Globalization.CultureInfo]::InvariantCulture) } | Out-Null
      Retry { $ws.Cells.Item($r, 40).FormulaR1C1 = '=SUM(RC6:RC39)' }
      Retry { $ws.Cells.Item($r, 40).NumberFormat = "0,00%" }
      Retry { $ws.Cells.Item($r, 41).FormulaR1C1 = (FormulaVU $cc $b1 $f2 $false) }
      Retry { $ws.Cells.Item($r, 41).NumberFormat = "`$ #.##0" }
      Retry { $ws.Cells.Item($r, 42).FormulaR1C1 = '=RC[-2]*RC[-1]' }
      Retry { $ws.Cells.Item($r, 42).NumberFormat = "`$ #.##0" }
      Retry { $ws.Rows($r.ToString()).OutlineLevel = 5 }
    }
    if ($r0 -lt $fin2) { $fin2 = $fin2 + $delta }
    Log ("  " + $prev + ": " + $nOld + " -> " + $nNew + " filas (desde " + $r0 + ")")
  }

  # ---------- IMPREVISTOS nuevo al final del grupo 2 ----------
  $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
  $A = $ws.Range("A3:E$last").Value2
  $yaHay = $false
  for ($i = 1; $i -le $A.GetLength(0); $i++) { if ([string]$A[$i,4] -eq 'IMPREVISTOS GENERALES POR SUBETAPA') { $yaHay = $true } }
  if (-not $yaHay) {
    # plantillas: filas N2/N3/N4 de PRELIMINARES (4,5,6) y N5 (7)
    $ins = $fin2 + 1
    # OJO: Rows.Copy() + Insert usa el PORTAPAPELES y en este libro deja a
    # Excel esperando un dialogo invisible (se colgo 13 min sin CPU). Se
    # insertan filas vacias y se copia con Copy(DESTINO), que no lo usa.
    Retry { $ws.Rows(($ins).ToString() + ":" + ($ins + 2).ToString()).Insert(-4121, 0) | Out-Null }
    Retry { $ws.Rows("4:6").Copy($ws.Rows(($ins).ToString() + ":" + ($ins + 2).ToString())) | Out-Null }
    $nuevoN2 = "2.13"
    Retry { $ws.Cells.Item($ins, 1).Value2 = 2.0 }
    Retry { $ws.Cells.Item($ins, 3).Value2 = $nuevoN2 }
    Retry { $ws.Cells.Item($ins, 4).Value2 = "IMPREVISTOS" }
    Retry { $ws.Cells.Item($ins + 1, 1).Value2 = 3.0 }
    Retry { $ws.Cells.Item($ins + 1, 4).Value2 = "IMPREVISTOS" }
    Retry { $ws.Cells.Item($ins + 2, 1).Value2 = 4.0 }
    Retry { $ws.Cells.Item($ins + 2, 4).Value2 = "IMPREVISTOS GENERALES POR SUBETAPA" }
    Retry { $ws.Range("F$ins" + ":AM" + ($ins + 2)).UnMerge() } | Out-Null
    foreach ($k in 0..2) { Retry { $ws.Range("F" + ($ins + $k) + ":AM" + ($ins + $k)).ClearContents() } }
    # 34 filas de nivel 5
    $r1 = $ins + 3
    Retry { $ws.Rows($r1.ToString() + ":" + ($r1 + 33).ToString()).Insert(-4121, 0) | Out-Null }
    Retry { $ws.Rows("7:7").Copy($ws.Rows($r1.ToString() + ":" + ($r1 + 33).ToString())) | Out-Null }
    Retry { $ws.Range("A$r1" + ":AP" + ($r1 + 33)).UnMerge() } | Out-Null
    $baseFin = $fin2 + 37   # el grupo 2 crecio en 3 + 34 filas
    for ($k = 0; $k -le 33; $k++) {
      $r = $r1 + $k; $col = 6 + $k; $cod = $codigo[$col]
      $suf = if ($cod -eq 'GEN') { 'GENERAL' } else { 'SUBETAPA ' + $cod }
      Retry { $ws.Cells.Item($r, 1).Value2 = 5.0 }
      Retry { $ws.Cells.Item($r, 3).FormulaR1C1 = $fC }
      Retry { $ws.Cells.Item($r, 4).Value2 = "IMPREVISTOS " + $suf }
      Retry { $ws.Cells.Item($r, 5).Value2 = "%" }
      Retry { $ws.Range("F$r" + ":AM$r").ClearContents() }
      Retry { $ws.Cells.Item($r, $col).NumberFormat = "0,00%" }
      if ($k -eq 0) { Retry { $ws.Cells.Item($r, $col).Formula = $pctImprev.ToString([System.Globalization.CultureInfo]::InvariantCulture) } }
      else { Retry { $ws.Cells.Item($r, $col).Formula = "=`$F`$$r1" } }
      Retry { $ws.Cells.Item($r, 40).FormulaR1C1 = '=SUM(RC6:RC39)' }
      Retry { $ws.Cells.Item($r, 40).NumberFormat = "0,00%" }
      Retry { $ws.Cells.Item($r, 41).FormulaR1C1 = (FormulaVU $col $ini2 $fin2 $true) }
      Retry { $ws.Cells.Item($r, 41).NumberFormat = "`$ #.##0" }
      Retry { $ws.Cells.Item($r, 42).FormulaR1C1 = '=RC[-2]*RC[-1]' }
      Retry { $ws.Cells.Item($r, 42).NumberFormat = "`$ #.##0" }
      Retry { $ws.Rows($r.ToString()).OutlineLevel = 5 }
    }
    Log ("IMPREVISTOS nuevo: capitulo " + $nuevoN2 + " en filas $ins.." + ($r1 + 33) + " con " + ($pctImprev * 100) + "%")
  } else { Log "IMPREVISTOS por subetapa ya existia: no se duplica" }

  # ---------- EJECUTADO: los 6.000 M de la 1440 son de la 1423 ----------
  $wsE = $null
  for ($k = 1; $k -le $wb.Worksheets.Count; $k++) { $w = $wb.Worksheets.Item($k); if ($w.Name -eq 'EJECUTADO') { $wsE = $w } }
  $lastE = $wsE.Cells.Item($wsE.Rows.Count, 1).End(-4162).Row
  $hE = @(); for ($c = 1; $c -le 20; $c++) { $hE += [string]$wsE.Cells.Item(1, $c).Value2 }
  $cN4 = [array]::IndexOf($hE, 'NIVEL4') + 1; $cAct = [array]::IndexOf($hE, 'ACTA') + 1
  $cEj = [array]::IndexOf($hE, 'EJECUTADO') + 1; $cTer = [array]::IndexOf($hE, 'TERCERO') + 1
  $cNota = [array]::IndexOf($hE, 'NOTA') + 1; $cDesc = [array]::IndexOf($hE, 'DESCRIPCION_ACTA') + 1
  $movidas = 0
  $vE = $wsE.Range("A2:T$lastE").Value2
  for ($i = 1; $i -le $vE.GetLength(0); $i++) {
    $r = $i + 1
    if ([string]($vE[$i, $cAct]) -eq '1440' -and [string]($vE[$i, $cTer]) -like 'COINVER*' -and [math]::Abs([double]($vE[$i, $cEj]) - 6000000000) -lt 1) {
      Retry { $wsE.Cells.Item($r, $cN4).Value2 = "1423" }
      Retry { $wsE.Cells.Item($r, $cAct).Value2 = "1423" }
      $nota = [string]($vE[$i, $cNota])
      $txt = "Movido de la 1440 a la 1423 por instruccion del usuario (nota del archivo de actas: en la 1440 cargaron 6.000 M a COINVER que son de la 1423)"
      Retry { $wsE.Cells.Item($r, $cNota).Value2 = (@($nota, $txt) | Where-Object { $_ }) -join ' | ' }
      $movidas++
      Log ("EJECUTADO fila " + $r + " movida a la 1423: " + [string]($vE[$i, $cDesc]))
    }
  }
  if ($movidas -ne 1) { throw "esperaba mover UNA fila de 6.000 M y movi $movidas" }

  # ---------- recalcular y verificar ----------
  $xl.Calculation = -4105
  try { $xl.CalculateFullRebuild() } catch { try { $xl.CalculateFull() } catch {} }
  Start-Sleep -Seconds 3
  $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
  # tras un CalculateFullRebuild grande, Value2 puede volver NULA la primera
  # vez (Excel sigue ocupado): se reintenta hasta que devuelva la matriz
  $A = $null; $V = $null
  for ($t = 1; $t -le 12 -and (-not $A -or -not $V); $t++) {
    try { $A = $ws.Range("A3:E$last").Value2; $V = $ws.Range("AP3:AP$last").Value2 } catch {}
    if (-not $A -or -not $V) { Start-Sleep -Seconds 5 }
  }
  if (-not $A -or -not $V) { throw "no pude leer las columnas de la hoja despues del recalculo" }
  $tot = @{}; $errores = 0; $ini2b = 0; $fin2b = 0; $totG2 = 0.0; $totInd = 0.0; $totImp = 0.0
  for ($i = 1; $i -le $A.GetLength(0); $i++) {
    $r = $i + 2; $niv = if ($A[$i,1] -ne $null) { [int]$A[$i,1] } else { 0 }; $d = [string]$A[$i,4]
    # OJO: PowerShell NO distingue mayusculas: $v y $V eran la MISMA
    # variable y la matriz se destruia en la primera vuelta
    $val = $V[$i,1]
    if ($val -is [string] -and $val -like '#*') { $errores++ }
    if ($niv -eq 1 -and $d -match '^ACTIVIDADES POR EJECUTAR') { $totG2 = [double]$val }
    if ($niv -eq 1 -and $d -eq 'INDIRECTOS') { $totInd = [double]$val }
    if ($niv -eq 4 -and $d -eq 'IMPREVISTOS GENERALES POR SUBETAPA') { $totImp = [double]$val }
    if ($niv -eq 5) { foreach ($b in $bloques) { if ($d -match $b.pat) { $tot[$b.pre] = [double]$tot[$b.pre] + [double]$val } } }
  }
  Log ("celdas con error en AP: " + $errores)
  foreach ($k in $esperado.Keys) {
    $dif = [double]$tot[$k] - $esperado[$k]
    Log ("  {0,-34} {1,18:N0} (esperado {2,18:N0}) dif {3,12:N0}" -f $k, $tot[$k], $esperado[$k], $dif)
    if ([math]::Abs($dif) -gt 5000) { throw ("el capitulo " + $k + " cambio de total") }
  }
  Log ("IMPREVISTOS nuevo = {0:N0}" -f $totImp)
  Log ("grupo 2 = {0:N0} (antes 145.678.994.374) | INDIRECTOS = {1:N0} (antes 19.481.156.391)" -f $totG2, $totInd)
  if ($errores -gt 0) { throw "hay celdas con error en VALOR_TOTAL" }
  if ([math]::Abs($totInd - 19481156391) -gt 5000) { throw "los INDIRECTOS cambiaron de total" }
  if ([math]::Abs($totG2 - 145678994374 - $totImp) -gt 5000) { throw "el grupo 2 no cuadra con el imprevisto nuevo" }
  if ($totImp -lt 4000000000) { throw "el imprevisto nuevo salio demasiado bajo" }
  $xl.ScreenUpdating = $true
  Retry { $wb.Save() } | Out-Null
  $ok = $true
  Log "GUARDADO"
} finally {
  if ($wb) { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO" }
