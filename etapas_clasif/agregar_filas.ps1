# agregar_filas.ps1 v2 - patrones sin acentos (el ps1 en ANSI mangla UTF8)
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

  # cache de descripciones y codigos
  $desc = @{}; $cods = @{}
  for ($r = 1; $r -le $maxR; $r++) {
    $v = [string]$ws.Cells.Item($r, 4).Value2
    if ($v) { $desc[$r] = $v }
    $c = [string]$ws.Cells.Item($r, 3).Value2
    if ($c) { $cods[$c] = $r }
  }

  function Find-Row([string]$patron) {
    foreach ($k in ($desc.Keys | Sort-Object)) {
      if ($desc[$k] -like $patron) { return $k }
    }
    return 0
  }
  function Next-Code([string]$cod) {
    $parts = $cod.Split('.')
    $ult = $parts[-1]; $ancho = $ult.Length; $n = [int]$ult
    do {
      $n++
      $parts[-1] = $n.ToString().PadLeft($ancho, '0')
      $cand = ($parts -join '.')
    } while ($cods.ContainsKey($cand))
    return $cand
  }

  $trabajos = @(
    @{ patron = "*caja de inspecci*n doble norma CS276*"; codigo = "2.6.1.4.02"; reemplazo = $null;
       nueva = "Construccion de camara de paso MT norma CS280"; existePatron = "*CS280*" },
    @{ patron = "*poste de concreto 12 m.*recto AP*"; codigo = "2.6.2.9.2"; reemplazo = @("12 m.", "14 m.");
       nueva = $null; existePatron = "*poste de concreto 14 m.*" },
    @{ patron = "Suministro tuber*piezas especiales HD*4*"; codigo = $null; reemplazo = @([string][char]0x00D8 + "4", [string][char]0x00D8 + "12");
       nueva = $null; existePatron = "Suministro tuber*piezas especiales HD*12*" },
    @{ patron = "Instalaci*tuber*piezas especiales HD*4*"; codigo = $null; reemplazo = @([string][char]0x00D8 + "4", [string][char]0x00D8 + "12");
       nueva = $null; existePatron = "Instalaci*tuber*piezas especiales HD*12*" }
  )

  foreach ($t in $trabajos) {
    if ((Find-Row $t.existePatron) -gt 0) { Write-Output ("YA EXISTE: " + $t.existePatron); continue }
    $fila = Find-Row $t.patron
    if ($fila -eq 0) { Write-Output ("NO HALLADA: " + $t.patron); continue }
    $textoNuevo = if ($t.nueva) { $t.nueva } else { $desc[$fila].Replace($t.reemplazo[0], $t.reemplazo[1]) }
    $codigo = if ($t.codigo) { $t.codigo } else { Next-Code ([string]$ws.Cells.Item($fila, 3).Value2) }
    $ws.Rows.Item($fila).Copy() | Out-Null
    $ws.Rows.Item($fila + 1).Insert(-4121) | Out-Null
    $ws.Cells.Item($fila + 1, 3).Value2 = $codigo
    $ws.Cells.Item($fila + 1, 4).Value2 = $textoNuevo
    $cods[$codigo] = $fila + 1
    # refrescar cache de filas corridas
    $desc = @{}
    $maxR = $ws.UsedRange.Rows.Count
    for ($r = 1; $r -le $maxR; $r++) {
      $v = [string]$ws.Cells.Item($r, 4).Value2
      if ($v) { $desc[$r] = $v }
    }
    Write-Output ("AGREGADA fila " + ($fila+1) + " [" + $codigo + "]: " + $textoNuevo)
  }

  $wb.Save()
  Write-Output "GUARDADO"
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}