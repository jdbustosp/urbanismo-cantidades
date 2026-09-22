param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

$text = [System.IO.File]::ReadAllText($Path)
$depth = 0
$minimum = 0
$line = 1
$lastZeroLine = 1
$inString = $false
$escaped = $false
$inComment = $false

foreach ($ch in $text.ToCharArray()) {
  if ($ch -eq "`n") {
    $line++
    $inComment = $false
    $escaped = $false
    continue
  }
  if ($inComment) { continue }
  if ($inString) {
    if ($escaped) {
      $escaped = $false
    } elseif ($ch -eq '\') {
      $escaped = $true
    } elseif ($ch -eq '"') {
      $inString = $false
    }
    continue
  }
  if ($ch -eq ';') {
    $inComment = $true
  } elseif ($ch -eq '"') {
    $inString = $true
  } elseif ($ch -eq '(') {
    $depth++
  } elseif ($ch -eq ')') {
    $depth--
    if ($depth -lt $minimum) {
      $minimum = $depth
      Write-Output "MIN depth=$minimum line=$line"
    }
    if ($depth -eq 0) { $lastZeroLine = $line }
  }
}

Write-Output "FINAL depth=$depth last_zero_line=$lastZeroLine total_lines=$line in_string=$inString"
