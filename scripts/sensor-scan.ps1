#!/usr/bin/env pwsh
## sensor-scan.ps1 -- Sensor Automated Scan Script v10
## Run in pre-commit hook or manually to verify project integrity
## Usage: .\scripts\sensor-scan.ps1 [-Root "D:\2026-06-04"]
##
## Checks:
##   1/14  BOM scan (.gd files must be UTF-8 without BOM)
##   2/14  .tscn ext_resource UID self-reference (ERR-013)
##   3/14  Physics callback dangerous patterns (ERR-001)
##   4/14  int() narrowing conversion (ERR-002)
##   5/14  Godot 3 deprecated API (ERR-014)
##   6/14  .tscn header first byte validity (ERR-023)
##   7/14  SpriteFrames frame dict 'region' (ERR-024) - must use AtlasTexture
##   8/14  Godot --check-only GDScript validation (ERR-015) ← CRITICAL: catches Variant/type errors
##   9/14  SceneTree script calling get_tree() (ERR-028) - extends SceneTree cannot call Node methods
##   10/14 GAME_DESIGN.md content integrity (ERR-DOC-001) - GDD corruption + TODO scan [GAP-001/004/010]
##   11/14 Variant node property access with := (ERR-030) - use explicit type: var x: Node2D = node as Node2D
##   12/14 TileSet .tres missing tile_size (ERR-031) - every TileSet must have explicit tile_size in [resource]
##   13/14 Func param shadowing base class property (ERR-033) - visible/position/name etc. as param names
##   14/14 make_current() before add_child (ERR-034) - node must be in tree before calling tree-dependent API

param(
    [string]$Root = "D:\2026-06-04"
)

$hasError   = $false
$hasWarning = $false

function Write-Pass { param($msg) Write-Host "  [PASS] $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red;    $script:hasError   = $true }
function Write-Warn { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:hasWarning = $true }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [Sensor v9] Godot Project Integrity Scan"                    -ForegroundColor Cyan
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
## 10/10  GAME_DESIGN.md Content Integrity (ERR-DOC-001) [GAP-001/004/010]
##
##  This check addresses the "silent GDD corruption" gap where:
##  - PowerShell -replace causes Chinese character corruption (e.g. 疫空 燔斷)
##  - Critical GDD sections lose their content without any error
##  - [GDD TODO] markers are left unresolved
##
##  Enforces:
##  (a) No known garbled characters from ERR-DOC-001 list
##  (b) Key section anchor keywords must exist (cross-check with sensor.md Level 3)
##  (c) No unresolved [GDD TODO] markers (QA must not pass with these)
##
##  ⚠️ ROLE ENFORCEMENT:
##     - If CORRUPT: Designer must use replace_file_content tool to fix
##     - If MISSING_KEYWORDS: Designer must verify the section was not accidentally erased
##     - If GDD_TODO: QA must require Designer to resolve before signing off
## ============================================================
Write-Host "`n[10/10] Scanning GAME_DESIGN.md content integrity (ERR-DOC-001 / GAP-001/004/010)..." -ForegroundColor Yellow
$gddIssues = 0

$gddPath = Join-Path $Root "docs\GAME_DESIGN.md"
if (-not (Test-Path $gddPath)) {
    Write-Warn "GAME_DESIGN.md not found at '$gddPath' -- skipping GDD integrity check"
} else {
    $gddContent = [System.IO.File]::ReadAllText($gddPath, [System.Text.Encoding]::UTF8)

    # --- (a) Known garbled characters from ERR-DOC-001 ---
    # These arise when PowerShell -replace processes Chinese text with $1 expanding to empty.
    # We use Unicode codepoints to avoid encoding issues in this .ps1 file itself.
    # U+75AB = corrupted "liu" (should be U+7559 = stay/reserve)
    # U+71D4 = corrupted char, U+9120 = corrupted char, U+9150 = corrupted char
    $corruptList = @(
        ([char]0x75AB + [char]0x7A7A),   # U+75AB U+7A7A = corrupted (should be: U+7559 = 留空)
        ([char]0x71D4 + [char]0x65B7),   # garbled variant
        ([char]0x9120 + [char]0x6838),   # garbled variant
        ([char]0x9150 + [char]0x65AD),   # garbled variant
        ([char]0x6E3A + [char]0x8A8D),   # garbled variant
        ([char]0x7A2E + [char]0x5165),   # garbled variant
        ([char]0x9881 + [char]0x5E03),   # garbled variant of U+767C U+5E03 (fa bu)
        [char]0x6DAD,                     # isolated garbled char
        ([char]0x6E3A + [char]0x832B)    # garbled variant
    )
    $corruptFound = @()
    foreach ($c in $corruptList) {
        if ($gddContent.Contains($c)) { $corruptFound += "U+$('{0:X4}' -f [int][char]$c[0])" }
    }
    if ($corruptFound.Count -gt 0) {
        Write-Fail "ERR-DOC-001: GAME_DESIGN.md contains garbled Unicode chars: $($corruptFound -join ', ')"
        Write-Host "   Root cause: PowerShell -replace was used on .md file, causing Chinese char corruption" -ForegroundColor Red
        Write-Host "   Fix: Use replace_file_content tool to restore the affected section" -ForegroundColor Yellow
        Write-Host "   Role: DESIGNER must fix before any commit" -ForegroundColor Yellow
        $gddIssues++
    } else {
        Write-Pass "GDD has no known garbled characters (ERR-DOC-001 clear)"
    }

    # --- (b) Key section keyword presence check (sensor.md Level 3 enforcement) ---
    # These ASCII/mixed keywords must exist to confirm critical GDD sections were not erased
    $requiredKeywords = @{
        'MeleeSlash.tscn'            = 'sec-8.3 (Melee VFX design)'
        '_spawn_melee_vfx_at_marker' = 'sec-8.3.1 (VFX Marker method)'
        'target_room_path'           = 'sec-10.5 (door connection/target_room property)'
        'start_room_entry'           = 'sec-10.11 (Walk-in room entry transition)'
    }
    $missingKeywords = @()
    foreach ($kw in $requiredKeywords.Keys) {
        if (-not $gddContent.Contains($kw)) {
            $missingKeywords += "'$kw' (section: $($requiredKeywords[$kw]))"
        }
    }
    if ($missingKeywords.Count -gt 0) {
        Write-Fail "GDD missing critical section keywords:"
        foreach ($m in $missingKeywords) {
            Write-Host "     Missing: $m" -ForegroundColor Red
        }
        Write-Host "   Possible cause: Section was accidentally erased by a PowerShell operation" -ForegroundColor Yellow
        Write-Host "   Role: DESIGNER must restore the missing section from git history" -ForegroundColor Yellow
        $gddIssues++
    } else {
        Write-Pass "GDD all $($requiredKeywords.Count) critical section keywords present"
    }

    # --- (c) Unresolved [GDD TODO] markers ---
    $gddTodoMatches = [regex]::Matches($gddContent, '\[GDD TODO\]')
    if ($gddTodoMatches.Count -gt 0) {
        Write-Warn "GDD has $($gddTodoMatches.Count) unresolved [GDD TODO] marker(s) -- QA must NOT pass until Designer resolves all"
        $gddLines = $gddContent -split "`n"
        $lineNo = 0
        foreach ($line in $gddLines) {
            $lineNo++
            if ($line.Contains('[GDD TODO]')) {
                Write-Host "     Line ${lineNo}: $($line.Trim())" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Pass "GDD has no unresolved [GDD TODO] markers"
    }
}
if ($gddIssues -eq 0) { if (Test-Path $gddPath) { Write-Pass "GDD content integrity check complete" } }

## ============================================================
## 11/12  Variant node property access with := (ERR-030)
##
##  BAD: var cam_zone = get_node_or_null("X")   ← untyped Variant
##       var x := cam_zone.global_position       ← Cannot infer type
##
##  GOOD: var cam_zone: Node2D = get_node_or_null("X") as Node2D
##        var x: Vector2 = cam_zone.global_position
##
##  Detection: pattern  var X = get_node_or_null(  (no colon-type)
##             followed by: var Y := <X>.   (property on untyped var)
## ============================================================
Write-Host "`n[11/12] Scanning for ERR-030 (Variant := property access on get_node_or_null)..." -ForegroundColor Yellow
$err030Count = 0

foreach ($f in $scriptFiles) {
    $lines = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
    ## Collect all variable names assigned with untyped get_node_or_null (no ': Type' annotation)
    $untypedNodes = @{}
    $lineNo = 0
    foreach ($line in $lines) {
        $lineNo++
        $trimmed = $line.TrimStart()
        if ($trimmed.StartsWith('#')) { continue }
        ## Match: var varname = get_node_or_null(  [no colon-type before = ]
        if ($trimmed -match '^var\s+(\w+)\s*=\s*get_node_or_null\(') {
            $varName = $Matches[1]
            $untypedNodes[$varName] = $lineNo
        }
        ## Match: var Y := untypedVar.someProperty  (not .get_node_or_null, which returns Variant but is OK to chain)
        foreach ($uv in $untypedNodes.Keys) {
            if ($trimmed -match "^var\s+\w+\s*:=\s*${uv}\.(global_position|position|rotation|scale|transform|size)") {
                Write-Fail "ERR-030: Variant property access with := in '$($f.Name)':$lineNo -- '$trimmed'. Declare '$uv' with explicit type: 'var ${uv}: Node2D = get_node_or_null(...) as Node2D'"
                $err030Count++
                break
            }
        }
    }
}
if ($err030Count -eq 0) { Write-Pass "No ERR-030: No untyped Variant property access with :=" }

## ============================================================
## 12/12  TileSet .tres missing tile_size (ERR-031)
##
##  Every TileSet .tres [resource] block MUST have explicit tile_size.
##  Missing tile_size → Godot uses default Vector2i(16,16).
##  If texture tiles are 8x8, this causes editor grid misalignment.
##
##  Detection: file has type="TileSet" header AND [resource] block
##             but [resource] block does NOT contain 'tile_size ='
## ============================================================
Write-Host "`n[12/12] Scanning TileSet .tres for missing tile_size (ERR-031)..." -ForegroundColor Yellow
$err031Count = 0

$tresFiles = [array](Get-ChildItem $Root -Recurse -Filter "*.tres" -ErrorAction SilentlyContinue |
    Where-Object { -not $_.FullName.Contains("\.git\") })
if ($null -eq $tresFiles) { $tresFiles = @() }

foreach ($f in $tresFiles) {
    try {
        $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        ## Only process TileSet resources
        if (-not ($content -match 'gd_resource type="TileSet"')) { continue }
        ## Find last [resource] block (root resource)
        $resIdx = $content.LastIndexOf('[resource]')
        if ($resIdx -lt 0) { continue }
        $resBlock = $content.Substring($resIdx, [Math]::Min(400, $content.Length - $resIdx))
        if (-not ($resBlock -match 'tile_size\s*=')) {
            Write-Fail "ERR-031: TileSet .tres missing tile_size in [resource] block: '$($f.Name)'. Add 'tile_size = Vector2i(W, H)' to [resource] block (check texture tile dimensions first)."
            $err031Count++
        }
    } catch {
        Write-Warn "Cannot read .tres for ERR-031 check: $($f.Name) -- $_"
    }
}
if ($err031Count -eq 0) { Write-Pass "All TileSet .tres have explicit tile_size (ERR-031 clear)" }

## ============================================================
## 13/14  Func param shadowing base class property (ERR-033)
##
##  GDScript 4 reports shadowing warning when a function parameter
##  has the same name as an inherited property (visible, position, etc.)
##  Detects: func xxx(visible:), func xxx(position:), etc.
## ============================================================
Write-Host "`n[13/14] Scanning for ERR-033 (func param shadowing base class property)..." -ForegroundColor Yellow
$shadowProps  = @('visible','position','rotation','scale','modulate','name','owner','process_mode','transform','z_index')
$err033Count  = 0
foreach ($f in $gdFiles) {
    try {
        $lines = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
        $lineNo = 0
        foreach ($line in $lines) {
            $lineNo++
            $trimmed = $line.TrimStart()
            if ($trimmed -match '^func\s+\w+\s*\(') {
                foreach ($prop in $shadowProps) {
                    ## Match: func xxx(visible:  or  func xxx(..., visible:
                    if ($trimmed -match "\b${prop}\s*:") {
                        Write-Fail "ERR-033: Func param '$prop' shadows base class property in '$($f.Name)':$lineNo. Rename param to avoid shadowing (e.g. 'show_hint' instead of 'visible')."
                        $err033Count++
                    }
                }
            }
        }
    } catch {
        Write-Warn "Cannot read file for ERR-033 check: $($f.Name) -- $_"
    }
}
if ($err033Count -eq 0) { Write-Pass "No ERR-033: No func param shadowing base class properties" }

## ============================================================
## 14/14  make_current() before add_child (ERR-034)
##
##  Camera2D.make_current() requires is_inside_tree() == true.
##  Detects: make_current() on the line BEFORE add_child() for same var.
##  Heuristic: 'make_current' appears before 'add_child' within 5 lines
##  in the same function body.
## ============================================================
Write-Host "`n[14/14] Scanning for ERR-034 (make_current() before add_child())..." -ForegroundColor Yellow
$err034Count = 0
foreach ($f in $gdFiles) {
    try {
        $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $lines   = $content -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $trimmedI = $lines[$i].TrimStart()
            ## Skip comment lines
            if ($trimmedI.StartsWith('#')) { continue }
            if ($trimmedI -match '\bmake_current\b\(\)') {
                ## Look AHEAD up to 6 non-comment lines for add_child
                ## If add_child appears AFTER make_current → ERR-034
                $window_end = [Math]::Min($lines.Count - 1, $i + 6)
                for ($j = $i + 1; $j -le $window_end; $j++) {
                    $trimmedJ = $lines[$j].TrimStart()
                    ## Skip comment lines in the window
                    if ($trimmedJ.StartsWith('#')) { continue }
                    if ($trimmedJ -match '\badd_child\b') {
                        Write-Fail "ERR-034: make_current() at line $($i+1) appears BEFORE add_child() at line $($j+1) in '$($f.Name)'. Node must be in scene tree before calling make_current()."
                        $err034Count++
                        break
                    }
                }
            }
        }
    } catch {
        Write-Warn "Cannot read file for ERR-034 check: $($f.Name) -- $_"
    }
}
if ($err034Count -eq 0) { Write-Pass "No ERR-034: No make_current() before add_child() patterns" }

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
    Write-Host " [Sensor v10] PASSED (14/14) -- No issues found." -ForegroundColor Green
    exit 0
}
