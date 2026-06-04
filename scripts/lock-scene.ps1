# ==============================================================
# scripts/lock-scene.ps1
# Git LFS 場景鎖定管理工具 (取代 tscnmerge)
#
# 用途：鎖定 .tscn/.tres 場景，防止多人同時修改導致合併衝突
# 使用：.\scripts\lock-scene.ps1 [lock|unlock|status] [path]
# ==============================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("lock","unlock","status","list")]
    [string]$Action,

    [string]$Path = ""
)

function Write-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "🔒 Godot Scene LFS Lock Manager" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Lock-Scene {
    param([string]$ScenePath)

    if (-not (Test-Path $ScenePath)) {
        Write-Host "❌ 找不到檔案：$ScenePath" -ForegroundColor Red
        exit 1
    }

    $ext = [System.IO.Path]::GetExtension($ScenePath)
    if ($ext -notin @(".tscn", ".tres")) {
        Write-Host "⚠️  警告：$ScenePath 不是 .tscn 或 .tres 檔案" -ForegroundColor Yellow
    }

    Write-Host "🔒 正在鎖定場景：$ScenePath" -ForegroundColor Yellow
    $result = git lfs lock $ScenePath 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 鎖定成功！其他人現在無法修改此場景。" -ForegroundColor Green
        Write-Host "   完成後請執行：.\scripts\lock-scene.ps1 unlock $ScenePath" -ForegroundColor Gray
    } else {
        Write-Host "❌ 鎖定失敗：$result" -ForegroundColor Red
        Write-Host "   可能此場景已被其他人鎖定，請先查看：.\scripts\lock-scene.ps1 list" -ForegroundColor Gray
    }
}

function Unlock-Scene {
    param([string]$ScenePath)

    Write-Host "🔓 正在解鎖場景：$ScenePath" -ForegroundColor Yellow
    $result = git lfs unlock $ScenePath 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 解鎖成功！" -ForegroundColor Green
    } else {
        Write-Host "❌ 解鎖失敗：$result" -ForegroundColor Red
        Write-Host "   如需強制解鎖：git lfs unlock --force $ScenePath" -ForegroundColor Gray
    }
}

function Show-Status {
    param([string]$ScenePath)

    Write-Host "🔍 查詢鎖定狀態：$ScenePath" -ForegroundColor Yellow
    git lfs locks --path $ScenePath
}

function List-AllLocks {
    Write-Host "📋 目前所有鎖定的場景：" -ForegroundColor Yellow
    $locks = git lfs locks 2>&1
    if ($locks) {
        Write-Host $locks -ForegroundColor White
    } else {
        Write-Host "   （目前沒有任何場景被鎖定）" -ForegroundColor Gray
    }
}

# ——————— 主執行流程 ———————
Write-Header

switch ($Action) {
    "lock"   { Lock-Scene -ScenePath $Path }
    "unlock" { Unlock-Scene -ScenePath $Path }
    "status" { Show-Status -ScenePath $Path }
    "list"   { List-AllLocks }
}

Write-Host ""
