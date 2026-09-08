# OPCIONAL - NO SE HA CORRIDO (espera decision del usuario, 2026-09-08)
#
# Al pasar los indirectos a BASE VIVA quedo a la vista que la cobertura
# por etapa esta incompleta:
#   * NINGUNO de los 6 capitulos tiene fila para la ETAPA 06 (base viva
#     1.691.950.010) aunque el titulo dice "ET 1 a 9";
#   * PGU y PMT no tienen fila GENERAL, y hoy el 59% del costo directo
#     esta en la subetapa GEN (85.426.423.858) -> se les escapa entera.
#
# Si el usuario dice que SI, este script agrega las filas que faltan con
# el mismo patron (UM=%, cantidad=% del capitulo, VU=subtotal vivo de
# esa etapa) y deja los porcentajes de cada capitulo.
#
# EFECTO EN PLATA (calculado con las bases vivas de hoy):
#   ETAPA 06 en los 6 capitulos ... +185.268.526
#   GENERAL en PGU ................ +170.852.848
#   GENERAL en PMT ................ +427.132.119
#   TOTAL ......................... +783.253.493
#
# Uso:  & agregar_etapa06_general.ps1
$ErrorActionPreference = "Stop"
$libro = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE\0. GENERAL\260915_ACTUALIZACION GENERAL PPTO\urbanismo maipore.xlsx"
$bkdir = "C:\Users\juanbusper\Streaming de Google Drive\Mi unidad\TRABAJO\COLSUBSIDIO\URBANISMO MAIPORE\MEMORIAS\V3\PROYECTO_URBANISMO_GENERAL\BACKUPS"
$bk = Join-Path $bkdir ("urbanismo maipore_backup_antes_etapa06_" + (Get-Date -Format "yyyyMMdd_HHmm") + ".xlsx")
Copy-Item $libro $bk
Write-Output ("backup: " + $bk)

# capitulo -> @{ patron de fila hermana ; texto de la fila nueva ; agregar GENERAL? }
$capitulos = @(
  @{ pat = '^PLAN DE GESTION URBANA \(PGU\) ETAPA'; base = 'PLAN DE GESTION URBANA (PGU) '; general = $true },
  @{ pat = '^COSTOS GESTION AMBIENTAL \(CAR\) ETAPA'; base = 'COSTOS GESTION AMBIENTAL (CAR) '; general = $false },
  @{ pat = '^PMT - ETAPA'; base = 'PMT - '; general = $true },
  @{ pat = '^ADMIN DELEGAD \+ HON \+ REEMB ETAPA'; base = 'ADMIN DELEGAD + HON + REEMB '; general = $false },
  @{ pat = '^INTERVENTORIA \+ HON \+ REEMB ETAPA'; base = 'INTERVENTORIA + HON + REEMB '; general = $false },
  @{ pat = '^ESTUDIOS Y DISE.OS ETAPA'; base = 'ESTUDIOS Y DISEÑOS '; general = $false }
)
function Retry([scriptblock]$__sb) {
  for ($t = 1; $t -le 5; $t++) {
    try { & $__sb; return } catch { if ($t -eq 5) { throw }; Start-Sleep -Milliseconds (400 * $t) }
  }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$wb = $null; $ok = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $xl.Calculation = -4135
  $ws = $wb.Worksheets.Item("POR EJECUTAR")
  $agregadas = 0
  foreach ($cap in $capitulos) {
    # (re)localizar cada vez: las inserciones corren las filas
    $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
    $de = $ws.Range("D3:D$last").Value2
    $r05 = 0; $rUlt = 0; $tieneGeneral = $false; $tiene06 = $false
    for ($i = 1; $i -le $de.GetLength(0); $i++) {
      $d = [string]$de[$i,1]
      if ($d -match $cap.pat) {
        $rUlt = $i + 2
        if ($d -match 'ETAPA 05') { $r05 = $i + 2 }
        if ($d -match 'ETAPA 06') { $tiene06 = $true }
      }
      if ($d -eq ($cap.base + "GENERAL")) { $tieneGeneral = $true; $rUlt = $i + 2 }
    }
    if ($r05 -eq 0) { Write-Output ("  OJO no encontre ETAPA 05 de " + $cap.base); continue }
    $pct = $ws.Cells.Item($r05, 40).Value2      # el % del capitulo
    # --- ETAPA 06 ---
    if (-not $tiene06) {
      Retry { $ws.Rows(($r05 + 1).ToString()).Insert(-4121, 0) | Out-Null }
      $r = $r05 + 1
      Retry { $ws.Cells.Item($r, 1).Value2 = 5.0 }
      Retry { $ws.Cells.Item($r, 4).Value2 = ($cap.base + "ETAPA 06") }
      Retry { $ws.Cells.Item($r, 5).Value2 = "%" }
      Retry { $ws.Cells.Item($r, 26).Value2 = $pct }
      Retry { $ws.Cells.Item($r, 40).Formula = '=SUM($F' + $r + ':$AM' + $r + ')' }
      Retry { $ws.Cells.Item($r, 42).Formula = "=AN$r*AO$r" }
      Retry { $ws.Rows($r.ToString()).OutlineLevel = 5 }
      $agregadas++
      Write-Output ("  + " + $cap.base + "ETAPA 06 (fila " + $r + ", " + $pct + ")")
    }
    # --- GENERAL ---
    if ($cap.general -and -not $tieneGeneral) {
      $last = $ws.Cells.Item($ws.Rows.Count, 4).End(-4162).Row
      $de2 = $ws.Range("D3:D$last").Value2
      $rUlt = 0
      for ($i = 1; $i -le $de2.GetLength(0); $i++) { if ([string]$de2[$i,1] -match $cap.pat) { $rUlt = $i + 2 } }
      Retry { $ws.Rows(($rUlt + 1).ToString()).Insert(-4121, 0) | Out-Null }
      $r = $rUlt + 1
      Retry { $ws.Cells.Item($r, 1).Value2 = 5.0 }
      Retry { $ws.Cells.Item($r, 4).Value2 = ($cap.base + "GENERAL") }
      Retry { $ws.Cells.Item($r, 5).Value2 = "%" }
      Retry { $ws.Cells.Item($r, 39).Value2 = $pct }
      Retry { $ws.Cells.Item($r, 40).Formula = '=SUM($F' + $r + ':$AM' + $r + ')' }
      Retry { $ws.Cells.Item($r, 42).Formula = "=AN$r*AO$r" }
      Retry { $ws.Rows($r.ToString()).OutlineLevel = 5 }
      $agregadas++
      Write-Output ("  + " + $cap.base + "GENERAL (fila " + $r + ", " + $pct + ")")
    }
  }
  Write-Output ("filas agregadas: " + $agregadas)
  $xl.Calculation = -4105
  try { $xl.CalculateFull() } catch {}
  Retry { $wb.Save() }
  $ok = $true
  Write-Output "GUARDADO. AHORA correr ajustar_porcentajes.ps1 (pone el VU vivo en las filas nuevas) y dinamica_formatos.ps1."
} finally {
  if ($wb) { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } }
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}