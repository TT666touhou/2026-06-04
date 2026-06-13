#!/usr/bin/env pwsh
## sensor-scan.ps1 -- Sensor Automated Scan Script v5
## Run in pre-commit hook or manually to verify project integrity
## Usage: .\scripts\sensor-scan.ps1 [-Root "D:\2026-06-04"]
##
## Checks:
##   1/9  BOM scan (.gd files must be UTF-8 without BOM)
##   2/9  .tscn ext_resource UID self-reference (ERR-013)
##   3/9  Physics callback dangerous patterns (ERR-001)
##   4/9  int() narrowing conversion (ERR-002)
##   5/9  Godot 3 deprecated API (ERR-014)
##   6/9  .tscn header first byte validity (ERR-023)
##   7/9  SpriteFrames frame dict 'region' (ERR-024) - must use AtlasTexture
##   8/9  Godot --check-only GDScript validation (ERR-015) ← CRITICAL: catches Variant/type errors
##   9/9  SceneTree script calling get_tree() (ERR-028) - extends SceneTree cannot call Node methods

param(
    [string]$Root = "D:\2026-06-04"
)

$hasError   = $false
$hasWarning = $false

function Write-Pass { param($msg) Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red;    $script:hasError   = $true }
function Write-Warn { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:hasWarning = $true }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [Sensor v5] Godot Project Integrity Scan"                    -ForegroundColor Cyan
Write-Host " Root: $Root"                                                  -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

## ============================================================
## Collect file lists once — used across multiple checks
## ============================================================
$gdFiles = [array](Get-ChildItem $Root -Recurse -Filter "*.gd" -ErrorAction SilentlyContinue |
    Where-Object { (-not $_.FullName.Contains("\addons\")) -and (-not $_.FullName.Contains("\gut\")) })

$tscnFiles = [array](Get-ChildItem $Root -Recurse -Filter "*.tscn" -ErrorAction SilentlyContinue |
    Where-Object { -not $_.FullName.Contains("\.git\") })

$scriptFiles = [array](Get-ChildItem (Join-Path $Root "scripts") -Recurse -Filter "*.gd" -ErrorAction SilentlyContinue)

if ($null -eq $gdFiles)     { $gdFiles     = @() }
if ($null -eq $tscnFiles)   { $tscnFiles   = @() }
if ($null -eq $scriptFiles) { $scriptFiles = @() }

## ============================================================
## 1/9  BOM Scan -- all .gd files must be UTF-8 without BOM
## ============================================================
Write-Host "`n[1/9] Scanning .gd file encoding (BOM)..." -ForegroundColor Yellow
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
else { Write-Fail "Found $bomCount BOM issues in .gd files" }

## ============================================================
## 2/9  .tscn ext_resource UID self-reference scan (ERR-013)
##      Detects scenes where an ext_resource uid equals the scene's own uid
## ============================================================
Write-Host "`n[2/9] Scanning .tscn ext_resource UID self-references (ERR-013)..." -ForegroundColor Yellow
$uidSelfRefCount = 0

foreach ($f in $tscnFiles) {
    $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $sceneUIDMatch = [regex]::Match($content, 'gd_scene[^"]*uid="([^"]+)"')
    if (-not $sceneUIDMatch.Success) { continue }

    $sceneUID   = $sceneUIDMatch.Groups[1].Value
    $extMatches = [regex]::Matches($content, 'ext_resource[^"]*uid="([^"]+)"')
    foreach ($m in $extMatches) {
        if ($m.Groups[1].Value -eq $sceneUID) {
            Write-Fail "UID self-reference (ERR-013): $($f.Name) -- ext_resource uid=$($m.Groups[1].Value) equals scene uid"
            $uidSelfRefCount++
        }
    }
}
if ($uidSelfRefCount -eq 0) { Write-Pass "All $($tscnFiles.Count) .tscn files have no UID self-references" }

## ============================================================
## 3/9  Physics callback dangerous pattern scan (ERR-001)
##      queue_free/add_child/change_scene called directly inside body_entered etc.
## ============================================================
Write-Host "`n[3/9] Scanning physics callback dangerous patterns (ERR-001)..." -ForegroundColor Yellow
$physicsIssues  = 0
$dangerCalls    = @("add_child(", "queue_free(", "change_scene_to_file(")
$callbackFuncs  = @("func _on_body_entered", "func _on_area_entered", "func _on_body_exited", "func _on_area_exited")

foreach ($f in $scriptFiles) {
    $lines = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
    $inCallback    = $false
    $funcIndentLen = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line    = $lines[$i]
        $trimmed = $line.TrimStart()
        $lineIndent = $line.Length - $trimmed.Length

        foreach ($cb in $callbackFuncs) {
            if ($line.Contains($cb)) {
                $inCallback    = $true
                $funcIndentLen = $lineIndent
                break
            }
        }

        if ($inCallback -and $trimmed.Length -gt 0) {
            if ($trimmed.StartsWith("func ") -and $lineIndent -le $funcIndentLen -and $i -gt 0) {
                $inCallback = $false
                continue
            }
            foreach ($danger in $dangerCalls) {
                if ($line.Contains($danger) -and -not $line.Contains("call_deferred")) {
                    Write-Fail "Direct call in physics callback (ERR-001): $($f.Name):$($i+1) -- $trimmed"
                    $physicsIssues++
                }
            }
        }
    }
}
if ($physicsIssues -eq 0) { Write-Pass "No physics callback dangerous patterns found" }

## ============================================================
## 4/9  Narrowing conversion scan (ERR-002)
##      int(node.x) or int(node.y) should be roundi()
## ============================================================
Write-Host "`n[4/9] Scanning for int() narrowing conversion patterns (ERR-002)..." -ForegroundColor Yellow
$narrowingCount = 0

foreach ($f in $scriptFiles) {
    $hits = Select-String -Path $f.FullName -Pattern "=\s*int\([a-z_]+\.[xy]\)" -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
        Write-Warn "Narrowing conversion (ERR-002): $($f.Name):$($h.LineNumber) -- $($h.Line.Trim())"
        $narrowingCount++
    }
}
if ($narrowingCount -eq 0) { Write-Pass "No int() narrowing conversion issues found" }

## ============================================================
## 5/9  Godot 3 deprecated API scan (ERR-014)
##      BAD (Godot 3): export var, onready var, setget, old stretch constants
##      GOOD (Godot 4): @export var, @onready var  <-- must NOT be flagged
## ============================================================
Write-Host "`n[5/9] Scanning for Godot 3 deprecated APIs (ERR-014)..." -ForegroundColor Yellow
$deprecatedCount = 0

foreach ($f in $gdFiles) {
    $lines  = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
    $lineNo = 0
    foreach ($line in $lines) {
        $lineNo++
        $trimmed = $line.TrimStart()
        $matched = $false
        $reason  = ""

        # Godot 3: 'export var' without @ prefix  (Godot 4: '@export var')
        if ($trimmed.StartsWith("export var ")) {
            $matched = $true; $reason = "Godot 3 'export var' -- use '@export var' instead"
        }
        # Godot 3: 'onready var' without @ prefix  (Godot 4: '@onready var')
        elseif ($trimmed.StartsWith("onready var ")) {
            $matched = $true; $reason = "Godot 3 'onready var' -- use '@onready var' instead"
        }
        # Godot 3: 'setget' keyword
        elseif ($trimmed.Contains("setget ")) {
            $matched = $true; $reason = "Godot 3 'setget' keyword -- use property get/set in Godot 4"
        }
        # Godot 3: TextureRect.STRETCH_FIT was renamed in Godot 4 (does not exist)
        # NOTE: STRETCH_KEEP_ASPECT_CENTERED is VALID in Godot 4 — do NOT flag it
        # Skip comment lines (## prefix) to avoid false positives from doc comments
        elseif (-not $trimmed.StartsWith("#") -and $trimmed.Contains("TextureRect.STRETCH_FIT")) {
            $matched = $true; $reason = "Godot 3 TextureRect.STRETCH_FIT -- use STRETCH_KEEP_ASPECT or STRETCH_SCALE in Godot 4"
        }

        if ($matched) {
            Write-Warn "Deprecated Godot 3 API (ERR-014): $($f.Name):$lineNo -- [$reason]"
            $deprecatedCount++
        }
    }
}
if ($deprecatedCount -eq 0) { Write-Pass "No Godot 3 deprecated API found" }

## ============================================================
## 6/9  .tscn header first-byte validity (ERR-023)
##      Every .tscn must begin with '[' (0x5B) after optional BOM
##      PowerShell Get-Content/Set-Content pipelines can silently strip it
## ============================================================
Write-Host "`n[6/9] Scanning .tscn header first-byte validity (ERR-023)..." -ForegroundColor Yellow
$headerIssues = 0

foreach ($f in $tscnFiles) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($bytes.Length -eq 0) { Write-Warn "Empty .tscn file: $($f.Name)"; continue }

        # Determine start index (skip UTF-8 BOM EF BB BF or UTF-16 BOM FF FE / FE FF)
        $startIdx = 0
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $startIdx = 3
        } elseif ($bytes.Length -ge 2 -and ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)) {
            $startIdx = 2
        } elseif ($bytes.Length -ge 2 -and ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF)) {
            $startIdx = 2
        }

        if ([char]$bytes[$startIdx] -ne '[') {
            $preview = [System.Text.Encoding]::UTF8.GetString($bytes, $startIdx, [Math]::Min(40, $bytes.Length - $startIdx))
            Write-Fail "Invalid .tscn header (ERR-023): $($f.Name) -- first char='$([char]$bytes[$startIdx])' expected '['. Preview: $preview"
            $headerIssues++
        }
    } catch {
        Write-Warn "Cannot read .tscn for header check: $($f.Name) -- $_"
    }
}
if ($headerIssues -eq 0) { Write-Pass "All $($tscnFiles.Count) .tscn files have valid '[gd_scene' headers" }

## ============================================================
## 7/9  SpriteFrames ERR-024: frame dict must use AtlasTexture, not raw region
##
##  BAD (Godot 4 ignores the "region" key in frame dicts):
##    "frames": [{"texture": ExtResource("2_tex"), "region": Rect2(0,0,w,h)}]
##
##  GOOD (AtlasTexture sub-resource with atlas+region, referenced by SubResource):
##    [sub_resource type="AtlasTexture" id="AT_0"]
##    atlas = ExtResource("2_tex")
##    region = Rect2(0, 0, w, h)
##    "frames": [{"texture": SubResource("AT_0"), "duration": 1.0}]
##
##  Detection: a file that has BOTH
##    (a) "texture": ExtResource(    <- raw texture ref inside a frame dict (quoted key)
##    (b) "region": Rect2(           <- region key inside a frame dict (quoted key)
##  is using the wrong format.
##  Note: correct AtlasTexture files have 'atlas = ExtResource(' (no quotes, different key name)
## ============================================================
Write-Host "`n[7/9] Scanning SpriteFrames for ERR-024 (frame dict 'region' instead of AtlasTexture)..." -ForegroundColor Yellow
$spriteFramesIssues = 0

# Exact byte strings to search for (quoted keys only appear in the wrong format)
$wrongTexKey    = '"texture": ExtResource('   # quoted "texture" key = inside frame dict JSON
$wrongRegionKey = '"region": Rect2('          # quoted "region" key = inside frame dict JSON

foreach ($f in $tscnFiles) {
    try {
        $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        if ($content.Contains($wrongTexKey) -and $content.Contains($wrongRegionKey)) {
            Write-Fail "SpriteFrames uses 'region' in frame dict (ERR-024): $($f.Name) -- Replace each frame with an AtlasTexture sub-resource"
            $spriteFramesIssues++
        }
    } catch {
        Write-Warn "Cannot read .tscn for SpriteFrames check: $($f.Name) -- $_"
    }
}
if ($spriteFramesIssues -eq 0) { Write-Pass "All $($tscnFiles.Count) .tscn files use correct AtlasTexture format for SpriteFrames" }

## ============================================================
## 8/9  Godot --check-only GDScript validation (ERR-015)
##      This is the AUTHORITATIVE check for ALL GDScript errors:
##      - Variant type inference (e.g. Array.back() untyped)
##      - Narrowing conversions
##      - Missing type annotations
##      - Compile-time errors that static regex cannot detect
##
##      ⚠️ ROLE ENFORCEMENT: If this check fails, the error message will
##      name the file and line. The DEVELOPER role MUST fix it.
##      Reviewer MUST verify this passes before approving PR.
## ============================================================
Write-Host "`n[8/9] Running Godot --check-only GDScript validation (ERR-015)..." -ForegroundColor Yellow

## Locate Godot executable
$godotPathFile = "C:\Users\88698\.gemini\antigravity-ide\knowledge\godot_executable\artifacts\godot_path.txt"
$godotExe = $null
if (Test-Path $godotPathFile) {
    $godotExe = (Get-Content $godotPathFile -Encoding UTF8).Trim()
}
if (-not $godotExe -or -not (Test-Path $godotExe)) {
    ## Fallback: well-known path
    $godotExe = "C:\Users\88698\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
}

if (-not (Test-Path $godotExe)) {
    Write-Warn "Godot executable not found at '$godotExe' — skipping --check-only (ERR-015). Set path in godot_path.txt."
} else {
    $checkLog = Join-Path $env:TEMP "sensor_godot_check.log"
    try {
        $proc = Start-Process -FilePath $godotExe `
            -ArgumentList @("--headless", "--path", $Root, "--quit", "--check-only") `
            -Wait -NoNewWindow -PassThru `
            -RedirectStandardError $checkLog
        
        $logContent = if (Test-Path $checkLog) { Get-Content $checkLog -Raw } else { "" }
        
        ## Extract error lines (ignore warnings and info lines)
        $errorLines = ($logContent -split "`n") | Where-Object {
            $_ -match "^\s*ERROR:" -and $_ -notmatch "UID duplicate"
        }
        
        if ($errorLines.Count -gt 0) {
            Write-Host "" 
            Write-Host "  ❌ [ERR-015] GDScript compile errors detected:" -ForegroundColor Red
            foreach ($errLine in $errorLines) {
                Write-Host "     $($errLine.Trim())" -ForegroundColor Red
            }
            Write-Host ""
            Write-Host "  ⚠️  ROLE ACTION REQUIRED:" -ForegroundColor Red
            Write-Host "     → DEVELOPER must fix all GDScript errors listed above." -ForegroundColor Red
            Write-Host "     → Check type annotations: use 'var x: Node = arr.back()' not 'var x := arr.back()'" -ForegroundColor Yellow
            Write-Host "     → After fix, re-run: .\scripts\sensor-scan.ps1" -ForegroundColor Yellow
            Write-Fail "GDScript --check-only failed ($($errorLines.Count) error(s)) — see ERR-015 above"
        } else {
            Write-Pass "Godot --check-only: 0 GDScript errors (ERR-015 clear)"
        }
    } catch {
        Write-Warn "Could not run Godot --check-only: $_ — manual validation required"
    } finally {
        if (Test-Path $checkLog) { Remove-Item $checkLog -Force -ErrorAction SilentlyContinue }
    }
}

## ============================================================
## 9/9  SceneTree script calling get_tree() (ERR-028)
##      'extends SceneTree' scripts cannot call get_tree() (that is a Node method).
##      Self IS the SceneTree. Use: await process_frame, not await get_tree().process_frame
## ============================================================
Write-Host "`n[9/9] Scanning for ERR-028 (extends SceneTree using get_tree())..." -ForegroundColor Yellow
$err028Count = 0

foreach ($f in $gdFiles) {
    $lines = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
    $isSceneTree = $false
    foreach ($line in $lines) {
        if ($line.TrimStart().StartsWith("extends SceneTree")) {
            $isSceneTree = $true
        }
    }
    if ($isSceneTree) {
        $lineNo = 0
        foreach ($line in $lines) {
            $lineNo++
            if ($line.Contains("get_tree()")) {
                Write-Fail "ERR-028: extends SceneTree script '$($f.Name)':$lineNo calls get_tree() -- use 'self' (e.g. 'await process_frame' not 'await get_tree().process_frame')"
                $err028Count++
            }
        }
    }
}
if ($err028Count -eq 0) { Write-Pass "No ERR-028: No SceneTree scripts incorrectly calling get_tree()" }

## ============================================================
## Result summary
## ============================================================
Write-Host "`n============================================================" -ForegroundColor Cyan
if ($hasError) {
    Write-Host " [Sensor v5] FAILED -- Critical issues found. Fix before committing." -ForegroundColor Red
    Write-Host " Role action: DEVELOPER must fix GDScript errors; Sensor will re-verify." -ForegroundColor Red
    exit 1
} elseif ($hasWarning) {
    Write-Host " [Sensor v5] PASSED with warnings -- Review warnings before committing." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host " [Sensor v5] PASSED -- No issues found." -ForegroundColor Green
    exit 0
}
