Add-Type -AssemblyName System.Drawing
$bmp=[Drawing.Bitmap]::new(700,820)
$g=[Drawing.Graphics]::FromImage($bmp)
$g.Clear([Drawing.Color]::White)
$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$font=[Drawing.Font]::new('Arial',12)
$g.DrawString('VIA-17: geometria extraida del laboratorio',$font,[Drawing.Brushes]::Black,15,10)
$g.DrawString('Gris: contorno. Naranja: eje guardado. Azul: recalculado.',$font,[Drawing.Brushes]::Black,15,35)
$clip=[Drawing.Rectangle]::new(30,70,640,680)
$g.SetClip($clip)
foreach($part in @('boundary','oldaxis','newaxis')) {
 $file=Join-Path $PSScriptRoot "road-VIA-17-$part.csv"
 $points=@(Get-Content -LiteralPath $file | ForEach-Object {
  $xy=$_.Split(',')
  [Drawing.PointF]::new([single](350+([double]::Parse($xy[0],[cultureinfo]::InvariantCulture)-83104)*12),[single](90+(95458-[double]::Parse($xy[1],[cultureinfo]::InvariantCulture))*12))
 })
 $color=switch($part){'boundary'{[Drawing.Color]::Gray}'oldaxis'{[Drawing.Color]::DarkOrange}'newaxis'{[Drawing.Color]::Blue}}
 $pen=[Drawing.Pen]::new($color,2.3)
 $g.DrawLines($pen,[Drawing.PointF[]]$points)
 $pen.Dispose()
}
$g.ResetClip()
$g.DrawString('Detalle del extremo norte. No es una captura de AutoCAD.',$font,[Drawing.Brushes]::Black,15,780)
$bmp.Save((Join-Path $PSScriptRoot 'axis-detail.png'))
$g.Dispose(); $bmp.Dispose(); $font.Dispose()
