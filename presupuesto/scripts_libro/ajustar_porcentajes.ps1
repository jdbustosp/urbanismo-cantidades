# AJUSTE DE LOS CAPITULOS "POR PORCENTAJE" (2026-09-08, pedido del usuario)
#
# Regla del usuario: "van en funcion del porcentaje del subtotal de cada
# etapa: UM = %, la CANTIDAD es el porcentaje y el VALOR UNITARIO es el
# subtotal de esa etapa".
#
# Estado que se corrige:
#  (a) PGU / CAR / PMT / ADMIN DELEGADA / INTERVENTORIA / ESTUDIOS ya
#      tenian UM=% y cantidad=%, PERO su VU era
#      =SUMIF(PRECIOS_UNITARIOS...) apuntando a un NUMERO CONGELADO
#      (el subtotal de la etapa del presupuesto ORIGINAL) -> no se movia
#      nunca. Medido: etapa 05 congelada 29.909M vs real 5.346M (-82%);
#      GENERAL congelada 37.489M vs real 85.426M (+128%).
#  (b) "Obras preliminares generales" habia quedado al reves (celdas de
#      subetapa = base, VU = 3,5%). Se convierte al MISMO patron que sus
#      hermanas: UNA FILA POR ETAPA (01..09 + GENERAL) con el 3,5% en la
#      columna de su etapa y VU = subtotal vivo de esa etapa. El total
#      del capitulo NO cambia (3,5% x misma base).
#
# VU vivo = SUMPRODUCT sobre las filas NIVEL 5 del grupo 2 (ACTIVIDADES
# POR EJECUTAR) de (columnas de subetapa de esa etapa) x VR_UNITARIO.
#  - para PGU/CAR/PMT/ADMIN/INTERV/ESTUDIOS el rango INCLUYE las filas de
#    preliminares (los indirectos se calculan sobre el costo directo
#    completo, como en el presupuesto original);
#  - para las filas de PRELIMINARES el rango las EXCLUYE a ellas mismas
#    (evita la referencia circular).
# NO se toca IMPREVISTOS (su base es el parque al que pertenece, no la
# etapa: queda reportado como decision aparte).
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$bkdir = "C:\Users\juanbusper\Streaming de Google Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\MEMORIAS\V3\PROYECTO_URBANISMO_GENERAL\BACKUPS"
$bk = Join-Path $bkdir "urbanismo maipore_backup_antes_porcentajes_20260908.xlsx"
if (-not (Test-Path $bk)) { Copy-Item $libro $bk }
Write-Output ("backup: " + $bk)

function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (400 * $t) }
  }
}
# columnas de cada etapa (F=6 .. AM=39)
$colsEtapa = @{
  "01" = @(6);            "02" = @(7);          "03" = @(8,9,10)
  "04" = @(11,12,13,14,15,16,17)
  "05" = @(18,19,20,21,22,23,24,25)
  "06" = @(26);           "07" = @(27);         "08" = @(28,29,30,31,32)
  "09" = @(33,34,35,36,37,38)
  "GENERAL" = @(39) }
function LetraCol([int]$n) {
  $s = ""
  while ($n -gt 0) { $m = ($n - 1) % 26; $s = [char](65 + $m) + $s; $n = [math]::Floor(($n - 1) / 26) }
  $s
}
function FormulaVU($cols, $r1, $r2) {
  $piezas = @()
  foreach ($c in $cols) { $L = LetraCol $c; $piezas += ('$' + $L + '$' + $r1 + ':$' + $L + '$' + $r2) }
  $suma = if ($piezas.Count -eq 1) { $piezas[0] } else { "(" + ($piezas -join "+") + ")" }
  return ('=SUMPRODUCT(--($A$' + $r1 + ':$A$' + $r2 + '=5),' + $suma + ',$AO$' + $r1 + ':$AO$' + $r2 + ')')
}

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null; $ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $xl.Calculation = -4135
  $xl.ScreenUpdating = $false
  $ws = $wb.Worksheets.Item("POR EJECUTAR")
  $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
  Write-Output ("ultima fila: " + $last)

  # ---------- localizar grupo 2 y la fila de preliminares ----------
  $nivArr = $ws.Range("A3:A$last").Value2
  $desArr = $ws.Range("D3:D$last").Value2
  $n = $nivArr.GetLength(0)
  $ini2 = 0; $fin2 = 0; $rowPre = 0; $yaExplotado = $false
  for ($i = 1; $i -le $n; $i++) {
    $r = $i + 2
    $niv = if ($nivArr[$i,1] -ne $null) { [int]$nivArr[$i,1] } else { 0 }
    $d = [string]$desArr[$i,1]
    if ($niv -eq 1) {
      if ($d -match '^ACTIVIDADES POR EJECUTAR') { $ini2 = $r }
      elseif ($ini2 -gt 0 -and $fin2 -eq 0) { $fin2 = $r - 1 }
    }
    if ($niv -eq 5 -and $d -match '^Obras preliminares generales') {
      if ($rowPre -eq 0) { $rowPre = $r }
      if ($d -match 'ETAPA 01') { $yaExplotado = $true }
    }
  }
  if ($fin2 -eq 0) { $fin2 = $last }
  Write-Output ("grupo 2: filas $ini2..$fin2 | preliminares en fila $rowPre | ya explotado: $yaExplotado")
  if ($rowPre -eq 0) { throw "no encontre la fila de Obras preliminares generales" }

  $etapas = @("01","02","03","04","05","06","07","08","09","GENERAL")

  # ---------- (b) explotar preliminares en una fila por etapa ----------
  if (-not $yaExplotado) {
    Retry { $ws.Rows(($rowPre + 1).ToString() + ":" + ($rowPre + 9).ToString()).Insert(-4121, 0) | Out-Null }
    $fin2 = $fin2 + 9
    Write-Output ("insertadas 9 filas; grupo 2 ahora $ini2..$fin2")
    # limpiar la fila original y re-escribir el bloque completo
    Retry { $ws.Range("F$rowPre" + ":AM" + $rowPre).ClearContents() }
    $rBaseIni = $rowPre + 10      # primera fila de obra despues del bloque
    for ($k = 0; $k -lt 10; $k++) {
      $r = $rowPre + $k
      $e = $etapas[$k]
      $suf = if ($e -eq "GENERAL") { "GENERAL" } else { "ETAPA " + $e }
      Retry { $ws.Cells.Item($r, 1).Value2 = 5.0 }
      Retry { $ws.Cells.Item($r, 4).Value2 = "Obras preliminares generales " + $suf }
      Retry { $ws.Cells.Item($r, 5).Value2 = "%" }
      $c = $colsEtapa[$e][0]
      Retry { $ws.Cells.Item($r, $c).NumberFormat = "0.00%" }
      Retry { $ws.Cells.Item($r, $c).Value2 = 0.035 }
      Retry { $ws.Cells.Item($r, 40).Formula = '=SUM($F' + $r + ':$AM' + $r + ')' }
      Retry { $ws.Cells.Item($r, 40).NumberFormat = "0.00%" }
      Retry { $ws.Cells.Item($r, 41).Formula = (FormulaVU $colsEtapa[$e] $rBaseIni $fin2) }
      Retry { $ws.Cells.Item($r, 41).NumberFormat = "#,##0" }
      Retry { $ws.Cells.Item($r, 42).Formula = "=AN$r*AO$r" }
      Retry { $ws.Cells.Item($r, 42).NumberFormat = "#,##0" }
      Retry { $ws.Rows($r.ToString()).OutlineLevel = 5 }
    }
    # columna C (ITEM autonomo): misma formula que el resto de la hoja
    # (el FORMATO de las filas nuevas ya se hereda del insert con
    # CopyOrigin=xlFormatFromLeftOrAbove)
    $fC = '=IF(RC1<=2,RC3,LOOKUP(2,1/(R2C1:R[-1]C1=RC1-1),R2C3:R[-1]C3)&"."&COUNTIF(INDEX(C1,LOOKUP(2,1/(R2C1:R[-1]C1=RC1-1),ROW(R2C1:R[-1]C1))):RC1,RC1))'
    Retry { $ws.Range("C" + ($rowPre + 1) + ":C" + ($rowPre + 9)).FormulaR1C1 = $fC }
    Write-Output "preliminares explotado en 10 filas (01..09 + GENERAL)"
  } else {
    Write-Output "preliminares ya estaba explotado: solo se refrescan formulas"
  }

  # ---------- (a) VU vivo en TODOS los capitulos de porcentaje ----------
  $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
  $nivArr = $ws.Range("A3:A$last").Value2
  $desArr = $ws.Range("D3:D$last").Value2
  $umArr  = $ws.Range("E3:E$last").Value2
  $n = $nivArr.GetLength(0)
  $patron = '^(Obras preliminares generales|PLAN DE GESTION URBANA \(PGU\)|COSTOS GESTION AMBIENTAL \(CAR\)|PMT - ETAPA|ADMIN DELEGAD \+ HON \+ REEMB|INTERVENTORIA \+ HON \+ REEMB|ESTUDIOS Y DISE)'
  $rBasePre = $rowPre + 10
  $tocadas = 0; $saltadas = @()
  for ($i = 1; $i -le $n; $i++) {
    $r = $i + 2
    $niv = if ($nivArr[$i,1] -ne $null) { [int]$nivArr[$i,1] } else { 0 }
    if ($niv -ne 5) { continue }
    $d = [string]$desArr[$i,1]
    $um = [string]$umArr[$i,1]
    if ($d -notmatch $patron) { continue }
    if ($um -ne "%") { Retry { $ws.Cells.Item($r, 5).Value2 = "%" } }
    # etapa por el sufijo de la descripcion
    $e = $null
    if ($d -match 'ETAPA\s*0?(\d)') { $e = "0" + $Matches[1] }
    elseif ($d -match 'GENERAL') { $e = "GENERAL" }
    if ($e -eq $null -or -not $colsEtapa.ContainsKey($e)) { $saltadas += ("$r $d"); continue }
    $esPre = ($d -match '^Obras preliminares generales')
    $r1 = if ($esPre) { $rBasePre } else { $ini2 }
    Retry { $ws.Cells.Item($r, 41).Formula = (FormulaVU $colsEtapa[$e] $r1 $fin2) }
    Retry { $ws.Cells.Item($r, 41).NumberFormat = "#,##0" }
    Retry { $ws.Cells.Item($r, 40).NumberFormat = "0.00%" }
    foreach ($c in $colsEtapa[$e]) { Retry { $ws.Cells.Item($r, $c).NumberFormat = "0.00%" } }
    $tocadas++
  }
  Write-Output ("filas de porcentaje con VU VIVO: " + $tocadas)
  if ($saltadas.Count -gt 0) { foreach ($s in $saltadas) { Write-Output ("  OJO sin etapa reconocible: " + $s) } }

  # ---------- recalcular y verificar ----------
  $xl.Calculation = -4105
  try { $xl.CalculateFull() } catch { Start-Sleep -Seconds 5; try { $xl.CalculateFull() } catch {} }
  # total del grupo 2 (fila de nivel 1) y total de preliminares
  $totG2 = $ws.Cells.Item($ini2, 42).Value2
  $totPre = 0.0
  for ($k = 0; $k -lt 10; $k++) { $totPre += [double]$ws.Cells.Item(($rowPre + $k), 42).Value2 }
  Write-Output ("VERIF total grupo 2 = {0:N0} (esperado 145.678.994.374)" -f $totG2)
  Write-Output ("VERIF total preliminares = {0:N0} (esperado 4.926.342.805)" -f $totPre)
  if ([math]::Abs($totG2 - 145678994374.0) -gt 5000.0) { throw "VERIFICACION FALLO: el grupo 2 cambio de total" }
  if ([math]::Abs($totPre - 4926342804.92) -gt 5000.0) { throw "VERIFICACION FALLO: preliminares cambio de total" }
  # reporte de los capitulos de indirectos
  Write-Output "--- capitulos de porcentaje (nivel 2 del grupo 5) ---"
  $last2 = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
  $nv = $ws.Range("A3:A$last2").Value2
  $de = $ws.Range("D3:D$last2").Value2
  for ($i = 1; $i -le $nv.GetLength(0); $i++) {
    $r = $i + 2
    $niv = if ($nv[$i,1] -ne $null) { [int]$nv[$i,1] } else { 0 }
    if ($niv -ne 2) { continue }
    $d = [string]$de[$i,1]
    if ($d -match 'PGU|CAR|PMT|INTERVENTOR|ESTUDIOS|PRELIMINARES') {
      Write-Output ("  {0,-62} {1,20:N0}" -f $d, $ws.Cells.Item($r, 42).Value2)
    }
  }
  $xl.ScreenUpdating = $true
  Retry { $wb.Save() }
  $ok = $true
  Write-Output "GUARDADO"
} finally {
  if ($wb) { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO (fallo la verificacion)" }