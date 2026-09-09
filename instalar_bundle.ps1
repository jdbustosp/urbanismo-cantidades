# Instala (o REINSTALA tras cada edicion) el plugin Urbanismo Cantidades.
# Doble clic a INSTALAR.bat (que llama a este script) o directo:
#   powershell -ExecutionPolicy Bypass -File instalar_bundle.ps1
# Hace 3 cosas:
#  1. Copia lsp + manifiesto + cui del repo al bundle de ApplicationPlugins.
#  2. Borra los .cuix generados viejos (AutoCAD los regenera del .cui al
#     cargar; si quedara uno viejo, cargaria una interfaz desactualizada).
#  3. Agrega la carpeta del bundle a TRUSTEDPATHS de TODOS los perfiles de
#     AutoCAD del usuario (evita el dialogo "Unsigned Executable File").

param([switch]$ValidateOnly)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$lsp = Join-Path $repo "urbanismo_cantidades.lsp"
$xml = Join-Path $repo "bundle\PackageContents.xml"
$cuix = Join-Path $repo "bundle\cantidades.cuix"
$dest = Join-Path $env:APPDATA "Autodesk\ApplicationPlugins\UrbanismoCantidades.bundle"
$contents = Join-Path $dest "Contents"

if (-not (Test-Path $lsp)) { throw "No se encontro urbanismo_cantidades.lsp junto al script." }
if (-not (Test-Path $xml)) { throw "No se encontro bundle\PackageContents.xml en el repo." }

# Validar la entrega completa ANTES de modificar la instalacion.
$verMatch = [regex]::Match((Get-Content -LiteralPath $lsp -Raw), '\*urb-version\*\s+"([^"]+)"')
if (-not $verMatch.Success) { throw "No se pudo leer la version del motor." }
$ver = $verMatch.Groups[1].Value
[xml]$manifest = Get-Content -LiteralPath $xml -Raw
if ($manifest.ApplicationPackage.AppVersion -ne $ver) {
  throw "Versiones distintas: motor $ver / manifiesto $($manifest.ApplicationPackage.AppVersion)."
}
$requiredFiles = @()
foreach ($entry in $manifest.ApplicationPackage.Components.ComponentEntry) {
  $module = [string]$entry.ModuleName
  if (-not $module.StartsWith('./Contents/')) { throw "Ruta de componente no admitida: $module" }
  $relative = $module.Substring('./Contents/'.Length).Replace('/', '\')
  $source = if ($relative -eq 'urbanismo_cantidades.lsp') { $lsp } else { Join-Path (Join-Path $repo 'bundle') $relative }
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Falta un componente: $source" }
  $requiredFiles += [pscustomobject]@{ Source=$source; Relative=$relative }
}
if ($ValidateOnly) {
  Write-Output "Entrega ${ver}: manifiesto y $($requiredFiles.Count) referencias de componentes validos. No se instalo nada."
  return
}

New-Item -ItemType Directory -Force -Path $contents | Out-Null
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

# No anunciar una instalacion correcta si quedo una DLL vieja/bloqueada.
foreach ($item in $requiredFiles) {
  $installedFile = Join-Path $contents $item.Relative
  if (-not (Test-Path -LiteralPath $installedFile -PathType Leaf)) { throw "No se instalo: $installedFile" }
  if ((Get-FileHash -LiteralPath $item.Source -Algorithm SHA256).Hash -ne
      (Get-FileHash -LiteralPath $installedFile -Algorithm SHA256).Hash) {
    throw "Componente no actualizado: $installedFile. Cierre AutoCAD y vuelva a instalar."
  }
}
Copy-Item -LiteralPath $xml -Destination (Join-Path $dest 'PackageContents.xml') -Force

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

# Limpieza de un experimento fallido del 2026-08-28: se probo una clave
# demand-load (Applications\UrbCantRibbon2026\LOADER) que apuntaba a un
# DLL net10 invalido; si quedo residuo se elimina.
try {
  Get-ChildItem 'HKCU:\Software\Autodesk\AutoCAD\R25.1' -ErrorAction Stop | ForEach-Object {
    $k = Join-Path (Join-Path $_.PSPath 'Applications') 'UrbCantRibbon2026'
    if (Test-Path $k) {
      Remove-Item $k -Recurse -Force
      Write-Output "Clave demand-load residual eliminada: $k"
    }
  }
} catch {}

# CARGADOR acaddoc.lsp para TODAS las versiones de Civil 3D y AutoCAD instaladas.
# 2026-08-28 (C3D 2026): el Autoloader de bundles de 2026 es ERRATICO --
# en varios arranques reales no ejecuta los ComponentEntry sin error
# visible. 2026-09-02 (C3D 2023, reporte del usuario "no me reconoce los
# comandos"): el Autoloader de 2023 carga el .lsp SOLO en el primer
# documento del arranque -- al abrir el dwg de trabajo ese documento
# queda sin motor (AutoLISP es por-documento); antes no se notaba porque
# el Startup Suite viejo de BLOQUES PPTOS lo cargaba en cada dibujo.
# Este acaddoc.lsp vive en el Support de CADA perfil C3D/AutoCAD (ruta de
# busqueda + confiable), lo ejecuta el nucleo de AutoCAD en CADA apertura
# de dibujo, y desde S::STARTUP netloadea el DLL de la cinta y carga el
# motor. Con guardas: si el bundle ya cargo, no hace nada.
$xmlRaw = Get-Content $xml -Raw
$dll2023Name = ([regex]::Match($xmlRaw, 'net/(UrbCantRibbon2023[^"]*\.dll)')).Groups[1].Value
if ($dll2023Name -eq "") { $dll2023Name = "UrbCantRibbon2023.dll" }
$marker = ";;; === URBCANT AUTOLOAD (generado por instalar_bundle.ps1) ==="
$plantilla = @"
$marker
;;; El Autoloader de bundles no garantiza el motor en cada documento
;;; (2026: arranques sin componentes; 2023: lsp solo en el primer
;;; documento). Este cargador corre en cada apertura de dibujo y
;;; garantiza pestana CANTIDADES + motor. Con guardas: si el bundle ya
;;; cargo, no hace nada. NO editar a mano (se regenera al correr
;;; instalar_bundle.ps1 / INSTALAR.bat).
(vl-load-com)
(defun urbcant:bootstrap ()
  (vl-catch-all-apply 'vl-cmdf
    (list "_NETLOAD" "__DLL__"))
  (if (not (member "C:URBANISMO" (atoms-family 1)))
    (load "__LSP__" "urbcant: no se pudo cargar el motor"))
  (princ))
;;; Cargar el motor inmediatamente. Antes se confiaba solo en S::STARTUP;
;;; si otro complemento tenia un S::STARTUP que fallaba, nunca se alcanzaba
;;; URBCANT y los botones enviaban comandos desconocidos.
(urbcant:bootstrap)
(cond
  ((= (type s::startup) 'LIST)
    (setq s::startup (append s::startup '((urbcant:bootstrap)))))
  ((null s::startup)
    (defun-q s::startup () (urbcant:bootstrap)))
  (T
    (setq urbcant:startup-previo s::startup)
    (defun s::startup ()
      (urbcant:bootstrap)
      (vl-catch-all-apply urbcant:startup-previo nil))))
(princ)
;;; === FIN URBCANT AUTOLOAD ===
"@
$lspForLisp = ($contents + "\urbanismo_cantidades.lsp").Replace('\', '/')
$autodeskProfiles = Get-ChildItem (Join-Path $env:APPDATA "Autodesk") -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -like "C3D *" -or $_.Name -like "AutoCAD *" }
foreach ($profile in $autodeskProfiles) {
  # Civil 3D suele usar ...\C3D 2023\enu\Support; AutoCAD,
  # ...\AutoCAD 2024\R24.3\enu\Support. Se cubren ambas estructuras.
  $supportDirs = Get-ChildItem $profile.FullName -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq "Support" }
  foreach ($supportDir in $supportDirs) {
    $supp = $supportDir.FullName
    # 2023/2024 (.NET FW 4.8, DLL con nombre versionado del manifiesto);
    # 2025/2026 (.NET 8)
    $dllName = if ($profile.Name -match '(2019|202[0-4])$') { $dll2023Name } else { "UrbCantRibbon2025.dll" }
    $dllForLisp = ($contents + "\net\" + $dllName).Replace('\', '\\')
    $bloque = $plantilla.Replace('__DLL__', $dllForLisp).Replace('__LSP__', $lspForLisp)
    $acaddoc = Join-Path $supp "acaddoc.lsp"
    if (-not (Test-Path $acaddoc)) {
      Set-Content -Path $acaddoc -Value $bloque -Encoding ASCII
      Write-Output "Cargador acaddoc.lsp creado en: $acaddoc"
    } else {
      $actual = Get-Content $acaddoc -Raw
      if ($actual -match [regex]::Escape($marker)) {
        $regex = "(?s)" + [regex]::Escape($marker) + ".*?;;; === FIN URBCANT AUTOLOAD ==="
        $nuevo = [regex]::Replace($actual, $regex, ($bloque.TrimEnd() -replace '\$', '$$$$'))
        Set-Content -Path $acaddoc -Value $nuevo -Encoding ASCII
        Write-Output "Cargador acaddoc.lsp actualizado en: $acaddoc"
      } else {
        Add-Content -Path $acaddoc -Value ("`r`n" + $bloque) -Encoding ASCII
        Write-Output "Cargador agregado al acaddoc.lsp existente: $acaddoc"
      }
    }
  }
}

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
