Write-Host "=== Validating PL-GATE Docs ===" -ForegroundColor Cyan

# 1. cookbook
Write-Host "--- 1. cookbook.md ---" -ForegroundColor Yellow
$f1 = "D:\2026-06-04\docs\pixellab_cookbook.md"
if (Test-Path $f1) {
    $txt = [IO.File]::ReadAllText($f1)
    $lines = $txt.Split("`n").Count
    Write-Host ("  Exists, " + $lines + " lines") -ForegroundColor Green
    @("CK-1","CK-4","CK-6","CK-7","CDN_HEADERS","enhanced_prompt","DS Sprite","8 ") | ForEach-Object {
        if ($txt.Contains($_)) { Write-Host ("  OK: " + $_) -ForegroundColor Green }
        else { Write-Host ("  MISS: " + $_) -ForegroundColor Red }
    }
} else { Write-Host "NOT FOUND" -ForegroundColor Red }

# 2. designer
Write-Host "--- 2. designer.md ---" -ForegroundColor Yellow
$txt2 = [IO.File]::ReadAllText("D:\2026-06-04\roles\designer.md")
@("PL-MANDATORY GATE","llms.txt","pixellab_cookbook","PL-001","PL-003","PL-006","Step 1","Step 5","PL-1","PL-2","PL-3","PL-4") | ForEach-Object {
    if ($txt2.Contains($_)) { Write-Host ("  OK: " + $_) -ForegroundColor Green }
    else { Write-Host ("  MISS: " + $_) -ForegroundColor Red }
}

# 3. sensor
Write-Host "--- 3. sensor.md ---" -ForegroundColor Yellow
$txt3 = [IO.File]::ReadAllText("D:\2026-06-04\roles\sensor.md")
@("PL.","Level 1","browser_subagent","PL-003","SENSOR LEVEL 1","Designer","重做 5") | ForEach-Object {
    if ($txt3.Contains($_)) { Write-Host ("  OK: " + $_) -ForegroundColor Green }
    else { Write-Host ("  MISS: " + $_) -ForegroundColor Red }
}

# 4. workflow
Write-Host "--- 4. workflow.md ---" -ForegroundColor Yellow
$txt4 = [IO.File]::ReadAllText("C:\Users\88698\.gemini\antigravity-ide\knowledge\godot_multiagent_workflow\artifacts\workflow.md")
@("v6 2026-06-16","GATE-1","GATE-5","pixellab_cookbook","llms.txt","Two-Layer") | ForEach-Object {
    if ($txt4.Contains($_)) { Write-Host ("  OK: " + $_) -ForegroundColor Green }
    else { Write-Host ("  MISS: " + $_) -ForegroundColor Red }
}

Write-Host "=== Done ===" -ForegroundColor Cyan
