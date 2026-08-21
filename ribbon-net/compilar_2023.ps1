# Compila UrbCantRibbon2023.dll (.NET Framework 4.8) para AutoCAD/Civil 3D
# 2019-2024 con el csc.exe INTEGRADO de Windows (no requiere instalar nada).
# Salida: ..\bundle\net\UrbCantRibbon2023.dll
#   powershell -ExecutionPolicy Bypass -File ribbon-net\compilar_2023.ps1

$ErrorActionPreference = "Stop"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $dir "UrbCantRibbon.cs"
$outDir = Join-Path (Split-Path -Parent $dir) "bundle\net"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out = Join-Path $outDir "UrbCantRibbon2023_v4481.dll"

$acad = "C:\Program Files\Autodesk\AutoCAD 2023"
if (-not (Test-Path (Join-Path $acad "acmgd.dll"))) {
  throw "No se encontro AutoCAD 2023 en $acad (se necesitan sus DLL para referenciar)."
}

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$wpf = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\WPF"

& $csc /nologo /target:library /platform:x64 /optimize+ /define:URB_AEC_PROPERTY ("/out:" + $out) `
  ("/r:" + (Join-Path $acad "acmgd.dll")) `
  ("/r:" + (Join-Path $acad "accoremgd.dll")) `
  ("/r:" + (Join-Path $acad "acdbmgd.dll")) `
  ("/r:" + (Join-Path $acad "AdWindows.dll")) `
  ("/r:" + (Join-Path $acad "ACA\AecBaseMgd.dll")) `
  ("/r:" + (Join-Path $acad "ACA\AecPropDataMgd.dll")) `
  ("/r:" + (Join-Path $wpf "PresentationCore.dll")) `
  ("/r:" + (Join-Path $wpf "PresentationFramework.dll")) `
  ("/r:" + (Join-Path $wpf "WindowsBase.dll")) `
  ("/r:" + "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Xaml.dll") `
  ("/r:" + "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Core.dll") `
  ("/r:" + "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Microsoft.CSharp.dll") `
  $src

if ($LASTEXITCODE -ne 0) { throw "csc fallo con codigo $LASTEXITCODE" }
Write-Output "Compilado:"
Get-Item $out | Select-Object Name, Length, LastWriteTime


