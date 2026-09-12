param([string]$libro, [string]$idu, [string]$out)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
function Norm([string]$s) {
  if (-not $s) { return "" }
  $t = $s.ToLowerInvariant().Trim().Normalize([Text.NormalizationForm]::FormD)
  $sb2 = New-Object System.Text.StringBuilder
  foreach ($ch in $t.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$sb2.Append($ch)
    }
  }
  $t = $sb2.ToString() -replace '[^a-z0-9]+', ' '
  ($t -replace '\s+', ' ').Trim()
}

# ---- referencia IDU 2026-I ----
$ref = @{}
$lineas = [System.IO.File]::ReadAllLines($idu, [System.Text.Encoding]::UTF8)
for ($i = 1; $i -lt $lineas.Count; $i++) {
  $c = $lineas[$i] -split "`t"
  if ($c.Count -lt 8) { continue }
  $k = Norm $c[0]
  if ($k -eq "") { continue }
  if (-not $ref.ContainsKey($k)) {
    $vu = 0.0
    if ($c[5] -ne "") { try { $vu = [double]::Parse($c[5], [Globalization.CultureInfo]::InvariantCulture) } catch {} }
    $rt = 0.0
    if ($c[6] -ne "") { try { $rt = [double]::Parse($c[6], [Globalization.CultureInfo]::InvariantCulture) } catch {} }
    $ref[$k] = [pscustomobject]@{ Idu = $c[2]; Tipo = $c[3]; UmIdu = $c[4]; VuIdu = $vu; Ratio = $rt; Bandera = $c[7] }
  }
}
"referencia IDU cargada: " + $ref.Count + " actividades"

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$sb = New-Object System.Text.StringBuilder
function W($s) { [void]$sb.AppendLine($s) }
try {
  $wb = Retry { $xl.Workbooks.Open($libro, 0, $true) }
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = Retry { $wb.Worksheets.Item("POR EJECUTAR") }
  $ultima = $ws.UsedRange.Row + $ws.UsedRange.Rows.Count - 1
  $arr = $ws.Range("A1:AP" + $ultima).Value2
  # A=1 NIVEL, C=3 ITEM, D=4 DESCRIPCION, E=5 UM, AN=40 CANTIDAD, AO=41 VU
  $items = @()
  for ($r = 1; $r -le $ultima; $r++) {
    if ([string]$arr[$r, 1] -ne "5") { continue }
    $d = ([string]$arr[$r, 4]).Trim()
    if ($d -eq "") { continue }
    $cant = 0.0; $vu = 0.0
    try { $cant = [double]$arr[$r, 40] } catch {}
    try { $vu = [double]$arr[$r, 41] } catch {}
    $nm = Norm $d
    $rr = $null
    if ($ref.ContainsKey($nm)) { $rr = $ref[$nm] }
    $items += [pscustomobject]@{
      Fila = $r; Item = ([string]$arr[$r, 3]).Trim(); Desc = $d; UM = ([string]$arr[$r, 5]).Trim()
      Cant = $cant; Vu = [math]::Round($vu, 2); Norm = $nm
      Idu = if ($rr) { $rr.Idu } else { "" }
      VuIdu = if ($rr) { $rr.VuIdu } else { 0.0 }
      Ratio = if ($rr) { $rr.Ratio } else { 0.0 }
      Bandera = if ($rr) { $rr.Bandera } else { "sin referencia" }
    }
  }
  W ("actividades nivel 5: " + $items.Count)
  $vt = 0.0
  foreach ($x in $items) { $vt += ($x.Cant * $x.Vu) }
  W ("valor total nivel 5 hoy: " + [math]::Round($vt))

  # ---- A) que pasaria aplicando el precio IDU donde HAY referencia ----
  W ""
  W "== A) EFECTO DE APLICAR EL PRECIO IDU 2026 DONDE HAY REFERENCIA =="
  $porBandera = @{}
  foreach ($x in $items) {
    $b = $x.Bandera
    if (-not $porBandera.ContainsKey($b)) { $porBandera[$b] = [pscustomobject]@{ N = 0; Delta = 0.0; Base = 0.0 } }
    $porBandera[$b].N++
    $porBandera[$b].Base += ($x.Cant * $x.Vu)
    if ($x.VuIdu -gt 0) { $porBandera[$b].Delta += ($x.Cant * ($x.VuIdu - $x.Vu)) }
  }
  W "bandera`tactividades`tvalor actual`tdelta si se aplica IDU"
  foreach ($k in ($porBandera.Keys | Sort-Object)) {
    W ($k + "`t" + $porBandera[$k].N + "`t" + [math]::Round($porBandera[$k].Base) + "`t" +
       [math]::Round($porBandera[$k].Delta))
  }

  # ---- B) grupos con el MISMO nombre normalizado y precio distinto ----
  W ""
  W "== B) MISMO NOMBRE, PRECIO DISTINTO (hay que unificar) =="
  W "nombre`tvariantes`tprecios`tprecio IDU`tbandera`tpropuesto`tdelta"
  $nB = 0; $deltaB = 0.0
  foreach ($g in ($items | Group-Object Norm)) {
    $precios = @($g.Group | Select-Object -ExpandProperty Vu -Unique)
    $textos = @($g.Group | Select-Object -ExpandProperty Desc -Unique)
    if ($precios.Count -le 1 -and $textos.Count -le 1) { continue }
    $uno = $g.Group[0]
    # precio propuesto: IDU si la bandera es ok; si no, el mas usado
    $prop = 0.0
    if ($uno.VuIdu -gt 0 -and $uno.Bandera -like "ok*") {
      $prop = $uno.VuIdu
    } else {
      $prop = ($g.Group | Group-Object Vu | Sort-Object Count -Descending | Select-Object -First 1).Name
      $prop = [double]$prop
    }
    $d = 0.0
    foreach ($x in $g.Group) { $d += ($x.Cant * ($prop - $x.Vu)) }
    $nB++; $deltaB += $d
    W ($g.Name + "`t" + ($textos -join " | ") + "`t" + ($precios -join " | ") + "`t" +
       $uno.VuIdu + "`t" + $uno.Bandera + "`t" + [math]::Round($prop, 2) + "`t" + [math]::Round($d))
  }
  W ("grupos: $nB | delta total: " + [math]::Round($deltaB))

  # ---- C) familias con nombre parecido, misma UM y precio distinto ----
  W ""
  W "== C) FAMILIAS PARECIDAS CON PRECIO DISTINTO (revisar a mano) =="
  W "familia`tactividad`tUM`tVU libro`tVU IDU`tratio`tbandera`tveces"
  $stop = @("suministro", "e", "de", "del", "la", "el", "los", "las", "y", "en", "con",
            "para", "por", "un", "una", "al", "mo", "m", "o", "instalacion", "colocacion")
  $conFam = $items | ForEach-Object {
    $pal = @($_.Norm -split ' ' | Where-Object { $_ -and ($stop -notcontains $_) })
    $fam = if ($pal.Count -ge 2) { $pal[0] + " " + $pal[1] } elseif ($pal.Count -eq 1) { $pal[0] } else { "?" }
    $_ | Add-Member -NotePropertyName Fam -NotePropertyValue $fam -PassThru
  }
  $nC = 0
  foreach ($g in ($conFam | Group-Object Fam | Sort-Object Name)) {
    $distintas = @($g.Group | Group-Object Norm)
    if ($distintas.Count -lt 2) { continue }
    # solo interesa si comparten UM y tienen precios distintos
    $ums = @($g.Group | Select-Object -ExpandProperty UM -Unique)
    $precios = @($g.Group | Select-Object -ExpandProperty Vu -Unique)
    if ($ums.Count -ne 1 -or $precios.Count -lt 2) { continue }
    $nC++
    foreach ($d in $distintas) {
      $u = $d.Group[0]
      W ($g.Name + "`t" + $u.Desc + "`t" + $u.UM + "`t" + $u.Vu + "`t" + $u.VuIdu + "`t" +
         $u.Ratio + "`t" + $u.Bandera + "`t" + $d.Count)
    }
  }
  W ("familias a revisar: $nC")
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
"escrito: $out"
