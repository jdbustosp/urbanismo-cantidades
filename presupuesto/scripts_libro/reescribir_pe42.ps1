# REESCRITURA POR EJECUTAR en 42 COLUMNAS (2026-09-07) desde pe_nuevo2.tsv.
# Corrige el bug de GEN (paso2 escribio 41 columnas: las formulas CANT/VU/VT
# en AM/AN/AO pisaron la subetapa GEN de la col 39). Layout correcto:
#   A NIVEL | B PARENT (vacia) | C ITEM formula autonoma | D DESC | E UM |
#   F..AM = 34 subetapas (GEN en AM/39) | AN CANTIDAD =SUM(F:AM) |
#   AO VR_UNITARIO =SUMIF(PU) | AP VALOR_TOTAL
# En UN SOLO script: datos + formulas + anclas texto + preliminares 3,5% +
# subtotales de capitulo (C42) + formato L1 (colores/bordes/agrupadores/
# ocultas) + PE_RANGO A2:AP5000. Outline de filas SIEMPRE al final.
# VERIFICA antes de guardar; si algo no cuadra, cierra SIN guardar.
$ErrorActionPreference = "Stop"
$sp = Split-Path -Parent $MyInvocation.MyCommand.Path
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$lines = [System.IO.File]::ReadAllLines((Join-Path $sp "pe_nuevo3.tsv"), [System.Text.Encoding]::UTF8)
$n = $lines.Count
Write-Output "filas de datos: $n"
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (300 * $t) }
  }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
$ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $xl.Calculation = -4135
  $xl.ScreenUpdating = $false
  $xl.EnableEvents = $false
  $ws = $wb.Worksheets.Item("POR EJECUTAR")

  # --- limpiar TODO (contenido, formato, outlines, ocultas) ---
  Retry { $ws.Columns("A:B").Hidden = $false }
  Retry { $ws.Cells.Clear() | Out-Null }
  Retry { $ws.Rows.ClearOutline() }
  Retry { $ws.Columns.ClearOutline() }
  Write-Output "hoja limpia"

  # --- encabezados (2 filas x 42) ---
  $hdr1 = @("NIVEL","PARENT_CODIGO","ITEM (CODIGO)","DESCRIPCION","UM","Etapa 2","Etapa 3","","","","Etapa 4","","","","","","","Etapa 5","","","","","","","","Etapa 6","Etapa 7","Etapa 8","","","","","Etapa 9","","","","","General","","","","")
  $hdr2 = @("NIVEL","PARENT_CODIGO","ITEM (CODIGO)","DESCRIPCION","UM","1","2","3","3A","3B","4","4A","4B","4C","4D","4E","4F","5","5A","5B","5C","5D","5E","5F","5G","6","7","8","8A","8B","8C","8D","9","9A","9B","9C","9D","9E","GEN","CANTIDAD","VR_UNITARIO","VALOR_TOTAL")
  if ($hdr1.Count -ne 42 -or $hdr2.Count -ne 42) { throw ("encabezados mal contados: " + $hdr1.Count + "/" + $hdr2.Count) }
  $h = New-Object 'object[,]' 2, 42
  for ($j = 0; $j -lt 42; $j++) { $h[0, $j] = $hdr1[$j]; $h[1, $j] = $hdr2[$j] }
  Retry { $ws.Range($ws.Cells.Item(1, 1), $ws.Cells.Item(2, 42)).Value2 = $h }
  Write-Output "encabezados 42 col"

  # --- datos base (A nivel, D desc, E um, F..AM subetapas) ---
  $data = New-Object 'object[,]' $n, 42
  for ($i = 0; $i -lt $n; $i++) {
    $f = $lines[$i] -split "`t"
    $data[$i, 0] = [double]$f[0]
    $data[$i, 3] = $f[2]
    $data[$i, 4] = $f[3]
    for ($k = 0; $k -lt 34; $k++) {
      $v = if ((4 + $k) -lt $f.Count) { $f[4 + $k] } else { "" }
      if ($v -match '^-?[\d.eE+-]+$') { $data[$i, (5 + $k)] = [double]$v }
      elseif ($v -ne "") { $data[$i, (5 + $k)] = $v }
    }
  }
  $last = $n + 2
  Retry { $ws.Range($ws.Cells.Item(3, 1), $ws.Cells.Item($last, 42)).Value2 = $data }
  Write-Output "datos escritos (A3:AP$last)"

  # niveles en memoria
  $niv = New-Object 'int[]' $n
  for ($i = 0; $i -lt $n; $i++) { $niv[$i] = [int](($lines[$i] -split "`t")[0]) }

  # --- numeracion: C autonoma en N3-5 (por rachas), anclas texto N1-2 ---
  $fC = '=IF(RC1<=2,RC3,LOOKUP(2,1/(R2C1:R[-1]C1=RC1-1),R2C3:R[-1]C3)&"."&COUNTIF(INDEX(C1,LOOKUP(2,1/(R2C1:R[-1]C1=RC1-1),ROW(R2C1:R[-1]C1))):RC1,RC1))'
  $i = 0
  while ($i -lt $n) {
    if ($niv[$i] -ge 3) {
      $j = $i
      while (($j + 1) -lt $n -and $niv[$j + 1] -ge 3) { $j++ }
      $r1 = $i + 3; $r2 = $j + 3
      Retry { $ws.Range("C$r1`:C$r2").FormulaR1C1 = $fC }
      $i = $j + 1
    } else { $i++ }
  }
  $anclas = 0
  for ($i = 0; $i -lt $n; $i++) {
    if ($niv[$i] -le 2) {
      $f = $lines[$i] -split "`t"
      $row = $i + 3
      Retry { $ws.Cells.Item($row, 3).NumberFormat = "@" }
      Retry { $ws.Cells.Item($row, 3).Value2 = $f[1] }
      $anclas++
    }
  }
  Write-Output "numeracion: C autonoma + $anclas anclas texto"

  # --- CANT/VU/VT por rachas de nivel 5 ---
  $i = 0
  while ($i -lt $n) {
    if ($niv[$i] -eq 5) {
      $j = $i
      while (($j + 1) -lt $n -and $niv[$j + 1] -eq 5) { $j++ }
      $r1 = $i + 3; $r2 = $j + 3
      Retry { $ws.Range("AN$r1`:AN$r2").FormulaR1C1 = '=SUM(RC6:RC39)' }
      Retry { $ws.Range("AO$r1`:AO$r2").FormulaR1C1 = '=SUMIF(PRECIOS_UNITARIOS!C2,RC4,PRECIOS_UNITARIOS!C4)' }
      Retry { $ws.Range("AP$r1`:AP$r2").FormulaR1C1 = '=RC[-2]*RC[-1]' }
      $i = $j + 1
    } else { $i++ }
  }
  Write-Output "formulas CANT(AN)/VU(AO)/VT(AP) colocadas"

  # --- preliminares 2.1: 3,5% por subetapa, VU=1 ---
  $rowPre = 0; $rowIni22 = 0; $rowFinG2 = $last
  $enPre = $false
  for ($i = 0; $i -lt $n; $i++) {
    $f = $lines[$i] -split "`t"
    $row = $i + 3
    if ($niv[$i] -eq 2 -and $f[1] -eq "2.1") { $enPre = $true }
    elseif ($niv[$i] -eq 2) {
      if ($enPre -and $rowIni22 -eq 0) { $rowIni22 = $row }
      $enPre = $false
      if ($f[1] -match '^3\.' -and $rowFinG2 -eq $last) { $rowFinG2 = $row - 1 }
    }
    if ($enPre -and $niv[$i] -eq 5 -and $rowPre -eq 0) { $rowPre = $row }
  }
  Write-Output "preliminares fila=$rowPre base=$rowIni22..$rowFinG2"
  # v2 (reclamo 2026-09-07: "no puede ser 1 el VU..., tiene que ser el
  # 3,5%"): las celdas de subetapa llevan la BASE (costo directo de esa
  # subetapa), VR_UNITARIO = 0,035 mostrado como "3,5%", y VALOR_TOTAL =
  # CANT x VU = el 3,5% real. En la dinamica cada subetapa muestra su
  # 3,5% (CANTIDAD_sub x VU).
  if ($rowPre -gt 0 -and $rowIni22 -gt 0) {
    Retry { $ws.Cells.Item($rowPre, 41).NumberFormat = "0.0%" }
    Retry { $ws.Cells.Item($rowPre, 41).Value2 = 0.035 }
    $fPre = "=SUMPRODUCT(--(R" + $rowIni22 + "C1:R" + $rowFinG2 + "C1=5),R" + $rowIni22 + "C:R" + $rowFinG2 + "C,R" + $rowIni22 + "C41:R" + $rowFinG2 + "C41)"
    Retry { $ws.Range($ws.Cells.Item($rowPre, 6), $ws.Cells.Item($rowPre, 39)).FormulaR1C1 = $fPre }
    Retry { $ws.Range($ws.Cells.Item($rowPre, 6), $ws.Cells.Item($rowPre, 40)).NumberFormat = "#,##0" }
    Write-Output "preliminares: subetapas=base, VU=3,5%, VT=3,5% de la base"
  }

  # --- subtotales de VALOR_TOTAL en capitulos (niveles 1-4, col 42) ---
  $fSub = '=LET(ini,ROW()+1,tope,5000,fin,IFERROR(ini-1+XMATCH(TRUE,INDEX(C1,ini):INDEX(C1,tope)<=RC1),tope),SUMPRODUCT((INDEX(C1,ini):INDEX(C1,fin)=5)*INDEX(C42,ini):INDEX(C42,fin)))'
  $puestos = 0
  for ($i = 0; $i -lt $n; $i++) {
    if ($niv[$i] -ge 1 -and $niv[$i] -le 4) {
      $row = $i + 3
      Retry { $ws.Cells.Item($row, 42).FormulaR1C1 = $fSub }
      $puestos++
    }
  }
  Retry { $ws.Range("AP3:AP$last").NumberFormat = "#,##0" }
  Write-Output "subtotales VT en capitulos: $puestos"

  # --- FORMATO (L1): colores por nivel, bordes, anchos ---
  $colores = @{1 = 0x808080; 2 = 0x99FFFF; 3 = 0xF7DCC4; 4 = 0xD1E8FF }
  Retry { $ws.Range("A3:AP$last").Interior.ColorIndex = -4142 }
  $i = 0
  while ($i -lt $n) {
    $nv = $niv[$i]
    $j = $i
    while (($j + 1) -lt $n -and $niv[$j + 1] -eq $nv) { $j++ }
    $r1 = $i + 3; $r2 = $j + 3
    if ($nv -le 4) {
      $c = $colores[$nv]
      $rng = $ws.Range("A$r1`:AP$r2")
      Retry { $rng.Interior.Color = $c }
      if ($nv -eq 1) { Retry { $rng.Font.Color = 0xFFFFFF; $rng.Font.Bold = $true } }
      elseif ($nv -le 3) { Retry { $rng.Font.Bold = $true } }
    }
    $i = $j + 1
  }
  Retry {
    $b = $ws.Range("C1:AP$last").Borders
    $b.LineStyle = 1; $b.Weight = 2; $b.Color = 0xA6A6A6
  }
  Retry { $ws.Columns("C").ColumnWidth = 14 }
  Retry { $ws.Columns("D").ColumnWidth = 62 }
  Retry { $ws.Columns("E").ColumnWidth = 6 }
  Retry { $ws.Columns("AN:AP").ColumnWidth = 14 }
  Write-Output "colores + bordes + anchos"

  # --- agrupadores: columnas F:AM y ocultar A:B; filas AL FINAL ---
  Retry { $ws.Outline.SummaryRow = 0 }
  Retry { $ws.Outline.SummaryColumn = 0 }
  Retry { $ws.Columns("F:AM").Group() | Out-Null }
  Retry { $ws.Columns("A:B").Hidden = $true }
  $i = 0
  while ($i -lt $n) {
    $nv = $niv[$i]
    $j = $i
    while (($j + 1) -lt $n -and $niv[$j + 1] -eq $nv) { $j++ }
    $r1 = $i + 3; $r2 = $j + 3
    $ol = [math]::Min($nv, 8)
    Retry { $ws.Rows("$r1`:$r2").OutlineLevel = $ol }
    $i = $j + 1
  }
  Write-Output "agrupador de columnas F:AM + A:B ocultas + outline de filas"

  # --- nombre PE_RANGO -> A2:AP5000 ---
  $existe = $null
  try { $existe = $wb.Names.Item("PE_RANGO") } catch {}
  if ($existe) { $existe.Delete() }
  $wb.Names.Add("PE_RANGO", "='POR EJECUTAR'!`$A`$2:`$AP`$5000") | Out-Null
  Write-Output "PE_RANGO = A2:AP5000"

  # --- recalcular y VERIFICAR antes de guardar ---
  $xl.Calculation = -4105
  try { $xl.CalculateFull() } catch { Start-Sleep -Seconds 5; try { $xl.CalculateFull() } catch {} }
  $chk = $ws.Range("AM2:AP2").Value2
  $c39 = [string]$chk[1, 1]; $c40 = [string]$chk[1, 2]; $c41 = [string]$chk[1, 3]; $c42 = [string]$chk[1, 4]
  Write-Output ("verif encabezados: 39=$c39 40=$c40 41=$c41 42=$c42")
  if ($c39 -ne "GEN" -or $c40 -ne "CANTIDAD" -or $c41 -ne "VR_UNITARIO" -or $c42 -ne "VALOR_TOTAL") { throw "VERIFICACION FALLO: encabezados 39-42" }
  # fila pluvial de control: Instalacion PVC flexible 12" tras el capitulo pluvial
  $rowPlu = 0
  for ($i = 0; $i -lt $n; $i++) {
    $f = $lines[$i] -split "`t"
    if ($f[2] -eq "RED DE ALCANTARILLADO PLUVIAL") { $rowPlu = $i + 3 }
    if ($rowPlu -gt 0 -and $f[2] -like "Instalación tubería PVC flexible Ø12*") {
      $r = $i + 3
      $cant = $ws.Cells.Item($r, 40).Value2
      $vu = $ws.Cells.Item($r, 41).Value2
      Write-Output ("verif pluvial fila " + $r + ": CANT=" + $cant + " VU=" + $vu)
      if ([math]::Abs($cant - 5980.02) -gt 0.5) { throw "VERIFICACION FALLO: cantidad pluvial 12 esperada 5980.02" }
      if ($vu -lt 1000) { throw "VERIFICACION FALLO: VU pluvial 12 sin precio" }
      break
    }
  }
  # GEN de control: INSTALACIONES REDES ELECTRICAS (GB, GEN=1)
  for ($i = 0; $i -lt $n; $i++) {
    $f = $lines[$i] -split "`t"
    if ($f[2] -eq "INSTALACIONES REDES ELECTRICAS" -and $f[0] -eq "5") {
      $r = $i + 3
      $gen = $ws.Cells.Item($r, 39).Value2
      $cant = $ws.Cells.Item($r, 40).Value2
      Write-Output ("verif GEN fila " + $r + ": GEN=" + $gen + " CANT=" + $cant)
      if ($gen -ne 1 -or $cant -ne 1) { throw "VERIFICACION FALLO: GEN no suma en CANTIDAD" }
      break
    }
  }
  $xl.EnableEvents = $true
  $xl.ScreenUpdating = $true
  Retry { $wb.Save() }
  $ok = $true
  Write-Output "GUARDADO PE 42 columnas"
} finally {
  if ($wb) { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO (verificacion fallo)" }