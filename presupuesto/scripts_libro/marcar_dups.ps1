param([string]$libro)
# Marca en PRECIOS_UNITARIOS el nombre repetido (mismo texto y mismo precio)
# para que el SUMIF de POR EJECUTAR deje de sumarlo dos veces.
# Sesion de Excel dedicada SOLO a escribir texto (ver README: mezclar
# escrituras de texto y de numero en la misma sesion hace fallar las de
# numero con "no se puede convertir Double a String").
$ErrorActionPreference = "Continue"
$MARCA = " [DUPLICADO NO USAR]"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false; $xl.ScreenUpdating = $false
$guardado = $false
try {
  $t0 = Get-Date
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $wp = $wb.Worksheets.Item("PRECIOS_UNITARIOS")
  $fnP = $wp.UsedRange.Row + $wp.UsedRange.Rows.Count - 1
  if ($fnP -lt 1300) { throw "PRECIOS_UNITARIOS no esta sana ($fnP filas), se aborta" }
  $pre = $wp.Range("A1:D" + $fnP).Value2
  $pre = ,$pre
  $pre = $pre[0]

  $vistos = @{}; $dups = @()
  for ($r = 2; $r -le $fnP; $r++) {
    $d = [string]$pre[$r,2]
    if ($d.Trim() -eq "" -or $d.Contains("[DUPLICADO")) { continue }
    $k = $d.Trim().ToUpperInvariant()
    $vu = 0.0; if ($pre[$r,4] -is [double]) { $vu = $pre[$r,4] }
    if ($vistos.ContainsKey($k)) {
      if ([Math]::Abs($vistos[$k] - $vu) -lt 0.01) { $dups += @{ Fila = $r; Desc = $d; Vu = $vu } }
    } else { $vistos[$k] = $vu }
  }
  "duplicados detectados: " + $dups.Count
  if ($dups.Count -eq 0) { "nada que marcar"; $wb.Close($false); return }
  if ($dups.Count -gt 60) { throw "demasiados duplicados ($($dups.Count)), se aborta" }
  $ok = 0
  foreach ($x in $dups) {
    $nuevo = $x.Desc + $MARCA
    $wp.Cells.Item($x.Fila, 2).Value2 = $nuevo
    if ([string]($wp.Cells.Item($x.Fila, 2).Value2) -eq $nuevo) {
      $ok++
      "   f" + $x.Fila + "  " + [Math]::Round($x.Vu,0) + "  " + $x.Desc
    }
  }
  "marcados y comprobados: $ok de " + $dups.Count
  if ($ok -ne $dups.Count) { throw "no se marcaron todos, se aborta sin guardar" }
  $wb.Save()
  $guardado = $true
  "GUARDADO en " + [Math]::Round(((Get-Date) - $t0).TotalSeconds,1) + " s"
} finally {
  try { if ($guardado) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  try { $xl.Quit() } catch {}
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
