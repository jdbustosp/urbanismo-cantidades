# agrega las columnas de subetapa 4F, 5F, 5G, 8D a POR EJECUTAR clonando
# la columna hermana (los SUMIFS usan el encabezado F$2, se adaptan solos)
$ErrorActionPreference = "Stop"
$libro = "D:\Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\urbanismo maipore.xlsx"
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  $ws = $wb.Worksheets.Item("POR EJECUTAR")

  function Get-Col([string]$hdr) {
    for ($c = 1; $c -le 60; $c++) {
      if ([string]$ws.Cells.Item(2, $c).Value2 -eq $hdr) { return $c }
    }
    return 0
  }
  # (nueva, hermana-de-la-que-clonar) en orden que no rompa posiciones
  foreach ($par in @(@("4F","4E"), @("5F","5E"), @("5G","5F"), @("8D","8C"))) {
    $nueva = $par[0]; $herm = $par[1]
    if ((Get-Col $nueva) -gt 0) { Write-Output ("YA EXISTE col " + $nueva); continue }
    $cH = Get-Col $herm
    if ($cH -eq 0) { Write-Output ("NO HALLADA hermana " + $herm); continue }
    $ws.Columns.Item($cH).Copy() | Out-Null
    $ws.Columns.Item($cH + 1).Insert(-4161) | Out-Null   # xlShiftToRight
    $ws.Cells.Item(2, $cH + 1).Value2 = $nueva
    Write-Output ("AGREGADA columna " + $nueva + " en posicion " + ($cH + 1))
  }
  $xl.Application.CutCopyMode = $false
  $wb.Save()
  Write-Output "GUARDADO"
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}