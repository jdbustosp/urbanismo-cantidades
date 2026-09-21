param(
  [Parameter(Mandatory=$true)][string]$InputFile,
  [Parameter(Mandatory=$true)][string]$OutputFile
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$paths=@()
foreach($line in [IO.File]::ReadLines($InputFile)) {
  $parts=$line.Split(';')
  $points=@()
  foreach($token in $parts[1..($parts.Length-1)]) {
    $xy=$token.Split(',')
    $points += [pscustomobject]@{X=[double]::Parse($xy[0],[cultureinfo]::InvariantCulture);Y=[double]::Parse($xy[1],[cultureinfo]::InvariantCulture)}
  }
  $paths += [pscustomobject]@{Name=$parts[0];Points=$points}
}
$all=@($paths | ForEach-Object {$_.Points})
$xmin=($all.X|Measure-Object -Minimum).Minimum;$xmax=($all.X|Measure-Object -Maximum).Maximum
$ymin=($all.Y|Measure-Object -Minimum).Minimum;$ymax=($all.Y|Measure-Object -Maximum).Maximum
$bitmap=New-Object Drawing.Bitmap(1200,1600)
$g=[Drawing.Graphics]::FromImage($bitmap);$g.Clear([Drawing.Color]::White)
$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$scale=[Math]::Min(1120/($xmax-$xmin),1500/($ymax-$ymin))
$colors=@{BOUNDARY=[Drawing.Color]::LightGray;SELECTED_SIDE=[Drawing.Color]::Red;TOPEROL_FAR=[Drawing.Color]::Orange;GUIDE_NEAR=[Drawing.Color]::Blue;GUIDE_FAR=[Drawing.Color]::Blue}
foreach($path in $paths) {
  $width=if($path.Name -eq 'BOUNDARY'){1.0}else{3.0}
  $pen=New-Object Drawing.Pen($colors[$path.Name],[single]$width)
  $pts=[Drawing.PointF[]]@($path.Points|ForEach-Object{New-Object Drawing.PointF([single](40+($_.X-$xmin)*$scale),[single](1560-($_.Y-$ymin)*$scale))})
  if($pts.Count -gt 1){$g.DrawLines($pen,$pts)}
  $pen.Dispose()
}
$font=New-Object Drawing.Font('Arial',14)
$g.DrawString('Rojo: lado seleccionado | Naranja: toperol | Azul: guia',$font,[Drawing.Brushes]::Black,20,12)
$font.Dispose();$bitmap.Save($OutputFile,[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bitmap.Dispose()
