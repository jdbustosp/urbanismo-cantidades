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
$ref = @{}
$lineas = [System.IO.File]::ReadAllLines($idu, [System.Text.Encoding]::UTF8)
for ($i = 1; $i -lt $lineas.Count; $i++) {
  $c = $lineas[$i] -split "`t"
  if ($c.Count -lt 8) { continue }
  $k = Norm $c[0]
  if ($k -eq "" -or $ref.ContainsKey($k)) { continue }
  $vu = 0.0
  if ($c[5] -ne "") { try { $vu = [double]::Parse($c[5], [Globalization.CultureInfo]::InvariantCulture) } catch {} }
  $ref[$k] = [pscustomobject]@{ Idu = $c[2]; Tipo = $c[3]; UmIdu = $c[4]; VuIdu = $vu; Bandera = $c[7] }
}
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
  $filas = @()
  for ($r = 1; $r -le $ultima; $r++) {
    if ([string]$arr[$r, 1] -ne "5") { continue }
    $d = ([string]$arr[$r, 4]).Trim()
    if ($d -eq "") { continue }
    $nm = Norm $d
    if (-not $ref.ContainsKey($nm)) { continue }
    $rr = $ref[$nm]
    if ($rr.Bandera -ne "ok") { continue }
    if ($rr.VuIdu -le 0) { continue }
    $cant = 0.0; $vu = 0.0
    try { $cant = [double]$arr[$r, 40] } catch {}
    try { $vu = [double]$arr[$r, 41] } catch {}
    $filas += [pscustomobject]@{
      Fila = $r; Item = ([string]$arr[$r, 3]).Trim(); Desc = $d; UM = ([string]$arr[$r, 5]).Trim()
      UmIdu = $rr.UmIdu; Cant = $cant; Vu = [math]::Round($vu, 2); VuIdu = $rr.VuIdu
      Delta = ($cant * ($rr.VuIdu - $vu)); Idu = $rr.Idu
    }
  }
  W ("actividades con match IDU confiable (bandera ok): " + $filas.Count)
  $tot = 0.0
  foreach ($f in $filas) { $tot += $f.Delta }
  W ("delta total: " + [math]::Round($tot))
  $umDistinta = @($filas | Where-Object { $_.UM -ne $_.UmIdu })
  W ("OJO, con unidad de medida DISTINTA a la del IDU: " + $umDistinta.Count)
  W ""
  W "== los 25 que mas mueven plata =="
  W "fila`titem`tactividad`tUM`tUM IDU`tcantidad`tVU libro`tVU IDU`tdelta"
  foreach ($f in ($filas | Sort-Object { [math]::Abs($_.Delta) } -Descending | Select-Object -First 25)) {
    W ($f.Fila.ToString() + "`t" + $f.Item + "`t" + $f.Desc + "`t" + $f.UM + "`t" + $f.UmIdu + "`t" +
       [math]::Round($f.Cant, 2) + "`t" + $f.Vu + "`t" + $f.VuIdu + "`t" + [math]::Round($f.Delta))
  }
  W ""
  W "== TODAS, para revisar =="
  W "fila`titem`tactividad`tUM`tUM IDU`tcantidad`tVU libro`tVU IDU`tdelta`tapu IDU"
  foreach ($f in ($filas | Sort-Object Fila)) {
    W ($f.Fila.ToString() + "`t" + $f.Item + "`t" + $f.Desc + "`t" + $f.UM + "`t" + $f.UmIdu + "`t" +
       [math]::Round($f.Cant, 2) + "`t" + $f.Vu + "`t" + $f.VuIdu + "`t" + [math]::Round($f.Delta) + "`t" + $f.Idu)
  }
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
"escrito: $out"
