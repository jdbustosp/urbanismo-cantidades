# agregar_carcamo.ps1 (2026-09-02) - clona una fila nivel-5 ML dentro de
# cada capitulo hidro (ACU/SAN/PLU) y la renombra a CARCAMO, para que la
# fila de memoria "Carcamo" (tramos con CARCAMO=SI) cruce sola. El precio
# llega solo por el SUMIF de VR_UNITARIO (PRECIOS_UNITARIOS!B804 CARCAMO).
$ErrorActionPreference = "Stop"
$libro = "D:\Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\urbanismo maipore.xlsx"

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  $ws = $wb.Worksheets.Item("POR EJECUTAR")
  $maxR = $ws.UsedRange.Rows.Count

  function Snapshot {
    $s = @{}
    for ($r = 1; $r -le $script:maxR; $r++) {
      $niv = $ws.Cells.Item($r, 1).Value2
      $d = [string]$ws.Cells.Item($r, 4).Value2
      $um = [string]$ws.Cells.Item($r, 5).Value2
      $c = [string]$ws.Cells.Item($r, 3).Value2
      $s[$r] = @($niv, $d, $um, $c)
    }
    return $s
  }

  $capPatrones = @("RED DE ACUEDUCTO*", "RED DE ALCANTARILLADO SANITARIO*", "RED DE ALCANTARILLADO PLUVIAL*")

  foreach ($pat in $capPatrones) {
    $snap = Snapshot
    # rango del capitulo: fila nivel 3 con ese nombre hasta el siguiente nivel <= 3
    $ini = 0; $fin = 0
    foreach ($r in ($snap.Keys | Sort-Object)) {
      $niv = $snap[$r][0]; $d = $snap[$r][1]
      if ($ini -eq 0) {
        if ($niv -eq 3 -and $d -like $pat) { $ini = $r }
      } elseif ($fin -eq 0) {
        if ($niv -ne $null -and $niv -le 3 -and $r -gt $ini) { $fin = $r - 1 }
      }
    }
    if ($ini -eq 0) { Write-Output ("CAPITULO NO HALLADO: " + $pat); continue }
    if ($fin -eq 0) { $fin = $maxR }
    # ya existe?
    $ya = $false
    for ($r = $ini; $r -le $fin; $r++) {
      if ($snap[$r][1] -like "*CARCAMO*") { $ya = $true; break }
    }
    if ($ya) { Write-Output ("YA EXISTE CARCAMO en " + $pat); continue }
    # fila a clonar: primer nivel-5 con UM=ML del capitulo (preferir Entibado)
    $fila = 0
    for ($r = $ini; $r -le $fin; $r++) {
      if ($snap[$r][0] -eq 5 -and $snap[$r][2] -eq "ML" -and $snap[$r][1] -like "*ntibado*") { $fila = $r; break }
    }
    if ($fila -eq 0) {
      for ($r = $ini; $r -le $fin; $r++) {
        if ($snap[$r][0] -eq 5 -and $snap[$r][2] -eq "ML") { $fila = $r; break }
      }
    }
    if ($fila -eq 0) { Write-Output ("SIN FILA ML CLONABLE en " + $pat); continue }
    # siguiente codigo libre del mismo grupo
    $cod = [string]$ws.Cells.Item($fila, 3).Value2
    $parts = $cod.Split('.')
    $ancho = $parts[-1].Length
    $cands = @{}
    for ($r = $ini; $r -le $fin; $r++) { $c = $snap[$r][3]; if ($c) { $cands[$c] = $r } }
    $n = [int]$parts[-1]
    do {
      $n++
      $parts[-1] = $n.ToString().PadLeft($ancho, '0')
      $cand = ($parts -join '.')
    } while ($cands.ContainsKey($cand))
    $ws.Rows.Item($fila).Copy() | Out-Null
    $ws.Rows.Item($fila + 1).Insert(-4121) | Out-Null
    $ws.Cells.Item($fila + 1, 3).Value2 = $cand
    $ws.Cells.Item($fila + 1, 4).Value2 = "CARCAMO"
    $ws.Cells.Item($fila + 1, 5).Value2 = "ML"
    $maxR = $ws.UsedRange.Rows.Count
    Write-Output ("AGREGADA CARCAMO " + $cand + " en " + $pat + " (clon de fila " + $fila + ")")
  }
  $wb.Save()
  Write-Output "GUARDADO"
}
finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
}
