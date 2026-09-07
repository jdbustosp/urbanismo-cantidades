# Transformador v2 (2026-09-07, pedido del usuario):
#  PLUVIAL espejo del sanitario:
#   - "SUMINISTRO E INSTALACION DE TUBERIA (TRAMOS ALL)" (22 refs Hex por
#     banda) se reemplaza por DOS capitulos: SUMINISTRO DE TUBERIAS (UN =
#     ML/6) + INSTALACION DE TUBERIAS (ML), por material+diametro.
#     NOVAFORT usa los nombres del sanitario ("...PVC flexible OX") para
#     heredar precios por SUMIF; concreto queda "en concreto CSR/CCR/CER".
#   - Las 2 tuberias del capitulo SUMIDEROS se BORRAN (fila 962 es copia
#     exacta columna a columna de la 933 = doble conteo del lookup).
#   - "CONSTRUCCIONES EN MAMPOSTERIA Y CONCRETO (TRAMOS ALL)" -> "POZOS
#     DE INSPECCION"; "OBRAS VARIAS" -> "PRUEBAS, INSPECCION Y ENTREGA"
#     (menos "Construccion de biofiltros", superado por BIORETENEDORES).
#   - Capitulos reordenados como el sanitario: SUM / INST / MT / POZOS /
#     SUMIDEROS / BIORET / CABEZALES / OBRAS COMPL / PRUEBAS.
#  ACUEDUCTO espejo del sanitario:
#   - MT sube a 3er capitulo (tras INSTALACION) y sus actividades quedan
#     en el orden del sanitario (comunes primero, especificos despues).
# Entrada: pe_nuevo.tsv   Salida: pe_nuevo2.tsv + pe2_cambios.log
$ErrorActionPreference = "Stop"
$sp = Split-Path -Parent $MyInvocation.MyCommand.Path
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$NSUB = 34

$pe = [System.IO.File]::ReadAllLines((Join-Path $sp "pe_nuevo.tsv"), [System.Text.Encoding]::UTF8)
$log = New-Object System.Collections.Generic.List[string]

# ---------- utilidades ----------
function Campos($l) { ,($l -split "`t") }
function Nivel($l) { ($l -split "`t")[0] }
function Desc($l) { ($l -split "`t")[2] }
function ColsNum($l) {
  $f = $l -split "`t"
  $c = @(0.0) * 34
  for ($k = 0; $k -lt 34; $k++) {
    if ((4 + $k) -lt $f.Count -and $f[4 + $k] -match '^-?[\d.eE+-]+$') { $c[$k] = [double]$f[4 + $k] }
  }
  ,$c
}
function FilaTxt($niv, $desc, $um, $cols) {
  $arr = New-Object System.Collections.Generic.List[string]
  $arr.Add([string]$niv); $arr.Add(""); $arr.Add($desc); $arr.Add($um)
  if ($cols) {
    foreach ($c in $cols) {
      if ([math]::Abs($c) -gt 1e-9) { $arr.Add(($c.ToString("0.##", [System.Globalization.CultureInfo]::InvariantCulture))) } else { $arr.Add("") }
    }
  } else { for ($k = 0; $k -lt 34; $k++) { $arr.Add("") } }
  return ($arr -join "`t")
}

# ---------- particionar en bloques por red (nivel 3) ----------
# bloque = @{hdr=linea nivel<=3; caps=lista de @{hdr=linea nivel4; items=lineas nivel5}}
$idx251ini = -1; $idx251fin = -1; $idx253ini = -1; $idx253fin = -1
for ($i = 0; $i -lt $pe.Count; $i++) {
  $f = $pe[$i] -split "`t"
  if ($f[0] -eq "3" -and $f[1] -eq "2.5.1") { $idx251ini = $i }
  elseif ($idx251ini -ge 0 -and $idx251fin -lt 0 -and [int]$f[0] -le 3 -and $i -gt $idx251ini) { $idx251fin = $i - 1 }
  if ($f[0] -eq "3" -and $f[1] -eq "2.5.3") { $idx253ini = $i }
  elseif ($idx253ini -ge 0 -and $idx253fin -lt 0 -and [int]$f[0] -le 3 -and $i -gt $idx253ini) { $idx253fin = $i - 1 }
}
if ($idx251ini -lt 0 -or $idx253ini -lt 0) { throw "no encontre 2.5.1 / 2.5.3" }
Write-Output ("2.5.1: lineas " + ($idx251ini + 1) + ".." + ($idx251fin + 1) + " | 2.5.3: " + ($idx253ini + 1) + ".." + ($idx253fin + 1))

function Capitulos($ini, $fin) {
  $caps = New-Object System.Collections.Generic.List[object]
  $cur = $null
  for ($i = $ini + 1; $i -le $fin; $i++) {
    $niv = ($pe[$i] -split "`t")[0]
    if ($niv -eq "4") {
      $cur = @{ hdr = $pe[$i]; items = (New-Object System.Collections.Generic.List[string]) }
      $caps.Add($cur)
    } elseif ($cur) { $cur.items.Add($pe[$i]) }
  }
  ,$caps
}

# ---------- 2.5.3 PLUVIAL ----------
$caps253 = Capitulos $idx253ini $idx253fin
$capTUB = $null; $capMAMP = $null; $capSUMID = $null; $capVARIAS = $null
$capCOMPL = $null; $capMT = $null; $capBIO = $null; $capCABE = $null
foreach ($c in $caps253) {
  $d = Desc $c.hdr
  if ($d -match '^SUMINISTRO E INSTALACI.N DE TUBER.A') { $capTUB = $c }
  elseif ($d -match '^CONSTRUCCIONES EN MAMPOSTER.A') { $capMAMP = $c }
  elseif ($d -match 'SUMIDEROS') { $capSUMID = $c }
  elseif ($d -match '^OBRAS VARIAS') { $capVARIAS = $c }
  elseif ($d -match '^OBRAS COMPLEMENTARIAS') { $capCOMPL = $c }
  elseif ($d -match '^MOVIMIENTO DE TIERRAS') { $capMT = $c }
  elseif ($d -match '^BIORETENEDORES') { $capBIO = $c }
  elseif ($d -match '^CABEZALES') { $capCABE = $c }
  else { throw ("capitulo pluvial no clasificado: " + $d) }
}
foreach ($p in @(@("TUB",$capTUB),@("MAMP",$capMAMP),@("SUMID",$capSUMID),@("VARIAS",$capVARIAS),@("COMPL",$capCOMPL),@("MT",$capMT),@("BIO",$capBIO),@("CABE",$capCABE))) {
  if (-not $p[1]) { throw ("falta capitulo pluvial " + $p[0]) }
}

# acumular tuberias del capitulo TRAMOS ALL por material+diametro
$acum = @{}; $catalogo = New-Object System.Collections.Generic.List[string]
$mlIn = 0.0
foreach ($l in $capTUB.items) {
  $d = Desc $l
  if ($d -notmatch '^Tuber.a (NOVAFORT|CCR|CER|CSR) (\d+)"') { throw ("ref inesperada en TRAMOS ALL: " + $d) }
  $key = $Matches[1] + "|" + $Matches[2]
  if (-not $acum.ContainsKey($key)) { $acum[$key] = @(0.0) * $NSUB; $catalogo.Add($key) }
  $cols = ColsNum $l
  for ($k = 0; $k -lt $NSUB; $k++) { $acum[$key][$k] += $cols[$k]; $mlIn += $cols[$k] }
}
# tuberias del capitulo SUMIDEROS: solo aportan el diametro al catalogo
# (sus cantidades son el DOBLE CONTEO ya verificado; se descartan)
$itemsSumid = New-Object System.Collections.Generic.List[string]
foreach ($l in $capSUMID.items) {
  $d = Desc $l
  if ($d -match '^Tuber.a (NOVAFORT|CCR|CER|CSR) (\d+)"') {
    $key = $Matches[1] + "|" + $Matches[2]
    if (-not $acum.ContainsKey($key)) { $acum[$key] = @(0.0) * $NSUB; $catalogo.Add($key) }
    $log.Add("PLUVIAL sumideros: eliminada '" + $d + "' (duplicado exacto del capitulo de tramos = doble conteo)")
  } else { $itemsSumid.Add($l) }
}
# ordenar catalogo: material (NOVAFORT,CSR,CCR,CER) y diametro ascendente
$ordMat = @{ "NOVAFORT" = 1; "CSR" = 2; "CCR" = 3; "CER" = 4 }
$catOrd = $catalogo | Sort-Object @{e={ $ordMat[($_ -split '\|')[0]] }}, @{e={ [int](($_ -split '\|')[1]) }}

function NombreTub($pref, $key) {
  $mat = ($key -split '\|')[0]; $dia = ($key -split '\|')[1]
  if ($mat -eq "NOVAFORT") { return ($pref + ' tubería PVC flexible Ø' + $dia + '"') }
  return ($pref + ' tubería en concreto ' + $mat + ' Ø' + $dia + '"')
}

$out253 = New-Object System.Collections.Generic.List[string]
$out253.Add($pe[$idx253ini])
# 1) SUMINISTRO (UN = ML/6, redondeado a 2)
$out253.Add((FilaTxt 4 "SUMINISTRO DE TUBERÍAS" "" $null))
foreach ($key in $catOrd) {
  $c = @(0.0) * $NSUB
  for ($k = 0; $k -lt $NSUB; $k++) { $c[$k] = [math]::Round($acum[$key][$k] / 6.0, 2) }
  $out253.Add((FilaTxt 5 (NombreTub "Suministro" $key) "UN" $c))
}
# 2) INSTALACION (ML)
$mlOut = 0.0
$out253.Add((FilaTxt 4 "INSTALACIÓN DE TUBERÍAS" "" $null))
foreach ($key in $catOrd) {
  foreach ($v in $acum[$key]) { $mlOut += $v }
  $out253.Add((FilaTxt 5 (NombreTub "Instalación" $key) "ML" $acum[$key]))
}
$log.Add(("PLUVIAL: 22 refs Hex + 2 de sumideros -> " + $catOrd.Count + " suministros (UN) + " + $catOrd.Count + " instalaciones (ML); ML control in=" + [math]::Round($mlIn,2) + " out=" + [math]::Round($mlOut,2)))
# 3) MT (ya es espejo del sanitario) sube al 3er lugar
$out253.Add($capMT.hdr); foreach ($l in $capMT.items) { $out253.Add($l) }
# 4) POZOS DE INSPECCION (renombrado)
$fm = Campos $capMAMP.hdr; $fm[2] = "POZOS DE INSPECCIÓN"
$out253.Add(($fm -join "`t")); foreach ($l in $capMAMP.items) { $out253.Add($l) }
$log.Add("PLUVIAL: 'CONSTRUCCIONES EN MAMPOSTERIA Y CONCRETO (TRAMOS ALL)' -> 'POZOS DE INSPECCION' (espejo sanitario)")
# 5) SUMIDEROS (sin las tuberias duplicadas)
$out253.Add($capSUMID.hdr); foreach ($l in $itemsSumid) { $out253.Add($l) }
# 6) BIORETENEDORES Y BIOSWALES
$out253.Add($capBIO.hdr); foreach ($l in $capBIO.items) { $out253.Add($l) }
# 7) CABEZALES DE DESCARGA
$out253.Add($capCABE.hdr); foreach ($l in $capCABE.items) { $out253.Add($l) }
# 8) OBRAS COMPLEMENTARIAS DE DRENAJE
$out253.Add($capCOMPL.hdr); foreach ($l in $capCOMPL.items) { $out253.Add($l) }
# 9) PRUEBAS, INSPECCION Y ENTREGA (ex OBRAS VARIAS, sin biofiltros)
$fv = Campos $capVARIAS.hdr; $fv[2] = "PRUEBAS, INSPECCIÓN Y ENTREGA"
$out253.Add(($fv -join "`t"))
foreach ($l in $capVARIAS.items) {
  if ((Desc $l) -match '^Construcci.n de biofiltros') {
    $log.Add("PLUVIAL: eliminada 'Construccion de biofiltros' (cantidad 0; superada por el capitulo BIORETENEDORES Y BIOSWALES)")
    continue
  }
  $out253.Add($l)
}
$log.Add("PLUVIAL: capitulos reordenados como sanitario (SUM/INST/MT/POZOS/SUMIDEROS/BIORET/CABEZALES/OBRAS COMPL/PRUEBAS); 'OBRAS VARIAS' -> 'PRUEBAS, INSPECCION Y ENTREGA'")

# ---------- 2.5.1 ACUEDUCTO ----------
$caps251 = Capitulos $idx251ini $idx251fin
$out251 = New-Object System.Collections.Generic.List[string]
$out251.Add($pe[$idx251ini])
$capMT1 = $null; $resto = New-Object System.Collections.Generic.List[object]
foreach ($c in $caps251) {
  if ((Desc $c.hdr) -match '^MOVIMIENTO DE TIERRAS') { $capMT1 = $c } else { $resto.Add($c) }
}
if (-not $capMT1) { throw "falta MT acueducto" }
$orden = @(
  "Localización y replanteo topográfico",
  "Excavación mecánica en material común",
  "Excavación manual en material común",
  "Excavación en conglomerado",
  "Cargue, transporte y disposición de sobrantes",
  "Geotextil NT 1600",
  "Entibado continuo E-1A, H≤2,00 m",
  "Entibado continuo E-1B, 2,00<H≤3,00 m",
  "Entibado E-2, H>3,00 m",
  "Cinta de señalización",
  "Cárcamo o placa de protección para tubería (Red de acueducto)",
  "Cama y atraque en arena de peña",
  "Relleno inicial alrededor de tubería",
  "Suministro y colocación de recebo B-200",
  "Relleno con material seleccionado de excavación")
$mtOrd = New-Object System.Collections.Generic.List[string]
$usadas = New-Object System.Collections.Generic.List[int]
foreach ($o in $orden) {
  for ($i = 0; $i -lt $capMT1.items.Count; $i++) {
    if (-not $usadas.Contains($i) -and (Desc $capMT1.items[$i]) -eq $o) { $mtOrd.Add($capMT1.items[$i]); $usadas.Add($i); break }
  }
}
for ($i = 0; $i -lt $capMT1.items.Count; $i++) { if (-not $usadas.Contains($i)) { $mtOrd.Add($capMT1.items[$i]) } }
if ($mtOrd.Count -ne $capMT1.items.Count) { throw "MT acueducto: conteo no cuadra" }
$nCap = 0
foreach ($c in $resto) {
  $out251.Add($c.hdr); foreach ($l in $c.items) { $out251.Add($l) }
  $nCap++
  if ($nCap -eq 2) {   # tras INSTALACION DE TUBERIAS entra el MT
    $out251.Add($capMT1.hdr); foreach ($l in $mtOrd) { $out251.Add($l) }
  }
}
$log.Add("ACUEDUCTO: MT sube al 3er capitulo (tras INSTALACION, como sanitario) y sus " + $mtOrd.Count + " actividades quedan en el orden del sanitario (comunes primero; manejo de aguas/demoliciones/reposiciones al final)")

# ---------- ensamblar ----------
$final = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $idx251ini; $i++) { $final.Add($pe[$i]) }
foreach ($l in $out251) { $final.Add($l) }
for ($i = $idx251fin + 1; $i -lt $idx253ini; $i++) { $final.Add($pe[$i]) }
foreach ($l in $out253) { $final.Add($l) }
for ($i = $idx253fin + 1; $i -lt $pe.Count; $i++) { $final.Add($pe[$i]) }

[System.IO.File]::WriteAllLines((Join-Path $sp "pe_nuevo2.tsv"), $final, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllLines((Join-Path $sp "pe2_cambios.log"), $log, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("filas: " + $final.Count + " (antes " + $pe.Count + ")")
foreach ($x in $log) { Write-Output ("  * " + $x) }