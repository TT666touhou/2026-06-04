# launch_multiplay.ps1
# 一鍵啟動本地多人測試（1個Server視窗 + N個Client視窗）
# 使用方式：
#   .\scripts\launch_multiplay.ps1            # 啟動 1 Server + 1 Client（共2人）
#   .\scripts\launch_multiplay.ps1 -Players 4 # 啟動 1 Server + 3 Client（共4人）
#   .\scripts\launch_multiplay.ps1 -Players 2 -Scene "res://scenes/level/game_world.tscn"

param(
    [int]$Players = 2,
    [string]$Scene = "",
    [switch]$Headless  # Server 以無視窗模式啟動
)

# ── Godot 執行檔路徑 ──────────────────────────────────────────────
$GodotExe = "C:\Users\88698\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
$ProjectPath = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $GodotExe)) {
    Write-Error "找不到 Godot 執行檔：$GodotExe"
    exit 1
}

if ($Players -lt 1 -or $Players -gt 4) {
    Write-Error "玩家數必須在 1-4 之間"
    exit 1
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  本地多人測試啟動器" -ForegroundColor Cyan
Write-Host "  玩家數：$Players（1 Server + $($Players - 1) Client）" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ── 啟動 Server（Player 1）───────────────────────────────────────
$LogDir = Join-Path $ProjectPath "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-Host "`n[1/2] 啟動 Server（Player 1）..." -ForegroundColor Green

$ServerArgs = @(
    "--path", $ProjectPath,
    "--",          # 傳給遊戲的參數分隔符
    "--local-server"  # 遊戲識別此為 Server 啟動
)
if ($Scene -ne "") {
    $ServerArgs += @("--scene", $Scene)
}
if ($Headless) {
    $ServerArgs += "--headless"
}

$ServerLog = Join-Path $LogDir "server.log"
$ServerProc = Start-Process -FilePath $GodotExe `
    -ArgumentList $ServerArgs `
    -PassThru `
    -RedirectStandardOutput $ServerLog `
    -RedirectStandardError "$ServerLog.err"

Write-Host "  Server PID: $($ServerProc.Id)" -ForegroundColor Green
Write-Host "  Log: $ServerLog" -ForegroundColor DarkGray

# ── 等待 Server 啟動 ─────────────────────────────────────────────
Write-Host "`n  等待 Server 啟動（1.5 秒）..." -ForegroundColor DarkGray
Start-Sleep -Milliseconds 1500

# ── 啟動 Client（Player 2, 3, 4）────────────────────────────────
for ($i = 2; $i -le $Players; $i++) {
    Write-Host "`n[2/$Players] 啟動 Client（Player $i）..." -ForegroundColor Yellow
    
    $ClientArgs = @(
        "--path", $ProjectPath,
        "--",
        "--local-client",
        "--player-index", "$i"
    )
    if ($Scene -ne "") {
        $ClientArgs += @("--scene", $Scene)
    }
    
    $ClientLog = Join-Path $LogDir "client_p$i.log"
    $ClientProc = Start-Process -FilePath $GodotExe `
        -ArgumentList $ClientArgs `
        -PassThru `
        -RedirectStandardOutput $ClientLog `
        -RedirectStandardError "$ClientLog.err"
    
    Write-Host "  Client P$i PID: $($ClientProc.Id)" -ForegroundColor Yellow
    Write-Host "  Log: $ClientLog" -ForegroundColor DarkGray
    
    Start-Sleep -Milliseconds 500
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  所有實例已啟動！" -ForegroundColor Cyan
Write-Host "  - F3：切換 Debug Overlay" -ForegroundColor White
Write-Host "  - F4：切換碰撞框顯示" -ForegroundColor White  
Write-Host "  - F5：強制寫出 debug_state.json" -ForegroundColor White
Write-Host "  - Log 檔案位置：$LogDir" -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor Cyan

# ── 監控 debug_state.json ────────────────────────────────────────
Write-Host "`n  [監控模式] 按 Ctrl+C 結束監控..." -ForegroundColor DarkGray
$DebugJson = Join-Path $env:APPDATA "Godot\app_userdata\2026-06-04\debug_state.json"

while ($true) {
    Start-Sleep -Seconds 2
    if (Test-Path $DebugJson) {
        $content = Get-Content $DebugJson -Raw | ConvertFrom-Json
        $fps = $content.fps
        $pc  = $content.player_count
        $ts  = $content.timestamp_str
        Write-Host "[$ts] FPS:$fps  玩家:$pc  場景:$($content.current_scene)" -ForegroundColor DarkGray
    }
}
