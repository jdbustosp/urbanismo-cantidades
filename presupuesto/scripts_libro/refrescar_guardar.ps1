param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 20) { for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 1200 } } }
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$ok = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = Retry { $wb.Worksheets.Item("DINAMICA") }
  $pD = Retry { $ws.PivotTables("DinamicaPpto") }
  $pR = Retry { $ws.PivotTables("ResumenEtapas") }
  for ($v = 1; $v -le 3; $v++) {
    Retry { $pD.PivotCache().Refresh() }
    Retry { $pR.PivotCache().Refresh() }
    Start-Sleep -Seconds 2
  }
  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 3
  "actualizado 3 veces y se guarda"
  $wb.Save(); $ok = $true
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}