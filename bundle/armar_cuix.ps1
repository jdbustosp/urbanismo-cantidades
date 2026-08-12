# Reempaqueta bundle/cantidades.cuix a partir de bundle/cantidades.cui.
# El .cui es la FUENTE legible (editable a mano); el .cuix es lo que
# AutoCAD carga. NO usar MenuGroups.Load con el .cui directo: el
# convertidor de .cui monoliticos es anterior al ribbon y descarta los
# paneles en silencio (descubierto 2026-08-11).
# Uso: powershell -ExecutionPolicy Bypass -File bundle\armar_cuix.ps1
# Despues correr INSTALAR.bat para llevarlo al bundle instalado.

$ErrorActionPreference = "Stop"
$bundleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cui = Join-Path $bundleDir "cantidades.cui"
$out = Join-Path $bundleDir "cantidades.cuix"
if (-not (Test-Path $cui)) { throw "No se encontro cantidades.cui" }

$text = [System.IO.File]::ReadAllText($cui)

function Extract-Section($text, $open, $close) {
  $i = $text.IndexOf($open)
  $j = $text.IndexOf($close, $i)
  if ($i -lt 0 -or $j -lt 0) { throw "Seccion no encontrada: $open" }
  return $text.Substring($i, $j - $i + $close.Length)
}

$warn = @"
<!--
Archivo generado por armar_cuix.ps1 a partir de cantidades.cui.
No editar a mano: editar cantidades.cui y reempaquetar.
-->
"@

$ribbon = "<?xml version=`"1.0`"?>`r`n" + $warn + (Extract-Section $text "<RibbonRoot>" "</RibbonRoot>")
$macros = "<?xml version=`"1.0`"?>`r`n" + $warn +
  "<MenuGroup xmlns:xsd=`"http://www.w3.org/2001/XMLSchema`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" Name=`"CANTIDADES`" DisplayName=`"CANTIDADES`">`r`n" +
  (Extract-Section $text "<MacroGroup" "</MacroGroup>") + "`r`n</MenuGroup>"

$header = @"
<?xml version="1.0"?>
<CustSection xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <FileVersion MajorVersion="0" MinorVersion="6" IncrementalVersion="1" UserVersion="0" />
  <Header>
    <CommonConfiguration>
      <CommonItems>
        <ModifiedRev MajorVersion="16" MinorVersion="2" UserVersion="0" />
      </CommonItems>
    </CommonConfiguration>
  </Header>
</CustSection>
"@

$contentTypes = '<?xml version="1.0" encoding="utf-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="cui" ContentType="text/xml" /><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" /><Default Extension="xml" ContentType="text/xml" /></Types>'
$rels = '<?xml version="1.0" encoding="utf-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Type="CUI" Target="/Header.cui" Id="Rcant0000000001" /><Relationship Type="CUI" Target="/MenuGroup.cui" Id="Rcant0000000002" /><Relationship Type="CUI" Target="/RibbonRoot.cui" Id="Rcant0000000003" /></Relationships>'
$pkgInfo = @"
<?xml version="1.0" encoding="utf-8"?>
<MenuPackageParts>
  <PartData PartData_Name="/Header.cui" PartData_Modified="2026-08-11T20:00:00.0000000-05:00" />
  <PartData PartData_Name="/MenuGroup.cui" PartData_Modified="2026-08-11T20:00:00.0000000-05:00" />
  <PartData PartData_Name="/RibbonRoot.cui" PartData_Modified="2026-08-11T20:00:00.0000000-05:00" />
  <PartData PartData_Name="/Menu_Package_Info.xml" PartData_Modified="2026-08-11T20:00:00.0000000-05:00" />
</MenuPackageParts>
"@

if (Test-Path $out) { Remove-Item $out -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$enc = New-Object System.Text.UTF8Encoding($true)
$zip = [System.IO.Compression.ZipFile]::Open($out, 'Create')
$parts = @(
  @('[Content_Types].xml', $contentTypes),
  @('_rels/.rels', $rels),
  @('Header.cui', $header),
  @('MenuGroup.cui', $macros),
  @('RibbonRoot.cui', $ribbon),
  @('Menu_Package_Info.xml', $pkgInfo)
)
foreach ($part in $parts) {
  $entry = $zip.CreateEntry($part[0])
  $es = $entry.Open()
  $bytes = $enc.GetBytes($part[1])
  $es.Write($bytes, 0, $bytes.Length)
  $es.Close()
}
$zip.Dispose()
Write-Output "cantidades.cuix reempaquetado:"
Get-Item $out | Select-Object Name, Length
