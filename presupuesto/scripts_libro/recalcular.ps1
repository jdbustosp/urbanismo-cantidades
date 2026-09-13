param([string]$libro)
$ErrorActionPreference = "Continue"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false; $xl.ScreenUpdating = $false
$guardado = $false
try {
  $t0 = Get-Date
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = $wb.Worksheets.Item("POR EJECUTAR")
  $fn = $ws.UsedRange.Row + $ws.UsedRange.Rows.Count - 1
  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 4
  $xl.CalculateFull(); Start-Sleep -Seconds 2

  $a = $ws.Range("A1:AQ" + $fn).Value2
  $a = ,$a
  $a = $a[0]
  $tot = 0.0
  "== NIVEL 1 =="
  for ($r = 3; $r -le $fn; $r++) {
    if ([string]$a[$r,1] -ne "1") { continue }
    $v = 0.0; if ($a[$r,42] -is [double]) { $v = $a[$r,42] }
    $tot += $v
    "  " + ([string]$a[$r,3]).PadRight(4) + " " + ([string]$a[$r,4]).PadRight(46) + " " + [Math]::Round($v,0)
  }
  "  TOTAL POR EJECUTAR = " + [Math]::Round($tot,0)

  "`n== capitulos de nivel 2 =="
  for ($r = 3; $r -le $fn; $r++) {
    if ([string]$a[$r,1] -ne "2") { continue }
    $d = [string]$a[$r,4]
    if ($d.Length -gt 46) { $d = $d.Substring(0,46) }
    $v = 0.0; if ($a[$r,42] -is [double]) { $v = $a[$r,42] }
    "  " + ([string]$a[$r,3]).PadRight(6) + " " + $d.PadRight(46) + " " + [Math]::Round($v,0)
  }
  "`n== control =="
  foreach ($p in @(@(939,"2.4.2.4 pozos"), @(1352,"2.13 imprevistos"), @(417,"imprev viejo 2.3.1"))) {
    $v = 0.0; if ($a[$p[0],42] -is [double]) { $v = $a[$p[0],42] }
    "  " + ($p[1]).PadRight(22) + " = " + [Math]::Round($v,0)
  }
  if ($tot -lt 100000000000) { throw "el total no tiene sentido, se aborta sin guardar" }
  $wb.Save()
  $guardado = $true
  "`nGUARDADO en " + [Math]::Round(((Get-Date) - $t0).TotalSeconds,1) + " s"
} finally {
  try { if ($guardado) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  try { $xl.Quit() } catch {}
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
