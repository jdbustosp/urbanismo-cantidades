# Verificacion final 2026-09-08: expande la dinamica y comprueba que en
# NIVEL 5 se ven CANTIDAD y V.UNITARIO, en capitulos NO, y que el color
# del nivel 4 es distinto al del nivel 2. Cierra SIN guardar.
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $wsD = $wb.Worksheets.Item("DINAMICA")
  $pt = $wsD.PivotTables("DinamicaPpto")
  foreach ($fn in @("N1","N2","N3","N4")) { try { $pt.PivotFields($fn).ShowDetail = $true } catch {} }
  $rngC = $pt.PivotFields("Suma CANTIDAD").DataRange
  $ini = $rngC.Row; $nF = $rngC.Rows.Count; $cC = $rngC.Column
  Write-Output ("pivot expandida: filas " + $nF)
  $muestra = @{1=0;2=0;3=0;4=0;5=0}
  $colorNivel = @{}
  $ejemplos = @()
  for ($k = 0; $k -lt $nF; $k++) {
    $r = $ini + $k
    $niv = 0
    try { $niv = $wsD.Cells.Item($r, $cC).PivotCell.RowItems.Count } catch {}
    if ($niv -ge 1 -and $niv -le 5 -and $muestra[$niv] -lt 2) {
      $muestra[$niv]++
      if (-not $colorNivel.ContainsKey($niv)) { $colorNivel[$niv] = $wsD.Cells.Item($r,1).Interior.Color }
      $ejemplos += ("  n{0} fila {1} | CANT='{2}' VU='{3}' VT='{4}' | color={5} | {6}" -f $niv, $r, $wsD.Cells.Item($r,2).Text, $wsD.Cells.Item($r,3).Text, $wsD.Cells.Item($r,4).Text, $wsD.Cells.Item($r,1).Interior.Color, $wsD.Cells.Item($r,1).Text)
    }
  }
  foreach ($e in $ejemplos) { Write-Output $e }
  Write-Output ""
  Write-Output "colores por nivel (esperado: n1=8421504 gris, n2=10092543 amarillo, n3=16243908 azul, n4=16771281 durazno, n5=16777215 blanco)"
  foreach ($k in ($colorNivel.Keys | Sort-Object)) { Write-Output ("  nivel " + $k + " -> " + $colorNivel[$k]) }
  # buscar una fila de porcentaje en la dinamica
  Write-Output ""
  Write-Output "=== filas de porcentaje en la dinamica ==="
  $n = 0
  for ($k = 0; $k -lt $nF -and $n -lt 4; $k++) {
    $r = $ini + $k
    $et = $wsD.Cells.Item($r,1).Text
    if ($et -match 'Obras preliminares generales|PGU\) ETAPA') {
      Write-Output ("  fila $r | CANT='" + $wsD.Cells.Item($r,2).Text + "' VU='" + $wsD.Cells.Item($r,3).Text + "' VT='" + $wsD.Cells.Item($r,4).Text + "' | " + $et)
      $n++
    }
  }
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}