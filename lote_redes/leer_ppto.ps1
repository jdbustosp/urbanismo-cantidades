# Vuelca las actividades del presupuesto real (POR EJECUTAR) a CSV para
# el cruce de inconsistencias del lote de redes. Solo lectura.
$ErrorActionPreference = "Stop"
$xlsx = "D:\Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\urbanismo maipore.xlsx"
$out = "C:\Users\jdbus\Documents\URBANISMO\work\lote_redes\ppto_actividades.csv"
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
try {
  $wb = $excel.Workbooks.Open($xlsx, 0, $true)  # ReadOnly
  $ws = $wb.Worksheets.Item("POR EJECUTAR")
  $lastRow = $ws.Cells.SpecialCells(11).Row  # xlCellTypeLastCell
  $data = $ws.Range("A1:F$lastRow").Value2
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("fila;nivel;descripcion;um;cantidad")
  for ($r = 1; $r -le $lastRow; $r++) {
    $nivel = $data[$r, 1]
    $desc = $data[$r, 4]
    $um = $data[$r, 5]
    $cant = $data[$r, 6]
    if ($null -ne $desc -and "$desc".Trim() -ne "") {
      $d = "$desc".Replace(";", ",").Replace("`n", " ")
      $lines.Add("$r;$nivel;$d;$um;$cant")
    }
  }
  [System.IO.File]::WriteAllLines($out, $lines)
  Write-Output ("filas exportadas: " + $lines.Count)
} finally {
  if ($wb) { $wb.Close($false) }
  $excel.Quit()
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
}
