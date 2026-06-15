# fetch_reference.ps1 - §P 視覺參考獲取工具（整合版）
# 
# 用途：整合 §P P2-A/C/E 的參考圖片獲取方法
# 使用：.\scripts\utils\fetch_reference.ps1 -Method A -Url "https://..."
#       .\scripts\utils\fetch_reference.ps1 -Method C -YoutubeUrl "https://youtu.be/..." -Timestamp "00:01:30"
#       .\scripts\utils\fetch_reference.ps1 -Method E -GifPath "C:\Temp\char.gif"
#
# §P 文件：C:\Users\88698\.gemini\antigravity-ide\knowledge\godot_multiagent_workflow\artifacts\workflow.md

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("A", "C", "E")]
    [string]$Method,
    
    [string]$Url,
    [string]$YoutubeUrl,
    [string]$Timestamp = "00:00:30",
    [string]$GifPath,
    [string]$OutDir = "$env:TEMP\ds_ref_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)

Write-Host "============================================================"
Write-Host "[§P] 視覺參考獲取工具 v1"
Write-Host "     方法：$Method | 輸出：$OutDir"
Write-Host "============================================================"

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

switch ($Method) {
    "A" {
        # §P P2-A: 直連 URL 抓取
        if (!$Url) { Write-Error "方法 A 需要 -Url 參數"; exit 1 }
        Write-Host "[P2-A] 抓取：$Url"
        $filename = [System.IO.Path]::GetFileName($Url.Split("?")[0])
        if (!$filename) { $filename = "image_$(Get-Date -Format 'HHmmss').png" }
        $outPath = Join-Path $OutDir $filename
        
        try {
            $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
            Invoke-WebRequest -Uri $Url -OutFile $outPath -Headers $headers -TimeoutSec 30
            $size = (Get-Item $outPath).Length
            Write-Host "[P2-A] ✅ 完成：$outPath ($size bytes)"
            Write-Host "[P2-A] 請使用 view_file 工具加載此圖片進行 AI Vision 分析"
        } catch {
            Write-Error "[P2-A] ❌ 失敗：$($_.Exception.Message)"
        }
    }
    
    "C" {
        # §P P2-C: yt-dlp + FFmpeg 擷取幀
        if (!$YoutubeUrl) { Write-Error "方法 C 需要 -YoutubeUrl 參數"; exit 1 }
        
        # 檢查工具是否安裝
        $ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue
        $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
        
        if (!$ytdlp) {
            Write-Error "未安裝 yt-dlp。請執行：winget install yt-dlp.yt-dlp"
            exit 1
        }
        if (!$ffmpeg) {
            Write-Error "未安裝 ffmpeg。請執行：winget install Gyan.FFmpeg"
            exit 1
        }
        
        Write-Host "[P2-C] YouTube：$YoutubeUrl"
        Write-Host "[P2-C] 時間點：$Timestamp"
        Write-Host "[P2-C] 正在取得串流 URL..."
        
        try {
            $streamUrl = yt-dlp -f "best[height<=1080][ext=mp4]" --get-url $YoutubeUrl 2>$null
            if (!$streamUrl) {
                $streamUrl = yt-dlp --get-url $YoutubeUrl 2>$null
            }
            
            if (!$streamUrl) {
                Write-Error "[P2-C] ❌ 無法取得串流 URL，請確認影片可存取"
                exit 1
            }
            
            Write-Host "[P2-C] 正在擷取幀..."
            $outPath = Join-Path $OutDir "frame_$($Timestamp -replace ':', '_').png"
            
            # 擷取單幀
            ffmpeg -ss $Timestamp -i $streamUrl -vframes 1 -q:v 2 $outPath -y 2>&1 | Select-String "frame|error" | Write-Host
            
            if (Test-Path $outPath) {
                $size = (Get-Item $outPath).Length
                Write-Host "[P2-C] ✅ 完成：$outPath ($size bytes)"
                Write-Host "[P2-C] 提示：使用 view_file 工具加載此截圖進行 AI Vision 分析"
            } else {
                Write-Error "[P2-C] ❌ 未生成截圖，請確認 URL 和時間點"
            }
        } catch {
            Write-Error "[P2-C] ❌ 錯誤：$($_.Exception.Message)"
        }
    }
    
    "E" {
        # §P P2-E: ImageMagick GIF 拆幀分析
        if (!$GifPath) { Write-Error "方法 E 需要 -GifPath 參數"; exit 1 }
        if (!(Test-Path $GifPath)) { Write-Error "GIF 文件不存在：$GifPath"; exit 1 }
        
        $magick = Get-Command magick -ErrorAction SilentlyContinue
        if (!$magick) {
            Write-Error "未安裝 ImageMagick。請執行：winget install ImageMagick.ImageMagick"
            exit 1
        }
        
        Write-Host "[P2-E] 分析 GIF：$GifPath"
        
        # 1. 基本資訊
        Write-Host "`n[P2-E] --- 基本資訊 ---"
        magick identify $GifPath
        
        # 2. 拆幀
        Write-Host "`n[P2-E] --- 拆幀 ---"
        magick $GifPath -coalesce "$OutDir\frame_%d.png"
        $frames = Get-ChildItem $OutDir -Filter "frame_*.png"
        Write-Host "[P2-E] 共 $($frames.Count) 幀，已儲存至 $OutDir"
        
        # 3. 色彩分析（第一幀）
        Write-Host "`n[P2-E] --- 色彩直方圖（前20色） ---"
        magick $GifPath[0] -format "%c" histogram:info: | Select-Object -First 20
        
        # 4. 唯一色彩圖
        magick $GifPath[0] -unique-colors "$OutDir\unique_colors.png"
        Write-Host "[P2-E] 唯一色彩圖：$OutDir\unique_colors.png"
        
        Write-Host "`n[P2-E] ✅ 完成！請依序使用 view_file 工具分析各幀圖片"
        Get-ChildItem $OutDir | Select-Object Name, Length | Format-Table
    }
}

Write-Host "`n============================================================"
Write-Host "[§P] 完成。請記得分析後刪除臨時文件（不 commit）"
Write-Host "     刪除：Remove-Item -Path '$OutDir' -Recurse"
Write-Host "============================================================"
