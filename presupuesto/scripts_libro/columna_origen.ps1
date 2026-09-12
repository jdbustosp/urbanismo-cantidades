param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
function Norm([string]$s) {
  if (-not $s) { return "" }
  $t = $s.ToLowerInvariant().Trim().Normalize([Text.NormalizationForm]::FormD)
  $sb2 = New-Object System.Text.StringBuilder
  foreach ($ch in $t.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$sb2.Append($ch)
    }
  }
  $t = $sb2.ToString() -replace '[^a-z0-9]+', ' '
  ($t -replace '\s+', ' ').Trim()
}
$N = [string][char]0xD1
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$ok = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}

  # ---- lo que SI viene de AutoCAD: esta en la tabla de memorias ----
  $wm = Retry { $wb.Worksheets.Item("MEMORIAS") }
  $nm = $wm.UsedRange.Row + $wm.UsedRange.Rows.Count - 1
  $am = $wm.Range("A1:L" + $nm).Value2
  $deCad = @{}
  for ($r = 2; $r -le $nm; $r++) {
    $k = Norm ([string]$am[$r, 3])     # ESPECIFICACION
    if ($k -ne "") { $deCad[$k] = 1 }
  }
  "actividades distintas en las memorias de AutoCAD: " + $deCad.Count

  $ws = Retry { $wb.Worksheets.Item("POR EJECUTAR") }
  $ultima = $ws.UsedRange.Row + $ws.UsedRange.Rows.Count - 1
  $arr = $ws.Range("A1:AP" + $ultima).Value2

  # PE_RANGO llega hasta AP, asi que la columna AQ (43) queda FUERA de la
  # consulta BD_PE: se puede agregar sin tocar ninguna query.
  $COL = 43
  Retry { $ws.Cells.Item(1, $COL).Value2 = "ORIGEN" }
  Retry { $ws.Cells.Item(2, $COL).Value2 = "ORIGEN" }
  Retry { $ws.Range($ws.Cells.Item(1, $COL), $ws.Cells.Item(2, $COL)).Font.Bold = $true }

  $cuenta = @{}
  $valores = New-Object 'object[,]' ($ultima - 2), 1
  for ($r = 3; $r -le $ultima; $r++) {
    $niv = [string]$arr[$r, 1]
    $item = ([string]$arr[$r, 3]).Trim()
    $desc = ([string]$arr[$r, 4]).Trim()
    $um = ([string]$arr[$r, 5]).Trim()
    $o = ""
    if ($niv -ne "5") {
      $o = ""
    } elseif ($item -like "2.3.*") {
      $o = "EXTERNO: PARQUES DE EQUIPAMIENTOS"
    } elseif ($item -like "2.9.1.*") {
      $o = "EXTERNO: TRONCAL MU" + $N + "A"
    } elseif ($item -like "2.9.2.*") {
      $o = "EXTERNO: CABEZAL DE DESCARGA MU" + $N + "A"
    } elseif ($um -eq "%") {
      $o = "PORCENTAJE (se calcula)"
    } elseif ($deCad.ContainsKey((Norm $desc))) {
      $o = "AUTOCAD"
    } else {
      $o = "MANUAL"
    }
    $valores[($r - 3), 0] = $o
    if ($o -ne "") {
      if (-not $cuenta.ContainsKey($o)) { $cuenta[$o] = 0 }
      $cuenta[$o]++
    }
  }
  # se escribe columna completa de una vez con un rango de una sola columna
  $dest = $ws.Range($ws.Cells.Item(3, $COL), $ws.Cells.Item($ultima, $COL))
  Retry { $dest.Value2 = $valores }
  Retry { $ws.Columns.Item($COL).ColumnWidth = 34 }
  "reparto de ORIGEN (solo nivel 5):"
  foreach ($k in ($cuenta.Keys | Sort-Object)) { "   " + $k + " -> " + $cuenta[$k] }

  # control: PE_RANGO sigue llegando solo hasta AP
  "PE_RANGO = " + $wb.Names.Item("PE_RANGO").RefersTo
  $wb.Save()
  $ok = $true
  "guardado"
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
