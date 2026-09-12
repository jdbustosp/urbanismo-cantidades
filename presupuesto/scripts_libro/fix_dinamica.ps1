param([string]$libro)
$ErrorActionPreference = "Stop"
$ci = [System.Globalization.CultureInfo]::InvariantCulture
function Retry($sb, $n = 10) {
  for ($i = 1; $i -le $n; $i++) {
    try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 }
  }
}
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  "AutoSave apagado"

  # ---------------------------------------------------------------
  # 1) BD_PE: la ETAPA sale del primer digito de la SUBETAPA (el
  #    "if d <= 2 then d + 1" corria la etapa 1 a la 2 y la 2 a la 3),
  #    y la subetapa GEN se llama GENERAL igual que en el ejecutado.
  # ---------------------------------------------------------------
  $q = $wb.Queries.Item("BD_PE")
  $f = $q.Formula
  $viejo = 'Eta = Table.AddColumn(NoCero, "ETAPA", each if [SUBETAPA] = "GEN" then "GENERAL" else let d = Number.From(Text.Start([SUBETAPA],1)) in Text.From(if d <= 2 then d + 1 else d)),'
  $nuevo = 'Sub2 = Table.TransformColumns(NoCero, {{"SUBETAPA", each if _ = "GEN" then "GENERAL" else _}}),' + "`r`n" +
           '  Eta = Table.AddColumn(Sub2, "ETAPA", each if [SUBETAPA] = "GENERAL" then "GENERAL" else Text.From(Number.From(Text.Start([SUBETAPA],1)))),'
  if ($f.Contains($viejo)) {
    $q.Formula = $f.Replace($viejo, $nuevo)
    "BD_PE corregida: ETAPA = primer digito de la SUBETAPA; GEN -> GENERAL"
  } elseif ($f.Contains('Text.From(Number.From(Text.Start([SUBETAPA],1)))')) {
    "BD_PE ya estaba corregida"
  } else {
    throw "No se encontro el paso ETAPA en BD_PE; no se toca nada."
  }

  # ---------------------------------------------------------------
  # 2) refrescar la BD
  # ---------------------------------------------------------------
  $wsBD = Retry { $wb.Worksheets.Item("BD") }
  $lo = $wsBD.ListObjects.Item("BD_CONSOL")
  $lo.QueryTable.BackgroundQuery = $false
  Retry { $lo.QueryTable.Refresh($false) }
  $filas = $lo.ListRows.Count
  "BD_CONSOL refrescada: $filas filas"
  $wb.RefreshAll()
  Start-Sleep -Seconds 3
  $xl.CalculateFullRebuild()
  Start-Sleep -Seconds 2

  # control: etapas y subetapas resultantes
  $arr = $wsBD.Range("A1:M" + ($filas + 1)).Value2
  $pares = @{}
  for ($r = 2; $r -le $filas + 1; $r++) {
    $k = [string]$arr[$r, 13] + " / " + [string]$arr[$r, 7]
    $pares[$k] = 1
  }
  "pares ETAPA_TXT / SUBETAPA despues del arreglo:"
  foreach ($k in ($pares.Keys | Sort-Object)) { "   $k" }

  $wb.Save()
  "guardado (paso 1: BD)"
} finally {
  try { $wb.Close($true) } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
