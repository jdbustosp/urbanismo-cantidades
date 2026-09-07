# Precios ronda 3 (2026-09-07 tarde):
#  A) 17 actividades del paquete descoles/box culvert/complementarios
#     que estaban SIN precio (VU en blanco en la hoja) -- criterio ALTO
#     anclado en analogias internas del propio libro.
#  B) 9 correcciones de COHERENCIA, todas AL ALZA: las tuberias
#     "novafor 315/250 mm" de los parques estaban 3-4x por debajo de la
#     serie oficial del mismo libro (315mm=12" -> tubo 6m = 941.853);
#     ALMA CAFE alineada a las series RDE21 y recebo/arena del libro.
# Idempotente: inserta solo si no existe; update por descripcion exacta.
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$catBOX = "CABEZALES, CAMARAS Y BOX CULVERT (DESCOLES)"
$nuevos = @(
  @($catBOX, 'MAT - Concreto industrializado 4000 psi', "M3", 650000),
  @($catBOX, 'MAT - Concreto tremie 4000 psi', "M3", 780000),
  @($catBOX, 'sc-Bombeo de concreto', "M3", 60000),
  @($catBOX, 'MO - Concreto de limpieza', "M2", 30000),
  @($catBOX, 'MO - Box Culvert(Incluye formaleta y consumible)', "M3", 400000),
  @($catBOX, 'MO - Pilote Preexcavado ø50cm', "ML", 380000),
  @($catBOX, 'Movilizacion equipos pilotaje hinca y prebarrena', "UN", 18000000),
  @($catBOX, 'MAT - Hierro 60000 PSI', "KG", 7500),
  @($catBOX, 'MAT - Alambre negro', "KG", 6000),
  @($catBOX, 'MO - Manejo de hierro', "KG", 2800),
  @($catBOX, 'SC-Cinta PVC', "ML", 65000),
  @($catBOX, 'PRUEBAS HERMETICIDAD-CCTV', "UN", 6000000),
  @($catBOX, 'HSEQ', "UN", 9000000),
  @($catBOX, 'PALETEROS', "MES", 5500000),
  @($catBOX, 'POLIZAS - PARA CONTRATO DE URBANISMO CON EL ADMON DELEGADO', "GB", 25000000),
  @($catBOX, 'TRAMITE ENTREGA CAR', "GB", 25000000),
  @($catBOX, 'VIGILANCIA MIENTRAS SE ENTREGAN LAS OBRAS', "MES", 8000000)
)
$updates = @(
  @('Suministro tuberia novafor 315 mm 6"- 6 mts', 941853),
  @('Mano de obra tuberia novafort 315 mm - 6"', 42702),
  @('Suministro tuberia novafor 250 mm 8"- 6 mts', 654547),
  @('Suministro tuberia novafor 315 mm 4"- 6 mts', 941853),
  @('Mano de obra tuberia novafort 315 mm - 4"', 42702),
  @('TUBERIA PVC-RDE21 4"', 228893),
  @('RELLENO EN ARENA DE PEÑA', 110000),
  @('RELLENO EN RECEBO B-200', 110000),
  @('Dren filtro 200 mm (filtro frances)', 110000)
)
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (300 * $t) }
  }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $xl.Calculation = -4135
  $ws = $wb.Worksheets.Item("PRECIOS_UNITARIOS")
  $last = $ws.Cells.Item($ws.Rows.Count, 2).End(-4162).Row
  Write-Output ("PU ultima fila: " + $last)
  $descArr = $ws.Range("B2:B$last").Value2
  $mapa = @{}
  for ($i = 1; $i -le $descArr.GetLength(0); $i++) {
    $v = $descArr[$i, 1]
    if ($v -and -not $mapa.ContainsKey([string]$v)) { $mapa[[string]$v] = $i + 1 }
  }
  $agregados = 0; $r = $last
  foreach ($n in $nuevos) {
    if ($mapa.ContainsKey([string]$n[1])) { Write-Output ("  ya existe: " + $n[1]); continue }
    $r++
    Retry { $ws.Cells.Item($r, 1).Value2 = $n[0] }
    Retry { $ws.Cells.Item($r, 2).Value2 = $n[1] }
    Retry { $ws.Cells.Item($r, 3).Value2 = $n[2] }
    Retry { $ws.Cells.Item($r, 4).Value2 = [double]$n[3] }
    $agregados++
  }
  Write-Output ("precios agregados: " + $agregados)
  $corregidos = 0
  foreach ($u in $updates) {
    if ($mapa.ContainsKey([string]$u[0])) {
      $fila = $mapa[[string]$u[0]]
      $antes = $ws.Cells.Item($fila, 4).Value2
      Retry { $ws.Cells.Item($fila, 4).Value2 = [double]$u[1] }
      Write-Output ("  coherencia fila " + $fila + ": '" + $u[0] + "' " + [math]::Round([double]$antes,0) + " -> " + $u[1])
      $corregidos++
    } else { Write-Output ("  OJO no encontrada para corregir: " + $u[0]) }
  }
  Write-Output ("precios corregidos: " + $corregidos)
  $xl.Calculation = -4105
  try { $xl.CalculateFull() } catch {}
  Retry { $wb.Save() }
  Write-Output "GUARDADO precios ronda 3"
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}