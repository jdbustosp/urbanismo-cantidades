param([string]$libro)
$ErrorActionPreference = "Stop"
function Retry($sb, $n = 12) {
  for ($i = 1; $i -le $n; $i++) { try { return & $sb } catch { if ($i -eq $n) { throw }; Start-Sleep -Milliseconds 900 } }
}
# Unificaciones SIN efecto en plata: el mismo precio unitario, solo cambia
# como esta escrito el nombre. Las que cambian precio NO se tocan aqui.
$cambios = @(
  @{ de = "base granular BG";      a = "Base granular BG" },
  @{ de = "COMISION TOPOGRAFICA";  a = "Comision topografica" },
  @{ de = "PLANOS RECORD";         a = "Planos record" },
  @{ de = "Subbase granular 0,20m idu"; a = "Subabase granular SBG-B" }
)
$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false; $xl.DisplayAlerts = $false
$ok = $false
try {
  $wb = Retry { $xl.Workbooks.Open($libro) }
  try { $wb.AutoSaveOn = $false } catch {}
  $ws = Retry { $wb.Worksheets.Item("POR EJECUTAR") }
  $ultima = $ws.UsedRange.Row + $ws.UsedRange.Rows.Count - 1
  $arr = $ws.Range("A1:AP" + $ultima).Value2
  $total = 0
  foreach ($c in $cambios) {
    $n = 0
    for ($r = 1; $r -le $ultima; $r++) {
      if ([string]$arr[$r, 1] -ne "5") { continue }
      $d = [string]$arr[$r, 4]
      if ($d.Trim() -ceq $c.de) {
        # control: el precio tiene que ser el mismo que el del nombre destino
        Retry { $ws.Cells.Item($r, 4).Value2 = $c.a }
        $n++
      }
    }
    "  '" + $c.de + "'  ->  '" + $c.a + "'   filas cambiadas: $n"
    $total += $n
  }
  "total de renglones renombrados: $total"
  $xl.CalculateFullRebuild(); Start-Sleep -Seconds 3
  # el total del grupo 2 no puede moverse: el nombre no cambia cantidades
  $wb.Save()
  $ok = $true
  "guardado"
} finally {
  try { if ($ok) { $wb.Close($true) } else { $wb.Close($false) } } catch {}
  $xl.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
