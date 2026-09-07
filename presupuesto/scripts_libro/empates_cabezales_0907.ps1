# empates_cabezales_0907.ps1 - remate de la ronda IDU/plano 2026-09-07:
# 1) POR EJECUTAR: borra las 2 filas DUPLICADAS del cabezal O12-O16 con
#    cantidad 0 (residuo de la corrida v3 de precios_idu_0907: el catch
#    atrapo la excepcion de CutCopyMode DESPUES del Copy+Insert y el
#    Save igual corrio -> quedaron 2 copias sin renombrar). La fila
#    buena (cant=66) no se toca.
# 2) Pone la tilde a "tuberia" en las 2 filas nuevas de rango (cosmetico,
#    el match normaliza tildes de todas formas).
# 3) URB_EQUIVALENCIAS: siembra las claves de EMPATE para que los 8
#    accesorios del plano con anotacion EMPATE (tras TIPOFIX en el
#    modelo) caigan DETERMINISTA a su fila: "empate en tee 6 6" es
#    ambigua por score (la fila O8xO6 tambien contiene {empate,tee,6})
#    y las de red existente se siembran por determinismo.
$ErrorActionPreference = "Stop"
$libro = "D:\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$bk = "D:\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\BACKUPS\urbanismo maipore_backup_antes_empates_20260907.xlsx"
Copy-Item $libro $bk -Force
Write-Output ("backup: " + $bk)

$OO = [string][char]0x00D8   # O de diametro
$XX = [string][char]0x00D7   # signo por
$II = [string][char]0x00ED   # i con tilde

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}

  # --- 1) duplicadas de cabezal con cant 0 ---
  $pe = $wb.Worksheets.Item("POR EJECUTAR")
  $maxR = $pe.UsedRange.Rows.Count
  $nombreDup = "Cabezal de descarga en concreto para tuber" + $II + "a " + $OO + "12`"-" + $OO + "16`" (incluye aletas y solado)"
  $victimas = @()
  for ($r = 1; $r -le $maxR; $r++) {
    $nom = [string]$pe.Cells.Item($r, 4).Value2
    if ($nom -eq $nombreDup) {
      $cant = $pe.Cells.Item($r, 40).Value2   # col AN = CANT
      if ($cant -eq $null -or $cant -eq 0) { $victimas += $r }
      else { Write-Output ("conservo fila " + $r + " (cant " + $cant + ")") }
    }
  }
  [array]::Reverse($victimas)
  foreach ($r in $victimas) {
    $pe.Rows.Item($r).EntireRow.Delete() | Out-Null
    Write-Output ("borrada fila duplicada " + $r)
  }

  # --- 2) tilde en las filas nuevas de rango ---
  $maxR = $pe.UsedRange.Rows.Count
  for ($r = 1; $r -le $maxR; $r++) {
    $nom = [string]$pe.Cells.Item($r, 4).Value2
    if ($nom -and $nom.StartsWith("Cabezal de descarga en concreto para tuberia ")) {
      $nuevo = $nom.Replace("para tuberia ", "para tuber" + $II + "a ")
      $pe.Range("D" + $r).Value2 = [string]$nuevo
      Write-Output ("tildada: " + $nuevo)
    }
  }
  $pu = $wb.Worksheets.Item("PRECIOS_UNITARIOS")
  $maxR = $pu.UsedRange.Rows.Count
  for ($r = 1; $r -le $maxR; $r++) {
    $nom = [string]$pu.Cells.Item($r, 2).Value2
    if ($nom -and $nom.StartsWith("Cabezal de descarga en concreto para tuberia ")) {
      $nuevo = $nom.Replace("para tuberia ", "para tuber" + $II + "a ")
      $pu.Range("B" + $r).Value2 = [string]$nuevo
      Write-Output ("tildada PU: " + $nuevo)
    }
  }

  # --- 3) equivalencias de empate ---
  $eq = $wb.Worksheets.Item("URB_EQUIVALENCIAS")
  $filaEmpRed4 = "Empate a red existente " + $OO + "4`""
  $filaEmpRed12 = "Empate a red existente " + $OO + "12`""
  $filaEmpTee = "Empate en tee " + $OO + "6`" " + $XX + " " + $OO + "6`""
  $nuevas = @(
    @{ k = "ACUEDUCTO|empate a red existente 4"; v = $filaEmpRed4 },
    @{ k = "ACUEDUCTO|empate a red existente 12"; v = $filaEmpRed12 },
    @{ k = "ACUEDUCTO|empate en tee 6 6"; v = $filaEmpTee }
  )
  $maxE = $eq.UsedRange.Rows.Count
  $exist = @{}
  for ($r = 1; $r -le $maxE; $r++) {
    $k = [string]$eq.Cells.Item($r, 1).Value2
    if ($k) { $exist[$k] = $true }
  }
  $sig = $maxE + 1
  foreach ($nv in $nuevas) {
    if ($exist.ContainsKey($nv.k)) { Write-Output ("ya existe: " + $nv.k); continue }
    $eq.Range("A" + $sig).Value2 = [string]$nv.k
    $eq.Range("B" + $sig).Value2 = [string]$nv.v
    Write-Output ("equivalencia: " + $nv.k + " -> " + $nv.v)
    $sig++
  }

  $wb.Save()
  Write-Output "GUARDADO"
}
finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
}
