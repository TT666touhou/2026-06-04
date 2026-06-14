#!/usr/bin/env pwsh
param()
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ok = $true

# 1. Check hook
$hook = [System.IO.File]::ReadAllText('d:\2026-06-04\hooks\pre-commit', [System.Text.Encoding]::UTF8)
$checks = @('GAP-001','GAP-003','GAP-008','Designer/3','QA/4','CORRUPT_FOUND','ERR-DOC-001')
Write-Host '=== HOOK CHECKS ==='
foreach ($c in $checks) {
    if ($hook.Contains($c)) { Write-Host ('  OK: ' + $c) }
    else { Write-Host ('  FAIL: ' + $c); $ok = $false }
}

# 2. Check sensor
$sensor = [System.IO.File]::ReadAllText('d:\2026-06-04\scripts\sensor-scan.ps1', [System.Text.Encoding]::UTF8)
$sc = @('10/10','0x75AB','requiredKeywords','target_room_path','start_room_entry','MeleeSlash.tscn','PASSED (10/10)','[Sensor v6]','GAP-001/004/010')
Write-Host '=== SENSOR CHECKS ==='
foreach ($c in $sc) {
    if ($sensor.Contains($c)) { Write-Host ('  OK: ' + $c) }
    else { Write-Host ('  FAIL: ' + $c); $ok = $false }
}
$sections = [regex]::Matches($sensor, '##\s+\d+/\d+\s+')
Write-Host ('  Section headers: ' + $sections.Count + ' (need >=10)')
if ($sections.Count -lt 10) { $ok = $false }

# 3. Check reviewer
$rev = [System.IO.File]::ReadAllText('d:\2026-06-04\roles\reviewer.md', [System.Text.Encoding]::UTF8)
$rc = @('GAP-005','sensor-scan.ps1','10/10 PASS')
Write-Host '=== REVIEWER CHECKS ==='
foreach ($c in $rc) {
    if ($rev.Contains($c)) { Write-Host ('  OK: ' + $c) }
    else { Write-Host ('  FAIL: ' + $c); $ok = $false }
}

# 4. Check developer
$dev = [System.IO.File]::ReadAllText('d:\2026-06-04\roles\developer.md', [System.Text.Encoding]::UTF8)
$dc = @('GAP-006','DEV-DOC1','DEV-DOC5','ERR-029','Portal Walk-in')
Write-Host '=== DEVELOPER CHECKS ==='
foreach ($c in $dc) {
    if ($dev.Contains($c)) { Write-Host ('  OK: ' + $c) }
    else { Write-Host ('  FAIL: ' + $c); $ok = $false }
}

# 5. Check workflow
$wf = [System.IO.File]::ReadAllText('C:\Users\88698\.gemini\antigravity-ide\knowledge\godot_multiagent_workflow\artifacts\workflow.md', [System.Text.Encoding]::UTF8)
$wc = @('## M. [RRP]','### M1.','### M2.','### M3.','### M4.','### M5.','STEP 1','STEP 6','GAP-001','GAP-009','GAP-010','Rule Reinforcement Protocol','Gap Audit 2026-06-14')
Write-Host '=== WORKFLOW §M CHECKS ==='
$wfLines = ($wf -split "`n").Count
Write-Host ('  Lines: ' + $wfLines)
foreach ($c in $wc) {
    if ($wf.Contains($c)) { Write-Host ('  OK: ' + $c) }
    else { Write-Host ('  FAIL: ' + $c); $ok = $false }
}

Write-Host ''
if ($ok) { Write-Host 'RESULT: ALL PASSED' }
else { Write-Host 'RESULT: SOME FAILED'; exit 1 }
