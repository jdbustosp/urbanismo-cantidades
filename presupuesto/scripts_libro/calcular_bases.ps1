# Calcula el SUBTOTAL VIVO por ETAPA del grupo 2 (ACTIVIDADES POR EJECUTAR)
# = suma sobre filas nivel 5 de (celdas de subetapa de esa etapa) x VU.
# Compara contra los VU CONGELADOS que hoy usan PGU/CAR/PMT/etc.
# Columnas del TSV: 0=fila, 1=NIVEL, 3=ITEM, 4=DESC, 5=UM, 6..39=subetapas,
# 40=CANTIDAD, 41=VR_UNITARIO, 42=VALOR_TOTAL
$ErrorActionPreference = "Stop"
$sp = Split-Path -Parent $MyInvocation.MyCommand.Path
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
function LeerTsv($nombre) {
  $txt = [System.IO.File]::ReadAllText((Join-Path $sp $nombre), [System.Text.Encoding]::UTF8)
  ,(([System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding(1252).GetBytes($txt))) -split "`r?`n")
}
# codigos de subetapa en orden (indice 0..33 -> columna F..AM)
$codes = @("1","2","3","3A","3B","4","4A","4B","4C","4D","4E","4F","5","5A","5B","5C","5D","5E","5F","5G","6","7","8","8A","8B","8C","8D","9","9A","9B","9C","9D","9E","GEN")
$lineas = LeerTsv "pe_0908.tsv"
# limites del grupo 2
$ini2 = 0; $fin2 = 0
foreach ($l in $lineas) {
  $f = $l -split "`t"
  if ($f.Count -lt 5) { continue }
  $fila = [int]$f[0]
  if ($f[1] -eq "1") {
    if ($f[4] -match '^ACTIVIDADES POR EJECUTAR') { $ini2 = $fila }
    elseif ($ini2 -gt 0 -and $fin2 -eq 0) { $fin2 = $fila - 1 }
  }
}
Write-Output ("grupo 2 (ACTIVIDADES POR EJECUTAR): filas " + $ini2 + ".." + $fin2)

$base = @{}; foreach ($c in $codes) { $base[$c] = 0.0 }
$basePrelim = @{}; foreach ($c in $codes) { $basePrelim[$c] = 0.0 }
$filaPrelim = 0
$n5 = 0
foreach ($l in $lineas) {
  $f = $l -split "`t"
  if ($f.Count -lt 42) { continue }
  $fila = [int]$f[0]
  if ($fila -lt $ini2 -or $fila -gt $fin2) { continue }
  if ($f[1] -ne "5") { continue }
  $n5++
  $vu = 0.0
  if ($f[41] -match '^-?[\d.eE+-]+$') { $vu = [double]$f[41] }
  $esPrelim = ($f[4] -match '^Obras preliminares generales')
  if ($esPrelim) { $filaPrelim = $fila }
  for ($k = 0; $k -lt 34; $k++) {
    $ix = 6 + $k
    if ($ix -ge $f.Count) { continue }
    if ($f[$ix] -match '^-?[\d.eE+-]+$') {
      $v = [double]$f[$ix] * $vu
      $base[$codes[$k]] += $v
      if (-not $esPrelim) { $basePrelim[$codes[$k]] += $v }
    }
  }
}
Write-Output ("filas nivel 5 en grupo 2: " + $n5 + " | fila de preliminares: " + $filaPrelim)

# agrupar por ETAPA (digito inicial del codigo de subetapa; GEN aparte)
function BaseEtapa($tabla, $etapa) {
  $s = 0.0
  foreach ($c in $codes) {
    if ($etapa -eq "GEN") { if ($c -eq "GEN") { $s += $tabla[$c] } }
    elseif ($c -ne "GEN" -and $c.Substring(0,1) -eq $etapa) { $s += $tabla[$c] }
  }
  $s
}
# VU congelados que usan hoy las filas de porcentaje
$congelado = @{
  "1" = 11128725492.3992; "2" = 1828918499.0; "3" = 13208977046.1337;
  "4" = 16487623174.3517; "5" = 29909045493.2993; "7" = 1506894081.77456;
  "8" = 24366374974.3265; "9" = 10226246098.4319; "GEN" = 37488693000.6307 }
Write-Output ""
Write-Output ("ETAPA | base VIVA (con prelim) | base SIN prelim | congelado actual | dif% vs congelado")
$tot = 0.0; $totCong = 0.0
foreach ($e in @("1","2","3","4","5","6","7","8","9","GEN")) {
  $bv = BaseEtapa $base $e
  $bs = BaseEtapa $basePrelim $e
  $cg = if ($congelado.ContainsKey($e)) { $congelado[$e] } else { 0.0 }
  $dif = if ($cg -gt 0) { [math]::Round(100.0 * ($bv - $cg) / $cg, 1) } else { 0.0 }
  $tot += $bv; $totCong += $cg
  Write-Output ("{0,-4} | {1,22:N0} | {2,20:N0} | {3,18:N0} | {4,6}%" -f $e, $bv, $bs, $cg, $dif)
}
Write-Output ("TOTAL| {0,22:N0} |                      | {1,18:N0}" -f $tot, $totCong)