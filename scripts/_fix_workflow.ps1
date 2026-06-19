#!/usr/bin/env pwsh
# Detect workflow.md encoding state and repair it
param()

$wfPath  = "C:\Users\88698\.gemini\antigravity-ide\knowledge\godot_multiagent_workflow\artifacts\workflow.md"
$srcPath = "D:\2026-06-04\scripts\_rrp_section.md"
$utf8    = [System.Text.Encoding]::UTF8
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Read raw bytes to detect encoding boundary
$bytes = [System.IO.File]::ReadAllBytes($wfPath)
Write-Host "File size: $($bytes.Length) bytes"

# Try to read as UTF-8 and find where it breaks
$raw = [System.IO.File]::ReadAllText($wfPath, $utf8)

# Try different approaches to find cut point
$markers = @(
    "player.tscn" + [char]0x5F15 + [char]0x7528,   # player.tscn 引用
    "ERR-027",
    "L5"
)

$cutIdx = -1
foreach ($m in $markers) {
    $idx = $raw.LastIndexOf($m)
    if ($idx -ge 0) {
        Write-Host "Found marker '$m' at idx $idx"
        $cutIdx = $idx
        break
    }
}

if ($cutIdx -lt 0) {
    # Last resort: find by line count (original was 414 lines)
    $rawLines = $raw -split "`n"
    Write-Host "Total lines (read as UTF8): $($rawLines.Count)"

    # Take first 414 lines (original file)
    $originalLines = $rawLines[0..413]
    $trimmed = $originalLines -join "`n"
} else {
    # Find next newline after the marker
    $nextNl = $raw.IndexOf("`n", $cutIdx)
    if ($nextNl -lt 0) { $nextNl = $cutIdx + 100 }
    $trimmed = $raw.Substring(0, $nextNl + 1)
}

Write-Host "Trimmed length: $($trimmed.Length) chars"

# Append the RRP section
$rrp = [System.IO.File]::ReadAllText($srcPath, $utf8NoBom)
$combined = $trimmed + "`n" + $rrp
[System.IO.File]::WriteAllText($wfPath, $combined, $utf8NoBom)
Write-Host "Done. Lines: $((Get-Content $wfPath).Count)"
(Get-Content $wfPath -Tail 5) | ForEach-Object { Write-Host "  $_" }
