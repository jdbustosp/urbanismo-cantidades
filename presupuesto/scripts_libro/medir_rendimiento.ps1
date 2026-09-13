param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 25) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 1200 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
try {
  $t0 = Get-Date
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $tApertura = ((Get-Date) - $t0).TotalSeconds
  "apertura                 : " + [Math]::Round($tApertura, 1) + " s"

  $t1 = Get-Date
  $xl.CalculateFull()
  "recalculo completo       : " + [Math]::Round(((Get-Date) - $t1).TotalSeconds, 1) + " s"

  $t2 = Get-Date
  $xl.CalculateFull()
  "segundo recalculo        : " + [Math]::Round(((Get-Date) - $t2).TotalSeconds, 1) + " s"

  # escribir una celda suelta y ver cuanto tarda en responder
  $ws = Retry { $wb.Worksheets.Item("Observaciones") }
  $t3 = Get-Date
  $ws.Cells.Item(50, 10).Value2 = "prueba"
  $ws.Cells.Item(50, 10).ClearContents()
  "editar una celda suelta  : " + [Math]::Round(((Get-Date) - $t3).TotalSeconds, 1) + " s"

  "modo de calculo          : " + $xl.Calculation + "  (-4105 = automatico)"
  "hojas                    : " + $wb.Worksheets.Count
  $usadas = ""
  foreach ($h in $wb.Worksheets) {
    $usadas += "`n   " + $h.Name.PadRight(20) + " usado=" + $h.UsedRange.Address(0,0)
  }
  "rangos usados:" + $usadas
  $wb.Close($false)
} finally { $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null }
