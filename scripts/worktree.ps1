# ==============================================================
# scripts/worktree.ps1
# Git Worktree 多 Agent 工作區管理工具
#
# 用途：讓多個 AI Agent 在獨立目錄同時開發不同分支
# 使用：.\scripts\worktree.ps1 [new|list|remove|clean] [args]
# ==============================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("new","list","remove","clean","open")]
    [string]$Action,

    [string]$FeatureName = "",
    [string]$BaseBranch = "main"
)

$WorktreeRoot = "..\worktrees"

function Write-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Magenta
    Write-Host "🌿 Git Worktree — Multi-Agent 工作區管理器" -ForegroundColor Magenta
    Write-Host "============================================================" -ForegroundColor Magenta
}

function New-Worktree {
    param([string]$Feature, [string]$Base)

    if (-not $Feature) {
        Write-Host "❌ 請提供功能名稱。範例：.\scripts\worktree.ps1 new player-movement" -ForegroundColor Red
        exit 1
    }

    $BranchName = "feature/$Feature"
    $WorktreePath = "$WorktreeRoot\$Feature"

    Write-Host "🌱 建立新工作區：$Feature" -ForegroundColor Yellow
    Write-Host "   分支：$BranchName" -ForegroundColor Gray
    Write-Host "   路徑：$WorktreePath" -ForegroundColor Gray
    Write-Host ""

    # 建立 worktrees 父目錄
    if (-not (Test-Path $WorktreeRoot)) {
        New-Item -ItemType Directory -Path $WorktreeRoot | Out-Null
    }

    # 建立新分支並添加 worktree
    git worktree add -b $BranchName $WorktreePath $Base
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ 工作區建立成功！" -ForegroundColor Green
        Write-Host ""
        Write-Host "📋 Agent 使用指引：" -ForegroundColor Cyan
        Write-Host "   1. 在新的終端視窗，進入此工作區路徑" -ForegroundColor White
        Write-Host "   2. 開始開發功能，所有修改僅影響 $BranchName 分支" -ForegroundColor White
        Write-Host "   3. 完成後推送並建立 PR：git push origin $BranchName" -ForegroundColor White
        Write-Host "   4. PR 合併後清理工作區：.\scripts\worktree.ps1 remove $Feature" -ForegroundColor White
        Write-Host ""
        Write-Host "   工作區絕對路徑：$(Resolve-Path $WorktreePath)" -ForegroundColor Yellow
    } else {
        Write-Host "❌ 工作區建立失敗。" -ForegroundColor Red
    }
}

function List-Worktrees {
    Write-Host "📋 目前所有工作區：" -ForegroundColor Yellow
    Write-Host ""
    git worktree list
    Write-Host ""
}

function Remove-Worktree {
    param([string]$Feature)

    if (-not $Feature) {
        Write-Host "❌ 請提供功能名稱。範例：.\scripts\worktree.ps1 remove player-movement" -ForegroundColor Red
        exit 1
    }

    $WorktreePath = "$WorktreeRoot\$Feature"
    Write-Host "🗑️  移除工作區：$Feature" -ForegroundColor Yellow

    git worktree remove $WorktreePath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 工作區已移除。" -ForegroundColor Green
        # 清理空的父目錄
        if ((Get-ChildItem $WorktreeRoot -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item $WorktreeRoot -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "⚠️  如工作區有未提交的變更，使用強制移除：" -ForegroundColor Yellow
        Write-Host "   git worktree remove --force $WorktreePath" -ForegroundColor Gray
    }
}

function Clean-Worktrees {
    Write-Host "🧹 清理所有過期工作區紀錄..." -ForegroundColor Yellow
    git worktree prune
    Write-Host "✅ 清理完成。" -ForegroundColor Green
}

function Open-Worktree {
    param([string]$Feature)
    $WorktreePath = "$WorktreeRoot\$Feature"
    $AbsPath = Resolve-Path $WorktreePath -ErrorAction SilentlyContinue
    if ($AbsPath) {
        # 在 Windows Terminal 新分頁中開啟工作區
        wt -w 0 new-tab --title "Agent: $Feature" --startingDirectory "$AbsPath" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "⚠️  Windows Terminal 未找到，請手動切換到路徑：" -ForegroundColor Yellow
            Write-Host "   $AbsPath" -ForegroundColor White
        } else {
            Write-Host "✅ 已在 Windows Terminal 新分頁開啟工作區：$Feature" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ 找不到工作區：$Feature" -ForegroundColor Red
    }
}

# ——————— 主執行流程 ———————
Write-Header

switch ($Action) {
    "new"    { New-Worktree -Feature $FeatureName -Base $BaseBranch }
    "list"   { List-Worktrees }
    "remove" { Remove-Worktree -Feature $FeatureName }
    "clean"  { Clean-Worktrees }
    "open"   { Open-Worktree -Feature $FeatureName }
}
