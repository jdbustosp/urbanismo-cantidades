# Compila UrbCantRibbon2025.dll (.NET 8) para AutoCAD/Civil 3D 2025+.
# Requiere el SDK de .NET 8 (dotnet --list-sdks debe mostrar 8.x) e
# internet la primera vez (baja el paquete de referencias AutoCAD.NET).
# Salida: ..\bundle\net\UrbCantRibbon2025.dll
#   powershell -ExecutionPolicy Bypass -File ribbon-net\compilar_2025.ps1

$ErrorActionPreference = "Stop"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path (Split-Path -Parent $dir) "bundle\net"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$tmp = Join-Path $env:TEMP "urbcant_net8_build"

& dotnet build (Join-Path $dir "UrbCantRibbon2025.csproj") -c Release -o $tmp --nologo -v quiet
if ($LASTEXITCODE -ne 0) { throw "dotnet build fallo con codigo $LASTEXITCODE" }

Copy-Item (Join-Path $tmp "UrbCantRibbon2025.dll") (Join-Path $outDir "UrbCantRibbon2025.dll") -Force
Write-Output "Compilado:"
Get-Item (Join-Path $outDir "UrbCantRibbon2025.dll") | Select-Object Name, Length, LastWriteTime
