param([string]$destino)
$ErrorActionPreference = "Stop"
$N = [string][char]0xD1
$raiz = "C:\Users\juanbusper\colsubsidio.com\Mi Gerencia Vivienda - COORDINACION DE PRESUPUESTOS\PPTOS directos\URB EXT MAIPORE"
$msg1 = Join-Path $raiz ("TRONCAL MU" + $N + "A\COLECTOR\PPTO COLECTOR AGUAS LLUVIAS MU" + $N + "A.msg")
if (-not (Test-Path -LiteralPath $msg1)) { throw "no existe el .msg" }
if (-not (Test-Path -LiteralPath $destino)) { New-Item -ItemType Directory -Path $destino | Out-Null }
"tamano del .msg: " + [math]::Round((Get-Item -LiteralPath $msg1).Length / 1024) + " KB"
$ol = New-Object -ComObject Outlook.Application
$ns = $ol.GetNamespace("MAPI")
$msg = $ns.OpenSharedItem($msg1)
"adjuntos: " + $msg.Attachments.Count
$idx = 0
for ($i = 1; $i -le $msg.Attachments.Count; $i++) {
  $a = $msg.Attachments.Item($i)
  "   [$i] " + $a.FileName + "  tipo=" + $a.Type
  if ($a.FileName -match "\.xlsx$") { $idx = $i }
}
if ($idx -eq 0) { throw "no hay xlsx adjunto" }
$a = $msg.Attachments.Item($idx)
$ruta = Join-Path $destino $a.FileName
"guardando el adjunto $idx en $ruta"
$a.SaveAsFile($ruta)
"listo: " + [math]::Round((Get-Item -LiteralPath $ruta).Length / 1024) + " KB"
$msg.Close(1)
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($ol) | Out-Null
