# ==============================================================
# scripts/set-role.ps1
# 設定目前 Antigravity Session 的 Agent 角色
#
# 用途：在每個 Antigravity 視窗啟動時執行，宣告此視窗的角色
# 使用：.\scripts\set-role.ps1 [architect|developer|reviewer|qa]
# ==============================================================

# param() 必須是腳本的第一個可執行語句（#注解不算）
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("designer","architect","developer","reviewer","qa","none")]
    [string]$Role
)

# 強制 UTF-8 輸出（修正 Shift-JIS / CP932 系統的中文亂碼問題）
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$RoleFile = ".agent-role"
$RoleColors = @{
    "designer"  = "Blue"
    "architect" = "Cyan"
    "developer" = "Green"
    "reviewer"  = "Yellow"
    "qa"        = "Magenta"
    "none"      = "Gray"
}

$RoleEmoji = @{
    "designer"  = "[DESIGN] "
    "architect" = "[ARCH]   "
    "developer" = "[DEV]    "
    "reviewer"  = "[REVIEW] "
    "qa"        = "[QA]     "
    "none"      = "[NONE]   "
}

$RoleDesc = @{
    "designer"  = "遊戲設計師 — 負責與用戶討論並維護 docs/GAME_DESIGN.md"
    "architect" = "系統架構師 — 負責設計 implementation_plan.md"
    "developer" = "開發者 — 負責撰寫 GDScript 代碼（在 Worktree 中）"
    "reviewer"  = "代碼審查員 — 負責審查 PR 並留下結構化意見"
    "qa"        = "品質保證員 — 負責黑箱測試並建立 QA 報告"
    "none"      = "未設定角色"
}

# 寫入角色文件（不含 BOM，確保 Git Hook 可正確讀取）
[System.IO.File]::WriteAllText("$PWD\$RoleFile", $Role)

Write-Host ""
Write-Host "============================================================" -ForegroundColor $RoleColors[$Role]
Write-Host "$($RoleEmoji[$Role]) 角色設定完成" -ForegroundColor $RoleColors[$Role]
Write-Host "============================================================" -ForegroundColor $RoleColors[$Role]
Write-Host "  角色：$Role" -ForegroundColor White
Write-Host "  職責：$($RoleDesc[$Role])" -ForegroundColor Gray
Write-Host ""
Write-Host "  角色定義文件：.\roles\$Role.md" -ForegroundColor Gray
Write-Host "  請在 Antigravity 對話開始時，將以上文件的內容貼入作為上下文。" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor $RoleColors[$Role]
Write-Host ""

# 顯示此角色的關鍵規則提醒
Write-Host "本角色的 Git Hook 規則：" -ForegroundColor White
switch ($Role) {
    "designer" {
        Write-Host "  [OK]  可以修改：docs/GAME_DESIGN.md（唯一可修改者）" -ForegroundColor Green
        Write-Host "  [NG]  禁止修改：.gd, .tscn, .tres, implementation_plan.md" -ForegroundColor Red
        Write-Host "  [DOC] 工作文件：docs/GAME_DESIGN.md" -ForegroundColor Cyan
        Write-Host "  [TIP] 提示：每次對話開始先讀取 GAME_DESIGN.md 了解目前進度" -ForegroundColor Gray
    }
    "architect" {
        Write-Host "  [OK]  可以提交：implementation_plan.md, docs/, roles/, RULES.md" -ForegroundColor Green
        Write-Host "  [NG]  禁止提交：.gd, .tscn, .tres 文件" -ForegroundColor Red
    }
    "developer" {
        Write-Host "  [OK]  可以提交：.gd, .tscn（需先 LFS Lock）, .tres" -ForegroundColor Green
        Write-Host "  [NG]  禁止提交：直接 push 到 main 的 .gd 文件" -ForegroundColor Red
        Write-Host "  [!!]  修改場景前：.\scripts\lock-scene.ps1 lock <path>" -ForegroundColor Yellow
    }
    "reviewer" {
        Write-Host "  [OK]  可以做：PR 審查、留言、要求修改" -ForegroundColor Green
        Write-Host "  [NG]  禁止做：自行修改代碼文件" -ForegroundColor Red
    }
    "qa" {
        Write-Host "  [OK]  可以提交：docs/qa-report-*.md" -ForegroundColor Green
        Write-Host "  [NG]  禁止提交：任何 .gd 或 .tscn 文件" -ForegroundColor Red
    }
}
Write-Host ""