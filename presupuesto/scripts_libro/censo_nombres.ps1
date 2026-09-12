param([string]$libro, [string]$out)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
function Norm([string]$s) {
  if (-not $s) { return "" }
  $t = $s.ToLowerInvariant().Trim()
  $t = $t.Normalize([Text.NormalizationForm]::FormD)
  $sb2 = New-Object System.Text.StringBuilder
  foreach ($ch in $t.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$sb2.Append($ch)
    }
  }
  $t = $sb2.ToString()
  $t = $t -replace '[^a-z0-9]+', ' '
  ($t -replace '\s+', ' ').Trim()
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
  # columnas
  $cN = 1; $cI = 3; $cD = 4; $cU = 5; $cV = 41
  $items = @()
  for ($r = 1; $r -le $ultima; $r++) {
    if ([string]$arr[$r, $cN] -ne "5") { continue }
    $d = ([string]$arr[$r, $cD]).Trim()
    if ($d -eq "") { continue }
    $um = ([string]$arr[$r, $cU]).Trim()
    $v = 0.0
    try { $v = [double]$arr[$r, $cV] } catch { $v = 0.0 }
    $items += [pscustomobject]@{
      Fila = $r; Item = ([string]$arr[$r, $cI]).Trim(); Desc = $d; UM = $um
      VU = [math]::Round($v, 2); Norm = (Norm $d)
    }
  }
  W ("actividades de nivel 5 leidas: " + $items.Count)

  # --- A) mismo nombre normalizado, texto o precio distinto ---
  W ""
  W "== A) MISMO NOMBRE (normalizado) CON TEXTO O PRECIO DISTINTO =="
  W "clave`tvariantes`tprecios`tfilas"
  $gA = $items | Group-Object Norm
  $nA = 0
  foreach ($g in $gA) {
    $textos = @($g.Group | Select-Object -ExpandProperty Desc -Unique)
    $precios = @($g.Group | Select-Object -ExpandProperty VU -Unique)
    if ($textos.Count -gt 1 -or $precios.Count -gt 1) {
      $nA++
      W ($g.Name + "`t" + ($textos -join " | ") + "`t" + ($precios -join " | ") + "`t" +
         (($g.Group | Select-Object -First 6 -ExpandProperty Fila) -join ","))
    }
  }
  W ("subtotal A: $nA")

  # --- B) familias por las 2 primeras palabras significativas ---
  W ""
  W "== B) FAMILIAS PARECIDAS (mismas 2 primeras palabras) CON PRECIOS DISTINTOS =="
  W "familia`tactividad`tUM`tVU`tveces"
  $stop = @("suministro", "e", "de", "del", "la", "el", "los", "las", "y", "en", "con",
            "para", "por", "un", "una", "al", "mo", "m", "o")
  $conFam = $items | ForEach-Object {
    $pal = @($_.Norm -split ' ' | Where-Object { $_ -and ($stop -notcontains $_) })
    $fam = if ($pal.Count -ge 2) { $pal[0] + " " + $pal[1] } elseif ($pal.Count -eq 1) { $pal[0] } else { "?" }
    $_ | Add-Member -NotePropertyName Fam -NotePropertyValue $fam -PassThru
  }
  $nB = 0
  foreach ($g in ($conFam | Group-Object Fam | Sort-Object Name)) {
    $distintas = @($g.Group | Group-Object Norm)
    if ($distintas.Count -lt 2) { continue }
    $precios = @($g.Group | Select-Object -ExpandProperty VU -Unique)
    if ($precios.Count -lt 2) { continue }
    $nB++
    foreach ($d in $distintas) {
      $uno = $d.Group[0]
      W ($g.Name + "`t" + $uno.Desc + "`t" + $uno.UM + "`t" + $uno.VU + "`t" + $d.Count)
    }
  }
  W ("subtotal B: $nB familias")
  $wb.Close($false)
} finally {
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
"escrito: $out"
