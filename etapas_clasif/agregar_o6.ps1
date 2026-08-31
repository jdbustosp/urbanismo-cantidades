$ErrorActionPreference = "Stop"
$libro = "D:\Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\urbanismo maipore.xlsx"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  $ws = $wb.Worksheets.Item("POR EJECUTAR")
  $maxR = $ws.UsedRange.Rows.Count
  foreach ($pat in @("Suministro tuber*PVC flexible*8*", "Instalaci*tuber*PVC flexible*8*")) {
    $fila = 0
    for ($r = 1; $r -le $maxR; $r++) {
      $v = [string]$ws.Cells.Item($r, 4).Value2
      if ($v -and $v -like $pat -and $v -notlike "*18*" -and $v -notlike "*8*8*") { $fila = $r; break }
    }
    if ($fila -eq 0) { Write-Output ("NO: " + $pat); continue }
    $desc = ([string]$ws.Cells.Item($fila, 4).Value2) -replace '8"', '6"'
    $existe = $false
    for ($r = 1; $r -le $maxR; $r++) {
      if ([string]$ws.Cells.Item($r, 4).Value2 -eq $desc) { $existe = $true; break }
    }
    if ($existe) { Write-Output ("YA: " + $desc); continue }
    $cod = [string]$ws.Cells.Item($fila, 3).Value2
    $parts = $cod.Split('.'); $ult = $parts[-1]; $ancho = $ult.Length; $n = [int]$ult
    do { $n++; $parts[-1] = $n.ToString().PadLeft($ancho,'0'); $cand = ($parts -join '.'); $choca = $false
      for ($r = 1; $r -le $maxR; $r++) { if ([string]$ws.Cells.Item($r,3).Value2 -eq $cand) { $choca = $true; break } }
    } while ($choca)
    $ws.Rows.Item($fila).Copy() | Out-Null
    $ws.Rows.Item($fila + 1).Insert(-4121) | Out-Null
    $ws.Cells.Item($fila + 1, 3).Value2 = $cand
    $ws.Cells.Item($fila + 1, 4).Value2 = $desc
    $maxR = $ws.UsedRange.Rows.Count
    Write-Output ("AGREGADA [" + $cand + "]: " + $desc)
  }
  $wb.Save()
  Write-Output "GUARDADO"
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}
