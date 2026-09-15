Add-Type -AssemblyName System.Drawing
$labDir=$PSScriptRoot
function Read-Points($name) {
 @(Get-Content (Join-Path $labDir $name) | ForEach-Object {
  $v=$_.Split(','); [pscustomobject]@{X=[double]::Parse($v[0],[cultureinfo]::InvariantCulture);Y=[double]::Parse($v[1],[cultureinfo]::InvariantCulture)}
 })
}
$src=Read-Points 'source.csv'; $old=Read-Points 'old-over.csv'; $new=Read-Points 'correct-over.csv'
$bmp=New-Object Drawing.Bitmap 1500,850
$g=[Drawing.Graphics]::FromImage($bmp);$g.Clear([Drawing.Color]::White);$g.SmoothingMode='AntiAlias'
$font=New-Object Drawing.Font 'Arial',16
$small=New-Object Drawing.Font 'Arial',12
$g.DrawString('Huella extraida de Civil 3D: azul = anden; rojo = sobreancho anterior; verde = corregido',$small,[Drawing.Brushes]::Black,20,15)
function Panel($left,$width,$all,$title) {
 $minX=($all|Measure-Object X -Minimum).Minimum;$maxX=($all|Measure-Object X -Maximum).Maximum
 $minY=($all|Measure-Object Y -Minimum).Minimum;$maxY=($all|Measure-Object Y -Maximum).Maximum
 $scale=[math]::Min(($width-50)/($maxX-$minX),700/($maxY-$minY))
 $g.DrawString($title,$font,[Drawing.Brushes]::Black,$left+20,50)
 foreach($group in @(@($old,'Red'),@($new,'ForestGreen'),@($src,'RoyalBlue'))) {
  $pts=[Drawing.PointF[]]@($group[0]|ForEach-Object {New-Object Drawing.PointF ([single]($left+25+($_.X-$minX)*$scale)),([single](800-($_.Y-$minY)*$scale))})
  $g.SetClip((New-Object Drawing.RectangleF $left,85,$width,735))
  $pen=New-Object Drawing.Pen ([Drawing.Color]::FromName($group[1])),2
  $g.DrawPolygon($pen,$pts);$pen.Dispose();$g.ResetClip()
 }
}
Panel 0 900 (@($src)+@($old)+@($new)) 'Antes: pico de 189,51 m'
Panel 900 600 (@($src)+@($new)) 'Despues: sobreancho lateral de 1 m'
$bmp.Save((Join-Path $labDir 'comparacion.png'),[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$bmp.Dispose();$font.Dispose();$small.Dispose()
