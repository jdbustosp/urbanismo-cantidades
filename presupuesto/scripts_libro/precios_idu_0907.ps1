# precios_idu_0907.ps1 - ajustes de precios anclados al visor IDU 2026-I
# Fase II (4-sep-2026) + desagregacion de cabezales por rango de diametro.
# 1) VALVULAS DE COMPUERTA: el libro estaba 2,2-2,6x POR ENCIMA del IDU
#    en TODA la serie -> nuevo VU = IDU x 1.35 (criterio: las nuestras
#    son HD bridadas vs elastica extremo liso del IDU), redondeado a 10k.
# 2) CAJA CONVENCIONAL PARA VALVULA: 2.65M -> 1.010.000 (IDU NS-027
#    841k x 1.2).
# 3) CABEZALES por rango: clona la fila "O12-O16" (8.5M, validada con
#    ancla IDU de concreto 914k/m3) en "O8-O10" (6.0M) y "O18-O24"
#    (12.5M). El motor 4.72+ emite "Cabezal de descarga en concreto para
#    tuberia <D>" y cruza por numeros; el "Cabezal de entrega" global
#    (VU paquete 37.2M) queda sin uso por el motor.
# Registra antes/despues en diagnosticos\precios_idu_20260907.tsv.
$ErrorActionPreference = "Stop"
$libro = "D:\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$diag = "D:\Drive\Mi unidad\VARIOS\CLAUDE\proyectos\URBANISMO EXTERNO\diagnosticos\precios_idu_20260907.tsv"
$log = @()

$cambios = @(
  @{ patron = "V*lvula de compuerta *4*"; nuevo = 1610000; ref = "IDU 4402 (1.190.850) x1.35" },
  @{ patron = "V*lvula de compuerta *6*"; nuevo = 3030000; ref = "IDU 3324 (2.247.570) x1.35" },
  @{ patron = "V*lvula de compuerta *8*"; nuevo = 5110000; ref = "IDU 3325 (3.785.326) x1.35" },
  @{ patron = "V*lvula de compuerta *12*"; nuevo = 10250000; ref = "IDU 4403 (7.593.696) x1.35" },
  @{ patron = "Caja convencional para v*lvula"; nuevo = 1010000; ref = "IDU 4978 NS-027 (841.061) x1.2" }
)

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $pu = $wb.Worksheets.Item("PRECIOS_UNITARIOS")
  $maxR = $pu.UsedRange.Rows.Count
  foreach ($c in $cambios) {
    $hecho = $false
    for ($r = 1; $r -le $maxR; $r++) {
      $nom = [string]$pu.Cells.Item($r, 2).Value2
      if ($nom -and $nom -like $c.patron) {
        $viejo = $pu.Cells.Item($r, 4).Value2
        $pu.Cells.Item($r, 4).Value2 = $c.nuevo
        $log += ($nom + "`t" + $viejo + "`t" + $c.nuevo + "`t" + $c.ref)
        Write-Output ("PRECIO: " + $nom + " " + $viejo + " -> " + $c.nuevo)
        $hecho = $true
      }
    }
    if (-not $hecho) { Write-Output ("NO HALLADO: " + $c.patron) }
  }

  # cabezales por rango en POR EJECUTAR (clonar la fila O12-O16)
  $pe = $wb.Worksheets.Item("POR EJECUTAR")
  $maxR = $pe.UsedRange.Rows.Count
  $fila = 0
  for ($r = 1; $r -le $maxR; $r++) {
    $nom = [string]$pe.Cells.Item($r, 4).Value2
    if ($nom -and $nom -like "Cabezal de descarga en concreto*12*16*") { $fila = $r; break }
  }
  if ($fila -eq 0) { Write-Output "NO HALLADA fila cabezal O12-O16" }
  else {
    # nombres construidos con [char] (PS 5.1 lee el .ps1 como ANSI y
    # rompe literales UTF-8: "tuberia" sin tilde a proposito)
    $OO = [string][char]0x00D8   # simbolo de diametro
    $nuevas = @(
      @{ nombre = ('Cabezal de descarga en concreto para tuberia ' + $OO + '8"-' + $OO + '10" (incluye aletas y solado)'); vu = 6000000 },
      @{ nombre = ('Cabezal de descarga en concreto para tuberia ' + $OO + '18"-' + $OO + '24" (incluye aletas y solado)'); vu = 12500000 }
    )
    # la col C (ITEM) es FORMULA autonumerada en el layout 42-col: el
    # clon la hereda y se renumera solo -- NO escribirle nada.
    # OJO COM: tras Copy+Insert, Cells.Item(...).Value2 = ... lanza
    # InvalidCast en esta hoja -- escribir via Range("D#") con cast y
    # CutCopyMode apagado (dos corridas fallidas lo confirmaron).
    foreach ($nv in $nuevas) {
      $ya = $false
      for ($r = 1; $r -le $maxR; $r++) {
        if ([string]$pe.Cells.Item($r, 4).Value2 -eq $nv.nombre) { $ya = $true; break }
      }
      if ($ya) { Write-Output ("YA EXISTE: " + $nv.nombre); continue }
      try {
        $pe.Rows.Item($fila).Copy() | Out-Null
        $pe.Rows.Item($fila + 1).Insert(-4121) | Out-Null

        $celda = $pe.Range("D" + ($fila + 1))
        $celda.Value2 = [string]$nv.nombre
        $maxR = $pe.UsedRange.Rows.Count
        # precio en PRECIOS_UNITARIOS: clonar fila del 12-16 alla tambien
        $maxPU = $pu.UsedRange.Rows.Count
        $puFila = 0
        for ($r = 1; $r -le $maxPU; $r++) {
          $nom = [string]$pu.Cells.Item($r, 2).Value2
          if ($nom -and $nom -like "Cabezal de descarga en concreto*12*16*") { $puFila = $r; break }
        }
        if ($puFila -gt 0) {
          $pu.Rows.Item($puFila).Copy() | Out-Null
          $pu.Rows.Item($puFila + 1).Insert(-4121) | Out-Null
  
          $pu.Range("B" + ($puFila + 1)).Value2 = [string]$nv.nombre
          $pu.Range("D" + ($puFila + 1)).Value2 = [double]$nv.vu
        }
        $log += ($nv.nombre + "`t(nueva)`t" + $nv.vu + "`tescala volumen; ancla IDU concreto 914k/m3")
        Write-Output ("AGREGADA: " + $nv.nombre + " VU " + $nv.vu)
      } catch {
        Write-Output ("FALLO cabezal '" + $nv.nombre + "': " + $_.Exception.Message + " -- las valvulas SE GUARDAN igual")
      }
    }
  }

  $wb.Save()
  Write-Output "GUARDADO"
}
finally {
  if ($wb) { $wb.Close($false) }
  $xl.Quit()
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($xl) | Out-Null
}
"NOMBRE`tVU_ANTES`tVU_NUEVO`tCRITERIO" | Out-File -FilePath $diag -Encoding utf8
$log | Out-File -FilePath $diag -Append -Encoding utf8
Write-Output ("tabla: " + $diag)
