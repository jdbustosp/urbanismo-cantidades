$ErrorActionPreference='Stop'
$repoDir='C:\Users\juanbusper\Streaming de Google Drive\Mi unidad\VARIOS\CLAUDE\proyectos\URBANISMO EXTERNO'
$labDir=$PSScriptRoot
# Mechanical snapshot/instrumentation; never modify the source engine.
$source=(& git -C $repoDir show 'ea5d740:urbanismo_cantidades.lsp') -join "`n"
if($LASTEXITCODE -ne 0){throw 'Base ea5d740 no disponible'}
foreach($name in @('offset-strip-symbols','fill-tactile-symbols','add-toperol-hatch','flush-tactile-batch','create-accessibility-features','evaluate-render-hatch','anden-cutout-blocks','objects-bbox-overlap-p','block-footprint-region')) {
 $source=[regex]::Replace($source,'\(defun urb:'+ $name +'\s+\(', '(defun lab:original-'+$name+' (')
}
$encoding=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $labDir 'profile-engine.lsp'),$source,$encoding)
$old="(urb:set-block-draw-order`r`n        block-definition`r`n        (if fast-ok`r`n          (urb:block-object-list block-definition)`r`n          (urb:variant-object-list copy-result)))"
if(-not $source.Contains($old)){$old=$old.Replace("`r`n","`n")}
if(-not $source.Contains($old)){throw 'Expected packaging call not found'}
$candidate=$source.Replace($old,'(bn:finish block-name handle)')
[IO.File]::WriteAllText((Join-Path $labDir 'profile-candidate.lsp'),$candidate,$encoding)
$flat=$source.Replace($old,'(URBANDENFLAT553 block-name)')
[IO.File]::WriteAllText((Join-Path $labDir 'flat-engine.lsp'),$flat,$encoding)
Get-Item (Join-Path $labDir 'profile-engine.lsp') | Select-Object Length
