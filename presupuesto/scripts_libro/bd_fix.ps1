# BD_PE ROBUSTA (2026-09-07): el error del usuario al refrescar
# ("The column 'GEN' of the table wasn't found") venia de la lista
# rigida de SelectColumns. Ahora la query QUITA las columnas
# estructurales por nombre (MissingField.Ignore) y hace
# UnpivotOtherColumns: CUALQUIER juego de columnas de subetapas
# funciona (GEN incluida, y las que se agreguen despues).
# Luego: RefreshAll sincrono + refresh de la dinamica + verificacion.
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (400 * $t) }
  }
}
$mPE = @'
let
  Src = Excel.CurrentWorkbook(){[Name="PE_RANGO"]}[Content],
  Prom = Table.PromoteHeaders(Src, [PromoteAllScalars=true]),
  ConNivel = Table.SelectRows(Prom, each [NIVEL] <> null and [NIVEL] <> ""),
  N1a = Table.AddColumn(ConNivel, "N1", each if Value.Is([NIVEL], type number) and [NIVEL] = 1 then Text.From([#"ITEM (CODIGO)"]) & " " & Text.From([DESCRIPCION]) else null),
  N2a = Table.AddColumn(N1a, "N2", each if Value.Is([NIVEL], type number) and [NIVEL] = 2 then Text.From([#"ITEM (CODIGO)"]) & " " & Text.From([DESCRIPCION]) else null),
  N3a = Table.AddColumn(N2a, "N3", each if Value.Is([NIVEL], type number) and [NIVEL] = 3 then Text.From([#"ITEM (CODIGO)"]) & " " & Text.From([DESCRIPCION]) else null),
  N4a = Table.AddColumn(N3a, "N4", each if Value.Is([NIVEL], type number) and [NIVEL] = 4 then Text.From([#"ITEM (CODIGO)"]) & " " & Text.From([DESCRIPCION]) else null),
  Fill = Table.FillDown(N4a, {"N1","N2","N3","N4"}),
  Solo5 = Table.SelectRows(Fill, each Value.Is([NIVEL], type number) and [NIVEL] = 5),
  N5a = Table.AddColumn(Solo5, "N5", each Text.From([#"ITEM (CODIGO)"]) & " " & Text.From([DESCRIPCION]) & " (" & Text.From([UM]) & ")"),
  Vun = Table.AddColumn(N5a, "VU", each try Number.From([VR_UNITARIO]) otherwise 0),
  SinEstr = Table.RemoveColumns(Vun, {"NIVEL","PARENT_CODIGO","ITEM (CODIGO)","DESCRIPCION","CANTIDAD","VR_UNITARIO","VALOR_TOTAL"}, MissingField.Ignore),
  Unp = Table.UnpivotOtherColumns(SinEstr, {"N1","N2","N3","N4","N5","UM","VU"}, "SUBETAPA", "CANTRAW"),
  Num = Table.AddColumn(Unp, "CANTIDAD", each try Number.From([CANTRAW]) otherwise 0),
  NoCero = Table.SelectRows(Num, each [CANTIDAD] <> 0),
  Eta = Table.AddColumn(NoCero, "ETAPA", each if [SUBETAPA] = "GEN" then "GENERAL" else let d = Number.From(Text.Start([SUBETAPA],1)) in Text.From(if d <= 2 then d + 1 else d)),
  VT = Table.AddColumn(Eta, "VALOR_TOTAL", each [CANTIDAD] * [VU]),
  Fin = Table.SelectColumns(VT, {"N1","N2","N3","N4","N5","ETAPA","SUBETAPA","UM","CANTIDAD","VU","VALOR_TOTAL"}),
  Ren = Table.RenameColumns(Fin, {{"VU","VR_UNITARIO"}})
in
  Ren
'@
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
$ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $xl.Calculation = -4135

  # 1) reemplazar la formula de BD_PE
  $q = $wb.Queries.Item("BD_PE")
  Retry { $q.Formula = $mPE }
  Write-Output "BD_PE reescrita (UnpivotOtherColumns robusto)"

  # 2) refrescar la tabla BD_CONSOL (sincrono) y todo lo demas
  $wsB = $wb.Worksheets.Item("BD")
  $loB = $wsB.ListObjects.Item("BD_CONSOL")
  Retry { $loB.QueryTable.BackgroundQuery = $false }
  Retry { $loB.QueryTable.Refresh($false) | Out-Null }
  $filas = $loB.DataBodyRange.Rows.Count
  Write-Output ("BD_CONSOL refrescada: " + $filas + " filas")
  if ($filas -lt 1500) { throw "VERIFICACION FALLO: BD_CONSOL con muy pocas filas" }

  # 3) refrescar la dinamica
  $wsD = $wb.Worksheets.Item("DINAMICA")
  $pt = $wsD.PivotTables("DinamicaPpto")
  Retry { $pt.PivotCache().Refresh() | Out-Null }
  Write-Output "DinamicaPpto refrescada"

  # 4) verificar que la BD trae subetapa GEN y filas de pluvial nuevas
  $datosB = $loB.DataBodyRange.Value2
  $nGen = 0; $nPlu = 0
  $cSub = 0; $cN5 = 0
  $hdrs = $loB.HeaderRowRange.Value2
  for ($j = 1; $j -le $hdrs.GetLength(1); $j++) {
    if ([string]$hdrs[1, $j] -eq "SUBETAPA") { $cSub = $j }
    if ([string]$hdrs[1, $j] -eq "N5") { $cN5 = $j }
  }
  for ($i = 1; $i -le $datosB.GetLength(0); $i++) {
    if ([string]$datosB[$i, $cSub] -eq "GEN") { $nGen++ }
    $n5v = [string]$datosB[$i, $cN5]
    if ($n5v -like "*PVC flexible*" -and $n5v -like "*Instalación*") { $nPlu++ }
  }
  Write-Output ("verif BD: filas con SUBETAPA=GEN " + $nGen + " | filas Instalacion PVC flexible " + $nPlu)
  if ($nGen -lt 5) { throw "VERIFICACION FALLO: no llegaron filas GEN a la BD" }

  # 5) RefreshAll global (queries + pivot) para dejar el 'Actualizar todo' probado
  Retry { $wb.RefreshAll() }
  Start-Sleep -Seconds 4
  $xl.Calculation = -4105
  try { $xl.CalculateFull() } catch {}
  Retry { $wb.Save() }
  $ok = $true
  Write-Output "GUARDADO BD + dinamica"
} finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO (fallo el refresh o la verificacion)" }