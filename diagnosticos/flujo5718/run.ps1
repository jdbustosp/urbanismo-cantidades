param([switch]$Native)
$ErrorActionPreference='Stop'
$lab='C:\Users\juanbusper\Documents\URBANISMO\work\flujo5718'
New-Item -ItemType Directory -Path $lab -Force | Out-Null
$name=if($Native){'native'}else{'core'}
if(Test-Path "$lab\$name.txt"){throw 'Preserve existing evidence'}
$fixture="$lab\fixture.dwg"
if(-not(Test-Path $fixture)){Copy-Item 'C:\Users\juanbusper\Documents\URBANISMO\work\tierras5715\fixture.dwg' $fixture}
$exe='C:\Program Files\Autodesk\AutoCAD 2023\accoreconsole.exe';$limit=60
$argsList=@('/i',"`"$fixture`"",'/s',"`"$PSScriptRoot\core.scr`"",'/l','en-US')
if($Native){$exe='C:\Program Files\Autodesk\AutoCAD 2023\acad.exe';$limit=90;$argsList=@("`"$fixture`"",'/ld','"C:\Program Files\Autodesk\AutoCAD 2023\AecBase.dbx"','/p','<<C3D_Metric>>','/product','C3D','/language','en-US','/b',"`"$PSScriptRoot\native.scr`"")}
$timer=[Diagnostics.Stopwatch]::StartNew()
$proc=Start-Process $exe -WindowStyle Hidden -PassThru -ArgumentList $argsList -RedirectStandardOutput "$lab\$name-console.txt" -RedirectStandardError "$lab\$name-stderr.txt"
"PID=$($proc.Id)"
while(-not $proc.HasExited -and $timer.Elapsed.TotalSeconds-lt$limit){Start-Sleep -Seconds 2;$proc.Refresh()}
if(-not $proc.HasExited){Stop-Process -Id $proc.Id -Force;'TIMEOUT owned PID only'}
"Seconds=$($timer.Elapsed.TotalSeconds)"
Get-Content "$lab\$name.txt" -ErrorAction SilentlyContinue
if(-not(Test-Path "$lab\$name.txt") -or -not(Select-String -LiteralPath "$lab\$name.txt" -Pattern 'FINISHED' -SimpleMatch -Quiet)){throw 'Test incomplete or failed'}
