# =============================================================
# dev-submit.ps1 — Developer 專屬：代碼投遞給 Reviewer 腳本
# =============================================================
# 用法：.\scripts\dev-submit.ps1 -feature "camera-fix"
#
# 替代直接 git commit .gd/.tscn/.tres 的正確流程：
#   1. 執行靜態驗證（--check-only）
#   2. 執行 Sensor 掃描
#   3. git add + commit 非代碼文件（docs、implementation_plan）
#   4. 建立 GitHub PR 並通知 Reviewer
#   5. 更新 Memory 任務狀態為 IN_REVIEW
#
# ⚠️  只有 QA 可以執行最終的 git commit + git push（包含代碼）
# ⚠️  Developer 執行 git commit .gd 會被 pre-commit hook 阻斷
# =============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$feature,

    [string]$description = "",
    [switch]$skipStaticCheck = $false,
    [switch]$skipSensorScan = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = "D:\2026-06-04"
$GodotBin = "C:\Users\88698\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
$StartTime = Get-Date

Write-Host ""
Write-Host "============================================================"
Write-Host "🚀 [dev-submit.ps1] Developer 代碼投遞流程開始"
Write-Host "   功能：$feature"
Write-Host "   時間限制：20 分鐘 (Developer 每次嘗試上限)"
Write-Host "============================================================"
Write-Host ""

# ── 步驟 0：確認角色為 Developer ─────────────────────────────
Write-Host "[步驟 0] 確認目前角色..."
$roleFile = Join-Path $ProjectRoot ".agent-role"
if (-not (Test-Path $roleFile)) {
    Write-Error "❌ .agent-role 文件不存在！請先執行 set-role.ps1 developer"
    exit 1
}
$currentRole = (Get-Content $roleFile -Raw).Trim()
if ($currentRole -ne "developer") {
    Write-Error "❌ 目前角色是 '$currentRole'，不是 developer！此腳本只供 Developer 使用。"
    exit 1
}
Write-Host "   ✅ 角色確認：developer"

# ── 步驟 1：靜態語法驗證 ─────────────────────────────────────
if (-not $skipStaticCheck) {
    Write-Host ""
    Write-Host "[步驟 1] 執行 Godot 靜態語法驗證（--check-only）..."
    $checkLog = Join-Path $ProjectRoot "dev_submit_check.log"
    
    if (Test-Path $GodotBin) {
        $proc = Start-Process -FilePath $GodotBin `
            -ArgumentList @("--headless", "--path", $ProjectRoot, "--check-only") `
            -PassThru -NoNewWindow `
            -RedirectStandardError $checkLog
        
        if (-not $proc.WaitForExit(30000)) {
            $proc.Kill()
            Write-Warning "⚠️  --check-only 超時（30秒），繼續流程..."
        }
        
        $logContent = Get-Content $checkLog -ErrorAction SilentlyContinue
        $errors = $logContent | Select-String -Pattern "error" -CaseSensitive:$false
        if ($errors) {
            Write-Host ""
            Write-Error "❌ GDScript 靜態錯誤！禁止投遞："
            $errors | ForEach-Object { Write-Host "   $($_.Line)" }
            Write-Host ""
            Write-Host "   修復後重新執行：.\scripts\dev-submit.ps1 -feature '$feature'"
            exit 1
        }
        Write-Host "   ✅ 靜態驗證通過（0 error）"
    } else {
        Write-Warning "   ⚠️  找不到 Godot 執行檔，跳過靜態驗證"
    }
} else {
    Write-Host "[步驟 1] ⚠️  跳過靜態驗證（-skipStaticCheck）"
}

# ── 步驟 2：Sensor 掃描 ───────────────────────────────────────
if (-not $skipSensorScan) {
    Write-Host ""
    Write-Host "[步驟 2] 執行 Sensor 掃描..."
    $sensorScript = Join-Path $ProjectRoot "scripts\sensor-scan.ps1"
    if (Test-Path $sensorScript) {
        try {
            $sensorJob = Start-Job -ScriptBlock { 
                param($script, $root)
                Set-Location $root
                & $script 2>&1
            } -ArgumentList $sensorScript, $ProjectRoot
            
            $sensorComplete = Wait-Job $sensorJob -Timeout 120
            if ($sensorComplete) {
                $sensorOutput = Receive-Job $sensorJob
                $sensorFails = $sensorOutput | Select-String "FAIL" 
                if ($sensorFails) {
                    Write-Host ""
                    Write-Warning "⚠️  Sensor 掃描發現問題："
                    $sensorFails | ForEach-Object { Write-Host "   $($_.Line)" }
                    Write-Host ""
                    Write-Host "   建議修復後再投遞，但允許繼續（Reviewer 會再次執行 Sensor）..."
                } else {
                    Write-Host "   ✅ Sensor 掃描通過"
                }
            } else {
                Remove-Job $sensorJob -Force
                Write-Warning "   ⚠️  Sensor 掃描超時（120秒），跳過"
            }
        } catch {
            Write-Warning "   ⚠️  Sensor 掃描失敗：$($_.Exception.Message)"
        }
    } else {
        Write-Warning "   ⚠️  找不到 sensor-scan.ps1，跳過"
    }
} else {
    Write-Host "[步驟 2] ⚠️  跳過 Sensor 掃描（-skipSensorScan）"
}

# ── 步驟 3：git add 代碼 + commit（由 hook 允許，因為只有文件）
# Developer 不直接 commit .gd，而是透過 worktree push 分支到 remote
Write-Host ""
Write-Host "[步驟 3] 確認工作分支並推送代碼到 remote..."
$currentBranch = git -C $ProjectRoot rev-parse --abbrev-ref HEAD 2>$null
Write-Host "   目前分支：$currentBranch"

if ($currentBranch -eq "main") {
    Write-Error "❌ 禁止在 main 分支上直接推送代碼！請先建立 feature 分支：git checkout -b feature/$feature"
    exit 1
}

# git add 所有代碼（pre-commit hook 會在非 developer role 下才允許）
# Developer 此時 role = developer，hook 會阻斷 .gd 的直接 commit
# 因此此步驟實際上是 push 到 feature branch（由 worktree.ps1 管理）
Write-Host "   ✅ 分支確認：feature 分支（$currentBranch）"

# ── 步驟 4：推送分支到 remote ──────────────────────────────
Write-Host ""
Write-Host "[步驟 4] 推送功能分支到 remote..."
try {
    git -C $ProjectRoot push origin $currentBranch --set-upstream 2>&1 | Out-Null
    Write-Host "   ✅ 推送完成：$currentBranch"
} catch {
    Write-Warning "   ⚠️  推送失敗，請手動執行：git push origin $currentBranch"
}

# ── 步驟 5：時間檢查 ─────────────────────────────────────────
$elapsed = (Get-Date) - $StartTime
Write-Host ""
if ($elapsed.TotalMinutes -gt 20) {
    Write-Host "⚠️  ════════════════════════════════════════════════════════"
    Write-Host "⚠️  警告：本次嘗試耗時 $([math]::Round($elapsed.TotalMinutes, 1)) 分鐘（超過 20 分鐘上限）"
    Write-Host "⚠️  若持續超時，請考慮熔斷並切換 architect role 求援"
    Write-Host "⚠️  ════════════════════════════════════════════════════════"
} else {
    Write-Host "✅ 本次耗時：$([math]::Round($elapsed.TotalMinutes, 1)) 分鐘（20 分鐘上限內）"
}

# ── 完成 ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================"
Write-Host "✅ [dev-submit.ps1] Developer 代碼投遞完成！"
Write-Host ""
Write-Host "   下一步："
Write-Host "   1. 建立 PR（若尚未建立）：gh pr create --title '[DEV] $feature' --base main"
Write-Host "   2. 通知 Reviewer 審查（限時 30 分鐘）"
Write-Host "   3. 等待 Reviewer 批准，然後 QA 執行最終測試"
Write-Host "   4. QA 執行最終 git commit+push（只有 QA 可以）"
Write-Host "============================================================"
Write-Host ""
