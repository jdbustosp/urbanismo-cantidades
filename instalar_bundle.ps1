# Instala (o REINSTALA tras cada edicion) el plugin Urbanismo Cantidades.
# Doble clic a INSTALAR.bat (que llama a este script) o directo:
#   powershell -ExecutionPolicy Bypass -File instalar_bundle.ps1
# Hace 3 cosas:
#  1. Copia lsp + manifiesto + cui del repo al bundle de ApplicationPlugins.
#  2. Borra los .cuix generados viejos (AutoCAD los regenera del .cui al
#     cargar; si quedara uno viejo, cargaria una interfaz desactualizada).
#  3. Agrega la carpeta del bundle a TRUSTEDPATHS de TODOS los perfiles de
#     AutoCAD del usuario (evita el dialogo "Unsigned Executable File").

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$lsp = Join-Path $repo "urbanismo_cantidades.lsp"
$xml = Join-Path $repo "bundle\PackageContents.xml"
$cuix = Join-Path $repo "bundle\cantidades.cuix"
$dest = Join-Path $env:APPDATA "Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle"
$contents = Join-Path $dest "Contents"

if (-not (Test-Path $lsp)) { throw "No se encontro urbanismo_cantidades.lsp junto al script." }
if (-not (Test-Path $xml)) { throw "No se encontro bundle\PackageContents.xml en el repo." }

New-Item -ItemType Directory -Force -Path $contents | Out-Null
Copy-Item $xml (Join-Path $dest "PackageContents.xml") -Force
Copy-Item $lsp (Join-Path $contents "urbanismo_cantidades.lsp") -Force
if (Test-Path $cuix) {
  # la interfaz se entrega como .cuix ya empaquetado (el convertidor de
  # .cui monoliticos es pre-ribbon y descartaba los paneles); se limpian
  # residuos de intentos anteriores (.cui, .bak.cuix, .mnr)
  foreach ($old in @("cantidades.cui","cantidades.bak.cuix","cantidades.mnr","cantidades_light.mnr")) {
    $p = Join-Path $contents $old
    if (Test-Path $p) { try { Remove-Item $p -Force } catch {} }
  }
  Copy-Item $cuix (Join-Path $contents "cantidades.cuix") -Force
}

# TRUSTEDPATHS en todos los perfiles de AutoCAD/Civil 3D del usuario
$trustAdd = $contents
$updated = 0
try {
  Get-ChildItem 'HKCU:\Software\Autodesk\AutoCAD' -ErrorAction Stop | Get-ChildItem | ForEach-Object {
    $prof = Join-Path $_.PSPath 'Profiles'
    if (Test-Path $prof) {
      Get-ChildItem $prof | ForEach-Object {
        $vars = Join-Path $_.PSPath 'Variables'
        if (Test-Path $vars) {
          $tp = (Get-ItemProperty $vars -ErrorAction SilentlyContinue).TRUSTEDPATHS
          if ($null -eq $tp) { $tp = '' }
          if ($tp.ToLower().IndexOf($trustAdd.ToLower()) -lt 0) {
            $new = if ($tp -eq '' -or $tp.EndsWith(';')) { $tp + $trustAdd } else { $tp + ';' + $trustAdd }
            Set-ItemProperty $vars -Name TRUSTEDPATHS -Value $new
            $updated++
          }
        }
      }
    }
  }
} catch {}

$ver = (Select-String -Path $lsp -Pattern '\*urb-version\*\s+"([^"]+)"' | Select-Object -First 1).Matches[0].Groups[1].Value
Write-Output "Plugin instalado/actualizado en:"
Write-Output "  $dest"
Write-Output "Version del motor: $ver"
Write-Output "Perfiles de AutoCAD con ruta confiable agregada: $updated"
Write-Output "Reinicie AutoCAD/Civil 3D: comandos + pestana CANTIDADES cargan solos."
