param([string]$libro, [string]$lista)
# Aplica precios a PRECIOS_UNITARIOS columna D. La lista es un TSV con el
# informe del barrido; se toman las lineas de la seccion "A)" cuyo primer
# campo es un numero de fila y el sexto el precio IDU.
$ErrorActionPreference = "Continue"

$pares = @()
$dentro = $false
foreach ($l in [System.IO.File]::ReadAllLines($lista, [System.Text.Encoding]::UTF8)) {
  if ($l -like "*A) precios alineados*") { $dentro = $true; continue }
  if ($l -like "*B) unidad distinta*") { $dentro = $false }
  if (-not $dentro) { continue }
  $c = $l -split "`t"
  if ($c.Count -lt 7) { continue }
  $fila = 0
  if (-not [int]::TryParse($c[0], [ref]$fila)) { continue }
  $precio = 0.0
  if (-not [double]::TryParse($c[5], [ref]$precio)) { continue }
  if ($fila -lt 2 -or $precio -le 0) { continue }
  $pares += @{ Fila = $fila; Precio = $precio; Desc = $c[1] }
}
"pares a aplicar: " + $pares.Count
if ($pares.Count -eq 0) { throw "no se leyo ninguna linea de la seccion A" }
if ($pares.Count -gt 400) { throw ("son " + $pares.Count + " pares: demasiados, se aborta") }

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$guardado = $false
try {
  $wb = $xl.Workbooks.Open($libro)
  try { $wb.AutoSaveOn = $false } catch {}
  $hoja = $wb.Worksheets.Item("PRECIOS_UNITARIOS")
  $filas = $hoja.UsedRange.Row + $hoja.UsedRange.Rows.Count - 1
  "PRECIOS_UNITARIOS tiene $filas filas"
  if ($filas -lt 1300) { throw "la hoja no esta sana, se aborta" }

  $ok = 0
  $mal = 0
  foreach ($p in $pares) {
    $f = $p.Fila
    $v = $p.Precio
    try {
      $hoja.Cells.Item($f, 4).Value2 = $v
      $leido = $hoja.Cells.Item($f, 4).Value2
      if (($leido -is [double]) -and ([Math]::Abs($leido - $v) -lt 0.01)) { $ok++ }
      else { $mal++; if ($mal -le 5) { "   no coincide f$f : quedo $leido (queria $v)" } }
    } catch {
      $mal++
      if ($mal -le 5) { "   error en f$f : " + $_.Exception.Message }
    }
  }
  "escritos y comprobados: $ok de " + $pares.Count + "   fallidos: $mal"
  if ($ok -eq 0) { throw "no se escribio ningun precio, se aborta sin guardar" }

  $filas2 = $hoja.UsedRange.Row + $hoja.UsedRange.Rows.Count - 1
  if ($filas2 -ne $filas) { throw "cambio el numero de filas, se aborta sin guardar" }
  $wb.Save()
  $guardado = $true
  "GUARDADO"
} finally {
  try { if ($guardado) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  try { $xl.Quit() } catch {}
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
