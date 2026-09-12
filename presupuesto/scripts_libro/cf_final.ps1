param([string]$libro)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
# ---------------------------------------------------------------------
# Color por nivel y ocultamiento en las DOS dinamicas, de forma que
# aguante que Excel guarde y actualice. Lo que se descubrio probando:
#
#  * Un formato condicional NORMAL de hoja sobre un rango que pisa una
#    pivot: al guardar, Excel le RECORTA el area de valores y solo le
#    deja la columna del rotulo.
#  * Un formato condicional con AMBITO DE PIVOT (extLst con pivot="1" +
#    <conditionalFormats> en la definicion de la pivot): al guardar,
#    Excel le deja el area de valores y le quita la columna del rotulo.
#  * El estilo de tabla dinamica solo expone 3 niveles de subtotal, y
#    le gana al formato, asi que va SIN relleno.
#  * El formato directo sobre las celdas no persiste en el area de
#    valores aunque PreserveFormatting este activo.
#
# O sea: los dos mecanismos son complementarios. Se usan ambos — el
# normal para la columna del rotulo y el de pivot para las columnas de
# valor.
# ---------------------------------------------------------------------
$BARRA = [string][char]92
$SLASH = "/"
$trabajo = Join-Path $env:TEMP ("cffin_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$desc = Join-Path $trabajo "x"
New-Item -ItemType Directory -Path $desc | Out-Null
$src = [System.IO.Compression.ZipFile]::OpenRead($libro)
$lista = @()
foreach ($e in $src.Entries) {
  $nombre = $e.FullName.Replace($BARRA, $SLASH)
  $lista += $nombre
  $destino = Join-Path $desc ($nombre.Replace($SLASH, $BARRA))
  $dir = Split-Path -Parent $destino
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $inS = $e.Open(); $outS = [System.IO.File]::Create($destino)
  $inS.CopyTo($outS); $outS.Close(); $inS.Close()
}
$src.Dispose()
$enc = New-Object System.Text.UTF8Encoding($false)

$wbx = [System.IO.File]::ReadAllText((Join-Path $desc "xl\workbook.xml"), [System.Text.Encoding]::UTF8)
$rels = [System.IO.File]::ReadAllText((Join-Path $desc "xl\_rels\workbook.xml.rels"), [System.Text.Encoding]::UTF8)
$rid = $null
foreach ($m in [regex]::Matches($wbx, '<sheet[^>]*/>')) {
  if ($m.Value -match 'name="DINAMICA"' -and $m.Value -match 'r:id="([^"]+)"') { $rid = $Matches[1] }
}
$target = $null
foreach ($m in [regex]::Matches($rels, '<Relationship[^>]*/>')) {
  if ($m.Value -match ('Id="' + [regex]::Escape($rid) + '"') -and $m.Value -match 'Target="([^"]+)"') { $target = $Matches[1] }
}
$rutaHoja = Join-Path $desc ("xl" + $BARRA + (($target -replace '^/xl/', '' -replace '^\./', '') -replace $SLASH, $BARRA))
function RutaPivot($desc, $nombre) {
  foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $desc "xl\pivotTables") -Filter *.xml)) {
    $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    if ($t -match ('<pivotTableDefinition[^>]*\sname="' + [regex]::Escape($nombre) + '"')) { return $f.FullName }
  }
  throw "no se encontro $nombre"
}
function Esc($s) { $s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;") }
function Guid12 { "{" + ([guid]::NewGuid().ToString().ToUpper()) + "}" }

# ---- dxf para el formato NORMAL (van en styles.xml) ----
$rutaEst = Join-Path $desc "xl\styles.xml"
$est = [System.IO.File]::ReadAllText($rutaEst, [System.Text.Encoding]::UTF8)
if (-not ($est -match '<dxfs count="(\d+)">')) { throw "sin dxfs" }
$nAntes = [int]$Matches[1]
$colores = @("FF808080", "FFFFFF9A", "FFC4DCF7", "FFFFE0D1")
$nuevos = ""
foreach ($c in $colores) {
  $nuevos += ('<dxf><fill><patternFill patternType="solid"><fgColor rgb="' + $c +
              '"/><bgColor rgb="' + $c + '"/></patternFill></fill></dxf>')
}
$ids = @($nAntes, ($nAntes + 1), ($nAntes + 2), ($nAntes + 3))
$est = [regex]::Replace($est, '<dxfs count="\d+">', ('<dxfs count="' + ($nAntes + 4) + '">'), 1)
$est = [regex]::Replace($est, '</dxfs>', ($nuevos + '</dxfs>'), 1)
[System.IO.File]::WriteAllText($rutaEst, $est, $enc)
"dxfs de la hoja: $nAntes -> " + ($nAntes + 4)

# ---- dxf inline para el formato con ambito de pivot ----
$dxfColor = @()
foreach ($c in $colores) {
  $dxfColor += ('<x14:dxf><fill><patternFill patternType="solid"><fgColor rgb="' + $c +
                '"/><bgColor rgb="' + $c + '"/></patternFill></fill></x14:dxf>')
}
$dxfOcul = '<x14:dxf><numFmt numFmtId="231" formatCode=";;;"/></x14:dxf>'

$reglasHoja = ""       # x14, ambito de pivot -> columnas de VALOR
$cfPivot = @{ "DinamicaPpto" = ""; "ResumenEtapas" = "" }
$pri = 1
# OJO: con ambito de pivot, Excel usa el <pivotArea> como ambito real y
# pasa por encima del sqref. Si el area va sin referencias ("todas las
# celdas de datos"), la regla toca las CUATRO columnas de valor. Para que
# el ocultamiento caiga solo en CANTIDAD y V. UNITARIO hay que nombrar el
# campo de datos: field="4294967294" es el pseudo-campo "Valores" y
# <x v="n"/> el indice del dato (0 = Suma CANTIDAD, 1 = V. UNITARIO PROM,
# 2 = Suma VALOR_TOTAL, 3 = VR DESEM. FOVIS).
function ReglaPivot([string]$pivot, [string]$sqref, [string]$dxf, [string]$formula,
                    [bool]$stop, [int]$dato) {
  $s = '<x14:conditionalFormatting xmlns:xm="http://schemas.microsoft.com/office/excel/2006/main" pivot="1">' +
       '<x14:cfRule type="expression" priority="' + $script:pri + '"'
  if ($stop) { $s += ' stopIfTrue="1"' }
  $s += ' id="' + (Guid12) + '"><xm:f>' + (Esc $formula) + '</xm:f>' + $dxf +
        '</x14:cfRule><xm:sqref>' + $sqref + '</xm:sqref></x14:conditionalFormatting>'
  $script:reglasHoja += $s
  $area = '<pivotArea type="data" collapsedLevelsAreSubtotals="1" fieldPosition="0"'
  if ($dato -ge 0) {
    $area += '><references count="1"><reference field="4294967294" count="1"><x v="' +
             $dato + '"/></reference></references></pivotArea>'
  } else {
    $area += '/>'
  }
  $script:cfPivot[$pivot] += ('<conditionalFormat priority="' + $script:pri +
    '" scope="data" type="all"><pivotAreas count="1">' + $area + '</pivotAreas></conditionalFormat>')
  $script:pri++
}
# --- DinamicaPpto: ocultar SOLO cantidad (dato 0) y v.unitario (dato 1) ---
$fOcul = 'IF($G4="",FALSE,COUNTIF(BD!$E$2:$E$4000,$G4)=0)'
ReglaPivot "DinamicaPpto" "H4:H1609" $dxfOcul $fOcul $false 0
ReglaPivot "DinamicaPpto" "I4:I1609" $dxfOcul $fOcul $false 1
# --- DinamicaPpto: color en las CUATRO columnas de valor ---
$colsBD = @("A", "B", "C", "D")
for ($i = 0; $i -lt 4; $i++) {
  $f = 'IF($G4="",FALSE,COUNTIF(BD!$' + $colsBD[$i] + '$2:$' + $colsBD[$i] + '$4000,$G4)>0)'
  ReglaPivot "DinamicaPpto" "H4:K1609" $dxfColor[$i] $f $true (-1)
}
# --- ResumenEtapas: valores (B), 3 niveles; el ultimo va sin color ---
$colsR = @("M", "G", "A")
for ($i = 0; $i -lt 3; $i++) {
  $f = 'IF($A4="",FALSE,COUNTIF(BD!$' + $colsR[$i] + '$2:$' + $colsR[$i] + '$4000,$A4)>0)'
  ReglaPivot "ResumenEtapas" "B4:B452" $dxfColor[$i] $f $true (-1)
}
"reglas con ambito de pivot: " + ($pri - 1)

# ---- formato NORMAL para las columnas de ROTULO ----
function ReglaHoja($dxf, $priN, $formula) {
  '<cfRule type="expression" dxfId="' + [string]$dxf + '" priority="' + [string]$priN +
  '" stopIfTrue="1"><formula>' + (Esc $formula) + '</formula></cfRule>'
}
$cfNormal = '<conditionalFormatting sqref="G4:G4000">'
for ($i = 0; $i -lt 4; $i++) {
  $f = 'IF($G4="",FALSE,COUNTIF(BD!$' + $colsBD[$i] + '$2:$' + $colsBD[$i] + '$4000,$G4)>0)'
  $cfNormal += (ReglaHoja $ids[$i] $pri $f); $pri++
}
$cfNormal += '</conditionalFormatting><conditionalFormatting sqref="A4:A4000">'
for ($i = 0; $i -lt 3; $i++) {
  $f = 'IF($A4="",FALSE,COUNTIF(BD!$' + $colsR[$i] + '$2:$' + $colsR[$i] + '$4000,$A4)>0)'
  $cfNormal += (ReglaHoja $ids[$i] $pri $f); $pri++
}
$cfNormal += '</conditionalFormatting>'
"reglas normales de rotulo: 7"

# ---- escribir en las pivots ----
foreach ($nombre in @($cfPivot.Keys)) {
  $ruta = RutaPivot $desc $nombre
  $t = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
  $t = $t -replace 'applyNumberFormats="0"', 'applyNumberFormats="1"'
  $t = $t -replace 'applyPatternFormats="0"', 'applyPatternFormats="1"'
  $t = [regex]::Replace($t, '<conditionalFormats[\s\S]*?</conditionalFormats>', '')
  $t = [regex]::Replace($t, '<formats[\s\S]*?</formats>', '')
  $n = ([regex]::Matches($cfPivot[$nombre], '<conditionalFormat ')).Count
  if ($n -gt 0) {
    $bloque = '<conditionalFormats count="' + $n + '">' + $cfPivot[$nombre] + '</conditionalFormats>'
    $pos = $t.IndexOf("<pivotTableStyleInfo")
    $t = $t.Substring(0, $pos) + $bloque + $t.Substring($pos)
  }
  [System.IO.File]::WriteAllText($ruta, $t, $enc)
  "  " + $nombre + ": $n conditionalFormat de pivot"
}

# ---- escribir en la hoja ----
$t = [System.IO.File]::ReadAllText($rutaHoja, [System.Text.Encoding]::UTF8)
$t = [regex]::Replace($t, '<conditionalFormatting[\s\S]*?</conditionalFormatting>', '')
$t = [regex]::Replace($t, '<ext uri="\{78C0D931-6437-407d-A8EE-F0AAD7539E65\}"[\s\S]*?</ext>', '')
$anclas = @("<dataValidations", "<hyperlinks", "<printOptions", "<pageMargins", "<pageSetup",
            "<headerFooter", "<rowBreaks", "<colBreaks", "<drawing", "<legacyDrawing",
            "<tableParts", "<extLst", "</worksheet>")
$pos = -1
foreach ($a in $anclas) { $p = $t.IndexOf($a); if ($p -ge 0) { $pos = $p; break } }
$t = $t.Substring(0, $pos) + $cfNormal + $t.Substring($pos)
$ext = ('<ext uri="{78C0D931-6437-407d-A8EE-F0AAD7539E65}" ' +
        'xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main">' +
        '<x14:conditionalFormattings>' + $reglasHoja + '</x14:conditionalFormattings></ext>')
if ($t -match '<extLst>') { $t = [regex]::Replace($t, '<extLst>', ('<extLst>' + $ext), 1) }
else {
  $pos = $t.IndexOf("</worksheet>")
  $t = $t.Substring(0, $pos) + '<extLst>' + $ext + '</extLst>' + $t.Substring($pos)
}
[System.IO.File]::WriteAllText($rutaHoja, $t, $enc)
"hoja escrita"

$salida = Join-Path $trabajo "salida.xlsx"
$fs = [System.IO.File]::Create($salida)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($nombre in $lista) {
  $origen = Join-Path $desc ($nombre.Replace($SLASH, $BARRA))
  $entry = $zip.CreateEntry($nombre, [System.IO.Compression.CompressionLevel]::Optimal)
  $os = $entry.Open()
  $bytes = [System.IO.File]::ReadAllBytes($origen)
  $os.Write($bytes, 0, $bytes.Length); $os.Close()
}
$zip.Dispose(); $fs.Close()
Copy-Item -LiteralPath $salida -Destination $libro -Force
"libro actualizado: " + (Get-Item -LiteralPath $libro).Length + " bytes"
