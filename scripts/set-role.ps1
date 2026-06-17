# ==============================================================
# scripts/set-role.ps1 v2
# Set the current Antigravity Session Agent role
#
# Usage: .\scripts\set-role.ps1 [designer|architect|developer|reviewer|qa|sensor|none]
# v2: Added DOC_INDEX.md mandatory reminder + must-read file list per role
# ==============================================================

# param() must be first executable statement
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("designer","architect","developer","reviewer","qa","sensor","none")]
    [string]$Role
)

# Force UTF-8 output (fixes Shift-JIS / CP932 garbled text)
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$RoleFile = ".agent-role"
$RoleColors = @{
    "designer"  = "Blue"
    "architect" = "Cyan"
    "developer" = "Green"
    "reviewer"  = "Yellow"
    "qa"        = "Magenta"
    "sensor"    = "Red"
    "none"      = "Gray"
}

$RoleEmoji = @{
    "designer"  = "[DESIGN] "
    "architect" = "[ARCH]   "
    "developer" = "[DEV]    "
    "reviewer"  = "[REVIEW] "
    "qa"        = "[QA]     "
    "sensor"    = "[SENSOR] "
    "none"      = "[NONE]   "
}

$RoleDesc = @{
    "designer"  = "Game Designer - maintains docs/GAME_DESIGN.md"
    "architect" = "Architect - designs implementation_plan.md"
    "developer" = "Developer - writes GDScript code (in Worktree)"
    "reviewer"  = "Reviewer - reviews PRs and writes structured comments"
    "qa"        = "QA - black-box testing and QA reports"
    "sensor"    = "Sensor Guard - monitors dangerous patterns, triggers scans"
    "none"      = "No role set"
}

# Must-read files per role (SS READ SOP)
$RoleMustRead = @{
    "designer"  = @(
        "[READ -2] docs/DOC_INDEX.md (which docs are involved?)",
        "[READ -1] docs/PROJECT_STATUS.md (current Phase status)",
        "[READ  0] docs/ERROR_LOG.md (technical constraints)",
        "[READ  1] docs/GAME_DESIGN.md (design authority)"
    )
    "architect" = @(
        "[READ -2] docs/DOC_INDEX.md (which docs are involved?)",
        "[READ -1] docs/PROJECT_STATUS.md (current Phase status)",
        "[READ  0] docs/ERROR_LOG.md (architecture constraints)",
        "[READ  1] docs/GAME_DESIGN.md (confirm latest design)",
        "[READ  2] implementation_plan.md (if exists, check for stale design)"
    )
    "developer" = @(
        "[READ -2] docs/DOC_INDEX.md (which docs are involved?)",
        "[READ -1] docs/PROJECT_STATUS.md (current Phase task)",
        "[READ  0] docs/ERROR_LOG.md (known errors, do NOT repeat)",
        "[READ  1] implementation_plan.md (architect design plan)"
    )
    "reviewer"  = @(
        "[READ -2] docs/DOC_INDEX.md (which docs are involved?)",
        "[READ -1] docs/PROJECT_STATUS.md (Phase status check)",
        "[READ  0] docs/ERROR_LOG.md (known issue regression check)"
    )
    "qa"        = @(
        "[READ -2] docs/DOC_INDEX.md (which docs are involved?)",
        "[READ -1] docs/PROJECT_STATUS.md (tested Phase DoD)",
        "[READ  0] docs/ERROR_LOG.md (Critical issue regression check)"
    )
    "sensor"    = @(
        "[READ -2] docs/DOC_INDEX.md (which docs to monitor?)",
        "[READ  0] docs/ERROR_LOG.md (known dangerous patterns)",
        "[READ  1] roles/sensor.md (trigger table and scan scripts)",
        "[SCAN]    scripts/sensor-scan.ps1 (run all 15 checks)"
    )
    "none"      = @("[TIP] Run .\scripts\set-role.ps1 <role> to set a role")
}

# Write role file (no BOM, ensures Git Hook can read correctly)
[System.IO.File]::WriteAllText("$PWD\$RoleFile", $Role, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "============================================================" -ForegroundColor $RoleColors[$Role]
Write-Host "$($RoleEmoji[$Role]) Role set" -ForegroundColor $RoleColors[$Role]
Write-Host "============================================================" -ForegroundColor $RoleColors[$Role]
Write-Host "  Role: $Role" -ForegroundColor White
Write-Host "  Duty: $($RoleDesc[$Role])" -ForegroundColor Gray
Write-Host ""
Write-Host "  Role definition: .\roles\$Role.md" -ForegroundColor Gray
Write-Host "  Please read the above file at the start of each Antigravity session." -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor $RoleColors[$Role]
Write-Host ""

# Display must-read file list (SS READ SOP)
Write-Host "+--- Must-Read Files (SS READ SOP) -------------------------+" -ForegroundColor $RoleColors[$Role]
foreach ($item in $RoleMustRead[$Role]) {
    Write-Host "|  $item" -ForegroundColor White
}
Write-Host "+-----------------------------------------------------------+" -ForegroundColor $RoleColors[$Role]
Write-Host ""

# Display role-specific Git Hook rules
Write-Host "Git Hook rules for this role:" -ForegroundColor White
switch ($Role) {
    "designer" {
        Write-Host "  [OK]  Can modify: docs/GAME_DESIGN.md (only modifier)" -ForegroundColor Green
        Write-Host "  [NG]  Cannot modify: .gd, .tscn, .tres, implementation_plan.md" -ForegroundColor Red
        Write-Host "  [DOC] Maintains: docs/GAME_DESIGN.md, docs/DOC_INDEX.md" -ForegroundColor Cyan
    }
    "architect" {
        Write-Host "  [OK]  Can commit: implementation_plan.md, docs/, roles/, RULES.md" -ForegroundColor Green
        Write-Host "  [NG]  Cannot commit: .gd, .tscn, .tres files" -ForegroundColor Red
        Write-Host "  [DOC] Maintains: docs/DOC_INDEX.md, roles/*.md, workflow.md" -ForegroundColor Cyan
    }
    "developer" {
        Write-Host "  [OK]  Can commit: .gd, .tscn (LFS Lock first), .tres" -ForegroundColor Green
        Write-Host "  [NG]  Cannot commit: direct git commit of code (use dev-submit.ps1)" -ForegroundColor Red
        Write-Host "  [!!]  Before scene edit: .\scripts\lock-scene.ps1 lock <path>" -ForegroundColor Yellow
        Write-Host "  [!!]  Before commit: run sensor-scan.ps1, confirm all checks PASS" -ForegroundColor Yellow
    }
    "reviewer"  {
        Write-Host "  [OK]  Can do: PR review, comments, audit code + docs" -ForegroundColor Green
        Write-Host "  [NG]  Cannot do: directly modify code files" -ForegroundColor Red
        Write-Host "  [DOC] Maintains: docs/qa-report-*.md (QA writes these)" -ForegroundColor Cyan
    }
    "qa"        {
        Write-Host "  [OK]  Can commit: docs/qa-report-*.md, and final code commit" -ForegroundColor Green
        Write-Host "  [NG]  Cannot commit: any .gd or .tscn (except final QA commit)" -ForegroundColor Red
        Write-Host "  [!!]  QA is the ONLY role that can git commit + push (v4 rule)" -ForegroundColor Yellow
    }
    "sensor"    {
        Write-Host "  [!!]  On trigger: immediately stop current work, run sensor-scan.ps1" -ForegroundColor Red
        Write-Host "  [OK]  Can update: docs/ERROR_LOG.md (new ERR entries)" -ForegroundColor Green
    }
}
Write-Host ""
Write-Host "  [MOD] To modify workflow: follow 5-step SOP in docs/DOC_INDEX.md (SS MOD)" -ForegroundColor DarkCyan
Write-Host ""