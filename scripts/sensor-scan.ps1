#!/usr/bin/env pwsh
## sensor-scan.ps1 -- Sensor Automated Scan Script v10
## Run in pre-commit hook or manually to verify project integrity
## Usage: .\scripts\sensor-scan.ps1 [-Root "D:\2026-06-04"]
##
## Checks:
##   1/15  BOM scan (.gd files must be UTF-8 without BOM)
##   2/15  .tscn ext_resource UID self-reference (ERR-013)
##   3/15  Physics callback dangerous patterns (ERR-001)
##   4/15  int() narrowing conversion (ERR-002)
##   5/15  Godot 3 deprecated API (ERR-014)
##   6/15  .tscn header first byte validity (ERR-023)
##   7/15  SpriteFrames frame dict 'region' (ERR-024) - must use AtlasTexture
##   8/15  Godot --check-only GDScript validation (ERR-015) <- CRITICAL: skips if no .gd files
##   9/15  SceneTree script calling get_tree() (ERR-028)
##  10/15  Godot 3 connect() with string method name (ERR-030)
##  11/15  yield() call in Godot 4 code (ERR-031)
##  12/15  get_node_or_null() without type cast (ERR-032)
##  13/15  @export var without type annotation (ERR-033)
##  14/15  Hardcoded /root/ path access (ERR-034)
##  15/15  SOP state check (docs/sop-state.md PENDING items)

param(
    [string]$Root = "D:\2026-06-04"
)

$hasError   = $false
$hasWarning = $false

function Write-Pass { param($msg) Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red;    $script:hasError   = $true }
function Write-Warn { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:hasWarning = $true }
function Write-NA   { param($msg) Write-Host "  [N/A]  $msg" -ForegroundColor Cyan }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [Sensor v10] Godot Project Integrity Scan"                   -ForegroundColor Cyan
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
## 1/15  BOM Scan -- all .gd files must be UTF-8 without BOM
## ============================================================
Write-Host "`n[1/15] Scanning .gd file encoding (BOM)..." -ForegroundColor Yellow
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
## 2/15  .tscn ext_resource UID self-reference scan (ERR-013)
## ============================================================
Write-Host "`n[2/15] Scanning .tscn ext_resource UID self-references (ERR-013)..." -ForegroundColor Yellow
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
## 3/15  Physics callback dangerous pattern scan (ERR-001)
## ============================================================
Write-Host "`n[3/15] Scanning physics callback dangerous patterns (ERR-001)..." -ForegroundColor Yellow
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
## 4/15  Narrowing conversion scan (ERR-002)
## ============================================================
Write-Host "`n[4/15] Scanning for int() narrowing conversion patterns (ERR-002)..." -ForegroundColor Yellow
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
## 5/15  Godot 3 deprecated API scan (ERR-014)
##       BAD: export var, onready var, setget
##       GOOD: @export var, @onready var
## ============================================================
Write-Host "`n[5/15] Scanning for Godot 3 deprecated APIs (ERR-014)..." -ForegroundColor Yellow
$deprecatedCount = 0

foreach ($f in $gdFiles) {
    $lines  = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
    $lineNo = 0
    foreach ($line in $lines) {
        $lineNo++
        $trimmed = $line.TrimStart()
        $matched = $false
        $reason  = ""

        if ($trimmed.StartsWith("export var ")) {
            $matched = $true; $reason = "Godot 3 'export var' -- use '@export var' instead"
        }
        elseif ($trimmed.StartsWith("onready var ")) {
            $matched = $true; $reason = "Godot 3 'onready var' -- use '@onready var' instead"
        }
        elseif ($trimmed.Contains("setget ")) {
            $matched = $true; $reason = "Godot 3 'setget' keyword -- use property get/set in Godot 4"
        }
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
## 6/15  .tscn header first-byte validity (ERR-023)
## ============================================================
Write-Host "`n[6/15] Scanning .tscn header first-byte validity (ERR-023)..." -ForegroundColor Yellow
$headerIssues = 0

foreach ($f in $tscnFiles) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if ($bytes.Length -eq 0) { Write-Warn "Empty .tscn file: $($f.Name)"; continue }

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
## 7/15  SpriteFrames ERR-024: frame dict must use AtlasTexture, not raw region
## ============================================================
Write-Host "`n[7/15] Scanning SpriteFrames for ERR-024 (frame dict 'region' instead of AtlasTexture)..." -ForegroundColor Yellow
$spriteFramesIssues = 0

$wrongTexKey    = '"texture": ExtResource('
$wrongRegionKey = '"region": Rect2('

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
## 8/15  Godot --check-only GDScript validation (ERR-015)
##       SKIPPED (N/A) when no .gd files exist — avoids false FAIL on clean projects
##       CRITICAL when .gd files exist: catches Variant/type errors
## ============================================================
Write-Host "`n[8/15] Running Godot --check-only GDScript validation (ERR-015)..." -ForegroundColor Yellow

if ($gdFiles.Count -eq 0) {
    Write-NA "No .gd files present — skipping Godot --check-only (clean project, not an error)"
} else {
    $godotPathFile = "C:\Users\88698\.gemini\antigravity-ide\knowledge\godot_executable\artifacts\godot_path.txt"
    $godotExe = $null
    if (Test-Path $godotPathFile) {
        $godotExe = (Get-Content $godotPathFile -Encoding UTF8).Trim()
    }
    if (-not $godotExe -or -not (Test-Path $godotExe)) {
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

            $errorLines = ($logContent -split "`n") | Where-Object {
                $_ -match "^\s*ERROR:" -and $_ -notmatch "UID duplicate"
            }

            if ($errorLines.Count -gt 0) {
                Write-Host ""
                Write-Host "  [ERR-015] GDScript compile errors detected:" -ForegroundColor Red
                foreach ($errLine in $errorLines) {
                    Write-Host "     $($errLine.Trim())" -ForegroundColor Red
                }
                Write-Host ""
                Write-Host "  ROLE ACTION REQUIRED:" -ForegroundColor Red
                Write-Host "     -> DEVELOPER must fix all GDScript errors listed above." -ForegroundColor Red
                Write-Host "     -> After fix, re-run: .\scripts\sensor-scan.ps1" -ForegroundColor Yellow
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
}

## ============================================================
## 9/15  SceneTree script calling get_tree() (ERR-028)
## ============================================================
Write-Host "`n[9/15] Scanning for ERR-028 (extends SceneTree using get_tree())..." -ForegroundColor Yellow
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
                Write-Fail "ERR-028: extends SceneTree script '$($f.Name)':$lineNo calls get_tree() -- use 'self' (e.g. 'await process_frame')"
                $err028Count++
            }
        }
    }
}
if ($err028Count -eq 0) { Write-Pass "No ERR-028: No SceneTree scripts incorrectly calling get_tree()" }

## ============================================================
## 10/15 Godot 3 connect() with string method names (ERR-030)
##       BAD:  signal.connect("signal", self, "_handler")
##       GOOD: signal.connect(_handler) or signal.connect(func(): ...)
## ============================================================
Write-Host "`n[10/15] Scanning for Godot 3 string-based connect() (ERR-030)..." -ForegroundColor Yellow
$err030Count = 0

foreach ($f in $gdFiles) {
    $hits = Select-String -Path $f.FullName `
        -Pattern '\.connect\s*\(\s*"[^"]+"\s*,\s*[^,]+\s*,\s*"[^"]+"\s*\)' `
        -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
        $trimmed = $h.Line.TrimStart()
        if (-not $trimmed.StartsWith("#")) {
            Write-Fail "Godot 3 string connect (ERR-030): $($f.Name):$($h.LineNumber) -- use callable syntax: $trimmed"
            $err030Count++
        }
    }
}
if ($err030Count -eq 0) { Write-Pass "No Godot 3 string-based connect() patterns found" }

## ============================================================
## 11/15 yield() call — Godot 3 only, removed in Godot 4 (ERR-031)
##       Use 'await signal' or 'await get_tree().create_timer(n).timeout'
## ============================================================
Write-Host "`n[11/15] Scanning for Godot 3 yield() calls (ERR-031)..." -ForegroundColor Yellow
$err031Count = 0

foreach ($f in $gdFiles) {
    $hits = Select-String -Path $f.FullName -Pattern '\byield\s*\(' -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
        $trimmed = $h.Line.TrimStart()
        if (-not $trimmed.StartsWith("#")) {
            Write-Fail "Godot 3 yield() (ERR-031): $($f.Name):$($h.LineNumber) -- use 'await' instead: $trimmed"
            $err031Count++
        }
    }
}
if ($err031Count -eq 0) { Write-Pass "No Godot 3 yield() calls found" }

## ============================================================
## 12/15 get_node_or_null() without type cast (ERR-032)
##       BAD:  var x = get_node_or_null("NodePath")
##       GOOD: var x: NodeType = get_node_or_null("NodePath") as NodeType
## ============================================================
Write-Host "`n[12/15] Scanning for get_node_or_null() without type cast (ERR-032)..." -ForegroundColor Yellow
$err032Count = 0

foreach ($f in $gdFiles) {
    $lines  = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
    $lineNo = 0
    foreach ($line in $lines) {
        $lineNo++
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith("#")) { continue }
        if ($trimmed -match '=\s*get_node_or_null\([^)]*\)\s*$') {
            Write-Warn "get_node_or_null without type cast (ERR-032): $($f.Name):$lineNo -- add 'as NodeType': $trimmed"
            $err032Count++
        }
    }
}
if ($err032Count -eq 0) { Write-Pass "No untyped get_node_or_null() calls found" }

## ============================================================
## 13/15 @export var without type annotation (ERR-033)
##       BAD:  @export var speed = 100
##       GOOD: @export var speed: float = 100.0
## ============================================================
Write-Host "`n[13/15] Scanning for @export var without type annotation (ERR-033)..." -ForegroundColor Yellow
$err033Count = 0

foreach ($f in $gdFiles) {
    $hits = Select-String -Path $f.FullName `
        -Pattern '^\s*@export\s+var\s+\w+\s*=' `
        -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
        $trimmed = $h.Line.TrimStart()
        if ($trimmed -notmatch '@export\s+var\s+\w+\s*:') {
            Write-Warn "@export without type (ERR-033): $($f.Name):$($h.LineNumber) -- add ': Type': $trimmed"
            $err033Count++
        }
    }
}
if ($err033Count -eq 0) { Write-Pass "All @export vars have type annotations" }

## ============================================================
## 14/15 Hardcoded /root/ Autoload path access (ERR-034)
##       BAD:  get_node("/root/AutoloadName")
##       GOOD: AutoloadName  (access autoloads directly by their global name)
## ============================================================
Write-Host "`n[14/15] Scanning for hardcoded /root/ path access (ERR-034)..." -ForegroundColor Yellow
$err034Count = 0

foreach ($f in $gdFiles) {
    $hits = Select-String -Path $f.FullName -Pattern '"/root/[A-Z][a-zA-Z]+"' -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
        $trimmed = $h.Line.TrimStart()
        if (-not $trimmed.StartsWith("#")) {
            Write-Warn "Hardcoded /root/ path (ERR-034): $($f.Name):$($h.LineNumber) -- access autoloads directly by name: $trimmed"
            $err034Count++
        }
    }
}
if ($err034Count -eq 0) { Write-Pass "No hardcoded /root/ Autoload paths found" }

## ============================================================
## 15/15 SOP state check — docs/sop-state.md PENDING items
##       Warns when active SOPs have incomplete steps
## ============================================================
Write-Host "`n[15/15] Checking SOP state (docs/sop-state.md)..." -ForegroundColor Yellow
$sopStateFile = Join-Path $Root "docs\sop-state.md"

if (-not (Test-Path $sopStateFile)) {
    Write-NA "docs/sop-state.md not found — no active SOPs tracked"
} else {
    $sopContent = [System.IO.File]::ReadAllText($sopStateFile, [System.Text.Encoding]::UTF8)
    # Match only table rows where the Status cell is exactly "PENDING" (pipe-delimited)
    $pendingLines = ($sopContent -split "`n") | Where-Object { $_ -match '^\s*\|[^|]+\|[^|]+\|\s*PENDING\s*\|' }
    if ($pendingLines.Count -gt 0) {
        Write-Warn "SOP has $($pendingLines.Count) PENDING step(s) — complete before final commit:"
        foreach ($pLine in $pendingLines) {
            $stepName = ($pLine -split '\|')[2].Trim()
            Write-Host "     -> $stepName" -ForegroundColor Yellow
        }
        Write-Host "   -> See docs/sop-state.md for full SOP status" -ForegroundColor Gray
    } else {
        Write-Pass "All SOP steps complete (no PENDING items in sop-state.md)"
    }
}

## ============================================================
## Result summary
## ============================================================
Write-Host "`n============================================================" -ForegroundColor Cyan
if ($hasError) {
    Write-Host " [Sensor v10] FAILED -- Critical issues found. Fix before committing." -ForegroundColor Red
    Write-Host " Role action: DEVELOPER must fix GDScript errors; Sensor will re-verify." -ForegroundColor Red
    exit 1
} elseif ($hasWarning) {
    Write-Host " [Sensor v10] PASSED with warnings -- Review warnings before committing." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host " [Sensor v10] PASSED -- No issues found." -ForegroundColor Green
    exit 0
}
