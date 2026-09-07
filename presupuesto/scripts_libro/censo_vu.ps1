# Censo 2026-09-07 tarde: (1) actividades nivel 5 SIN precio en PU
# (SUMIF exacto = 0), (2) filas con cantidad 0 por capitulo (candidatas
# "no van"), (3) memorias ACUEDUCTO de MT que llenaran el MT tras el
# export v4.71, (4) VU por capitulo para el barrido de coherencia.
# OJO extractor: col 0 = numero de fila; el texto viene doble-codificado
# (UTF-8 leido como 1252) -> se repara al leer.
$ErrorActionPreference = "Stop"
$sp = Split-Path -Parent $MyInvocation.MyCommand.Path
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function LeerTsv($nombre) {
  $txt = [System.IO.File]::ReadAllText((Join-Path $sp $nombre), [System.Text.Encoding]::UTF8)
  $bytes = [System.Text.Encoding]::GetEncoding(1252).GetBytes($txt)
  $txt = [System.Text.Encoding]::UTF8.GetString($bytes)
  ,($txt -split "`r?`n")
}

# --- PU: desc -> precio (cols: 0 fila, 1 cat, 2 desc, 3 um, 4 precio) ---
$pu = @{}
$first = $true
foreach ($l in (LeerTsv "pu_live.tsv")) {
  if ($first) { $first = $false; continue }
  $f = $l -split "`t"
  if ($f.Count -ge 5 -and $f[2]) {
    $v = 0.0
    if ($f[4] -match '^-?[\d.eE+]+$') { $v = [double]$f[4] }
    if ($pu.ContainsKey($f[2])) { $pu[$f[2]] += $v } else { $pu[$f[2]] = $v }
  }
}
Write-Output ("PU descs: " + $pu.Count)

# --- PE (cols: 0 fila, 1 nivel, 4 desc, 5 um, 6..39 sub, 40 cant, 41 vu) ---
$sinPrecio = New-Object System.Collections.Generic.List[string]
$cero = New-Object System.Collections.Generic.List[string]
$vuLista = New-Object System.Collections.Generic.List[string]
$n3 = ""; $n4 = ""
$first = $true; $fila = 0
foreach ($l in (LeerTsv "pe42_live.tsv")) {
  $f = $l -split "`t"
  if ($f.Count -lt 6) { continue }
  $fila = [int]$f[0]
  if ($fila -le 2) { continue }
  $niv = $f[1]; $desc = $f[4]; $um = $f[5]
  if ($niv -eq "3") { $n3 = $desc }
  if ($niv -eq "4") { $n4 = $desc }
  if ($niv -ne "5") { continue }
  $cant = 0.0
  if ($f.Count -ge 41 -and $f[40] -match '^-?[\d.eE+]+$') { $cant = [double]$f[40] }
  $vu = 0.0
  if ($pu.ContainsKey($desc)) { $vu = $pu[$desc] }
  if ($vu -lt 1) {
    $sinPrecio.Add(("fila {0}`t{1} > {2}`tCANT={3}`t[{4}] {5}" -f $fila, $n3, $n4, [math]::Round($cant,2), $um, $desc))
  }
  if ($cant -eq 0.0) {
    $cero.Add(("fila {0}`t{1} > {2}`t[{3}] {4}" -f $fila, $n3, $n4, $um, $desc))
  }
  $vuLista.Add(("{0}`t{1}`t{2}`t{3}`t{4}`t{5}" -f $fila, $n3, $n4, $um, [math]::Round($vu,0), $desc))
}
[System.IO.File]::WriteAllLines((Join-Path $sp "censo_sin_precio.txt"), $sinPrecio, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllLines((Join-Path $sp "censo_cant_cero.txt"), $cero, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllLines((Join-Path $sp "censo_vu_todo.txt"), $vuLista, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("nivel5 SIN PRECIO: " + $sinPrecio.Count + " (censo_sin_precio.txt)")
Write-Output ("nivel5 CANTIDAD 0: " + $cero.Count + " (censo_cant_cero.txt)")

# --- memorias ACUEDUCTO de zanja (cols: 0 fila, 1 RED, 3 ESPEC, 10 CANT) ---
$acum = @{}
foreach ($l in (LeerTsv "vig_memorias.tsv")) {
  $f = $l -split "`t"
  if ($f.Count -ge 11 -and $f[1] -eq "ACUEDUCTO") {
    $esp = $f[3]
    if ($esp -match 'Cimentaci|recebo|sobrantes|Entibado|Excavaci|gravilla|arena|Carcamo|Cinta') {
      $q = 0.0
      if ($f[10] -match '^-?[\d.eE+]+$') { $q = [double]$f[10] }
      if ($acum.ContainsKey($esp)) { $acum[$esp] += $q } else { $acum[$esp] = $q }
    }
  }
}
Write-Output "--- memorias ACUEDUCTO de zanja (TablaMemorias actual, sumadas) ---"
foreach ($k in ($acum.Keys | Sort-Object)) { Write-Output ("  " + $k + " = " + [math]::Round($acum[$k], 2)) }