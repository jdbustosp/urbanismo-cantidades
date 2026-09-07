# DINAMICA ronda 3 (2026-09-07): "que se vean los subtotales pero solo
# del valor total". Excel no permite subtotal por-campo-de-valor, asi
# que: (1) subtotales automaticos en N1..N4 (salen las 3 columnas) y
# (2) las celdas de subtotal de Suma CANTIDAD y V. UNITARIO PROM se
# OCULTAN con formato ";;;" via PivotSelect "'Nx'[All] 'campo'"
# (fallback: barrido por PivotCell). El formato persiste en refresh
# (PreserveFormatting); si se rearma el layout, re-correr este script.
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (400 * $t) }
  }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
$ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}

  # 1) refrescar la BD primero (la hoja PE cambio: -37 filas y
  # preliminares nuevo esquema)
  $wsB = $wb.Worksheets.Item("BD")
  $loB = $wsB.ListObjects.Item("BD_CONSOL")
  Retry { $loB.QueryTable.BackgroundQuery = $false }
  Retry { $loB.QueryTable.Refresh($false) | Out-Null }
  $filas = $loB.DataBodyRange.Rows.Count
  Write-Output ("BD_CONSOL refrescada: " + $filas + " filas")
  if ($filas -lt 1500) { throw "BD_CONSOL con muy pocas filas" }

  # 2) pivot: subtotales automaticos en N1..N4 + refresh
  $wsD = $wb.Worksheets.Item("DINAMICA")
  $pt = $wsD.PivotTables("DinamicaPpto")
  try { $pt.PivotCache().Refresh() | Out-Null } catch {}
  foreach ($fn in @("N1","N2","N3","N4")) {
    $pf = $pt.PivotFields($fn)
    Retry { $pf.Subtotals = @($true,$false,$false,$false,$false,$false,$false,$false,$false,$false,$false,$false) }
  }
  Retry { $pt.SubtotalLocation(1) | Out-Null }   # xlAtTop
  Retry { $pt.PreserveFormatting = $true }
  Retry { $pt.RefreshTable() | Out-Null }
  Write-Output "subtotales N1..N4 activos (arriba)"

  # 3) ocultar los subtotales de CANTIDAD y VU (solo debe verse el VT)
  $campos = @("Suma CANTIDAD", "V. UNITARIO PROM")
  $ocultas = 0; $fallo = $false
  foreach ($nf in @("N1","N2","N3","N4")) {
    foreach ($df in $campos) {
      try {
        $pt.PivotSelect("'" + $nf + "'[All] '" + $df + "'", 2, $true)
        $xl.Selection.NumberFormat = ";;;"
        $ocultas++
      } catch { $fallo = $true }
    }
  }
  Write-Output ("PivotSelect ocultos: " + $ocultas + "/8" + $(if ($fallo) { " (con fallos -> barrido)" } else { "" }))
  if ($fallo -or $ocultas -lt 8) {
    # fallback: barrido por PivotCell sobre las columnas de esos campos
    foreach ($df in $campos) {
      $rngD = $pt.PivotFields($df).DataRange
      $nr = $rngD.Rows.Count
      for ($i = 1; $i -le $nr; $i++) {
        $c = $rngD.Cells.Item($i, 1)
        $tipo = -1
        try { $tipo = $c.PivotCell.PivotCellType } catch {}
        if ($tipo -eq 2 -or $tipo -eq 7) {
          try { $c.NumberFormat = ";;;" ; $ocultas++ } catch {}
        }
      }
    }
    Write-Output ("barrido PivotCell: total ocultas " + $ocultas)
  }
  # total general: tambien solo VT
  foreach ($df in $campos) {
    try {
      $rngD = $pt.PivotFields($df).DataRange
      $c = $rngD.Cells.Item($rngD.Rows.Count, 1)
      if ($c.PivotCell.PivotCellType -eq 3) { $c.NumberFormat = ";;;" }
    } catch {}
  }

  # 4) RefreshAll final (deja probado el Actualizar todo) y guardar
  Retry { $wb.RefreshAll() }
  Start-Sleep -Seconds 4
  Retry { $wb.Save() }
  $ok = $true
  Write-Output "GUARDADO dinamica con subtotales solo-VT"
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO" }