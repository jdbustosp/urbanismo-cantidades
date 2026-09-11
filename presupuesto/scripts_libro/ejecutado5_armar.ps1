# Arma la tabla EJECUTADO de 5 niveles (2026-09-11, pedido del usuario, v3).
#  N1 1 EJECUTADO | N2 categoria (EJECUTADO ACTAS / COINVER / PAYC) |
#  N3 capitulo | N4 ACTA | N5 CONTRATISTA
#  BASE = cada pago del ARCHIVO DE ACTAS (hoja "Consolidado Jul 2026").
#  EJECUTADO    = VALOR del pago en el archivo de actas. Total = el
#                 EJECUTADO de la hoja Resumen (158.872.558.615).
#  DESEMBOLSADO = "VR TOTAL EJEC Coinver y PYC" de la BD de Lugel (su
#                 dinamica lo llama "VR DESEM. FOVIS") para ese mismo pago;
#                 0 si el pago aun no esta en la BD.
#  Categoria/capitulo: los de la BD de Lugel para ese pago; si el pago no
#  esta en la BD o Lugel lo tiene en una categoria que no es de las tres
#  (4 por ejecutar / 6 humedales / 7 indirectos): COINVER S.A -> COINVER,
#  PAYC SAS -> PAYC, el resto -> EJECUTADO ACTAS.
param([string]$dir = $PSScriptRoot)
$ErrorActionPreference = "Stop"
$ci = [System.Globalization.CultureInfo]::InvariantCulture
function N($s) { $d = 0.0; if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $ci, [ref]$d)) { $d } else { 0.0 } }
function Llave([string]$s) {
  $s = ([regex]::Replace($s, '\s+', ' ')).Trim().ToUpperInvariant()
  $n = $s.Normalize([Text.NormalizationForm]::FormD)
  (-join ($n.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' }))
}
function Limpio([string]$s) { ([regex]::Replace($s, '\s+', ' ')).Trim() }

$PREVIAS = '1. ACTAS PREVIAS (1268 - 1280 - 1299 - 1305)'
$POSTER  = '2. ACTAS POSTERIORES A LA 1305'
$PAYC3   = '1. HONORARIOS Y REEMBOLSABLES PAYC'
$N1      = '1 EJECUTADO'
$N2A = '1. EJECUTADO ACTAS'; $N2C = '2. PRESUPUESTO COINVER'; $N2P = '3. PRESUPUESTO PAYC'
function N3Acta([string]$acta) { if (@('1268','1280','1299','1305') -contains $acta) { $PREVIAS } else { $POSTER } }

# ---------------- BD de Lugel: pagos con acta (todas las categorias) ----------------
$bd = New-Object System.Collections.Generic.List[object]
foreach ($ln in (Get-Content (Join-Path $dir 'bd.tsv') -Encoding UTF8 | Select-Object -Skip 3)) {
  $t = $ln.Split("`t"); while ($t.Length -lt 36) { $t += '' }
  if ($t[2] -eq '' -or $t[12] -eq '') { continue }
  $bd.Add([pscustomobject]@{ acta=$t[2]; clas=(Limpio $t[3]); ter=(Limpio $t[4]); valor=(N $t[8]); c1=$t[12]; c2=$t[13];
        est=$t[22]; por=$t[23]; desem=(N $t[25]); ant=(N $t[28]); usado=$false })
}

# ---------------- base: archivo de actas ----------------
$actas = New-Object System.Collections.Generic.List[object]
foreach ($ln in (Get-Content (Join-Path $dir 'actas_cons.tsv') -Encoding UTF8 | Select-Object -Skip 1)) {
  $x = $ln.Split("`t"); if ($x.Length -lt 8 -or $x[1] -notmatch '^\d{4}$') { continue }
  $actas.Add([pscustomobject]@{ acta=$x[1]; clas=(Limpio $x[2]); ter=(Limpio $x[3]); nit=(Limpio $x[4]); desc=(Limpio $x[5]);
        fecha=$x[6]; val=(N $x[7]); ano=$x[8]; m=$null })
}
# 1) acta + tercero + valor
foreach ($a in $actas) {
  $m = $bd | Where-Object { -not $_.usado -and $_.acta -eq $a.acta -and (Llave $_.ter) -eq (Llave $a.ter) -and [math]::Abs($_.valor - $a.val) -lt 1 } | Select-Object -First 1
  if ($m) { $m.usado = $true; $a.m = $m }
}
# 2) acta + valor (mismo pago con el tercero escrito distinto en la BD)
$renombres = New-Object System.Collections.Generic.List[string]
foreach ($a in ($actas | Where-Object { $null -eq $_.m })) {
  $m = $bd | Where-Object { -not $_.usado -and $_.acta -eq $a.acta -and [math]::Abs($_.valor - $a.val) -lt 1 } | Select-Object -First 1
  if ($m) { $m.usado = $true; $a.m = $m; $renombres.Add("$($m.ter) (BD) = $($a.ter) (actas)") }
}

$filas = New-Object System.Collections.Generic.List[object]
foreach ($a in $actas) {
  $m = $a.m; $nota = @()
  $kt = Llave $a.ter; $kc = Llave $a.clas
  if ($m -and $m.c1 -match '^[123]\.') { $c1 = $m.c1; $c2 = $m.c2 }
  else {
    if ($m) { $nota += ('En la BD de Lugel esta en ' + $m.c1) }
    if ($kt -match '^COINVER') {
      $c1 = '2.'; $c2 = if ($kc -match 'ADMIN') { '5. REEMBOLSABLES' } elseif ($kc -match 'RED 24|RED DE 24') { '2. RED MATRIZ' } elseif ($kc -match 'PTAR') { '3. PTAR' } else { '1. URBANISMO' }
    } elseif ($kt -match '^PAYC') { $c1 = '3.'; $c2 = $PAYC3 }
    else { $c1 = '1.'; $c2 = '' }
  }
  switch -Regex ($c1) {
    '^1\.' { $n2 = $N2A; $n3 = N3Acta $a.acta }
    '^2\.' { $n2 = $N2C; $n3 = $c2 }
    '^3\.' { $n2 = $N2P; $n3 = $PAYC3 }
  }
  if (-not $m) { $nota += 'Pago del archivo de actas jul/2026 que no esta en la BD de Lugel: sin desembolso registrado' }
  $n5 = Limpio $a.ter
  if ((Llave $n5) -eq (Llave 'ALVAREZ LAGOS VICTOR')) { $n5 = 'VICTOR ALVAREZ LAGOS' }
  $filas.Add([pscustomobject]@{ n2=$n2; n3=$n3; acta=$a.acta; n5=$n5; ejec=$a.val;
      desem=$(if ($m) { $m.desem } else { 0.0 }); ant=$(if ($m) { $m.ant } else { 0.0 });
      clas=$a.clas; ter=$a.ter; nit=$a.nit; desc=$a.desc; fecha=$a.fecha; ano=$a.ano;
      est=$(if ($m) { $m.est } else { '' }); por=$(if ($m) { $m.por } else { '' }); nota=($nota -join ' | ') })
}

# ---------------- salida ----------------
$ord = $filas | Sort-Object n2, n3, @{e={[int]$_.acta}}, n5, fecha
$hdr = 'NIVEL1','NIVEL2','NIVEL3','NIVEL4','NIVEL5','ETAPA','SUBETAPA','EJECUTADO','DESEMBOLSADO','VR_TOTAL_ANT_BD','ACTA','CLASIFICACION','TERCERO','NIT','DESCRIPCION_ACTA','FECHA','ANO_ACTA','ESTADO','EJECUTADO_POR','NOTA'
$out = New-Object System.Collections.Generic.List[string]
$out.Add(($hdr -join "`t"))
foreach ($r in $ord) {
  $out.Add((@($N1, $r.n2, $r.n3, $r.acta, $r.n5, 'GENERAL', 'GENERAL',
      $r.ejec.ToString('0.##', $ci), $r.desem.ToString('0.##', $ci), $r.ant.ToString('0.##', $ci), $r.acta, $r.clas, $r.ter, $r.nit,
      ($r.desc -replace "`t",' '), $r.fecha, $r.ano, $r.est, $r.por, $r.nota) -join "`t"))
}
[System.IO.File]::WriteAllLines((Join-Path $dir 'ejecutado_nuevo.tsv'), $out, (New-Object System.Text.UTF8Encoding($false)))

"filas: " + $ord.Count + " | sin pago en la BD: " + ($actas | Where-Object { $null -eq $_.m }).Count
"filas de la BD con acta que no aparecen en el archivo de actas: " + ($bd | Where-Object { -not $_.usado }).Count
"mismo pago con otro nombre en la BD (queda el del archivo de actas):"; $renombres | Sort-Object -Unique | ForEach-Object { "  $_" }
"pagos que Lugel tiene en categorias 4/6/7 (entran a EJECUTADO ACTAS):"
$actas | Where-Object { $_.m -and $_.m.c1 -notmatch '^[123]\.' } | Group-Object { $_.acta + ' ' + $_.clas + ' <- ' + $_.m.c1 } | ForEach-Object { "  {0,-90} n={1,3} {2,16:N0}" -f $_.Name, $_.Count, ($_.Group | Measure-Object val -Sum).Sum }
"pagos que no estan en la BD:"
$actas | Where-Object { $null -eq $_.m } | Group-Object { $_.acta + ' ' + $_.clas } | ForEach-Object { "  {0,-50} n={1,3} {2,16:N0}" -f $_.Name, $_.Count, ($_.Group | Measure-Object val -Sum).Sum }
"--- por categoria"
$ord | Group-Object n2 | ForEach-Object { "{0,-28} EJECUTADO={1,20:N0} DESEMBOLSADO={2,20:N0}" -f $_.Name, ($_.Group | Measure-Object ejec -Sum).Sum, ($_.Group | Measure-Object desem -Sum).Sum }
"{0,-28} EJECUTADO={1,20:N0} DESEMBOLSADO={2,20:N0}" -f 'TOTAL', ($ord | Measure-Object ejec -Sum).Sum, ($ord | Measure-Object desem -Sum).Sum
"--- por acta"
$ord | Group-Object acta | Sort-Object Name | ForEach-Object { "{0,-6} EJ={1,18:N0} DES={2,18:N0}" -f $_.Name, ($_.Group | Measure-Object ejec -Sum).Sum, ($_.Group | Measure-Object desem -Sum).Sum }
"--- filas con ejecutado < desembolsado: " + ($ord | Where-Object { $_.ejec -lt $_.desem - 0.5 }).Count
"--- totales para verificar: EJECUTADO=" + ($ord | Measure-Object ejec -Sum).Sum.ToString('0.##', $ci) + " DESEMBOLSADO=" + ($ord | Measure-Object desem -Sum).Sum.ToString('0.##', $ci)
