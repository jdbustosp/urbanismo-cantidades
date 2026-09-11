# Escribe la hoja EJECUTADO de 5 niveles en el libro vigente y conecta la
# dinamica (2026-09-11). Exige el libro CERRADO. AutoSaveOn=false. Verifica
# antes de guardar; si algo no cuadra, cierra SIN guardar.
#   EJECUTADO    -> VALOR_TOTAL en la BD de la dinamica
#   DESEMBOLSADO -> VR_DESEM_FOVIS en la BD (campo "VR DESEM. FOVIS")
param(
  [string]$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx",
  [string]$tsv = (Join-Path $PSScriptRoot 'ejecutado_nuevo.tsv'),
  [double]$espEjec = 159172738549.89,
  [double]$espDes = 158048497876
)
$ErrorActionPreference = "Stop"
$ci = [System.Globalization.CultureInfo]::InvariantCulture
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 6; $t++) { try { return (& $__sb) } catch { if ($t -eq 6) { throw }; Start-Sleep -Milliseconds (500 * $t) } }
}
function LetraC([int]$n) { $s = ""; while ($n -gt 0) { $m = ($n - 1) % 26; $s = [char](65 + $m) + $s; $n = [math]::Floor(($n - 1) / 26) }; $s }

# ---------- datos ----------
$lin = [System.IO.File]::ReadAllLines($tsv, [System.Text.Encoding]::UTF8)
$hdr = $lin[0].Split("`t"); $nc = $hdr.Count; $nr = $lin.Count
$colTexto = @('NIVEL4','ACTA','NIT','FECHA')
$colNum = @('EJECUTADO','DESEMBOLSADO','VR_TOTAL_ANT_BD','ANO_ACTA')
$arr = New-Object 'object[,]' $nr, $nc
for ($j = 0; $j -lt $nc; $j++) { $arr[0, $j] = $hdr[$j] }
for ($i = 1; $i -lt $nr; $i++) {
  $t = $lin[$i].Split("`t")
  for ($j = 0; $j -lt $nc; $j++) {
    $v = if ($j -lt $t.Count) { $t[$j] } else { '' }
    $h = $hdr[$j]
    if ($h -eq 'FECHA' -and $v -match '^\d+(\.\d+)?$') { $v = [DateTime]::FromOADate([double]::Parse($v, $ci)).ToString('dd/MM/yyyy') }
    if ($colNum -contains $h) { if ($v -eq '') { $arr[$i, $j] = $null } else { $arr[$i, $j] = [double]::Parse($v, $ci) } }
    else { $arr[$i, $j] = $v }
  }
}
Write-Output ("datos: " + ($nr - 1) + " filas x " + $nc + " columnas")

$mBdEjec = @'
let
  // 2026-09-11: EJECUTADO en 5 niveles (1 EJECUTADO / categoria / capitulo /
  // ACTA / CONTRATISTA). EJECUTADO -> VALOR_TOTAL (guiado por el desembolso y
  // nunca menor que el); DESEMBOLSADO -> VR_DESEM_FOVIS.
  Src = Excel.CurrentWorkbook(){[Name="EJECUTADO_Tabla"]}[Content],
  Base = Table.SelectColumns(Src, {"NIVEL1","NIVEL2","NIVEL3","NIVEL4","NIVEL5","ETAPA","SUBETAPA","EJECUTADO","DESEMBOLSADO"}),
  Ren = Table.RenameColumns(Base, {{"NIVEL1","N1"},{"NIVEL2","N2"},{"NIVEL3","N3"},{"NIVEL4","N4"},{"NIVEL5","N5"},{"EJECUTADO","VALOR_TOTAL"},{"DESEMBOLSADO","VR_DESEM_FOVIS"}}),
  Txt = Table.TransformColumns(Ren, {{"N4", each if _ = null then null else Text.From(_)}}),
  Num = Table.TransformColumns(Txt, {{"VALOR_TOTAL", each try Number.From(_) otherwise null}, {"VR_DESEM_FOVIS", each try Number.From(_) otherwise null}}),
  UM = Table.AddColumn(Num, "UM", each null),
  Cant = Table.AddColumn(UM, "CANTIDAD", each null),
  Vu = Table.AddColumn(Cant, "VR_UNITARIO", each null),
  Fin = Table.SelectColumns(Vu, {"N1","N2","N3","N4","N5","ETAPA","SUBETAPA","UM","CANTIDAD","VR_UNITARIO","VALOR_TOTAL","VR_DESEM_FOVIS"})
in
  Fin
'@

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null; $ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  if ($wb.ReadOnly) { throw "el libro abrio en SOLO LECTURA (alguien lo tiene abierto)" }
  $xl.ScreenUpdating = $false

  # ---------- 1) tabla EJECUTADO ----------
  $ws = $wb.Worksheets.Item("EJECUTADO")
  $lo = $ws.ListObjects.Item("EJECUTADO_Tabla")
  $estilo = $lo.TableStyle.Name
  Retry { $lo.Delete() } | Out-Null
  Retry { $ws.Cells.Clear() } | Out-Null
  for ($j = 0; $j -lt $nc; $j++) {
    if ($colTexto -contains $hdr[$j]) { $L = LetraC ($j + 1); Retry { $ws.Range("${L}1:${L}$nr").NumberFormat = "@" } | Out-Null }
  }
  $rng = $ws.Range("A1").Resize($nr, $nc)
  Retry { $rng.Value2 = $arr } | Out-Null
  $lo = Retry { $ws.ListObjects.Add(1, $rng, $null, 1) }
  $lo.Name = "EJECUTADO_Tabla"
  try { $lo.TableStyle = $estilo } catch {}
  foreach ($h in @('EJECUTADO','DESEMBOLSADO','VR_TOTAL_ANT_BD')) {
    $L = LetraC ([array]::IndexOf($hdr, $h) + 1); Retry { $ws.Range("${L}2:${L}$nr").NumberFormat = "`$ #.##0" } | Out-Null
  }
  Retry { $ws.Range("A1").Resize(1, $nc).Font.Bold = $true } | Out-Null
  Retry { $ws.Columns("A:T").AutoFit() | Out-Null } | Out-Null
  foreach ($h in @('DESCRIPCION_ACTA','NOTA','NIVEL3','NIVEL5','TERCERO','CLASIFICACION')) {
    $L = LetraC ([array]::IndexOf($hdr, $h) + 1); if ($ws.Columns($L).ColumnWidth -gt 55) { $ws.Columns($L).ColumnWidth = 55 }
  }
  Write-Output ("EJECUTADO_Tabla: " + $lo.Range.Address() + " estilo " + $estilo)

  # ---------- 2) query BD_EJEC ----------
  $wb.Queries.Item("BD_EJEC").Formula = $mBdEjec
  Write-Output "query BD_EJEC actualizada"

  # ---------- 3) refrescar BD_CONSOL y verificar ----------
  $loB = $wb.Worksheets.Item("BD").ListObjects.Item("BD_CONSOL")
  Retry { $loB.QueryTable.BackgroundQuery = $false } | Out-Null
  Retry { $loB.QueryTable.Refresh($false) | Out-Null } | Out-Null
  $bh = @(); foreach ($c in $loB.HeaderRowRange.Cells) { $bh += [string]$c.Value2 }
  Write-Output ("BD_CONSOL: " + $loB.DataBodyRange.Rows.Count + " filas | columnas: " + ($bh -join ","))
  $iN1 = [array]::IndexOf($bh, 'N1'); $iVT = [array]::IndexOf($bh, 'VALOR_TOTAL'); $iPG = [array]::IndexOf($bh, 'VR_DESEM_FOVIS')
  if ($iPG -lt 0) { throw "BD_CONSOL no trae VR_DESEM_FOVIS" }
  $v = $loB.DataBodyRange.Value2
  $sa = 0.0; $sd = 0.0; $ne = 0
  for ($i = 1; $i -le $v.GetLength(0); $i++) {
    if ([string]$v[$i, ($iN1 + 1)] -eq '1 EJECUTADO') {
      $ne++
      if ($v[$i, ($iVT + 1)] -is [double]) { $sa += $v[$i, ($iVT + 1)] }
      if ($v[$i, ($iPG + 1)] -is [double]) { $sd += $v[$i, ($iPG + 1)] }
    }
  }
  Write-Output ("BD_CONSOL EJECUTADO: " + $ne + " filas | ejecutado " + $sa.ToString('N0') + " | desembolsado " + $sd.ToString('N0'))
  if ([math]::Abs($sa - $espEjec) -gt 1 -or [math]::Abs($sd - $espDes) -gt 1) { throw "los totales de BD_CONSOL no cuadran con lo esperado" }

  # ---------- 4) dinamica: refrescar y agregar el DESEMBOLSADO ----------
  $wsD = $wb.Worksheets.Item("DINAMICA")
  $pt = $wsD.PivotTables("DinamicaPpto")
  Retry { $pt.PreserveFormatting = $true } | Out-Null
  Retry { $pt.PivotCache().Refresh() | Out-Null } | Out-Null
  $dfs = $pt.DataFields()
  $ya = $false; $nomVT = $null
  for ($i = 1; $i -le $dfs.Count; $i++) { $d = $dfs.Item($i); if ($d.SourceName -eq 'VR_DESEM_FOVIS') { $ya = $true }; if ($d.SourceName -eq 'VALOR_TOTAL') { $nomVT = $d.Name } }
  if (-not $ya) { Retry { $pt.AddDataField($pt.PivotFields("VR_DESEM_FOVIS"), "VR DESEM. FOVIS", -4157) | Out-Null } | Out-Null }
  Retry { $pt.DataFields().Item("VR DESEM. FOVIS").NumberFormat = "`$ #.##0" } | Out-Null
  $dfs = $pt.DataFields(); $df = @(); for ($i = 1; $i -le $dfs.Count; $i++) { $df += $dfs.Item($i).Name }
  Write-Output ("campos de valor: " + ($df -join " | ") + " (ejecutado = " + $nomVT + ")")
  $ga = $pt.GetPivotData($nomVT, "N1", "1 EJECUTADO").Value2
  $gd = $pt.GetPivotData("VR DESEM. FOVIS", "N1", "1 EJECUTADO").Value2
  Write-Output ("dinamica 1 EJECUTADO: ejecutado " + ([double]$ga).ToString('N0') + " | desembolsado " + ([double]$gd).ToString('N0'))
  if ([math]::Abs($ga - $espEjec) -gt 1 -or [math]::Abs($gd - $espDes) -gt 1) { throw "la dinamica no cuadra" }

  # ---------- 5) formato por nivel (criterio de dinamica_formatos.ps1, ahora
  #               con la columna del desembolsado) ----------
  foreach ($fn in @("N1","N2","N3","N4")) { try { $pt.PivotFields($fn).ShowDetail = $true } catch {} }
  $rngC = $pt.PivotFields("Suma CANTIDAD").DataRange
  $filaIni = $rngC.Row; $nFilas = $rngC.Rows.Count; $colC = $rngC.Column
  $LC = LetraC $colC; $LV = LetraC ($colC + 1); $LU = LetraC ($colC + $pt.DataFields().Count - 1)
  $niveles = New-Object 'int[]' $nFilas
  for ($i = 0; $i -lt $nFilas; $i++) { try { $niveles[$i] = $wsD.Cells.Item($filaIni + $i, $colC).PivotCell.RowItems.Count } catch { $niveles[$i] = 0 } }
  $colores = @{1 = 0x808080; 2 = 0x99FFFF; 3 = 0xF7DCC4; 4 = 0xD1E8FF }
  $i = 0; $bloques = 0
  while ($i -lt $nFilas) {
    $niv = $niveles[$i]; $j = $i
    while (($j + 1) -lt $nFilas -and $niveles[$j + 1] -eq $niv) { $j++ }
    $r1 = $filaIni + $i; $r2 = $filaIni + $j
    $rngFila = $wsD.Range("A$r1" + ":" + $LU + $r2)
    $rngCV = $wsD.Range($LC + $r1 + ":" + $LV + $r2)
    if ($niv -eq 5) {
      Retry { $wsD.Range($LC + $r1 + ":" + $LC + $r2).NumberFormat = "#.##0,00###" } | Out-Null
      Retry { $wsD.Range($LV + $r1 + ":" + $LV + $r2).NumberFormat = "`$ #.##0" } | Out-Null
      for ($q2 = $r1; $q2 -le $r2; $q2++) { if ($wsD.Cells.Item($q2, 1).Text -match '\(%\)\s*$') { Retry { $wsD.Cells.Item($q2, $colC).NumberFormat = "0,00%" } | Out-Null } }
      Retry { $rngFila.Interior.ColorIndex = -4142 } | Out-Null
      Retry { $rngFila.Font.Bold = $false } | Out-Null
      Retry { $rngFila.Font.Color = 0 } | Out-Null
    } else {
      Retry { $rngCV.NumberFormat = ";;;" } | Out-Null
      if ($niv -ge 1 -and $niv -le 4) {
        Retry { $rngFila.Interior.Color = $colores[$niv] } | Out-Null
        Retry { $rngFila.Font.Bold = $true } | Out-Null
        if ($niv -eq 1) { Retry { $rngFila.Font.Color = 0xFFFFFF } | Out-Null } else { Retry { $rngFila.Font.Color = 0 } | Out-Null }
      }
    }
    $bloques++; $i = $j + 1
  }
  Write-Output ("dinamica formateada: " + $nFilas + " filas, " + $bloques + " bloques, columnas A:" + $LU)
  try { $pt.PivotFields("N3").ShowDetail = $false } catch {}
  $xl.ScreenUpdating = $true
  Retry { $wb.Save() } | Out-Null
  $ok = $true
  Write-Output "GUARDADO"
} finally {
  if ($wb) { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
if (-not $ok) { throw "NO SE GUARDO" }
