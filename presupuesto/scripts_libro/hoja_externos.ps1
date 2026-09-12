param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
$N = [string][char]0xD1          # N con virgulilla
$raiz = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE"

# bloques: titulo, capitulo del libro que alimenta, archivo, hoja del ppto, hoja de memorias
$bloques = @(
  [pscustomobject]@{
    Titulo   = "1. PARQUES DE EQUIPAMIENTOS"
    Capitulo = "2.3 EQUIPAMIENTOS (PARQUES-SENDEROS PEATONALES Y PUENTES)"
    Archivo  = (Join-Path $raiz "PARQUES\Ajustes parques\250310_ppto\20250310- PPTO ADECUACIONES.xlsx")
    Ppto     = "PPTO DETALLADO"
    Memorias = "MEMORIAS"
  },
  [pscustomobject]@{
    Titulo   = "2. TRONCAL MU" + $N + "A"
    Capitulo = "2.9.1 TRONCAL MU" + $N + "A"
    Archivo  = (Join-Path $raiz ("TRONCAL MU" + $N + "A\Presupuesto Troncal Mu" + $N + "a.xlsx"))
    Ppto     = "TRONCAL MU" + $N + "A"
    Memorias = "MEMORIAS"
  },
  [pscustomobject]@{
    Titulo   = "3. CABEZAL DE DESCARGA / COLECTOR MU" + $N + "A"
    Capitulo = "2.9.2 CABEZAL DE DESCARGA"
    Archivo  = (Join-Path $env:TEMP "claude\C--Users-juanbusper-Streaming-de-Google-Drive-Mi-unidad-VARIOS-CLAUDE-proyectos-URBANISMO-EXTERNO\175b61ea-fdaa-4fe5-b13d-06d3533f410a\scratchpad\externos\251112-CABEZAL DESCARGA MAIPORE-F3-V1.xlsx")
    Ppto     = ""
    Memorias = ""
  }
)

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$xl.ScreenUpdating = $false
$ok = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $nombreHoja = "PPTOS EXTERNOS"
  $ws = $null
  for ($k = 1; $k -le $wb.Worksheets.Count; $k++) {
    if ($wb.Worksheets.Item($k).Name -eq $nombreHoja) { $ws = $wb.Worksheets.Item($k) }
  }
  if ($ws) {
    Retry { $ws.Cells.Clear() | Out-Null }
    "hoja existente reutilizada"
  } else {
    $wsPE = $wb.Worksheets.Item("POR EJECUTAR")
    $ws = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $wsPE)
    Retry { $ws.Name = $nombreHoja }
    "hoja creada: $nombreHoja"
  }

  $fila = 1
  Retry { $ws.Cells.Item($fila, 1).Value2 = "PRESUPUESTOS EXTERNOS - de donde vienen las cantidades que NO salen de AutoCAD" }
  Retry { $ws.Cells.Item($fila, 1).Font.Size = 14 }
  Retry { $ws.Cells.Item($fila, 1).Font.Bold = $true }
  $fila += 1
  Retry { $ws.Cells.Item($fila, 1).Value2 = ("Armada el " + (Get-Date).ToString("yyyy-MM-dd HH:mm") + ". Cada bloque trae el presupuesto del tercero y sus memorias, tal como llegaron.") }
  $fila += 2
  $filaIndice = $fila
  Retry { $ws.Cells.Item($fila, 1).Value2 = "INDICE" }
  Retry { $ws.Cells.Item($fila, 1).Font.Bold = $true }
  $fila += ($bloques.Count + 2)

  $indice = @()
  foreach ($b in $bloques) {
    $inicio = $fila
    # ---- banda del bloque ----
    Retry { $ws.Cells.Item($fila, 1).Value2 = $b.Titulo }
    Retry { $ws.Range($ws.Cells.Item($fila, 1), $ws.Cells.Item($fila, 12)).Interior.Color = 8421504 }
    Retry { $ws.Cells.Item($fila, 1).Font.Bold = $true }
    Retry { $ws.Cells.Item($fila, 1).Font.Color = 16777215 }
    $fila += 1
    Retry { $ws.Cells.Item($fila, 1).Value2 = "Alimenta el capitulo:" }
    Retry { $ws.Cells.Item($fila, 2).Value2 = $b.Capitulo }
    Retry { $ws.Cells.Item($fila, 1).Font.Bold = $true }
    $fila += 1
    Retry { $ws.Cells.Item($fila, 1).Value2 = "Archivo fuente:" }
    Retry { $ws.Cells.Item($fila, 2).Value2 = $b.Archivo }
    Retry { $ws.Cells.Item($fila, 1).Font.Bold = $true }
    $fila += 1

    if (-not (Test-Path -LiteralPath $b.Archivo)) {
      Retry { $ws.Cells.Item($fila, 1).Value2 = "PENDIENTE: el archivo no esta en disco. Guardar el adjunto del correo en la carpeta del COLECTOR y volver a correr este script." }
      Retry { $ws.Cells.Item($fila, 1).Font.Italic = $true }
      Retry { $ws.Cells.Item($fila, 1).Font.Color = 255 }
      $fila += 3
      $indice += [pscustomobject]@{ Titulo = $b.Titulo; Fila = $inicio; Estado = "PENDIENTE (falta el archivo)" }
      continue
    }

    $wbe = Retry { $xl.Workbooks.Open($b.Archivo, 0, $true) }
    try { $wbe.AutoSaveOn = $false } catch {}
    $detalle = ""
    foreach ($par in @(@("PRESUPUESTO", $b.Ppto), @("MEMORIAS", $b.Memorias))) {
      $etiqueta = $par[0]; $hoja = $par[1]
      if ($hoja -eq "") { continue }
      $we = $null
      for ($k = 1; $k -le $wbe.Worksheets.Count; $k++) {
        if ($wbe.Worksheets.Item($k).Name -eq $hoja) { $we = $wbe.Worksheets.Item($k) }
      }
      if (-not $we) {
        Retry { $ws.Cells.Item($fila, 1).Value2 = ($etiqueta + ": no se encontro la hoja '" + $hoja + "'") }
        $fila += 2
        continue
      }
      $ur = $we.UsedRange
      $nf = $ur.Rows.Count
      $nc = $ur.Columns.Count
      $f0 = $ur.Row
      $c0 = $ur.Column
      Retry { $ws.Cells.Item($fila, 1).Value2 = ($etiqueta + " - hoja '" + $hoja + "' (" + $nf + " filas x " + $nc + " columnas, desde " + $ur.Address() + ")") }
      Retry { $ws.Range($ws.Cells.Item($fila, 1), $ws.Cells.Item($fila, 12)).Interior.Color = 10092543 }
      Retry { $ws.Cells.Item($fila, 1).Font.Bold = $true }
      $fila += 1
      # Se copia el rango y se pega SOLO valores y formatos: asignar el
      # arreglo 2D a Value2 por COM lo rechaza PowerShell (intenta convertir
      # Object[,] a String), y pegar las formulas dejaria vinculos al
      # archivo del tercero.
      $dest = $ws.Cells.Item($fila, 1)
      Retry { $ur.Copy() | Out-Null }
      Retry { $dest.PasteSpecial(-4163) | Out-Null }   # xlPasteValues
      Retry { $dest.PasteSpecial(-4122) | Out-Null }   # xlPasteFormats
      # el interop tipado no acepta CutCopyMode = 0; no es critico limpiarlo
      try { $xl.CutCopyMode = 0 } catch {}
      $fila += $nf
      $detalle += ($etiqueta + " " + $nf + "f; ")
      $fila += 1
    }
    $wbe.Close($false)
    $fila += 1
    $indice += [pscustomobject]@{ Titulo = $b.Titulo; Fila = $inicio; Estado = $detalle }
    "  bloque listo: " + $b.Titulo + " (fila " + $inicio + ") " + $detalle
  }

  # ---- indice ----
  $f = $filaIndice + 1
  foreach ($i in $indice) {
    Retry { $ws.Cells.Item($f, 1).Value2 = $i.Titulo }
    Retry { $ws.Cells.Item($f, 2).Value2 = ("fila " + $i.Fila) }
    Retry { $ws.Cells.Item($f, 3).Value2 = $i.Estado }
    $f += 1
  }
  Retry { $ws.Columns.Item(1).ColumnWidth = 52 }
  Retry { $ws.Columns.Item(2).ColumnWidth = 60 }
  Retry { $ws.Columns.Item(3).ColumnWidth = 40 }
  Retry { $ws.Rows.Item(1).RowHeight = 20 }
  "filas usadas: " + $ws.UsedRange.Address()
  $wb.Save()
  $ok = $true
  "guardado"
} finally {
  $xl.ScreenUpdating = $true
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
