$ErrorActionPreference='Stop'
$repoDir=Split-Path -Parent $PSScriptRoot
$buildDir=Join-Path $env:TEMP 'urbcant_anden553_build'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$cadDir='C:\Program Files\Autodesk\AutoCAD 2023'
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /target:library /optimize+ "/out:$buildDir\UrbAndenFast2023_v553.dll" "/reference:$cadDir\acmgd.dll" "/reference:$cadDir\acdbmgd.dll" "/reference:$cadDir\accoremgd.dll" (Join-Path $PSScriptRoot 'UrbAndenFast.cs')
if($LASTEXITCODE -ne 0){throw 'Fallo .NET Framework'}
& dotnet build (Join-Path $PSScriptRoot 'UrbAndenFast2025.csproj') -c Release -o $buildDir --nologo -v quiet
if($LASTEXITCODE -ne 0){throw 'Fallo .NET8'}
Write-Output "Compilados en $buildDir. Copiar al bundle solo tras validacion."
