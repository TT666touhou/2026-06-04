#!/usr/bin/env pwsh
## sensor-scan.ps1 -- Sensor Automated Scan Script v2
## Run in pre-commit hook or manually to verify project integrity
## Usage: .\scripts\sensor-scan.ps1 [-Root "D:\2026-06-04"]

param(
    [string]$Root = "D:\2026-06-04"
)

$hasError = $false
$hasWarning = $false

function Write-Pass  { param($msg) Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail  { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:hasError = $true }
function Write-Warn  { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:hasWarning = $true }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [Sensor v2] Godot Project Integrity Scan" -ForegroundColor Cyan
Write-Host " Root: $Root" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

## ============================================================
## 1. BOM Scan -- all .gd files must be UTF-8 without BOM
## ============================================================
Write-Host "`n[1/7] Scanning .gd file encoding..." -ForegroundColor Yellow
$gdFiles = @(Get-ChildItem $Root -Recurse -Filter "*.gd" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\addons\\" -and $_.FullName -notmatch "\\gut\\" })
$bomCount = 0

foreach ($f in $gdFiles) {
    try {
        $b = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) {
            Write-Fail "UTF-8 BOM detected: $($f.Name) (ERR-015)"
            $bomCount++
        } elseif ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) {
            Write-Fail "UTF-16 LE BOM detected: $($f.Name) (ERR-011)"
            $bomCount++
        } elseif ($b.Length -ge 2 -and $b[0] -eq 0xFE -and $b[1] -eq 0xFF) {
            Write-Fail "UTF-16 BE BOM detected: $($f.Name) (ERR-011)"
            $bomCount++
        }
    } catch {
        Write-Warn "Cannot read $($f.Name): $_"
    }
}
if ($bomCount -eq 0) { Write-Pass "All $($gdFiles.Count) .gd files have no BOM" }
else { Write-Fail "Found $bomCount BOM issues total" }

## ============================================================
## 2. .tscn ext_resource UID self-reference scan (ERR-013)
## ============================================================
Write-Host "`n[2/7] Scanning .tscn ext_resource UID self-references..." -ForegroundColor Yellow
$scenesDir = Join-Path $Root "scenes"
$tscnFiles = @(Get-ChildItem $scenesDir -Recurse -Filter "*.tscn" -ErrorAction SilentlyContinue)
$uidSelfRefCount = 0

foreach ($f in $tscnFiles) {
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    
    $sceneUIDMatch = [regex]::Match($content, 'gd_scene[^"]*uid="([^"]+)"')
    if ($sceneUIDMatch.Success) {
        $sceneUID = $sceneUIDMatch.Groups[1].Value
        $extMatches = [regex]::Matches($content, 'ext_resource[^"]*uid="([^"]+)"')
        foreach ($m in $extMatches) {
            $extUID = $m.Groups[1].Value
            if ($extUID -eq $sceneUID) {
                Write-Fail "UID self-reference (ERR-013): $($f.Name) -- ext_resource uid=$extUID equals scene uid"
                $uidSelfRefCount++
            }
        }
    }
}
if ($uidSelfRefCount -eq 0) { Write-Pass "All $($tscnFiles.Count) .tscn files have no UID self-references" }

## ============================================================
## 3. Physics callback dangerous pattern scan (Level 1 ERR-001)
## ============================================================
Write-Host "`n[3/7] Scanning physics callback dangerous patterns..." -ForegroundColor Yellow
$scriptsDir = Join-Path $Root "scripts"
$gdScripts = @(Get-ChildItem $scriptsDir -Recurse -Filter "*.gd" -ErrorAction SilentlyContinue)
$physicsIssues = 0

$dangerousInCallback = @("add_child", "queue_free", "change_scene_to_file")
$callbackFuncs = @("func _on_body_entered", "func _on_area_entered", "func _on_body_exited", "func _on_area_exited")

foreach ($f in $gdScripts) {
    $lines = Get-Content $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    
    $inCallback = $false
    $funcIndentLen = 0
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Check if entering a callback function
        foreach ($cb in $callbackFuncs) {
            if ($line.TrimStart() -eq ($line -replace "^\s*", "") -and $line -match [regex]::Escape($cb)) {
                $inCallback = $true
                $funcIndentLen = $line.Length - $line.TrimStart().Length
                break
            }
        }
        
        if ($inCallback) {
            $trimmed = $line.TrimStart()
            $lineIndent = $line.Length - $trimmed.Length
            # Exit callback when we see a new func at same or lower indent level
            if ($trimmed -ne "" -and $lineIndent -le $funcIndentLen -and $trimmed.StartsWith("func ") -and $i -gt 0) {
                $inCallback = $false
                continue
            }
            # Check for dangerous patterns without call_deferred
            foreach ($danger in $dangerousInCallback) {
                if ($line -match ($danger + "\(") -and $line -notmatch "call_deferred") {
                    Write-Fail "Direct call in physics callback (ERR-001): $($f.Name):$($i+1) -- $($trimmed)"
                    $physicsIssues++
                }
            }
        }
    }
}
if ($physicsIssues -eq 0) { Write-Pass "No physics callback dangerous patterns found" }

## ============================================================
## 4. Narrowing conversion scan (Level 2 ERR-002)
## ============================================================
Write-Host "`n[4/7] Scanning for int() narrowing conversion patterns..." -ForegroundColor Yellow
$narrowingCount = 0
foreach ($f in $gdScripts) {
    $hits = Get-Content $f.FullName -ErrorAction SilentlyContinue | 
        Select-String -Pattern "=\s*int\([a-z_]+\.[xy]\)" -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
        Write-Warn "Narrowing conversion (ERR-002): $($f.Name):$($h.LineNumber) -- $($h.Line.Trim())"
        $narrowingCount++
    }
}
if ($narrowingCount -eq 0) { Write-Pass "No int() narrowing conversion issues found" }

## ============================================================
## 5. Godot 3 deprecated API scan (Level 2 ERR-014)
## ============================================================
Write-Host "`n[5/7] Scanning for Godot 3 deprecated APIs..." -ForegroundColor Yellow
$deprecatedAPIs = @(
    "TextureRect\.STRETCH_KEEP_ASPECT_CENTERED",
    "TextureRect\.STRETCH_FIT",
    "setget ",
    "^export var ",     # Godot 3: no @ prefix
    "^onready var "     # Godot 3: no @ prefix
)

$deprecatedCount = 0
foreach ($f in $gdFiles) {
    $lines = Get-Content $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        $trimmed = $line.TrimStart()
        foreach ($api in $deprecatedAPIs) {
            # For ^ patterns, check trimmed line start
            $pattern = $api.TrimStart("^")
            if ($api.StartsWith("^")) {
                if ($trimmed.StartsWith($pattern)) {
                    Write-Warn "Deprecated Godot 3 API (ERR-014): $($f.Name):$lineNum -- $trimmed"
                    $deprecatedCount++
                    break
                }
            } else {
                if ($trimmed -match [regex]::Escape($pattern)) {
                    Write-Warn "Deprecated Godot 3 API (ERR-014): $($f.Name):$lineNum -- $trimmed"
                    $deprecatedCount++
                    break
                }
            }
        }
    }
}
if ($deprecatedCount -eq 0) { Write-Pass "No Godot 3 deprecated API found" }

## ============================================================
## 6. .tscn header validity scan (ERR-023)
##    Every .tscn must start with '[gd_scene' on line 1
##    Missing '[' = file was corrupted by PowerShell regex substitution
## ============================================================
Write-Host "`n[6/7] Scanning .tscn header line validity (ERR-023)..." -ForegroundColor Yellow
$allTscnFiles = @(Get-ChildItem $Root -Recurse -Filter "*.tscn" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\.git" })
$headerIssues = 0

foreach ($f in $allTscnFiles) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($bytes.Length -eq 0) { Write-Warn "Empty .tscn file: $($f.Name)"; continue }
        
        # Skip BOM if present (EF BB BF)
        $startIdx = 0
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $startIdx = 3
        } elseif ($bytes.Length -ge 2 -and ($bytes[0] -eq 0xFF -or $bytes[0] -eq 0xFE)) {
            $startIdx = 2  # UTF-16 BOM
        }
        
        $firstMeaningfulByte = $bytes[$startIdx]
        $firstChar = [char]$firstMeaningfulByte
        
        if ($firstChar -ne '[') {
            $preview = [System.Text.Encoding]::UTF8.GetString($bytes, $startIdx, [Math]::Min(40, $bytes.Length - $startIdx))
            Write-Fail "Invalid .tscn header (ERR-023): $($f.Name) -- first char='$firstChar' expected '['. Preview: $preview"
            $headerIssues++
        }
    } catch {
        Write-Warn "Cannot read .tscn: $($f.Name) -- $_"
    }
}
if ($headerIssues -eq 0) { Write-Pass "All $($allTscnFiles.Count) .tscn files have valid '[gd_scene' headers" }

## ============================================================
## 7. SpriteFrames 'region' in frame dict scan (ERR-024)
##    In Godot 4, frame dicts with 'region' key are IGNORED.
##    Each frame must use an AtlasTexture sub-resource.
## ============================================================
Write-Host "`n[7/7] Scanning SpriteFrames for incorrect 'region' in frame dict (ERR-024)..." -ForegroundColor Yellow
$spriteFramesIssues = 0

foreach ($f in $allTscnFiles) {
    try {
        $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        # Check for the pattern: "region": Rect2 inside a "frames" block with an ExtResource texture
        # This means: texture is a full PNG (not AtlasTexture), but trying to use region in frame dict
        if ($content -match '"texture":\s*ExtResource\(' -and $content -match '"region":\s*Rect2\(') {
            Write-Fail "SpriteFrames uses 'region' in frame dict (ERR-024): $($f.Name) -- use AtlasTexture sub-resource instead"
            $spriteFramesIssues++
        }
    } catch {
        Write-Warn "Cannot read .tscn: $($f.Name) -- $_"
    }
}
if ($spriteFramesIssues -eq 0) { Write-Pass "All VFX .tscn files use correct AtlasTexture format for SpriteFrames" }

## ============================================================
## Result summary
## ============================================================
Write-Host "`n============================================================" -ForegroundColor Cyan
if ($hasError) {
    Write-Host " [Sensor v2] FAILED -- Critical issues found. Fix before committing." -ForegroundColor Red
    exit 1
} elseif ($hasWarning) {
    Write-Host " [Sensor v2] PASSED with warnings -- Review warnings before committing." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host " [Sensor v2] PASSED -- No issues found." -ForegroundColor Green
    exit 0
}
