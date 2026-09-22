$ErrorActionPreference = 'Stop'
$cad = 'C:\Program Files\Autodesk\AutoCAD 2023'
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /target:library /out:"$PSScriptRoot\..\..\TestSurface5715.dll" /reference:"$cad\acdbmgd.dll" /reference:"$cad\acmgd.dll" /reference:"$cad\accoremgd.dll" /reference:"$cad\AecBaseMgd.dll" /reference:"$cad\C3D\AeccDbMgd.dll" "$PSScriptRoot\TestSurface.cs"
if ($LASTEXITCODE -ne 0) { throw 'Test surface compilation failed.' }
