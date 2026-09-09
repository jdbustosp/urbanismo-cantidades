$ErrorActionPreference = 'Stop'
$repo4800 = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab4800 = 'C:\Users\juanbusper\Documents\URBANISMO\work\codex4800'
New-Item -ItemType Directory -Path $lab4800 -Force | Out-Null
$env:URB_REPO = $repo4800.Replace('\','/')
$env:URB_TEST_LAB = $lab4800.Replace('\','/')
$env:URB_TEST_SUPPRESS_AUTO_MIGRATION = '1'
Copy-Item -LiteralPath 'C:\Program Files\Autodesk\AutoCAD 2023\UserDataCache\en-us\Template\acadiso.dwt' -Destination "$lab4800\fixture.dwg" -Force
$scr4800 = Join-Path $PSScriptRoot 'geometry.scr'
$started4800 = Get-Date
$proc4800 = Start-Process -FilePath 'C:\Program Files\Autodesk\AutoCAD 2023\acad.exe' -ArgumentList @("`"$lab4800\fixture.dwg`"",'/ld','"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"','/p','"<<C3D_Metric>>"','/product','C3D','/language','en-US','/b',"`"$scr4800`"") -WindowStyle Hidden -PassThru
Write-Output "Civil fixture PID=$($proc4800.Id), limite 90 s"
if (-not $proc4800.WaitForExit(90000)) {
  Stop-Process -Id $proc4800.Id -Force
  Write-Output 'LIMITE: instancia de prueba cerrada; no se toco la sesion del usuario.'
}
Write-Output "Duracion=$([math]::Round(((Get-Date)-$started4800).TotalSeconds,1))s"
if (Test-Path "$lab4800\geometry_result.txt") { Get-Content -LiteralPath "$lab4800\geometry_result.txt" } else { Write-Output 'SIN RESULTADO: validacion real pendiente.' }
