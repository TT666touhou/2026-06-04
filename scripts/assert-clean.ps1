# =============================================================
# scripts/assert-clean.ps1  v1.1
# Pre-Edit Safety Gate — must run before modifying any file
#
# Usage:
#   .\scripts\assert-clean.ps1                  # check only, exit 1 if dirty
#   .\scripts\assert-clean.ps1 -AutoCommit      # auto WIP commit if dirty
#   .\scripts\assert-clean.ps1 -StrictUntracked # also check untracked files
#
# The AI Agent MUST call this before editing any file.
# =============================================================

param(
    [switch]$AutoCommit,
    [switch]$StrictUntracked,
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "[assert-clean] Pre-edit workspace safety check..." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# --- Gather dirty files ---
$UnstagedDirty  = @(git diff --name-only 2>$null | Where-Object { $_ -ne "" })
$StagedChanges  = @(git diff --cached --name-only 2>$null | Where-Object { $_ -ne "" })
$UntrackedFiles = @(git ls-files --others --exclude-standard 2>$null | Where-Object { $_ -ne "" })

$ImportantExt = @(".gd", ".tscn", ".tres", ".gdshader", ".gdextension")

function Is-Important([string]$path) {
    foreach ($ext in $ImportantExt) {
        if ($path.EndsWith($ext)) { return $true }
    }
    return $false
}

$DirtyReport = [System.Collections.Generic.List[string]]::new()
$DirtyImportant = [System.Collections.Generic.List[string]]::new()

foreach ($f in $UnstagedDirty) {
    $DirtyReport.Add("  UNSTAGED : $f")
    if (Is-Important $f) { $DirtyImportant.Add($f) }
}
foreach ($f in $StagedChanges) {
    $DirtyReport.Add("  STAGED   : $f (not yet committed)")
    if (Is-Important $f) { $DirtyImportant.Add($f) }
}

$UntrackedImportant = [System.Collections.Generic.List[string]]::new()
if ($StrictUntracked) {
    foreach ($f in $UntrackedFiles) {
        $DirtyReport.Add("  UNTRACKED: $f")
        if (Is-Important $f) { $UntrackedImportant.Add($f) }
    }
}

$IsDirty = ($UnstagedDirty.Count -gt 0) -or ($StagedChanges.Count -gt 0) -or ($UntrackedImportant.Count -gt 0)

# --- Clean: allow editing ---
if (-not $IsDirty) {
    Write-Host "  [OK] Workspace is clean. Safe to edit files." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# --- Dirty: report ---
Write-Host ""
Write-Host "  [WARNING] Workspace has uncommitted changes!" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Dirty file list:" -ForegroundColor Yellow
foreach ($line in $DirtyReport) {
    Write-Host $line -ForegroundColor DarkYellow
}
if ($DirtyImportant.Count -gt 0 -or $UntrackedImportant.Count -gt 0) {
    Write-Host ""
    Write-Host "  [!] Critical game files not yet committed:" -ForegroundColor Red
    foreach ($f in ($DirtyImportant + $UntrackedImportant)) {
        Write-Host "      $f" -ForegroundColor Red
    }
}

# --- AutoCommit mode ---
if ($AutoCommit) {
    Write-Host ""
    Write-Host "  [AutoCommit] Creating WIP commit..." -ForegroundColor Cyan

    git add -u 2>$null | Out-Null
    if ($StrictUntracked) {
        foreach ($f in $UntrackedImportant) { git add $f 2>$null | Out-Null }
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $msg = if ($Message) { "$Message ($timestamp)" } else { "[WIP] auto-save before edit ($timestamp)" }

    $result = git commit -m $msg --no-verify 2>&1
    Write-Host $result
    Write-Host ""
    Write-Host "  [OK] WIP commit done: $msg" -ForegroundColor Green
    Write-Host "       Workspace is now clean. Safe to edit." -ForegroundColor Green
    Write-Host ""
    exit 0
}

# --- Blocked ---
Write-Host ""
Write-Host "============================================================" -ForegroundColor Red
Write-Host "  [BLOCKED] Cannot edit files with dirty workspace!" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""
Write-Host "  Option A - Commit all changes (recommended):" -ForegroundColor Green
Write-Host "    git add -A"
Write-Host "    git commit -m `"[DEV] chore: save state before <task>`""
Write-Host ""
Write-Host "  Option B - Auto WIP commit:" -ForegroundColor Green
Write-Host "    .\scripts\assert-clean.ps1 -AutoCommit"
Write-Host ""
Write-Host "  Option C - Discard all changes (DANGEROUS):" -ForegroundColor Red
Write-Host "    git checkout -- ."
Write-Host "    git clean -fd"
Write-Host ""
exit 1
