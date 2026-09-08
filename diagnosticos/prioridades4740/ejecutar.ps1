param(
  [Parameter(Mandatory=$true)][string]$CoreConsole,
  [Parameter(Mandatory=$true)][string]$Template,
  [string]$Lab = (Join-Path $env:USERPROFILE 'Documents\URBANISMO\work\hardening4730')
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
foreach ($sourcePath in @($CoreConsole,$Template)) {
  if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "No existe: $sourcePath" }
}
New-Item -ItemType Directory -Force -Path $Lab | Out-Null
$Lab=(Resolve-Path -LiteralPath $Lab).Path
$baseline=Join-Path $Lab 'baseline.lsp'
$gitInfo=New-Object System.Diagnostics.ProcessStartInfo
$gitInfo.FileName='git.exe'
$gitInfo.WorkingDirectory=$repo
$gitInfo.Arguments='cat-file blob 0ffec47:urbanismo_cantidades.lsp'
$gitInfo.UseShellExecute=$false
$gitInfo.CreateNoWindow=$true
$gitInfo.RedirectStandardOutput=$true
$gitInfo.StandardOutputEncoding=New-Object System.Text.UTF8Encoding($false)
$gitProcess=[System.Diagnostics.Process]::Start($gitInfo)
$baseText=$gitProcess.StandardOutput.ReadToEnd()
$gitProcess.WaitForExit()
if ($gitProcess.ExitCode -ne 0) { throw 'No se pudo recuperar la version base 0ffec47.' }
[System.IO.File]::WriteAllText($baseline,$baseText,(New-Object System.Text.UTF8Encoding($false)))
Copy-Item -LiteralPath (Join-Path $repo 'urbanismo_cantidades.lsp') -Destination (Join-Path $Lab 'current.lsp') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'verify.lsp') -Destination (Join-Path $Lab 'verify.lsp') -Force
Copy-Item -LiteralPath $Template -Destination (Join-Path $Lab 'fixture.dwg') -Force
$result=Join-Path $Lab 'verify_result.txt'
if (Test-Path -LiteralPath $result) { Remove-Item -LiteralPath $result }
$script=Join-Path $Lab 'verify.scr'
Set-Content -LiteralPath $script -Encoding ASCII -Value @(
  '(load (strcat (getenv "URB_TEST_LAB") "/verify.lsp"))',
  '(command "_.QUIT" "_Y")'
)
$previousLab=$env:URB_TEST_LAB
try {
  $env:URB_TEST_LAB=$Lab.Replace('\','/')
  $process=Start-Process -FilePath $CoreConsole -ArgumentList "/i `"$Lab\fixture.dwg`" /s `"$script`" /l en-US" -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Lab 'console.txt') -RedirectStandardError (Join-Path $Lab 'stderr.txt')
  if (-not $process.WaitForExit(120000)) {
    Stop-Process -Id $process.Id -Force
    throw "Tiempo agotado. Revise $Lab\console.txt. Solo se cerro el proceso de prueba."
  }
  if (-not (Test-Path -LiteralPath $result)) { throw 'No se genero resultado; prueba incompleta.' }
  $report=Get-Content -LiteralPath $result -Raw
  Write-Output $report
  if ($report -notmatch 'RESULTADO \d+ OK / 0 FALLOS' -or $report -notmatch 'DONE') {
    throw 'Hay fallos o la prueba no termino.'
  }
} finally { $env:URB_TEST_LAB=$previousLab }
