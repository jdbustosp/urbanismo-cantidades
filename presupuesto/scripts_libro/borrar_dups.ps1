param([string]$libro)
# Elimina de PRECIOS_UNITARIOS las filas marcadas [DUPLICADO NO USAR] y
# recalcula. Criterio exacto y verificable: solo esas filas.
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
  "PRECIOS_UNITARIOS: $fnP filas"
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

  $pre = $wp.Range("A1:D" + $fnP).Value2
  $pre = (,$pre)[0]
  $borrar = @()
  for ($r = 2; $r -le $fnP; $r++) {
    $d = [string]$pre[$r,2]
    if ($d.Contains("[DUPLICADO NO USAR]")) { $borrar += $r }
  }
  "filas marcadas a eliminar: " + $borrar.Count
  if ($borrar.Count -eq 0) { throw "no hay filas marcadas" }
  if ($borrar.Count -ne 17) { throw ("se esperaban 17 y hay " + $borrar.Count + ", se aborta") }
  foreach ($r in ($borrar | Sort-Object -Descending)) { $wp.Rows.Item($r).Delete() }

  $fnP2 = $wp.UsedRange.Row + $wp.UsedRange.Rows.Count - 1
  "PRECIOS_UNITARIOS ahora: $fnP2 filas (se esperaban " + ($fnP - 17) + ")"
  if ($fnP2 -ne ($fnP - 17)) { throw "el conteo de filas no cuadra, se aborta sin guardar" }

  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 4
  $xl.CalculateFull(); Start-Sleep -Seconds 2
  $despues = Total
  "TOTAL despues = " + [Math]::Round($despues,0)
  "cambio        = " + [Math]::Round($despues - $antes,0)
  if ([Math]::Abs($despues - $antes) -gt ($antes * 0.02)) { throw "el total se movio mas de lo esperable, se aborta sin guardar" }

  $wb.Save()
  $guardado = $true
  "GUARDADO en " + [Math]::Round(((Get-Date) - $t0).TotalSeconds,1) + " s"
} finally {
  try { if ($guardado) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  try { $xl.Quit() } catch {}
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
