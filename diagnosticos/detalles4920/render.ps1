param(
  [string]$Dump = "C:\Users\juanbusper\Documents\URBANISMO\work\claude_20260910_detalles\dump.txt",
  [string]$Ventana = "vehicular",
  [string]$Salida = "C:\Users\juanbusper\Documents\URBANISMO\work\claude_20260910_detalles\r_vehicular.png",
  [double]$X1 = [double]::NaN, [double]$Y1 = [double]::NaN,
  [double]$X2 = [double]::NaN, [double]$Y2 = [double]::NaN,
  [int]$Ancho = 1600, [switch]$Voltear, [switch]$Claro
)
Add-Type -AssemblyName System.Drawing
$ci = [System.Globalization.CultureInfo]::InvariantCulture
function N([string]$s) { [double]::Parse($s, $ci) }

# color ACI aproximado (7 = negro sobre fondo blanco)
function Aci([int]$c) {
  switch ($c) {
    1 { return [System.Drawing.Color]::FromArgb(220,30,30) }
    2 { return [System.Drawing.Color]::FromArgb(200,170,0) }
    3 { return [System.Drawing.Color]::FromArgb(30,150,30) }
    4 { return [System.Drawing.Color]::FromArgb(0,160,170) }
    5 { return [System.Drawing.Color]::FromArgb(30,60,210) }
    6 { return [System.Drawing.Color]::FromArgb(180,40,180) }
    7 { return [System.Drawing.Color]::Black }
    8 { return [System.Drawing.Color]::FromArgb(110,110,110) }
    9 { return [System.Drawing.Color]::FromArgb(190,190,190) }
    default {
      if ($c -ge 250 -and $c -le 255) { $g = 50 + ($c-250)*38; return [System.Drawing.Color]::FromArgb($g,$g,$g) }
      return [System.Drawing.Color]::FromArgb(140,140,140)
    }
  }
}

# leer solo el bloque de la ventana pedida
$lines = Get-Content $Dump
$dentro = $false; $recs = New-Object System.Collections.Generic.List[string]
foreach ($ln in $lines) {
  if ($ln -match '^W (\S+) (\S+) (\S+) (\S+) (\S+)') {
    $dentro = ($Matches[1] -eq $Ventana)
    if ($dentro -and [double]::IsNaN($X1)) { $X1=N $Matches[2]; $Y1=N $Matches[3]; $X2=N $Matches[4]; $Y2=N $Matches[5] }
    continue
  }
  if ($ln -match '^E ') { $dentro = $false; continue }
  if ($dentro) { $recs.Add($ln) }
}
$w = $X2 - $X1; $h = $Y2 - $Y1
$esc = $Ancho / $w
$Alto = [int]([Math]::Ceiling($h * $esc))
$bmp = New-Object System.Drawing.Bitmap $Ancho, $Alto
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::White)
function PX([double]$x) { [single](($x - $X1) * $esc) }
function PY([double]$y) { if ($Voltear) { [single](($y - $Y1) * $esc) } else { [single](($Y2 - $y) * $esc) } }
function Pts($tok, $start, $n) {
  $arr = New-Object 'System.Drawing.PointF[]' $n
  for ($k=0; $k -lt $n; $k++) {
    $arr[$k] = New-Object System.Drawing.PointF (PX (N $tok[$start+2*$k])), (PY (N $tok[$start+2*$k+1]))
  }
  return ,$arr
}
# 1) rellenos primero
foreach ($r in $recs) {
  $t = $r.Split(' ')
  if ($t[0] -eq 'F') {
    $c = Aci ([int]$t[1]); $n = [int]$t[3]
    if ($n -lt 3) { continue }
    $pts = Pts $t 4 $n
    if ($Claro -and $t[1] -eq '7') { $c = [System.Drawing.Color]::FromArgb(250,250,250) }
    if ($Claro -and $t[1] -eq '8') { $c = [System.Drawing.Color]::FromArgb(200,200,200) }
    if ($t[2] -eq 'S') {
      $b = New-Object System.Drawing.SolidBrush $c; $g.FillPolygon($b, $pts); $b.Dispose()
      if ($Claro) { $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(150,150,150)), 1; $g.DrawPolygon($pen, $pts); $pen.Dispose() }
    } else {
      $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(120,$c)), 1; $g.DrawPolygon($pen, $pts); $pen.Dispose()
    }
  }
}
# 1b) rellenos translucidos (transparencia propia) encima de los demas
foreach ($r in $recs) {
  $t = $r.Split(' ')
  if ($t[0] -eq 'T' -and [int]$t[3] -ge 3) {
    $b = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, (Aci ([int]$t[1]))))
    $g.FillPolygon($b, (Pts $t 4 ([int]$t[3]))); $b.Dispose()
  }
}
# 2) lineas, polilineas y circulos
foreach ($r in $recs) {
  $t = $r.Split(' ')
  switch ($t[0]) {
    'L' { $pen = New-Object System.Drawing.Pen (Aci ([int]$t[1])), 1.2
          $g.DrawLine($pen, (PX (N $t[2])), (PY (N $t[3])), (PX (N $t[4])), (PY (N $t[5]))); $pen.Dispose() }
    'P' { $n = [int]$t[2]; if ($n -ge 2) { $pen = New-Object System.Drawing.Pen (Aci ([int]$t[1])), 1.2
          $g.DrawLines($pen, (Pts $t 3 $n)); $pen.Dispose() } }
    'C' { $pen = New-Object System.Drawing.Pen (Aci ([int]$t[1])), 1.0
          $rr = (N $t[4]) * $esc; $cx = PX (N $t[2]); $cy = PY (N $t[3])
          $g.DrawEllipse($pen, [single]($cx-$rr), [single]($cy-$rr), [single](2*$rr), [single](2*$rr)); $pen.Dispose() }
  }
}
# escala grafica de 1 m
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Red), 3
$g.DrawLine($pen, [single]20, [single]($Alto-20), [single](20+$esc), [single]($Alto-20)); $pen.Dispose()
$f = New-Object System.Drawing.Font "Arial", 12
$g.DrawString("1 m", $f, [System.Drawing.Brushes]::Red, [single]20, [single]($Alto-42))
$g.Dispose()
$bmp.Save($Salida, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
"{0} registros -> {1} ({2} x {3} px)" -f $recs.Count, $Salida, $Ancho, $Alto
