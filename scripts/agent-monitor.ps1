# ==============================================================
# scripts/agent-monitor.ps1
# Windows Terminal 多 Agent 監控儀表板 (Agent Deck 替代方案)
#
# 用途：一鍵開啟 Windows Terminal，分割成多個 pane，
#       每個 pane 對應一個 AI Agent 工作區，作為視覺化監控儀表板
# 使用：.\scripts\agent-monitor.ps1
# ==============================================================

param(
    [int]$AgentCount = 2,
    [string[]]$FeatureNames = @()
)

function Write-Header {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "🖥️  Multi-Agent 監控儀表板 (Windows Terminal)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Start-AgentDashboard {
    Write-Header

    # 取得目前 Git 專案根目錄
    $ProjectRoot = (git rev-parse --show-toplevel 2>$null).Trim()
    if (-not $ProjectRoot) {
        $ProjectRoot = (Get-Location).Path
    }

    Write-Host "📂 專案根目錄：$ProjectRoot" -ForegroundColor Yellow
    Write-Host ""

    # 取得所有 worktrees
    $WorktreeList = git worktree list --porcelain 2>$null
    $WorktreePaths = @($ProjectRoot)
    $WorktreeBranches = @("main")

    if ($WorktreeList) {
        $lines = $WorktreeList -split "`n"
        $currentPath = ""
        $currentBranch = ""
        foreach ($line in $lines) {
            if ($line -match "^worktree (.+)") {
                $currentPath = $matches[1].Trim()
            } elseif ($line -match "^branch refs/heads/(.+)") {
                $currentBranch = $matches[1].Trim()
                if ($currentPath -ne $ProjectRoot) {
                    $WorktreePaths += $currentPath
                    $WorktreeBranches += $currentBranch
                }
            }
        }
    }

    $TotalAgents = $WorktreePaths.Count
    Write-Host "🤖 偵測到 $TotalAgents 個工作區（Agent 槽位）：" -ForegroundColor Cyan
    for ($i = 0; $i -lt $TotalAgents; $i++) {
        Write-Host "   [$i] $($WorktreeBranches[$i]) → $($WorktreePaths[$i])" -ForegroundColor White
    }
    Write-Host ""

    # 檢查 Windows Terminal 是否可用
    $WtAvailable = $null -ne (Get-Command wt -ErrorAction SilentlyContinue)

    if (-not $WtAvailable) {
        Write-Host "⚠️  找不到 Windows Terminal (wt)。" -ForegroundColor Yellow
        Write-Host "   請從 Microsoft Store 安裝：Windows Terminal" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   替代方式：手動在以下路徑開啟終端視窗：" -ForegroundColor Yellow
        for ($i = 0; $i -lt $TotalAgents; $i++) {
            Write-Host "   → $($WorktreePaths[$i])  (分支: $($WorktreeBranches[$i]))" -ForegroundColor White
        }
        exit 0
    }

    # 組建 Windows Terminal 指令：主視窗 + split panes
    Write-Host "🚀 正在啟動 Windows Terminal 多 pane 儀表板..." -ForegroundColor Green

    # 第一個 pane：主工作區
    $WtCmd = "wt --title `"🎮 Agent Dashboard`" " +
             "--startingDirectory `"$($WorktreePaths[0])`" " +
             "new-tab --title `"[main] $($WorktreeBranches[0])`" " +
             "--startingDirectory `"$($WorktreePaths[0])`""

    # 後續 panes：各 feature worktrees
    for ($i = 1; $i -lt $TotalAgents; $i++) {
        $WtCmd += "; split-pane --title `"[Agent $i] $($WorktreeBranches[$i])`" " +
                  "--startingDirectory `"$($WorktreePaths[$i])`""
    }

    Invoke-Expression $WtCmd
    Write-Host "✅ 儀表板已啟動！每個 pane 對應一個 Agent 工作區。" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 使用提示：" -ForegroundColor Cyan
    Write-Host "   • Alt+Shift+D：在 Windows Terminal 中水平分割 pane" -ForegroundColor Gray
    Write-Host "   • Alt+Left/Right：切換 pane" -ForegroundColor Gray
    Write-Host "   • 新增 worktree：.\scripts\worktree.ps1 new [feature-name]" -ForegroundColor Gray
    Write-Host ""
}

Start-AgentDashboard
