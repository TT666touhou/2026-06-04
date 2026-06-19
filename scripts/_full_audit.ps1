#!/usr/bin/env pwsh
# Final Clean Comprehensive Gap Audit v2
param()
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$allOk = $true
$failures = @()

function Pass { param($label) Write-Host "  [OK]   $label" -ForegroundColor Green }
function Fail { param($label, $detail = "")
    Write-Host "  [FAIL] $label $detail" -ForegroundColor Red
    $script:allOk = $false
    $script:failures += $label
}
function CheckStr { param($label, $content, $pattern)
    if ($content.Contains($pattern)) { Pass $label }
    else { Fail $label "-- pattern: '$pattern'" }
}

# ============================================================
Write-Host "=== 1. ROLE FILES (6 files must exist) ===" -ForegroundColor Cyan
$roles = @('designer', 'architect', 'developer', 'reviewer', 'qa', 'sensor')
foreach ($r in $roles) {
    $p = "d:\2026-06-04\roles\$r.md"
    if (Test-Path $p) {
        $lineCount = (Get-Content $p -Encoding UTF8).Count
        Pass "$r.md ($lineCount lines)"
    } else {
        Fail "$r.md MISSING"
    }
}

# ============================================================
Write-Host "`n=== 2. PRE-COMMIT HOOK GATES ===" -ForegroundColor Cyan
$hook = [System.IO.File]::ReadAllText("d:\2026-06-04\hooks\pre-commit", [System.Text.Encoding]::UTF8)
$hookLines = ($hook -split "`n").Count
Write-Host "  Hook total lines: $hookLines"
CheckStr "GAP-001 Designer/3 garble gate"       $hook "GAP-001"
CheckStr "Designer/3 PowerShell garble scan"    $hook "CORRUPT_FOUND"
CheckStr "Designer/3 exit 1 on garble"          $hook "ERR-DOC-001"
CheckStr "GAP-008 QA/4 GDD TODO hard block"     $hook "GAP-008"
CheckStr "QA/4 exit 1 on GDD TODO"              $hook "GDD TODO"
CheckStr "GAP-003 Developer fix: reminder"      $hook "GAP-003"
CheckStr "Designer/1 no-code gate"              $hook "Designer/1"
CheckStr "Designer/3 gate header"               $hook "Designer/3"
CheckStr "QA/4 gate header"                     $hook "QA/4"
CheckStr "Developer/1 GDScript syntax check"    $hook "GDScript"
CheckStr "Architect/2 impl_plan gate"           $hook "Architect/2"
CheckStr "Reviewer/1 sensor-scan gate"          $hook "sensor-scan"

# ============================================================
Write-Host "`n=== 3. SENSOR-SCAN CHECKS ===" -ForegroundColor Cyan
$sensor = [System.IO.File]::ReadAllText("d:\2026-06-04\scripts\sensor-scan.ps1", [System.Text.Encoding]::UTF8)
$sections = [regex]::Matches($sensor, '##\s+\d+/\d+\s+')
Write-Host "  Sensor section headers: $($sections.Count) (need >=10)"
if ($sections.Count -lt 10) { Fail "Sensor sections < 10" }
CheckStr "Sensor BOM scan"          $sensor "BOM"
CheckStr "Sensor ERR-002 narrowing" $sensor "ERR-002"
CheckStr "Sensor ERR-014 deprecated" $sensor "ERR-014"
CheckStr "Sensor UID check"         $sensor "UID"
CheckStr "Sensor physics callback"  $sensor "physics"

# ============================================================
Write-Host "`n=== 4. WORKFLOW.md SECTION M ===" -ForegroundColor Cyan
$wf = [System.IO.File]::ReadAllText("C:\Users\88698\.gemini\antigravity-ide\knowledge\godot_multiagent_workflow\artifacts\workflow.md", [System.Text.Encoding]::UTF8)
$wfLines = ($wf -split "`n").Count
Write-Host "  workflow.md lines: $wfLines"
CheckStr "Section M header"         $wf "## M."
CheckStr "M1 Step header"           $wf "### M1"
CheckStr "GAP-001 in workflow"      $wf "GAP-001"
CheckStr "Rule Reinforcement"       $wf "Rule Reinforcement"
CheckStr "Gap Audit 2026-06-14"     $wf "Gap Audit 2026-06-14"

# ============================================================
Write-Host "" -ForegroundColor White
if ($allOk) {
    Write-Host "RESULT: ALL PASSED" -ForegroundColor Green
} else {
    Write-Host "RESULT: SOME FAILED" -ForegroundColor Red
    Write-Host "Failed checks:"
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
