# Instala (o REINSTALA tras cada edicion) el bundle de Urbanismo Cantidades.
# Uso: click derecho -> Ejecutar con PowerShell, o desde una terminal:
#   powershell -ExecutionPolicy Bypass -File instalar_bundle.ps1
# Que hace: copia PackageContents.xml y urbanismo_cantidades.lsp del repo a
#   %AppData%\Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle\
# AutoCAD/Civil 3D lo carga solo al arrancar (carpeta confiable por defecto).
# Reinstalar tras editar = volver a correr este script y reiniciar AutoCAD
# (o en la misma sesion: (load "...urbanismo_cantidades.lsp") como siempre).

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$lsp = Join-Path $repo "urbanismo_cantidades.lsp"
$xml = Join-Path $repo "bundle\PackageContents.xml"
$dest = Join-Path $env:APPDATA "Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle"

if (-not (Test-Path $lsp)) { throw "No se encontro urbanismo_cantidades.lsp junto al script." }
if (-not (Test-Path $xml)) { throw "No se encontro bundle\PackageContents.xml en el repo." }

New-Item -ItemType Directory -Force -Path (Join-Path $dest "Contents") | Out-Null
Copy-Item $xml (Join-Path $dest "PackageContents.xml") -Force
Copy-Item $lsp (Join-Path $dest "Contents\urbanismo_cantidades.lsp") -Force
$cui = Join-Path $repo "bundle\cantidades.cui"
if (Test-Path $cui) { Copy-Item $cui (Join-Path $dest "Contents\cantidades.cui") -Force }

# version informativa (del *urb-version* del lsp)
$ver = (Select-String -Path $lsp -Pattern '\*urb-version\*\s+"([^"]+)"' | Select-Object -First 1).Matches[0].Groups[1].Value
Write-Output "Bundle instalado/actualizado en:"
Write-Output "  $dest"
Write-Output "Version del motor: $ver"
Write-Output "Reinicie AutoCAD/Civil 3D para que cargue la nueva copia."
