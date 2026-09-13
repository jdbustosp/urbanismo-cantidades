param([string]$libro)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::OpenRead($libro)
function Leer($nombre) {
  $e = $zip.Entries | Where-Object { $_.FullName -eq $nombre }
  if (-not $e) { return $null }
  $sr = New-Object System.IO.StreamReader($e.Open())
  $t = $sr.ReadToEnd(); $sr.Close(); return $t
}

# ---- mapa hoja -> archivo ----
$wb = Leer "xl/workbook.xml"
$rels = Leer "xl/_rels/workbook.xml.rels"
$mapa = @{}
foreach ($m in [regex]::Matches($rels, '<Relationship Id="([^"]+)"[^>]*Target="([^"]+)"')) {
  $mapa[$m.Groups[1].Value] = $m.Groups[2].Value
}
$hojas = @()
foreach ($m in [regex]::Matches($wb, '<sheet[^>]*name="([^"]+)"[^>]*sheetId="(\d+)"[^>]*r:id="([^"]+)"')) {
  $tgt = $mapa[$m.Groups[3].Value]
  $hojas += [pscustomobject]@{ Nombre = $m.Groups[1].Value; Archivo = "xl/" + ($tgt -replace '^/xl/','') }
}

"=== HOJAS ==="
$vol = 'INDIRECT|INDIRECTO|OFFSET|DESREF|TODAY|HOY|NOW|AHORA|RAND|ALEATORIO|INFO|CELL|CELDA|SUMIF|SUMAR.SI|SUMIFS|SUMPRODUCT|SUMAPRODUCTO|LOOKUP|BUSCAR'
$tot = [pscustomobject]@{}
$filas = @()
foreach ($h in $hojas) {
  $e = $zip.Entries | Where-Object { $_.FullName -eq $h.Archivo }
  if (-not $e) { continue }
  $xml = Leer $h.Archivo
  $nf   = ([regex]::Matches($xml, '<f[ >]')).Count
  $nc   = ([regex]::Matches($xml, '<c[ >]')).Count
  $ncf  = ([regex]::Matches($xml, '<conditionalFormatting')).Count
  $ndv  = ([regex]::Matches($xml, '<dataValidation[ >]')).Count
  $nsp  = ([regex]::Matches($xml, 'SUMPRODUCT|SUMAPRODUCTO')).Count
  $nlet = ([regex]::Matches($xml, 'LET\(|_xlfn\.LET')).Count
  $nxm  = ([regex]::Matches($xml, 'XMATCH|XLOOKUP|_xlfn\.X')).Count
  $nind = ([regex]::Matches($xml, 'INDIRECT|INDIRECTO')).Count
  $noff = ([regex]::Matches($xml, 'OFFSET|DESREF')).Count
  $nvol = ([regex]::Matches($xml, 'TODAY\(|HOY\(|NOW\(|AHORA\(|RAND')).Count
  $dim  = if ($xml -match '<dimension ref="([^"]+)"') { $matches[1] } else { "?" }
  $filas += [pscustomobject]@{
    Hoja = $h.Nombre; Archivo = ($h.Archivo -replace 'xl/worksheets/','')
    KB = [Math]::Round($e.Length / 1KB); Celdas = $nc; Formulas = $nf
    SUMPRODUCT = $nsp; LET = $nlet; XMATCH = $nxm; INDIRECT = $nind
    OFFSET = $noff; Volatiles = $nvol; CF = $ncf; Validaciones = $ndv; Rango = $dim
  }
}
$filas | Format-Table -AutoSize

"=== TOTALES ==="
"  formulas totales    : " + ($filas | Measure-Object -Property Formulas -Sum).Sum
"  SUMPRODUCT totales  : " + ($filas | Measure-Object -Property SUMPRODUCT -Sum).Sum
"  LET totales         : " + ($filas | Measure-Object -Property LET -Sum).Sum
"  XMATCH/XLOOKUP      : " + ($filas | Measure-Object -Property XMATCH -Sum).Sum
"  INDIRECT totales    : " + ($filas | Measure-Object -Property INDIRECT -Sum).Sum
"  volatiles (HOY/NOW) : " + ($filas | Measure-Object -Property Volatiles -Sum).Sum

# ---- nombres definidos ----
"`n=== NOMBRES DEFINIDOS ==="
$nn = [regex]::Matches($wb, '<definedName name="([^"]+)"[^>]*>([^<]*)</definedName>')
"  total: $($nn.Count)"
foreach ($m in $nn | Select-Object -First 30) {
  $v = $m.Groups[2].Value
  if ($v.Length -gt 90) { $v = $v.Substring(0,90) + "..." }
  "   " + $m.Groups[1].Value + " = " + $v
}

# ---- calcPr / modo de calculo ----
"`n=== CALCULO ==="
if ($wb -match '<calcPr([^>]*)/>') { "  calcPr:" + $matches[1] } else { "  (sin calcPr)" }
$cc = Leer "xl/calcChain.xml"
if ($cc) { "  cadena de calculo: " + ([regex]::Matches($cc, '<c ')).Count + " celdas" }

# ---- conexiones / consultas externas ----
"`n=== CONEXIONES ==="
$conn = Leer "xl/connections.xml"
if ($conn) {
  foreach ($m in [regex]::Matches($conn, '<connection[^>]*name="([^"]+)"')) { "   " + $m.Groups[1].Value }
  "   (total: " + ([regex]::Matches($conn, '<connection ')).Count + ")"
} else { "   (ninguna)" }

# ---- pivot caches ----
"`n=== PIVOTS ==="
foreach ($e in $zip.Entries | Where-Object { $_.FullName -like "xl/pivotTables/pivotTable*.xml" }) {
  $x = Leer $e.FullName
  $nom = if ($x -match 'name="([^"]+)"') { $matches[1] } else { "?" }
  "   " + $e.FullName + "  nombre=" + $nom + "  " + [Math]::Round($e.Length/1KB) + " KB"
}
foreach ($e in $zip.Entries | Where-Object { $_.FullName -like "xl/pivotCache/pivotCacheDefinition*.xml" }) {
  $x = Leer $e.FullName
  $nr = if ($x -match 'recordCount="(\d+)"') { $matches[1] } else { "?" }
  $nc2 = ([regex]::Matches($x, '<cacheField ')).Count
  "   " + $e.FullName + "  registros=" + $nr + "  campos=" + $nc2
}
$zip.Dispose()
