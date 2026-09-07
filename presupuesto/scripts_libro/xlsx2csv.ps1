# Extrae una hoja de un xlsx/xlsm a CSV (tab-separated) sin abrir Excel.
# Uso: xlsx2csv.ps1 -file libro.xlsx -sheet "POR EJECUTAR" -out hoja.tsv [-maxCol 30]
param(
  [Parameter(Mandatory=$true)][string]$file,
  [Parameter(Mandatory=$true)][string]$sheet,
  [Parameter(Mandatory=$true)][string]$out,
  [int]$maxCol = 40
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function ColIndex([string]$ref) {
  $letters = ($ref -replace '\d','')
  $n = 0
  foreach ($ch in $letters.ToCharArray()) { $n = $n * 26 + ([int]$ch - 64) }
  return $n
}

$zip = [System.IO.Compression.ZipFile]::OpenRead($file)
try {
  # 1) resolver sheet name -> archivo sheetN.xml via workbook + rels
  $sr = New-Object System.IO.StreamReader($zip.GetEntry("xl/workbook.xml").Open())
  $wb = [xml]$sr.ReadToEnd(); $sr.Close()
  $sr = New-Object System.IO.StreamReader($zip.GetEntry("xl/_rels/workbook.xml.rels").Open())
  $rels = [xml]$sr.ReadToEnd(); $sr.Close()
  $sh = $wb.workbook.sheets.sheet | Where-Object { $_.name -eq $sheet }
  if (-not $sh) { throw "hoja no encontrada: $sheet" }
  $rid = $sh.GetAttribute("r:id")
  $target = ($rels.Relationships.Relationship | Where-Object { $_.Id -eq $rid }).Target
  if ($target -notlike "xl/*") { $target = "xl/" + $target }
  $target = $target -replace '/\./','/'

  # 2) sharedStrings
  $ss = @()
  $ssEntry = $zip.GetEntry("xl/sharedStrings.xml")
  if ($ssEntry) {
    $sr = New-Object System.IO.StreamReader($ssEntry.Open())
    $ssx = [xml]$sr.ReadToEnd(); $sr.Close()
    foreach ($si in $ssx.sst.si) {
      if ($si.t -ne $null -and $si.t -isnot [System.Xml.XmlElement]) { $ss += [string]$si.t }
      elseif ($si.t -is [System.Xml.XmlElement]) { $ss += [string]$si.t.'#text' }
      else {
        $txt = ""
        foreach ($r in $si.r) { $txt += [string]$r.t }
        $ss += $txt
      }
    }
  }

  # 3) hoja -> filas
  $sr = New-Object System.IO.StreamReader($zip.GetEntry($target).Open())
  $sx = [xml]$sr.ReadToEnd(); $sr.Close()
  $prot = $sx.worksheet.sheetProtection
  if ($prot) {
    Write-Output ("PROTECCION: sheet={0} objects={1} formatCells={2} formatColumns={3} insertRows={4}" -f `
      $prot.sheet, $prot.objects, $prot.formatCells, $prot.formatColumns, $prot.insertRows)
  }
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($row in $sx.worksheet.sheetData.row) {
    $vals = @("") * $maxCol
    foreach ($c in $row.c) {
      $ci = ColIndex $c.r
      if ($ci -gt $maxCol) { continue }
      $v = ""
      if ($c.t -eq "s") { $idx = [int]$c.v; if ($idx -lt $ss.Count) { $v = $ss[$idx] } }
      elseif ($c.t -eq "inlineStr") { $v = [string]$c.is.t }
      elseif ($c.t -eq "str") { $v = [string]$c.v }
      else { $v = [string]$c.v }
      $v = $v -replace "`t"," " -replace "`r?`n"," "
      $vals[$ci-1] = $v
    }
    $lines.Add(($row.r + "`t" + ($vals -join "`t")).TrimEnd("`t"))
  }
  [System.IO.File]::WriteAllLines($out, $lines, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output ("{0} filas -> {1}" -f $lines.Count, $out)
} finally { $zip.Dispose() }
