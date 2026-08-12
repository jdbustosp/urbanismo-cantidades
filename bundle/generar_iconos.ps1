# Genera los 27 iconos de la pestana CANTIDADES (PNG 32x32 y 16x16,
# fondo transparente, estilo plano legible sobre el tema oscuro de
# AutoCAD) en bundle\iconos\. Reproducible: editar aqui y volver a correr.
#   powershell -ExecutionPolicy Bypass -File bundle\generar_iconos.ps1
# Despues: armar_cuix.ps1 (los empaca) e INSTALAR.bat.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$dir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "iconos"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

# paleta (legible en tema oscuro)
$cGris   = [System.Drawing.Color]::FromArgb(200, 200, 200)
$cGrisOs = [System.Drawing.Color]::FromArgb(130, 130, 130)
$cAmar   = [System.Drawing.Color]::FromArgb(255, 200,  60)
$cVerde  = [System.Drawing.Color]::FromArgb(110, 200, 110)
$cAzul   = [System.Drawing.Color]::FromArgb(100, 170, 240)
$cNara   = [System.Drawing.Color]::FromArgb(240, 150,  70)
$cRojo   = [System.Drawing.Color]::FromArgb(230, 110, 100)
$cBlanco = [System.Drawing.Color]::FromArgb(235, 235, 235)

function New-Icon([string]$name, [scriptblock]$draw) {
  foreach ($size in @(32, 16)) {
    $bmp = [System.Drawing.Bitmap]::new($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $s = $size / 32.0
    & $draw $g $s
    $g.Dispose()
    $bmp.Save((Join-Path $dir ("cant_" + $name + "_" + $size + ".png")), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
  }
  Write-Output ("icono: " + $name)
}
function P($color, $w) { [System.Drawing.Pen]::new($color, $w) }
function B($color) { [System.Drawing.SolidBrush]::new($color) }

New-Icon "via" { param($g, $s)
  $g.FillPolygon((B $cGrisOs), @(
    ([System.Drawing.PointF]::new(11*$s, 3*$s)), ([System.Drawing.PointF]::new(21*$s, 3*$s)),
    ([System.Drawing.PointF]::new(28*$s, 29*$s)), ([System.Drawing.PointF]::new(4*$s, 29*$s))))
  $pen = P $cAmar (2*$s); $pen.DashStyle = 'Dash'
  $g.DrawLine($pen, 16*$s, 5*$s, 16*$s, 27*$s)
}
New-Icon "anden" { param($g, $s)
  $b = B $cGris
  foreach ($i in 0..2) { foreach ($j in 0..2) {
    $g.FillRectangle($b, (4 + $i*9)*$s, (4 + $j*9)*$s, 7*$s, 7*$s) } }
}
New-Icon "rampa" { param($g, $s)
  $g.FillPolygon((B $cGris), @(
    ([System.Drawing.PointF]::new(3*$s, 28*$s)), ([System.Drawing.PointF]::new(29*$s, 28*$s)),
    ([System.Drawing.PointF]::new(29*$s, 6*$s))))
  $g.DrawLine((P $cGrisOs (1.5*$s)), 12*$s, 28*$s, 29*$s, 13*$s)
}
New-Icon "zonaverde" { param($g, $s)
  $g.FillEllipse((B $cVerde), 6*$s, 3*$s, 20*$s, 18*$s)
  $g.FillRectangle((B $cNara), 14*$s, 19*$s, 4*$s, 10*$s)
}
New-Icon "prefabricado" { param($g, $s)
  $g.FillRectangle((B $cNara), 4*$s, 6*$s, 14*$s, 9*$s)
  $g.FillRectangle((B $cNara), 12*$s, 17*$s, 14*$s, 9*$s)
  $g.DrawRectangle((P $cBlanco (1*$s)), 4*$s, 6*$s, 14*$s, 9*$s)
  $g.DrawRectangle((P $cBlanco (1*$s)), 12*$s, 17*$s, 14*$s, 9*$s)
}
New-Icon "tsanitario" { param($g, $s)
  $g.DrawEllipse((P $cVerde (4*$s)), 6*$s, 6*$s, 20*$s, 20*$s)
}
New-Icon "tpluvial" { param($g, $s)
  $g.FillPolygon((B $cAzul), @(
    ([System.Drawing.PointF]::new(16*$s, 3*$s)), ([System.Drawing.PointF]::new(25*$s, 19*$s)),
    ([System.Drawing.PointF]::new(16*$s, 29*$s)), ([System.Drawing.PointF]::new(7*$s, 19*$s))))
}
New-Icon "tacueducto" { param($g, $s)
  $g.DrawEllipse((P $cAzul (4*$s)), 6*$s, 6*$s, 20*$s, 20*$s)
}
New-Icon "pozosan" { param($g, $s)
  $g.DrawEllipse((P $cVerde (2.5*$s)), 4*$s, 4*$s, 24*$s, 24*$s)
  $g.FillEllipse((B $cVerde), 12*$s, 12*$s, 8*$s, 8*$s)
}
New-Icon "pozoplu" { param($g, $s)
  $g.DrawEllipse((P $cAzul (2.5*$s)), 4*$s, 4*$s, 24*$s, 24*$s)
  $g.FillEllipse((B $cAzul), 12*$s, 12*$s, 8*$s, 8*$s)
}
New-Icon "sumidero" { param($g, $s)
  $g.DrawRectangle((P $cGris (2*$s)), 4*$s, 8*$s, 24*$s, 16*$s)
  foreach ($i in 1..4) {
    $g.DrawLine((P $cGris (2*$s)), (4 + $i*4.8)*$s, 10*$s, (4 + $i*4.8)*$s, 22*$s) }
}
New-Icon "camara" { param($g, $s)
  $g.DrawRectangle((P $cGris (2*$s)), 5*$s, 5*$s, 22*$s, 22*$s)
  $g.FillPolygon((B $cAmar), @(
    ([System.Drawing.PointF]::new(18*$s, 8*$s)), ([System.Drawing.PointF]::new(12*$s, 17*$s)),
    ([System.Drawing.PointF]::new(16*$s, 17*$s)), ([System.Drawing.PointF]::new(14*$s, 24*$s)),
    ([System.Drawing.PointF]::new(21*$s, 14*$s)), ([System.Drawing.PointF]::new(17*$s, 14*$s))))
}
New-Icon "accesorio" { param($g, $s)
  $g.FillPolygon((B $cAzul), @(
    ([System.Drawing.PointF]::new(4*$s, 8*$s)), ([System.Drawing.PointF]::new(4*$s, 24*$s)),
    ([System.Drawing.PointF]::new(16*$s, 16*$s))))
  $g.FillPolygon((B $cAzul), @(
    ([System.Drawing.PointF]::new(28*$s, 8*$s)), ([System.Drawing.PointF]::new(28*$s, 24*$s)),
    ([System.Drawing.PointF]::new(16*$s, 16*$s))))
  $g.DrawLine((P $cAzul (2*$s)), 16*$s, 16*$s, 16*$s, 8*$s)
}
New-Icon "luminaria" { param($g, $s)
  $g.FillEllipse((B $cAmar), 10*$s, 6*$s, 12*$s, 12*$s)
  $g.FillRectangle((B $cGris), 13*$s, 18*$s, 6*$s, 4*$s)
  $g.FillRectangle((B $cGris), 14*$s, 22*$s, 4*$s, 4*$s)
  foreach ($a in @(0, 45, 90, 135, 180)) {
    $rad = $a * [Math]::PI / 180
    $x1 = 16 + 9 * [Math]::Cos($rad); $y1 = 12 - 9 * [Math]::Sin($rad)
    $x2 = 16 + 13 * [Math]::Cos($rad); $y2 = 12 - 13 * [Math]::Sin($rad)
    $g.DrawLine((P $cAmar (1.5*$s)), $x1*$s, $y1*$s, $x2*$s, $y2*$s) }
}
New-Icon "editar" { param($g, $s)
  $g.FillPolygon((B $cNara), @(
    ([System.Drawing.PointF]::new(20*$s, 5*$s)), ([System.Drawing.PointF]::new(27*$s, 12*$s)),
    ([System.Drawing.PointF]::new(12*$s, 27*$s)), ([System.Drawing.PointF]::new(5*$s, 27*$s)),
    ([System.Drawing.PointF]::new(5*$s, 20*$s))))
  $g.FillPolygon((B $cBlanco), @(
    ([System.Drawing.PointF]::new(22*$s, 3*$s)), ([System.Drawing.PointF]::new(29*$s, 10*$s)),
    ([System.Drawing.PointF]::new(27*$s, 12*$s)), ([System.Drawing.PointF]::new(20*$s, 5*$s))))
}
New-Icon "etapas" { param($g, $s)
  $g.FillRectangle((B $cAzul), 4*$s, 20*$s, 24*$s, 7*$s)
  $g.FillRectangle((B $cGris), 7*$s, 12*$s, 18*$s, 6*$s)
  $g.FillRectangle((B $cBlanco), 10*$s, 5*$s, 12*$s, 5*$s)
}
New-Icon "qcuadro" { param($g, $s)
  $g.DrawRectangle((P $cGris (2*$s)), 4*$s, 5*$s, 24*$s, 22*$s)
  $g.DrawLine((P $cGris (1.5*$s)), 4*$s, 12*$s, 28*$s, 12*$s)
  $g.DrawLine((P $cGris (1.5*$s)), 4*$s, 19*$s, 28*$s, 19*$s)
  $g.DrawLine((P $cGris (1.5*$s)), 14*$s, 5*$s, 14*$s, 27*$s)
}
New-Icon "qmemoria" { param($g, $s)
  $g.DrawRectangle((P $cGris (2*$s)), 7*$s, 3*$s, 18*$s, 26*$s)
  foreach ($y in @(9, 14, 19, 24)) {
    $g.DrawLine((P $cGris (1.5*$s)), 10*$s, $y*$s, 22*$s, $y*$s) }
}
New-Icon "qverificacion" { param($g, $s)
  $g.DrawRectangle((P $cGris (2*$s)), 4*$s, 5*$s, 18*$s, 22*$s)
  $g.DrawLine((P $cGris (1.5*$s)), 4*$s, 12*$s, 22*$s, 12*$s)
  $pen = P $cVerde (3.5*$s); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $g.DrawLine($pen, 17*$s, 20*$s, 22*$s, 26*$s)
  $g.DrawLine($pen, 22*$s, 26*$s, 30*$s, 13*$s)
}
New-Icon "qalcance" { param($g, $s)
  $g.DrawEllipse((P $cGris (2*$s)), 4*$s, 4*$s, 24*$s, 24*$s)
  $pen = P $cVerde (3*$s)
  $g.DrawLine($pen, 10*$s, 13*$s, 16*$s, 13*$s)
  $g.DrawLine($pen, 13*$s, 10*$s, 13*$s, 16*$s)
  $g.DrawLine((P $cRojo (3*$s)), 17*$s, 21*$s, 23*$s, 21*$s)
}
New-Icon "qcsv" { param($g, $s)
  $g.DrawRectangle((P $cGris (2*$s)), 5*$s, 3*$s, 16*$s, 26*$s)
  foreach ($y in @(9, 14, 19)) {
    $g.DrawLine((P $cGris (1.5*$s)), 8*$s, $y*$s, 18*$s, $y*$s) }
  $pen = P $cVerde (3*$s); $pen.EndCap = 'ArrowAnchor'
  $g.DrawLine($pen, 20*$s, 24*$s, 30*$s, 24*$s)
}
New-Icon "qexcel" { param($g, $s)
  $g.FillRectangle((B $cVerde), 4*$s, 4*$s, 24*$s, 24*$s)
  $pen = P $cBlanco (3*$s); $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
  $g.DrawLine($pen, 10*$s, 10*$s, 22*$s, 22*$s)
  $g.DrawLine($pen, 22*$s, 10*$s, 10*$s, 22*$s)
}
New-Icon "qactualizar" { param($g, $s)
  $pen = P $cVerde (3*$s); $pen.EndCap = 'ArrowAnchor'
  $g.DrawArc($pen, 5*$s, 5*$s, 22*$s, 22*$s, -80, 160)
  $pen2 = P $cVerde (3*$s); $pen2.EndCap = 'ArrowAnchor'
  $g.DrawArc($pen2, 5*$s, 5*$s, 22*$s, 22*$s, 100, 160)
}
New-Icon "qvincular" { param($g, $s)
  $pen = P $cAzul (3*$s)
  $g.DrawEllipse($pen, 3*$s, 10*$s, 14*$s, 11*$s)
  $g.DrawEllipse($pen, 15*$s, 10*$s, 14*$s, 11*$s)
}
New-Icon "qdesvincular" { param($g, $s)
  $pen = P $cAzul (3*$s)
  $g.DrawEllipse($pen, 2*$s, 10*$s, 12*$s, 11*$s)
  $g.DrawEllipse($pen, 18*$s, 10*$s, 12*$s, 11*$s)
  $g.DrawLine((P $cRojo (2.5*$s)), 13*$s, 26*$s, 19*$s, 6*$s)
}
New-Icon "perfiles" { param($g, $s)
  $g.FillRectangle((B $cGrisOs), 4*$s, 5*$s, 24*$s, 6*$s)
  $g.FillRectangle((B $cNara), 4*$s, 13*$s, 24*$s, 6*$s)
  $g.FillRectangle((B $cGris), 4*$s, 21*$s, 24*$s, 6*$s)
}
New-Icon "ajustes" { param($g, $s)
  $g.FillEllipse((B $cGris), 8*$s, 8*$s, 16*$s, 16*$s)
  foreach ($a in @(0, 45, 90, 135, 180, 225, 270, 315)) {
    $rad = $a * [Math]::PI / 180
    $x = 16 + 11 * [Math]::Cos($rad); $y = 16 + 11 * [Math]::Sin($rad)
    $g.FillRectangle((B $cGris), ($x - 2.2)*$s, ($y - 2.2)*$s, 4.4*$s, 4.4*$s) }
  $g.FillEllipse((B ([System.Drawing.Color]::FromArgb(60, 60, 60))), 13*$s, 13*$s, 6*$s, 6*$s)
}
New-Icon "urbanismo" { param($g, $s)
  $g.FillRectangle((B $cGrisOs), 4*$s, 12*$s, 7*$s, 16*$s)
  $g.FillRectangle((B $cAzul), 12*$s, 5*$s, 8*$s, 23*$s)
  $g.FillRectangle((B $cGris), 21*$s, 16*$s, 7*$s, 12*$s)
  $b = B ([System.Drawing.Color]::FromArgb(45, 45, 45))
  foreach ($y in @(8, 13, 18, 23)) {
    $g.FillRectangle($b, 14*$s, $y*$s, 2*$s, 2*$s)
    $g.FillRectangle($b, 17*$s, $y*$s, 2*$s, 2*$s) }
}
New-Icon "mediatension" { param($g, $s)
  $g.DrawLine((P $cGris (2*$s)), 16*$s, 6*$s, 16*$s, 28*$s)
  $g.DrawLine((P $cGris (2*$s)), 7*$s, 9*$s, 25*$s, 9*$s)
  $g.DrawLine((P $cGrisOs (1.2*$s)), 8*$s, 9*$s, 12*$s, 15*$s)
  $g.DrawLine((P $cGrisOs (1.2*$s)), 24*$s, 9*$s, 20*$s, 15*$s)
  $g.FillPolygon((B $cAmar), @(
    ([System.Drawing.PointF]::new(21*$s, 14*$s)), ([System.Drawing.PointF]::new(14*$s, 22*$s)),
    ([System.Drawing.PointF]::new(18*$s, 22*$s)), ([System.Drawing.PointF]::new(16*$s, 29*$s)),
    ([System.Drawing.PointF]::new(24*$s, 19*$s)), ([System.Drawing.PointF]::new(20*$s, 19*$s))))
}
Write-Output "Iconos generados en $dir"
