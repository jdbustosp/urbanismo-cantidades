param([string]$libro)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

$trabajo = Join-Path $env:TEMP ("cfrot_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$desc = Join-Path $trabajo "x"
New-Item -ItemType Directory -Path $desc | Out-Null
$src = [System.IO.Compression.ZipFile]::OpenRead($libro)
$lista = @()
foreach ($e in $src.Entries) {
  $nombre = $e.FullName.Replace("\", "/")
  $lista += $nombre
  $destino = Join-Path $desc ($nombre.Replace("/", "\"))
  $dir = Split-Path -Parent $destino
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $inS = $e.Open(); $outS = [System.IO.File]::Create($destino)
  $inS.CopyTo($outS); $outS.Close(); $inS.Close()
}
$src.Dispose()

# hoja DINAMICA
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
$rutaHoja = Join-Path $desc ("xl\" + (($target -replace '^/xl/', '' -replace '^\./', '') -replace "/", "\"))

# ---- dxf: uno por nivel, reutilizando si ya existe el mismo ----
$rutaEst = Join-Path $desc "xl\styles.xml"
$est = [System.IO.File]::ReadAllText($rutaEst, [System.Text.Encoding]::UTF8)
$colores = @("FF808080", "FFFFFF9A", "FFC4DCF7", "FFFFE0D1")
$defs = @()
foreach ($c in $colores) {
  $defs += ('<dxf><fill><patternFill patternType="solid"><fgColor rgb="' + $c +
            '"/><bgColor rgb="' + $c + '"/></patternFill></fill></dxf>')
}
if (-not ($est -match '<dxfs count="(\d+)">([\s\S]*?)</dxfs>')) { throw "sin bloque dxfs" }
$existentes = @([regex]::Matches($Matches[2], '<dxf>[\s\S]*?</dxf>') | ForEach-Object { $_.Value })
$ids = @(); $faltan = ""; $n = $existentes.Count
foreach ($d in $defs) {
  $i = [array]::IndexOf($existentes, $d)
  if ($i -ge 0) { $ids += $i } else { $ids += $n; $faltan += $d; $n++ }
}
if ($faltan -ne "") {
  $est = [regex]::Replace($est, '<dxfs count="\d+">', ('<dxfs count="' + $n + '">'), 1)
  $est = [regex]::Replace($est, '</dxfs>', ($faltan + '</dxfs>'), 1)
  [System.IO.File]::WriteAllText($rutaEst, $est, (New-Object System.Text.UTF8Encoding($false)))
}
"dxfs: " + $n + " | ids nivel 1..4 = " + ($ids -join ",")

function Regla($dxf, $pri, $formula) {
  '<cfRule type="expression" dxfId="' + [string]$dxf + '" priority="' + [string]$pri +
  '" stopIfTrue="1"><formula>' +
  $formula.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;") +
  '</formula></cfRule>'
}
# SOLO la columna del rotulo de cada dinamica: es donde Excel deja vivir el
# formato condicional (el area de valores la maneja el estilo de la pivot).
$cf = '<conditionalFormatting sqref="G4:G4000">'
$cf += (Regla $ids[0] 1 'IF($G4="",FALSE,COUNTIF(BD!$A$2:$A$4000,$G4)>0)')
$cf += (Regla $ids[1] 2 'IF($G4="",FALSE,COUNTIF(BD!$B$2:$B$4000,$G4)>0)')
$cf += (Regla $ids[2] 3 'IF($G4="",FALSE,COUNTIF(BD!$C$2:$C$4000,$G4)>0)')
$cf += (Regla $ids[3] 4 'IF($G4="",FALSE,COUNTIF(BD!$D$2:$D$4000,$G4)>0)')
$cf += '</conditionalFormatting>'
$cf += '<conditionalFormatting sqref="A4:A4000">'
$cf += (Regla $ids[0] 5 'IF($A4="",FALSE,COUNTIF(BD!$M$2:$M$4000,$A4)>0)')
$cf += (Regla $ids[1] 6 'IF($A4="",FALSE,COUNTIF(BD!$G$2:$G$4000,$A4)>0)')
$cf += (Regla $ids[2] 7 'IF($A4="",FALSE,COUNTIF(BD!$A$2:$A$4000,$A4)>0)')
$cf += (Regla $ids[3] 8 'IF($A4="",FALSE,COUNTIF(BD!$B$2:$B$4000,$A4)>0)')
$cf += '</conditionalFormatting>'

$t = [System.IO.File]::ReadAllText($rutaHoja, [System.Text.Encoding]::UTF8)
$t = [regex]::Replace($t, '<conditionalFormatting[\s\S]*?</conditionalFormatting>', '')
# fuera tambien los restos que Excel haya movido al extLst
$t = [regex]::Replace($t, '<x14:conditionalFormattings>[\s\S]*?</x14:conditionalFormattings>', '')
$t = [regex]::Replace($t, '<ext uri="\{78C0D931-6437-407d-A8EE-F0AAD7539E65\}"[^>]*>\s*</ext>', '')
$anclas = @("<dataValidations", "<hyperlinks", "<printOptions", "<pageMargins", "<pageSetup",
            "<headerFooter", "<rowBreaks", "<colBreaks", "<drawing", "<legacyDrawing",
            "<tableParts", "<extLst", "</worksheet>")
$pos = -1
foreach ($a in $anclas) { $p = $t.IndexOf($a); if ($p -ge 0) { $pos = $p; break } }
$t = $t.Substring(0, $pos) + $cf + $t.Substring($pos)
[System.IO.File]::WriteAllText($rutaHoja, $t, (New-Object System.Text.UTF8Encoding($false)))
"formato condicional de rotulos inyectado"

$salida = Join-Path $trabajo "salida.xlsx"
$fs = [System.IO.File]::Create($salida)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
foreach ($nombre in $lista) {
  $origen = Join-Path $desc ($nombre.Replace("/", "\"))
  $entry = $zip.CreateEntry($nombre, [System.IO.Compression.CompressionLevel]::Optimal)
  $os = $entry.Open()
  $bytes = [System.IO.File]::ReadAllBytes($origen)
  $os.Write($bytes, 0, $bytes.Length); $os.Close()
}
$zip.Dispose(); $fs.Close()
Copy-Item -LiteralPath $salida -Destination $libro -Force
"libro actualizado: " + (Get-Item -LiteralPath $libro).Length + " bytes"
Remove-Item -LiteralPath $trabajo -Recurse -Force
