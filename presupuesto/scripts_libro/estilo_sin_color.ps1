param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$ok = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $st = $wb.TableStyles.Item("URB_NIVELES")
  foreach ($k in @(11, 12, 13, 23, 24, 25)) {
    try {
      $el = $st.TableStyleElements.Item([int]$k)
      Retry { $el.Interior.Pattern = -4142 }   # xlPatternNone
      Retry { $el.Font.Bold = $true }
      "  elemento $k sin relleno"
    } catch { "  elemento $k error: " + $_.Exception.Message.Split([Environment]::NewLine)[0] }
  }
  $wb.Save()
  $ok = $true
  "guardado"
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}