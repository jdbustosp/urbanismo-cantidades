param([string]$libro, [double]$precio = 117926, [switch]$Simular)
# Unifica la familia EXCAVACION MECANICA / A MAQUINA de material comun a un
# solo precio y verifica que la unidad sea M3. Solo escribe NUMEROS (por la
# cache de tipos COM de PowerShell, los textos van en otro proceso).
$ErrorActionPreference = "Continue"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false; $xl.ScreenUpdating = $false
$guardado = $false
try {
  $t0 = Get-Date
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $wp = $wb.Worksheets.Item("PRECIOS_UNITARIOS")
  $ws = $wb.Worksheets.Item("POR EJECUTAR")
  $fnP = $wp.UsedRange.Row + $wp.UsedRange.Rows.Count - 1
  $fnE = $ws.UsedRange.Row + $ws.UsedRange.Rows.Count - 1
  if ($fnP -lt 1300) { throw "hoja no sana, se aborta" }

  function Total() {
    $a = $ws.Range("A1:AQ" + $fnE).Value2
    $a = (,$a)[0]
    $t = 0.0
    for ($r = 3; $r -le $fnE; $r++) {
      if ([string]$a[$r,1] -ne "1") { continue }
      if ($a[$r,42] -is [double]) { $t += $a[$r,42] }
    }
    return $t
  }
  $xl.CalculateFull(); Start-Sleep -Milliseconds 1500
  $antes = Total
  "TOTAL antes = " + [Math]::Round($antes,0)

  # ---- la familia: mecanica / a maquina, de material comun ----
  $pre = $wp.Range("A1:D" + $fnP).Value2
  $pre = (,$pre)[0]
  $fam = @()
  for ($r = 2; $r -le $fnP; $r++) {
    $d = [string]$pre[$r,2]
    if ($d -eq "") { continue }
    $n = $d.ToLowerInvariant()
    $esExcav = ($n -match 'excavaci')
    # el punto cubre la vocal con o sin tilde: asi el patron no lleva acentos
    # (PowerShell 5.1 lee el .ps1 como ANSI y los rompe)
    $esMaquina = ($n -match 'mec.nica') -or ($n -match 'a m.quina') -or ($n -match 'm.quina, incluye')
    if (-not ($esExcav -and $esMaquina)) { continue }
    # la de canalizacion MT es otro contexto (red electrica), se deja aparte
    if ($n -match 'canalizaci') { continue }
    $um = [string]$pre[$r,3]
    $vu = 0.0; if ($pre[$r,4] -is [double]) { $vu = $pre[$r,4] }
    $fam += [pscustomobject]@{ Fila = $r; Desc = $d; Um = $um; Vu = $vu }
  }
  "`nfamilia EXCAVACION MECANICA encontrada: " + $fam.Count + " filas"
  foreach ($x in $fam) { "   f" + $x.Fila + "  " + $x.Um.PadRight(4) + " " + ([Math]::Round($x.Vu,0)).ToString().PadLeft(9) + "  " + $x.Desc }
  if ($fam.Count -lt 5 -or $fam.Count -gt 15) { throw "la familia tiene un tamaNo raro, se aborta" }

  $malUm = @($fam | Where-Object { $_.Um.Trim().ToUpperInvariant() -ne "M3" })
  "`nfilas con unidad distinta de M3: " + $malUm.Count
  foreach ($x in $malUm) { "   f" + $x.Fila + " tiene [" + $x.Um + "]  " + $x.Desc }

  # ---- cuanto costaria cada opcion ----
  $pe = $ws.Range("A1:AQ" + $fnE).Value2
  $pe = (,$pe)[0]
  $porDesc = @{}
  foreach ($x in $fam) { $porDesc[$x.Desc.Trim().ToUpperInvariant()] = $x.Vu }
  $cant = 0.0; $valorHoy = 0.0
  for ($r = 3; $r -le $fnE; $r++) {
    if ([string]$pe[$r,1] -ne "5") { continue }
    $d = ([string]$pe[$r,4]).Trim().ToUpperInvariant()
    if (-not $porDesc.ContainsKey($d)) { continue }
    if ($pe[$r,40] -is [double]) { $cant += $pe[$r,40] }
    if ($pe[$r,42] -is [double]) { $valorHoy += $pe[$r,42] }
  }
  "`ncantidad total de excavacion mecanica = " + [Math]::Round($cant,2) + " M3"
  "valor hoy                             = " + [Math]::Round($valorHoy,0)
  foreach ($p in 79829, 94195, 117926) {
    "   si se unifica a " + $p + " -> " + [Math]::Round($cant * $p, 0) + "   (cambio " + [Math]::Round($cant * $p - $valorHoy, 0) + ")"
  }

  if ($Simular) { "`n(simulacion, no se escribe nada)"; $wb.Close($false); return }

  # ---- aplicar ----
  $n = 0
  foreach ($x in $fam) {
    $wp.Cells.Item($x.Fila, 4).Value2 = $precio
    $leido = $wp.Cells.Item($x.Fila, 4).Value2
    if (($leido -is [double]) -and ([Math]::Abs($leido - $precio) -lt 0.01)) { $n++ }
  }
  "`nprecios unificados y comprobados: $n de " + $fam.Count + " a " + $precio
  if ($n -ne $fam.Count) { throw "no se escribieron todos, se aborta sin guardar" }

  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 4
  $xl.CalculateFull(); Start-Sleep -Seconds 2
  $despues = Total
  "TOTAL despues = " + [Math]::Round($despues,0)
  "cambio        = " + [Math]::Round($despues - $antes,0)
  if ($despues -lt ($antes * 0.8) -or $despues -gt ($antes * 1.2)) { throw "el total se movio demasiado, se aborta sin guardar" }

  $wb.Save()
  $guardado = $true
  "GUARDADO en " + [Math]::Round(((Get-Date) - $t0).TotalSeconds,1) + " s"
} finally {
  try { if ($guardado) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  try { $xl.Quit() } catch {}
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
