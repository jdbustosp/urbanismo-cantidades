param([string]$libro)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$BARRA = [string][char]92
$SLASH = "/"

$trabajo = Join-Path $env:TEMP ("pvfmt_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
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

# ---------- 1) dxf nuevos SIEMPRE al final. No se reutilizan: buscarlos por
#               texto no era fiable y termino apuntando a colores ajenos.
$rutaEst = Join-Path $desc "xl\styles.xml"
$est = [System.IO.File]::ReadAllText($rutaEst, [System.Text.Encoding]::UTF8)
if (-not ($est -match '<dxfs count="(\d+)">([\s\S]*?)</dxfs>')) { throw "sin bloque dxfs" }
$nAntes = [int]$Matches[1]
$colores = @("FF808080", "FFFFFF9A", "FFC4DCF7", "FFFFE0D1")
$nuevos = ""
foreach ($c in $colores) {
  $nuevos += ('<dxf><fill><patternFill patternType="solid"><fgColor rgb="' + $c +
              '"/><bgColor rgb="' + $c + '"/></patternFill></fill></dxf>')
}
$nuevos += '<dxf><numFmt numFmtId="201" formatCode=";;;"/></dxf>'
$idFill = @($nAntes, ($nAntes + 1), ($nAntes + 2), ($nAntes + 3))
$idOcul = $nAntes + 4
$nTot = $nAntes + 5
$est = [regex]::Replace($est, '<dxfs count="\d+">', ('<dxfs count="' + $nTot + '">'), 1)
$est = [regex]::Replace($est, '</dxfs>', ($nuevos + '</dxfs>'), 1)
[System.IO.File]::WriteAllText($rutaEst, $est, $enc)
"dxfs: $nAntes -> $nTot | rellenos " + ($idFill -join ",") + " | oculto $idOcul"

function AplicarFormats($ruta, $camposSubtotal, $campoHoja, $idsRelleno, $idOculto, $datosOcultar) {
  $t = [System.IO.File]::ReadAllText($ruta, [System.Text.Encoding]::UTF8)
  # que la pivot SI aplique los formatos guardados cada vez que se actualiza
  $t = $t -replace 'applyNumberFormats="0"', 'applyNumberFormats="1"'
  $t = $t -replace 'applyPatternFormats="0"', 'applyPatternFormats="1"'
  $t = $t -replace 'applyBorderFormats="0"', 'applyBorderFormats="1"'
  $t = $t -replace 'applyFontFormats="0"', 'applyFontFormats="1"'
  $t = [regex]::Replace($t, '<formats[\s\S]*?</formats>', '')
  $fmts = ""
  $n = 0
  # a) color de la FILA COMPLETA de cada nivel con subtotal. Hacen falta DOS
  #    entradas: con defaultSubtotal el area solo cubre el ROTULO, y las
  #    celdas de valor de esa misma fila se piden como type="data" con
  #    collapsedLevelsAreSubtotals (comprobado: con una sola entrada el
  #    color llegaba unicamente a la primera columna).
  for ($i = 0; $i -lt $camposSubtotal.Count; $i++) {
    $campo = $camposSubtotal[$i]
    $dxf = $idsRelleno[$i]
    $fmts += ('<format dxfId="' + $dxf + '"><pivotArea dataOnly="0" labelOnly="1" ' +
              'fieldPosition="0"><references count="1"><reference field="' + $campo +
              '" count="0" defaultSubtotal="1"/></references></pivotArea></format>')
    $n++
    $fmts += ('<format dxfId="' + $dxf + '"><pivotArea type="data" ' +
              'collapsedLevelsAreSubtotals="1" fieldPosition="0"><references count="1">' +
              '<reference field="' + $campo + '" count="0" defaultSubtotal="1"/>' +
              '</references></pivotArea></format>')
    $n++
  }
  # b) color del ultimo nivel cuando NO tiene fila de subtotal (es la hoja)
  if ($campoHoja -ge 0) {
    $dxf = $idsRelleno[$camposSubtotal.Count]
    $fmts += ('<format dxfId="' + $dxf + '"><pivotArea dataOnly="0" fieldPosition="0">' +
              '<references count="1"><reference field="' + $campoHoja + '" count="0"/>' +
              '</references></pivotArea></format>')
    $n++
  }
  # c) ocultar campos de datos en las filas de subtotal y en el total general
  foreach ($d in $datosOcultar) {
    foreach ($campo in $camposSubtotal) {
      $fmts += ('<format dxfId="' + $idOculto + '"><pivotArea type="data" ' +
                'collapsedLevelsAreSubtotals="1" fieldPosition="0"><references count="2">' +
                '<reference field="4294967294" count="1"><x v="' + $d + '"/></reference>' +
                '<reference field="' + $campo + '" count="0" defaultSubtotal="1"/>' +
                '</references></pivotArea></format>')
      $n++
    }
    $fmts += ('<format dxfId="' + $idOculto + '"><pivotArea type="data" grandRow="1" ' +
              'fieldPosition="0"><references count="1">' +
              '<reference field="4294967294" count="1"><x v="' + $d + '"/></reference>' +
              '</references></pivotArea></format>')
    $n++
  }
  $bloque = '<formats count="' + $n + '">' + $fmts + '</formats>'
  $pos = $t.IndexOf("<pivotTableStyleInfo")
  if ($pos -lt 0) { throw "sin pivotTableStyleInfo en $ruta" }
  $t = $t.Substring(0, $pos) + $bloque + $t.Substring($pos)
  [System.IO.File]::WriteAllText($ruta, $t, $enc)
  "  " + (Split-Path -Leaf $ruta) + ": $n formatos de area de pivot"
}

# DinamicaPpto: N1=0 N2=1 N3=2 N4=3 N5=4 | datos 0=CANTIDAD 1=V.UNITARIO
AplicarFormats (Join-Path $desc "xl\pivotTables\pivotTable1.xml") @(0, 1, 2, 3) (-1) $idFill $idOcul @(0, 1)
# ResumenEtapas: ETAPA_TXT=12 SUBETAPA=6 N1=0 | la hoja es N2=1 | nada que ocultar
AplicarFormats (Join-Path $desc "xl\pivotTables\pivotTable2.xml") @(12, 6, 0) 1 $idFill $idOcul @()

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
$chk = [System.IO.Compression.ZipFile]::OpenRead($salida)
$mal = @($chk.Entries | Where-Object { $_.FullName.Contains($BARRA) }).Count
$chk.Dispose()
if ($mal -gt 0) { throw "quedaron barras invertidas en el zip" }
Copy-Item -LiteralPath $salida -Destination $libro -Force
"libro actualizado: " + (Get-Item -LiteralPath $libro).Length + " bytes"
"carpeta de trabajo (se puede borrar a mano): $trabajo"
