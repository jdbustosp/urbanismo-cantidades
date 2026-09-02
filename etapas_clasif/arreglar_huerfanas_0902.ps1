# arreglar_huerfanas_0902.ps1 - 14 huerfanas del export 2026-09-02:
# 1) clona "Tuberia NOVAFORT 14 Hex (1,5-2,5)" -> banda (0-1,5)  [10 filas huerfanas]
# 2) clona "Tuberia NOVAFORT 12 Hex (1,5-2,5)" -> banda (2,5-3,5) [3 filas huerfanas]
# 3) borra la parametrica de prueba "jhkjhi" (fila 5 de URB_PARAMETRICAS) [1 huerfana]
$ErrorActionPreference = "Stop"
$libro = "D:\Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\urbanismo maipore.xlsx"

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  $ws = $wb.Worksheets.Item("POR EJECUTAR")

  function Add-Banda([int]$srcRow, [string]$bandaVieja, [string]$bandaNueva) {
    $maxR = $ws.UsedRange.Rows.Count
    $srcName = [string]$ws.Cells.Item($srcRow, 4).Value2
    $newName = $srcName.Replace($bandaVieja, $bandaNueva)
    # ya existe?
    for ($r = 1; $r -le $maxR; $r++) {
      if ([string]$ws.Cells.Item($r, 4).Value2 -eq $newName) {
        Write-Output ("YA EXISTE: " + $newName); return
      }
    }
    # siguiente codigo libre del grupo (mismo prefijo que el codigo fuente)
    $cod = [string]$ws.Cells.Item($srcRow, 3).Value2
    $parts = $cod.Split('.')
    $cods = @{}
    for ($r = 1; $r -le $maxR; $r++) {
      $c = [string]$ws.Cells.Item($r, 3).Value2
      if ($c) { $cods[$c] = $r }
    }
    $n = [int]$parts[-1]
    do {
      $n++
      $parts[-1] = [string]$n
      $cand = ($parts -join '.')
    } while ($cods.ContainsKey($cand))
    $ws.Rows.Item($srcRow).Copy() | Out-Null
    $ws.Rows.Item($srcRow + 1).Insert(-4121) | Out-Null
    $ws.Cells.Item($srcRow + 1, 3).Value2 = $cand
    $ws.Cells.Item($srcRow + 1, 4).Value2 = $newName
    Write-Output ("AGREGADA " + $cand + " | " + $newName + " (clon de fila " + $srcRow + ")")
  }

  # localizar filas fuente por nombre (las filas se corren al insertar)
  function Find-ByName([string]$patron) {
    $maxR = $ws.UsedRange.Rows.Count
    for ($r = 1; $r -le $maxR; $r++) {
      $d = [string]$ws.Cells.Item($r, 4).Value2
      if ($d -and $d -like $patron -and $ws.Cells.Item($r, 1).Value2 -eq 5) { return $r }
    }
    return 0
  }

  $src14 = Find-ByName "Tuber*NOVAFORT 14*Hex (1,5-2,5)*"
  if ($src14 -gt 0) { Add-Banda $src14 "(1,5-2,5)" "(0-1,5)" } else { Write-Output "NO HALLADA fuente NOVAFORT 14 (1,5-2,5)" }
  $src12 = Find-ByName "Tuber*NOVAFORT 12*Hex (1,5-2,5)*"
  if ($src12 -gt 0) { Add-Banda $src12 "(1,5-2,5)" "(2,5-3,5)" } else { Write-Output "NO HALLADA fuente NOVAFORT 12 (1,5-2,5)" }

  # parametrica de prueba
  $wp = $wb.Worksheets.Item("URB_PARAMETRICAS")
  $borradas = 0
  for ($r = $wp.UsedRange.Rows.Count; $r -ge 1; $r--) {
    $nom = [string]$wp.Cells.Item($r, 4).Value2
    if ($nom -eq "jhkjhi") {
      $wp.Rows.Item($r).Delete() | Out-Null
      $borradas++
      Write-Output ("BORRADA parametrica de prueba fila " + $r + " (jhkjhi)")
    }
  }
  if ($borradas -eq 0) { Write-Output "parametrica jhkjhi no encontrada" }

  $wb.Save()
  Write-Output "GUARDADO"
}
finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
}
