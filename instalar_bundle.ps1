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

# 2026-08-11 fase .NET: la pestana la dibuja el DLL (ribbon dinamico).
# El cuix YA NO se instala (si quedara, la pestana saldria duplicada por
# el registro de parciales del perfil) -- se retira junto con residuos.
foreach ($old in @("cantidades.cui","cantidades.cuix","cantidades.bak.cuix","cantidades.mnr","cantidades_light.mnr")) {
  $p = Join-Path $contents $old
  if (Test-Path $p) { try { Remove-Item $p -Force } catch {} }
}
# COPIAS FANTASMA (descubierto 2026-08-11): cuando el Autoloader cargo el
# cuix como componente, lo COPIO a la carpeta Support del perfil
# (p.ej. ...\Autodesk\C3D 2023\enu\Support\cantidades.cuix) y esa copia
# revivia la pestana vieja en cada arranque. Se barren todas.
foreach ($root in (Get-ChildItem (Join-Path $env:APPDATA 'Autodesk') -Directory -ErrorAction SilentlyContinue)) {
  if ($root.Name -ne 'ApplicationPlugins') {
    Get-ChildItem $root.FullName -Recurse -Depth 3 -Filter 'cantidades*' -ErrorAction SilentlyContinue |
      ForEach-Object { try { Remove-Item $_.FullName -Force } catch {} }
  }
}
# DLLs del ribbon (2023 = .NET FW 4.8, 2025 = .NET 8; el manifiesto elige).
# Si AutoCAD esta abierto, el DLL cargado queda bloqueado: se avisa y el
# resto de la instalacion continua (cerrar AutoCAD y volver a correr).
$dllBloqueado = $false
$netDir = Join-Path $repo "bundle\net"
if (Test-Path $netDir) {
  New-Item -ItemType Directory -Force -Path (Join-Path $contents "net") | Out-Null
  Get-ChildItem $netDir -Filter "*.dll" | ForEach-Object {
    try { Copy-Item $_.FullName (Join-Path $contents ("net\" + $_.Name)) -Force -ErrorAction Stop }
    catch { $dllBloqueado = $true } }
}
# iconos junto al DLL (los carga desde disco)
$icoDir = Join-Path $repo "bundle\iconos"
if (Test-Path $icoDir) {
  New-Item -ItemType Directory -Force -Path (Join-Path $contents "net\iconos") | Out-Null
  Get-ChildItem $icoDir -Filter "*.png" | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $contents ("net\iconos\" + $_.Name)) -Force }
}

# TRUSTEDPATHS en todos los perfiles de AutoCAD/Civil 3D del usuario.
# OJO (2026-08-24): TRUSTEDPATHS solo confia en el nivel EXACTO de la
# carpeta -- para que incluya subcarpetas (el DLL del ribbon vive en
# Contents\net\, no en Contents\ directo) hace falta el sufijo "\..." que
# usa AutoCAD para "esta carpeta y sus subcarpetas" (el mismo que arma el
# dialogo Opciones > Archivos > Ubicaciones de confianza con "Incluir
# subcarpetas"). Sin esto, el .lsp (directo en Contents) cargaba sin
# aviso pero el .dll (en Contents\net) mostraba "Unsigned Executable
# File" cada vez que se recompilaba.
$trustAdd = @($contents, ($contents + "\..."))
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
          foreach ($add in $trustAdd) {
            if ($tp.ToLower().IndexOf($add.ToLower()) -lt 0) {
              $tp = if ($tp -eq '' -or $tp.EndsWith(';')) { $tp + $add } else { $tp + ';' + $add }
              $updated++
            }
          }
          Set-ItemProperty $vars -Name TRUSTEDPATHS -Value $tp
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
if ($dllBloqueado) {
  Write-Output ""
  Write-Output "AVISO: AutoCAD esta abierto y la cinta (.dll) NO se pudo actualizar."
  Write-Output "Cierre TODAS las ventanas de AutoCAD y corra INSTALAR.bat de nuevo."
} else {
  Write-Output "Reinicie AutoCAD/Civil 3D: comandos + pestana CANTIDADES cargan solos."
}
