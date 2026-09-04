# optimizar_libro.ps1 (2026-09-04) - hace CASI INSTANTANEO el recalculo del
# libro: los ~800k SUMIFS que barren TablaMemorias (5.4k filas c/u; ~20 min
# de CalculateFull) se reemplazan por LOOKUP binario sobre una hoja oculta
# URB_AGG (tabla TablaAgg: KEY=ESPEC|SUBETAPA|RED ordenada, CANT=suma).
# El plugin v4.69.0 re-escribe TablaAgg en cada export.
# Verificacion integrada: suma por hoja de las celdas transformadas ANTES
# vs DESPUES (deben ser identicas) + tiempos de CalculateFull.
param([string]$libro = "C:\Users\jdbus\Documents\URBANISMO\work\perf0903\TEST\urbanismo maipore.xlsx")
$ErrorActionPreference = "Stop"
$log = "C:\Users\jdbus\Documents\URBANISMO\work\perf0903\optimizar_log.txt"
function L([string]$m) { $m | Out-File -FilePath $log -Append -Encoding utf8; Write-Output $m }
"" | Out-File -FilePath $log -Encoding utf8

$rx = [regex]'SUMIFS\(TablaMemorias\[CANTIDAD\],TablaMemorias\[ESPECIFICACION\],([^,]+),TablaMemorias\[SUBETAPA\],([^,]+),TablaMemorias\[RED\],("(?:[^"]|"")*"|[^),]+)\)'

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  $xl.Calculation = -4135  # manual

  # ---------- 1) construir URB_AGG desde TablaMemorias ----------
  $wsMem = $wb.Worksheets.Item("MEMORIAS")
  $loMem = $wsMem.ListObjects.Item(1)
  $body = $loMem.DataBodyRange.Value2
  $nMem = $body.GetLength(0)
  $agg = @{}
  for ($i = 1; $i -le $nMem; $i++) {
    $red = [string]$body[$i,1]; $esp = [string]$body[$i,3]
    $sub = [string]$body[$i,8]; $cant = $body[$i,10]
    if ($cant -isnot [double]) { $cant = [double]("0" + $cant) }
    $k = $esp + "|" + $sub + "|" + $red
    if ($agg.ContainsKey($k)) { $agg[$k] += $cant } else { $agg[$k] = $cant }
  }
  L ("memorias: " + $nMem + " filas -> " + $agg.Count + " claves agregadas")

  # hoja URB_AGG (recrear limpia; nunca borrar DENTRO del foreach de la coleccion)
  $vieja = $null
  foreach ($ws in $wb.Worksheets) { if ($ws.Name -eq "URB_AGG") { $vieja = $ws } }
  if ($vieja) { $vieja.Visible = -1; $vieja.Delete() }
  $wsA = $wb.Worksheets.Add()
  $wsA.Name = "URB_AGG"
  $wsA.Cells.Item(1,1).Value2 = "KEY"; $wsA.Cells.Item(1,2).Value2 = "CANT"
  # TAMANO FIJO 4000: las operaciones ESTRUCTURALES sobre una tabla con
  # 800k formulas dependientes reconstruyen el arbol de dependencias
  # (minutos). Con tamano fijo el plugin solo cambia VALORES + Sort
  # (baratisimo). Relleno con centinela U+00FF (ordena despues de todo).
  $FIL = 4000
  $n = $agg.Count
  if ($n -gt $FIL) { throw ("claves agregadas " + $n + " > " + $FIL + " - subir FIL") }
  $cent = [string]([char]0x00FF) * 6
  $arr = New-Object 'object[,]' $FIL, 2
  $i = 0
  foreach ($k in $agg.Keys) { $arr[$i,0] = $k; $arr[$i,1] = $agg[$k]; $i++ }
  while ($i -lt $FIL) { $arr[$i,0] = $cent; $arr[$i,1] = 0.0; $i++ }
  $rng = $wsA.Range($wsA.Cells.Item(2,1), $wsA.Cells.Item($FIL+1,2))
  $rng.Value2 = $arr
  # ordenar con el criterio DE EXCEL (el LOOKUP binario lo exige);
  # Header=xlNo(2) explicito para que no adivine
  $m = [Type]::Missing
  $rng.Sort($wsA.Range("A2"), 1, $m, $m, 1, $m, 1, 2) | Out-Null
  $loA = $wsA.ListObjects.Add(1, $wsA.Range($wsA.Cells.Item(1,1), $wsA.Cells.Item($FIL+1,2)), $null, 1)
  $loA.Name = "TablaAgg"
  $wsA.Visible = 2  # veryhidden
  L ("URB_AGG creada: " + $n + " claves + relleno hasta " + $FIL + " filas fijas, tabla TablaAgg")

  # ---------- 2) snapshot ANTES + transformar hoja por hoja ----------
  $t0 = Get-Date
  $xl.CalculateFull()
  $tAntes = ((Get-Date) - $t0).TotalSeconds
  L ("CalculateFull ANTES: " + [math]::Round($tAntes,1) + " s")

  $tot = 0; $hojas = 0; $resumen = @{}
  foreach ($ws in $wb.Worksheets) {
    if ($ws.Name -in @("URB_AGG","MEMORIAS")) { continue }
    $ur = $ws.UsedRange
    $f = $ur.FormulaR1C1
    if ($f -isnot [object[,]]) { continue }
    $vals = $ur.Value2
    $r0 = $ur.Row; $c0 = $ur.Column
    $nr = $f.GetLength(0); $nc = $f.GetLength(1)
    $suma = 0.0; $cnt = 0
    $writes = @()   # lista de @(fila, colIni, colFin, nuevaR1C1)
    for ($r = 1; $r -le $nr; $r++) {
      $runStart = 0; $runFormula = $null
      for ($c = 1; $c -le $nc + 1; $c++) {
        $esMatch = $false; $nueva = $null
        if ($c -le $nc) {
          $s = $f[$r,$c]
          if ($s -is [string] -and $s -like "*SUMIFS(TablaMemorias*") {
            $m = $rx.Match($s)
            if ($m.Success) {
              $esMatch = $true
              $k = $m.Groups[1].Value + '&"|"&' + $m.Groups[2].Value + '&"|"&' + $m.Groups[3].Value
              # IFERROR propio: cubre claves menores que la primera (da N/A)
              # aunque la formula original no tuviera IFERROR por fuera
              $lk = 'IFERROR(IF(LOOKUP(' + $k + ',TablaAgg[KEY])=' + $k + ',LOOKUP(' + $k + ',TablaAgg[KEY],TablaAgg[CANT]),0),0)'
              $nueva = $rx.Replace($s, $lk, 1)
              $v = $vals[$r,$c]
              if ($v -is [double]) { $suma += $v }
              $cnt++
            }
          }
        }
        if ($esMatch -and $runStart -eq 0) { $runStart = $c; $runFormula = $nueva }
        elseif ($esMatch -and $nueva -ne $runFormula) {
          # formula distinta en la misma fila: cerrar run y abrir otro
          $writes += ,@($r, $runStart, ($c - 1), $runFormula)
          $runStart = $c; $runFormula = $nueva
        }
        elseif (-not $esMatch -and $runStart -gt 0) {
          $writes += ,@($r, $runStart, ($c - 1), $runFormula)
          $runStart = 0; $runFormula = $null
        }
      }
    }
    if ($cnt -eq 0) { continue }
    foreach ($w in $writes) {
      $rr = $r0 + $w[0] - 1
      $cc1 = $c0 + $w[1] - 1; $cc2 = $c0 + $w[2] - 1
      $tgt = $ws.Range($ws.Cells.Item($rr,$cc1), $ws.Cells.Item($rr,$cc2))
      $tgt.FormulaR1C1 = $w[3]
    }
    $resumen[$ws.Name] = @($cnt, $suma)
    $tot += $cnt; $hojas++
  }
  L ("transformadas: " + $tot + " formulas en " + $hojas + " hojas")

  # ---------- 3) recalcular DESPUES + verificar equivalencia ----------
  $t0 = Get-Date
  $xl.CalculateFull()
  $tDespues = ((Get-Date) - $t0).TotalSeconds
  L ("CalculateFull DESPUES: " + [math]::Round($tDespues,1) + " s")

  $fallas = 0
  foreach ($ws in $wb.Worksheets) {
    if (-not $resumen.ContainsKey($ws.Name)) { continue }
    $ur = $ws.UsedRange
    $f = $ur.Formula
    $vals = $ur.Value2
    $nr = $f.GetLength(0); $nc = $f.GetLength(1)
    $suma = 0.0; $cnt = 0
    for ($r = 1; $r -le $nr; $r++) {
      for ($c = 1; $c -le $nc; $c++) {
        $s = $f[$r,$c]
        # OJO: -like trata [KEY] como clase de caracteres; usar Contains
        if ($s -is [string] -and $s.Contains("TablaAgg[KEY]")) {
          $v = $vals[$r,$c]
          if ($v -is [double]) { $suma += $v }
          $cnt++
        }
      }
    }
    $ref = $resumen[$ws.Name]
    if (($cnt -ne $ref[0]) -or ([math]::Abs($suma - $ref[1]) -gt 0.02)) {
      $fallas++
      L ("FALLA " + $ws.Name + ": antes " + $ref[0] + " celdas suma " + [math]::Round($ref[1],3) + " | despues " + $cnt + " celdas suma " + [math]::Round($suma,3))
    }
  }
  if ($fallas -eq 0) { L ("VERIFICACION OK: todas las hojas suman identico (tolerancia 0.02)") }
  else { L ("VERIFICACION: " + $fallas + " hojas con diferencia - NO usar este libro") }

  $xl.Calculation = -4105  # automatic
  if ($fallas -eq 0) { $wb.Save(); L "GUARDADO" } else { L "NO GUARDADO (fallas)" }
}
finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
}
