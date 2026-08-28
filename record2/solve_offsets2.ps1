# solve_offsets2.ps1 - v2: clusters sobre TODAS las entidades del record
# BT (segs+cajas+fotos) y offset por cluster votado con DOS anclas:
# cajas record->cajas modelo y fotometrias record->postes modelo.
# Solo clusters con >=6 inliers. Emite rec_bt_adj.lsp.
$ErrorActionPreference = "Stop"
$W = "C:\Users\jdbus\Documents\URBANISMO\work\record2"

$recCajas = @(); $recSegs = @(); $recFotos = @()
foreach ($ln in Get-Content "$W\rec_bt_raw.txt") {
  $p = $ln.Split('|')
  switch ($p[0]) {
    "CAJA" { $recCajas += ,@([double]$p[1], [double]$p[2]) }
    "FOTO" { $recFotos += ,@([double]$p[1], [double]$p[2]) }
    "SEG"  { $recSegs  += ,@([double]$p[1], [double]$p[2], [double]$p[3], [double]$p[4]) }
  }
}
$modCajas = @(); $modPostes = @()
foreach ($ln in Get-Content "$W\model_bt.txt") {
  $p = $ln.Split('|')
  if ($p[0] -eq "CAJA") { $modCajas += ,@([double]$p[1], [double]$p[2]) }
  if ($p[0] -eq "POSTE") { $modPostes += ,@([double]$p[1], [double]$p[2]) }
}
Write-Output ("record: cajas=" + $recCajas.Count + " segs=" + $recSegs.Count + " fotos=" + $recFotos.Count + " | modelo: cajas=" + $modCajas.Count + " postes=" + $modPostes.Count)

# --- puntos representativos de TODO el record: cajas, fotos, seg-medios
$pts = New-Object System.Collections.ArrayList
foreach ($x in $recCajas) { [void]$pts.Add(@($x[0], $x[1], 0)) }   # tipo 0 caja
foreach ($x in $recFotos) { [void]$pts.Add(@($x[0], $x[1], 1)) }   # tipo 1 foto
$segMidIdx = @()
for ($i = 0; $i -lt $recSegs.Count; $i++) {
  $s = $recSegs[$i]
  $segMidIdx += $pts.Count
  [void]$pts.Add(@((($s[0]+$s[2])/2.0), (($s[1]+$s[3])/2.0), 2))   # tipo 2 seg
}
$N = $pts.Count

# --- flood fill con celdas (umbral 400 m) para eficiencia
$cell = 400.0
$grid = @{}
for ($i = 0; $i -lt $N; $i++) {
  $k = [string][math]::Floor($pts[$i][0]/$cell) + "," + [string][math]::Floor($pts[$i][1]/$cell)
  if (-not $grid.ContainsKey($k)) { $grid[$k] = New-Object System.Collections.ArrayList }
  [void]$grid[$k].Add($i)
}
$cluster = New-Object int[] $N
for ($i = 0; $i -lt $N; $i++) { $cluster[$i] = -1 }
$cid = 0
for ($i = 0; $i -lt $N; $i++) {
  if ($cluster[$i] -ge 0) { continue }
  $stack = New-Object System.Collections.Stack
  $stack.Push($i); $cluster[$i] = $cid
  while ($stack.Count -gt 0) {
    $a = $stack.Pop()
    $cx = [math]::Floor($pts[$a][0]/$cell); $cy = [math]::Floor($pts[$a][1]/$cell)
    for ($gx = $cx-1; $gx -le $cx+1; $gx++) {
      for ($gy = $cy-1; $gy -le $cy+1; $gy++) {
        $k = "$gx,$gy"
        if ($grid.ContainsKey($k)) {
          foreach ($j in $grid[$k]) {
            if ($cluster[$j] -lt 0) { $cluster[$j] = $cid; $stack.Push($j) }
          }
        }
      }
    }
  }
  $cid++
}
Write-Output ("clusters (todas las entidades): " + $cid)

# --- offset por cluster: votos caja->caja y foto->poste (bucket 1 m)
$offsets = @{}
for ($c = 0; $c -lt $cid; $c++) {
  $anchors = @()   # pares (punto record, lista candidatos modelo)
  $csize = 0
  for ($i = 0; $i -lt $N; $i++) {
    if ($cluster[$i] -ne $c) { continue }
    $csize++
    if ($pts[$i][2] -eq 0) { $anchors += ,@($pts[$i][0], $pts[$i][1], 0) }
    if ($pts[$i][2] -eq 1) { $anchors += ,@($pts[$i][0], $pts[$i][1], 1) }
  }
  if ($anchors.Count -lt 4) {
    if ($csize -gt 20) { Write-Output ("cluster " + $c + ": " + $csize + " ents, sin anclas suficientes (" + $anchors.Count + ")") }
    continue
  }
  $votes = @{}
  foreach ($a in $anchors) {
    $targets = if ($a[2] -eq 0) { $modCajas } else { $modPostes }
    foreach ($m in $targets) {
      $dx = [math]::Round($m[0] - $a[0]); $dy = [math]::Round($m[1] - $a[1])
      $k = "$dx,$dy"
      if ($votes.ContainsKey($k)) { $votes[$k]++ } else { $votes[$k] = 1 }
    }
  }
  $best = $votes.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1
  $bd = $best.Key.Split(','); $bdx = [double]$bd[0]; $bdy = [double]$bd[1]
  $sx = 0.0; $sy = 0.0; $cnt = 0
  foreach ($a in $anchors) {
    $targets = if ($a[2] -eq 0) { $modCajas } else { $modPostes }
    $bestd = 9e9; $bm = $null
    foreach ($m in $targets) {
      $dx = $m[0] - ($a[0] + $bdx); $dy = $m[1] - ($a[1] + $bdy)
      $d = $dx*$dx + $dy*$dy
      if ($d -lt $bestd) { $bestd = $d; $bm = $m }
    }
    if ($bestd -lt 2.25) { $sx += $bm[0] - $a[0]; $sy += $bm[1] - $a[1]; $cnt++ }
  }
  if ($cnt -ge 6) {
    $offsets[$c] = @(($sx/$cnt), ($sy/$cnt))
    Write-Output ("cluster " + $c + ": " + $csize + " ents / " + $anchors.Count + " anclas -> offset (" + [math]::Round($sx/$cnt,3) + ", " + [math]::Round($sy/$cnt,3) + "), inliers " + $cnt)
  } else {
    if ($csize -gt 20) { Write-Output ("cluster " + $c + ": " + $csize + " ents / " + $anchors.Count + " anclas -> SIN offset (inliers " + $cnt + ")") }
  }
}

# --- emitir datos ajustados
$out = New-Object System.Text.StringBuilder
[void]$out.AppendLine(";;; record BT con offsets por hoja resueltos (v2, generado)")
[void]$out.AppendLine("(setq rec:bt-segs '(")
$segOk = 0; $segSkip = 0
for ($i = 0; $i -lt $recSegs.Count; $i++) {
  $c = $cluster[$segMidIdx[$i]]
  if ($offsets.ContainsKey($c)) {
    $o = $offsets[$c]; $s = $recSegs[$i]
    [void]$out.AppendLine("  (" + [math]::Round($s[0]+$o[0],3) + " " + [math]::Round($s[1]+$o[1],3) + " " + [math]::Round($s[2]+$o[0],3) + " " + [math]::Round($s[3]+$o[1],3) + ")")
    $segOk++
  } else { $segSkip++ }
}
[void]$out.AppendLine("))")
[void]$out.AppendLine("(setq rec:bt-cajas '(")
for ($i = 0; $i -lt $recCajas.Count; $i++) {
  $c = $cluster[$i]
  if ($offsets.ContainsKey($c)) {
    $o = $offsets[$c]
    [void]$out.AppendLine("  (" + [math]::Round($recCajas[$i][0]+$o[0],3) + " " + [math]::Round($recCajas[$i][1]+$o[1],3) + ")")
  }
}
[void]$out.AppendLine("))")
[void]$out.AppendLine("(setq rec:bt-fotos '(")
for ($i = 0; $i -lt $recFotos.Count; $i++) {
  $c = $cluster[$recCajas.Count + $i]
  if ($offsets.ContainsKey($c)) {
    $o = $offsets[$c]
    [void]$out.AppendLine("  (" + [math]::Round($recFotos[$i][0]+$o[0],3) + " " + [math]::Round($recFotos[$i][1]+$o[1],3) + ")")
  }
}
[void]$out.AppendLine("))")
[void]$out.AppendLine("(princ (strcat ""\nbt-adj: "" (itoa (length rec:bt-segs)) "" segs, "" (itoa (length rec:bt-cajas)) "" cajas, "" (itoa (length rec:bt-fotos)) "" fotos""))(princ)")
Set-Content -Path "$W\rec_bt_adj.lsp" -Value $out.ToString() -Encoding ASCII
Write-Output ("emitido: segs " + $segOk + " (omitidos " + $segSkip + ")")