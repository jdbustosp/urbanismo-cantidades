param([string]$libro)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($libro)
foreach ($e in $z.Entries) {
  if ($e.FullName -like "xl/pivotTables/*.xml") {
    $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
    $t = $sr.ReadToEnd(); $sr.Close()
    $nom = "?"
    if ($t -match '<pivotTableDefinition[^>]*\sname="([^"]+)"') { $nom = $Matches[1] }
    "=== " + $e.FullName + "  name=" + $nom
    foreach ($a in @("applyNumberFormats", "applyPatternFormats", "applyBorderFormats", "applyFontFormats", "preserveFormatting")) {
      if ($t -match ($a + '="([^"]*)"')) { "    " + $a + " = " + $Matches[1] } else { "    " + $a + " = (ausente)" }
    }
    if ($t -match '<formats count="(\d+)">([\s\S]*?)</formats>') {
      "    <formats count=" + $Matches[1] + ">"
      $n = 0
      foreach ($m in [regex]::Matches($Matches[2], '<format[\s\S]*?</format>|<format[^>]*/>')) {
        $n++
        if ($n -le 8) { "       " + $m.Value }
      }
      "       (total entradas: $n)"
    } else {
      "    SIN <formats>   <-- se perdieron"
    }
    if ($t -match '<pivotTableStyleInfo[^>]*/>') { "    " + $Matches[0] }
  }
}
$z.Dispose()
