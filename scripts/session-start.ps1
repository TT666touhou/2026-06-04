# session-start.ps1 -- AI session bootstrap (run this first every conversation)
# Usage: powershell -NoProfile -File scripts\session-start.ps1
$Root = "D:\2026-06-04"
$UTF8 = [System.Text.Encoding]::UTF8
$Sep = "=" * 60

function Read-UTF8 { param($path)
    [System.IO.File]::ReadAllLines($path, $UTF8)
}

Write-Host ""
Write-Host $Sep -ForegroundColor Cyan
Write-Host "  SESSION START BRIEFING" -ForegroundColor Cyan
Write-Host $Sep -ForegroundColor Cyan

# 1. Current role
$role = (Read-UTF8 "$Root\.agent-role") -join "" | ForEach-Object { $_.Trim() }
Write-Host "`n[1] Role: $role" -ForegroundColor Yellow

# 2. Recent 5 update log entries from PROJECT_STATUS
Write-Host "`n[2] Recent changes (PROJECT_STATUS.md):" -ForegroundColor Yellow
(Read-UTF8 "$Root\docs\PROJECT_STATUS.md") |
    Where-Object { $_ -match "^\| 2026" } |
    Select-Object -Last 5 |
    ForEach-Object { Write-Host "  $_" }

# 3. Last 3 GAP headings from ERROR_LOG
Write-Host "`n[3] Recent GAPs (ERROR_LOG.md):" -ForegroundColor Yellow
(Read-UTF8 "$Root\docs\ERROR_LOG.md") |
    Where-Object { $_ -match "^## GAP-" } |
    Select-Object -Last 3 |
    ForEach-Object { Write-Host "  $_" }

# 4. Actual PENDING rows in sop-state.md (table cells only, not header docs)
Write-Host "`n[4] SOP PENDING items:" -ForegroundColor Yellow
$pending = (Read-UTF8 "$Root\docs\sop-state.md") |
    Where-Object { $_ -match "^\|.+\| PENDING \|" }
if ($pending) {
    $pending | ForEach-Object { Write-Host "  !! $_" -ForegroundColor Red }
} else {
    Write-Host "  OK - no PENDING" -ForegroundColor Green
}

Write-Host "`n$Sep" -ForegroundColor Cyan
Write-Host "  Next: Read workflow.md + roles\$role.md for full rules" -ForegroundColor Gray
Write-Host "$Sep`n" -ForegroundColor Cyan
