param([string]$libro, [string]$out)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 25) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 1200 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$sb = New-Object System.Text.StringBuilder
function W($s) { [void]$sb.AppendLine($s) }
try {
  $wb = Retry { $xl.Workbooks.Open($libro, 0, $true) }
  try { $wb.AutoSaveOn = $false } catch {}
  $wp = Retry { $wb.Worksheets.Item("PRECIOS_UNITARIOS") }
  $ws = Retry { $wb.Worksheets.Item("POR EJECUTAR") }
  $fnP = $wp.UsedRange.Row + $wp.UsedRange.Rows.Count - 1
  $pre = $wp.Range("A1:D" + $fnP).Value2

  # nombres EXACTOS repetidos (el SUMIF de la hoja compara el texto tal cual)
  $grupos = @{}
  for ($r = 2; $r -le $fnP; $r++) {
    $d = [string]$pre[$r, 2]
    if ($d.Trim() -eq "") { continue }
    $k = $d.Trim().ToUpperInvariant()
    if (-not $grupos.ContainsKey($k)) { $grupos[$k] = @() }
    $vu = 0.0; try { $vu = [double]$pre[$r, 4] } catch {}
    $grupos[$k] += [pscustomobject]@{ Fila = $r; Desc = $d; Um = [string]$pre[$r,3]; Vu = $vu; Cat = [string]$pre[$r,1] }
  }
  $dups = @($grupos.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 })
  W ("nombres repetidos en PRECIOS_UNITARIOS: " + $dups.Count)

  # cuanto pesa cada actividad en el presupuesto
  $fnPE = $ws.UsedRange.Row + $ws.UsedRange.Rows.Count - 1
  $pe = $ws.Range("A1:AQ" + $fnPE).Value2
  $uso = @{}
  for ($r = 3; $r -le $fnPE; $r++) {
    if ([string]$pe[$r, 1] -ne "5") { continue }
    $d = ([string]$pe[$r, 4]).Trim().ToUpperInvariant()
    if ($d -eq "") { continue }
    $c = 0.0; try { $c = [double]$pe[$r, 40] } catch {}
    if (-not $uso.ContainsKey($d)) { $uso[$d] = 0.0 }
    $uso[$d] += $c
  }

  $total = 0.0
  $lista = @()
  foreach ($g in $dups) {
    $n = $g.Value.Count
    $suma = ($g.Value | Measure-Object -Property Vu -Sum).Sum
    $primero = $g.Value[0].Vu
    $cant = 0.0
    if ($uso.ContainsKey($g.Key)) { $cant = $uso[$g.Key] }
    $sobrecosto = ($suma - $primero) * $cant
    $total += $sobrecosto
    $lista += [pscustomobject]@{
      Desc = $g.Value[0].Desc; Veces = $n; Filas = (($g.Value | ForEach-Object { $_.Fila }) -join ",");
      Precios = (($g.Value | ForEach-Object { [Math]::Round($_.Vu,0) }) -join " + ")
      VuCobrado = $suma; VuCorrecto = $primero; Cant = $cant; Sobrecosto = $sobrecosto
      Iguales = (($g.Value | ForEach-Object { [Math]::Round($_.Vu,2) } | Select-Object -Unique).Count -eq 1)
    }
  }
  W ("sobrecosto total por precios duplicados: " + [Math]::Round($total, 0))
  W ""
  W "desc`tveces`tfilas`tprecios`tVU que cobra el libro`tVU correcto`tcantidad`tsobrecosto`tprecios iguales entre si"
  foreach ($x in ($lista | Sort-Object Sobrecosto -Descending)) {
    W ("$($x.Desc)`t$($x.Veces)`t$($x.Filas)`t$($x.Precios)`t$([Math]::Round($x.VuCobrado,0))`t$([Math]::Round($x.VuCorrecto,0))`t$([Math]::Round($x.Cant,2))`t$([Math]::Round($x.Sobrecosto,0))`t$($x.Iguales)")
  }
  $txt = $sb.ToString()
  [System.IO.File]::WriteAllText($out, $txt, (New-Object System.Text.UTF8Encoding($false)))
  $txt.Split("`n") | Select-Object -First 40 | ForEach-Object { $_.TrimEnd() }
  "`n(informe completo en $out)"
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
