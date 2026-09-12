# DINAMICA (2026-09-11, pedido del usuario):
#  1) tabla nueva en A3: ETAPA / SUBETAPA / nivel 1 (1 EJECUTADO,
#     2 ACTIVIDADES POR EJECUTAR...) con el VT total. Sale de la misma BD.
#  2) colores por nivel y subtotales de CANTIDAD / V.UNITARIO ocultos con
#     FORMATO CONDICIONAL sobre el nivel (columna auxiliar oculta que busca
#     la etiqueta en la tabla BD): asi sobreviven a cualquier "Actualizar
#     todo". Antes era formato de celda y al crecer la dinamica se corria.
param(
  [string]$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx",
  [int]$filaTope = 6000
)
$ErrorActionPreference = "Stop"
$logf = Join-Path $PSScriptRoot "dinamica_a3.log"
function Log($m) { [System.IO.File]::AppendAllText($logf, ((Get-Date).ToString("HH:mm:ss") + "  " + $m + [Environment]::NewLine)); Write-Output $m }
function Retry([scriptblock]$__sb) { for ($t = 1; $t -le 8; $t++) { try { return (& $__sb) } catch { if ($t -eq 8) { throw }; Start-Sleep -Milliseconds (400 * $t) } } }
function LetraCol([int]$n) { $s = ""; while ($n -gt 0) { $m = ($n - 1) % 26; $s = [char](65 + $m) + $s; $n = [math]::Floor(($n - 1) / 26) }; $s }
function Hoja($wb, $nombre) {
  $h = $null
  for ($t = 1; $t -le 6 -and -not $h; $t++) {
    try { for ($k = 1; $k -le $wb.Worksheets.Count; $k++) { $w = $wb.Worksheets.Item($k); if ($w.Name -eq $nombre) { $h = $w } } } catch {}
    if (-not $h) { Start-Sleep -Seconds 2 }
  }
  if (-not $h) { throw ("no pude tomar la hoja " + $nombre) }
  $h
}
$colores = @{ 1 = 0x808080; 2 = 0x99FFFF; 3 = 0xF7DCC4; 4 = 0xD1E8FF }

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null; $ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  if ($wb.ReadOnly) { throw "el libro abrio en SOLO LECTURA" }
  $wsD = Hoja $wb "DINAMICA"
  $wsB = Hoja $wb "BD"
  $pt = $wsD.PivotTables("DinamicaPpto")
  Log ("pivot principal en " + $pt.TableRange2.Address())

  # ---------- 0) la BD gana una etiqueta de etapa ----------
  # "ETAPA 2" en vez de "2": los codigos de subetapa (2, 3...) son iguales a
  # los numeros de etapa y al pintar por nivel se confundian
  $qBD = $wb.Queries.Item("BD_CONSOL")
  if ($qBD.Formula -notmatch 'ETAPA_TXT') {
    $qBD.Formula = @'
let
  A = BD_PE,
  B = BD_EJEC,
  Uni = Table.Combine({B, A}),
  Eta = Table.AddColumn(Uni, "ETAPA_TXT", each if [ETAPA] = null then "SIN ETAPA" else "ETAPA " & Text.From([ETAPA]))
in
  Eta
'@
    Log "query BD_CONSOL: + columna ETAPA_TXT"
    Start-Sleep -Seconds 5
  }

  # ---------- 1) refrescar BD y dinamica ----------
  $loB = Retry { $wsB.ListObjects.Item("BD_CONSOL") }
  Retry { $loB.QueryTable.BackgroundQuery = $false } | Out-Null
  Retry { $loB.QueryTable.Refresh($false) | Out-Null } | Out-Null
  # OJO: recorrer .Cells con foreach devuelve UN solo objeto con toda la
  # fila (y el encabezado sale como "N1 N2 N3 ..."): se indexa celda a celda
  $bh = @()
  for ($c = 1; $c -le $loB.HeaderRowRange.Columns.Count; $c++) { $bh += [string]$loB.HeaderRowRange.Cells.Item(1, $c).Value2 }
  Log ("BD_CONSOL: " + $loB.DataBodyRange.Rows.Count + " filas | " + ($bh -join ","))
  Retry { $pt.PivotCache().Refresh() | Out-Null } | Out-Null
  $pt.PreserveFormatting = $true
  foreach ($fn in @("N1","N2","N3","N4")) { try { $pt.PivotFields($fn).ShowDetail = $true } catch {} }

  $idx = @{}
  foreach ($nm in @("N1","N2","N3","N4","ETAPA","SUBETAPA","ETAPA_TXT")) {
    $i = [array]::IndexOf($bh, $nm)
    if ($i -lt 0) { throw ("la BD no trae la columna " + $nm) }
    $idx[$nm] = LetraCol ($i + 1)
  }

  # ---------- 2) tabla nueva en A3 (ETAPAS / SUBETAPAS / nivel 1) ----------
  $existe = $false
  for ($i = 1; $i -le $wsD.PivotTables().Count; $i++) { if ($wsD.PivotTables($i).Name -eq "ResumenEtapas") { $existe = $true } }
  if (-not $existe) {
    $npt = Retry { $pt.PivotCache().CreatePivotTable("DINAMICA!R3C1", "ResumenEtapas") }
    Start-Sleep -Seconds 2
    $pos = 1
    foreach ($nm in @("ETAPA_TXT","SUBETAPA","N1")) {
      $campo = Retry { $npt.PivotFields($nm) }
      Retry { $campo.Orientation = 1 } | Out-Null
      Retry { $campo.Position = $pos } | Out-Null
      $pos = $pos + 1
    }
    $df = Retry { $npt.AddDataField($npt.PivotFields("VALOR_TOTAL"), "VT total", -4157) }
    Retry { $df.NumberFormat = "`$ #.##0" } | Out-Null
    # xlCompactRow = 0 (con 1 = tabular salen 3 columnas de etiqueta y se
    # come la columna D que usa el auxiliar)
    try { $npt.RowAxisLayout(0) } catch {}
    Retry { $npt.ColumnGrand = $false } | Out-Null
    Retry { $npt.RowGrand = $true } | Out-Null
    try { $npt.TableStyle2 = $pt.TableStyle2 } catch {}
    Log ("tabla nueva ResumenEtapas en " + $npt.TableRange2.Address())
  } else {
    $npt = $wsD.PivotTables("ResumenEtapas")
    try { $npt.RowAxisLayout(0) } catch {}
    Retry { $npt.PivotCache().Refresh() | Out-Null } | Out-Null
    Log ("ResumenEtapas ya existia en " + $npt.TableRange2.Address())
  }

  # ---------- 3) columnas auxiliares de NIVEL (ocultas) ----------
  $gCol = $pt.TableRange2.Column
  $gLet = LetraCol $gCol
  $ultCol = $gCol + $pt.TableRange2.Columns.Count - 1
  $auxCol = $ultCol + 2
  $auxLet = LetraCol $auxCol
  $fila0 = $pt.TableRange2.Row + 1
  $fNivel = '=IF($' + $gLet + $fila0 + '="","",IFERROR(MATCH($' + $gLet + $fila0 + ',BD!$' + $idx["N1"] + '$2:$' + $idx["N1"] + '$' + $filaTope + ',0)*0+1,IFERROR(MATCH($' + $gLet + $fila0 + ',BD!$' + $idx["N2"] + '$2:$' + $idx["N2"] + '$' + $filaTope + ',0)*0+2,IFERROR(MATCH($' + $gLet + $fila0 + ',BD!$' + $idx["N3"] + '$2:$' + $idx["N3"] + '$' + $filaTope + ',0)*0+3,IFERROR(MATCH($' + $gLet + $fila0 + ',BD!$' + $idx["N4"] + '$2:$' + $idx["N4"] + '$' + $filaTope + ',0)*0+4,5)))))'
  Retry { $wsD.Range($auxLet + $fila0 + ":" + $auxLet + $filaTope).Formula = $fNivel } | Out-Null
  Retry { $wsD.Range($auxLet + ($fila0 - 1)).Value2 = "NIVEL (aux)" } | Out-Null
  Retry { $wsD.Columns($auxLet + ":" + $auxLet).Hidden = $true } | Out-Null
  $fNivR = '=IF($A4="","",IFERROR(MATCH($A4,BD!$' + $idx["ETAPA_TXT"] + '$2:$' + $idx["ETAPA_TXT"] + '$' + $filaTope + ',0)*0+1,IFERROR(MATCH($A4,BD!$' + $idx["SUBETAPA"] + '$2:$' + $idx["SUBETAPA"] + '$' + $filaTope + ',0)*0+2,IFERROR(MATCH($A4,BD!$' + $idx["N1"] + '$2:$' + $idx["N1"] + '$' + $filaTope + ',0)*0+3,4))))'
  Retry { $wsD.Range("D4:D" + $filaTope).Formula = $fNivR } | Out-Null
  Retry { $wsD.Range("D3").Value2 = "NIVEL (aux)" } | Out-Null
  Retry { $wsD.Columns("D:D").Hidden = $true } | Out-Null
  Log ("auxiliares: principal en " + $auxLet + " (etiquetas " + $gLet + "), resumen en D")

  # ---------- 4) formato condicional por nivel ----------
  # principal: fila completa por color + CANTIDAD/V.UNITARIO ocultos en los
  # niveles 1..4 (solo se ve el VALOR_TOTAL y el desembolsado)
  $rngP = $wsD.Range($gLet + $fila0 + ":" + (LetraCol $ultCol) + $filaTope)
  Retry { $rngP.FormatConditions.Delete() } | Out-Null
  foreach ($niv in @(1,2,3,4)) {
    $fc = Retry { $rngP.FormatConditions.Add(2, 0, ("=$" + $auxLet + $fila0 + "=" + $niv)) }
    $fc.Interior.Color = $colores[$niv]
    $fc.Font.Bold = $true
    if ($niv -eq 1) { $fc.Font.Color = 0xFFFFFF } else { $fc.Font.Color = 0 }
  }
  $rngCV = $wsD.Range((LetraCol ($gCol + 1)) + $fila0 + ":" + (LetraCol ($gCol + 2)) + $filaTope)
  # sin AND(): este Excel rechaza la coma como separador de argumentos al
  # crear la regla por COM -- el producto de comparaciones hace lo mismo
  $fc = Retry { $rngCV.FormatConditions.Add(2, 0, ("=($" + $auxLet + $fila0 + ">0)*($" + $auxLet + $fila0 + "<5)")) }
  $fc.NumberFormat = ";;;"
  Log ("formato condicional: " + $rngP.Address() + " (4 niveles) + " + $rngCV.Address() + " (cantidad/VU ocultos)")
  # resumen A:B, tres niveles
  $rngR = $wsD.Range("A4:B" + $filaTope)
  Retry { $rngR.FormatConditions.Delete() } | Out-Null
  foreach ($niv in @(1,2,3)) {
    $fc = Retry { $rngR.FormatConditions.Add(2, 0, ("=`$D4=" + $niv)) }
    $fc.Interior.Color = $colores[$niv]
    $fc.Font.Bold = $true
    if ($niv -eq 1) { $fc.Font.Color = 0xFFFFFF } else { $fc.Font.Color = 0 }
  }
  # ---------- 5) verificar que el formato aguanta un refresh ----------
  Retry { $pt.PivotCache().Refresh() | Out-Null } | Out-Null
  Retry { $npt.PivotCache().Refresh() | Out-Null } | Out-Null
  $muestra = @()
  for ($r = $fila0; $r -le $fila0 + 6; $r++) {
    $muestra += ("   " + $wsD.Cells.Item($r, $gCol).Text + " | nivel " + $wsD.Cells.Item($r, $auxCol).Text +
      " | color " + $wsD.Cells.Item($r, $gCol).DisplayFormat.Interior.Color +
      " | cant [" + $wsD.Cells.Item($r, $gCol + 1).Text + "]")
  }
  Log "muestra del principal despues de refrescar:"; foreach ($m in $muestra) { Log $m }
  $muestra = @()
  for ($r = 4; $r -le 10; $r++) { $muestra += ("   " + $wsD.Cells.Item($r,1).Text + " | nivel " + $wsD.Cells.Item($r,4).Text + " | " + $wsD.Cells.Item($r,2).Text + " | color " + $wsD.Cells.Item($r,1).DisplayFormat.Interior.Color) }
  Log "muestra del resumen:"; foreach ($m in $muestra) { Log $m }
  Retry { $wb.Save() } | Out-Null
  $ok = $true
  Log "GUARDADO"
} finally {
  if ($wb) { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO" }
