# Transformador v3 (2026-09-07 tarde, pedidos del usuario):
#  - MT ACUEDUCTO depurado a ESPEJO EXACTO del sanitario + arena de pena:
#    fuera exc manual, exc conglomerado (resaltadas por el usuario),
#    relleno inicial, manejo de aguas y las 3 de demolicion/reposicion
#    (las reparaciones viales viven en ALMA CAFE).
#  - PLUVIAL: tuberias que definitivamente no van -> quedan SOLO
#    NOVAFORT (PVC flexible) 12/14/20/24 (12/14/20 con cantidad, 24 es
#    el diametro por defecto de los tramos TRAT del modelo). Fuera
#    18/27 y TODA la serie en concreto CSR/CCR/CER (nunca modelada).
#  - PLUVIAL POZOS: fuera "Sum e inst cono y tapa" (subconjunto duplicado
#    de "base, cono y tapa") y "Camara en concreto Diam>=36" (ya no hay
#    tuberias >=36 en el capitulo).
# Entrada: pe_nuevo2.tsv  Salida: pe_nuevo3.tsv + pe3_cambios.log
$ErrorActionPreference = "Stop"
$sp = Split-Path -Parent $MyInvocation.MyCommand.Path
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$pe = [System.IO.File]::ReadAllLines((Join-Path $sp "pe_nuevo2.tsv"), [System.Text.Encoding]::UTF8)
$out = New-Object System.Collections.Generic.List[string]
$log = New-Object System.Collections.Generic.List[string]

$mtACU = @(
  "Excavación manual en material común",
  "Excavación en conglomerado",
  "Relleno inicial alrededor de tubería",
  "Manejo y agotamiento de aguas",
  "Demolición de pavimento flexible",
  "Reposición de pavimento flexible y estructura",
  "Demolición y reposición de andén")
$pozosPLU = @(
  "Suministro e instalación cono y tapa para pozo de inspección",
  "Cámara en concreto (Diám.>=36"")")

$n3 = ""; $n4 = ""
foreach ($l in $pe) {
  $f = $l -split "`t"
  $niv = $f[0]; $desc = $f[2]
  if ($niv -eq "3") { $n3 = $desc; $n4 = "" }
  if ($niv -eq "4") { $n4 = $desc }
  $drop = $false
  if ($niv -eq "5") {
    if ($n3 -eq "RED DE ACUEDUCTO" -and $n4 -match '^MOVIMIENTO DE TIERRAS' -and ($mtACU -contains $desc)) {
      $drop = $true
      $log.Add("MT ACUEDUCTO: eliminada '" + $desc + "' (no va; espejo exacto del sanitario)")
    }
    if ($n3 -eq "RED DE ALCANTARILLADO PLUVIAL" -and ($n4 -eq "SUMINISTRO DE TUBERÍAS" -or $n4 -eq "INSTALACIÓN DE TUBERÍAS")) {
      if ($desc -match 'en concreto (CSR|CCR|CER)') {
        $drop = $true
        $log.Add("PLUVIAL tuberias: eliminada '" + $desc + "' (serie en concreto: definitivamente no va, nunca modelada)")
      } elseif ($desc -match 'PVC flexible Ø(18|27)"') {
        $drop = $true
        $log.Add("PLUVIAL tuberias: eliminada '" + $desc + "' (diametro sin uso en el diseno)")
      }
    }
    if ($n3 -eq "RED DE ALCANTARILLADO PLUVIAL" -and $n4 -eq "POZOS DE INSPECCIÓN" -and ($pozosPLU -contains $desc)) {
      $drop = $true
      $log.Add("PLUVIAL pozos: eliminada '" + $desc + "' (duplicada/sin tuberias de ese porte)")
    }
  }
  if (-not $drop) { $out.Add($l) }
}
[System.IO.File]::WriteAllLines((Join-Path $sp "pe_nuevo3.tsv"), $out, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllLines((Join-Path $sp "pe3_cambios.log"), $log, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("filas: " + $out.Count + " (antes " + $pe.Count + ", eliminadas " + ($pe.Count - $out.Count) + ")")
foreach ($x in $log) { Write-Output ("  - " + $x) }