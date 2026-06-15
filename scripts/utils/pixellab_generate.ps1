# PixelLab Generation Script
# §O: Only run when user explicitly requests generation
# §O-NOBROWSER: Uses Invoke-RestMethod, never browser
# Usage: .\pixellab_generate.ps1 -Id "1A" -Prompt "..." -Width 16 -Height 16 -DetailStyle "medium"

param(
    [Parameter(Mandatory)][string]$Id,
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][int]$Width,
    [Parameter(Mandatory)][int]$Height,
    [string]$DetailStyle = "medium",
    [string]$OutDir = "D:\2026-06-04\assets\characters\pixellab_experiments"
)

$token = "956460ee-978e-4d60-999a-f4b0f567bb48"
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json" }

# VfxMix 34-color palette
$palette = @(
    "#363232","#453C3C","#62494C","#7F4A50",
    "#56774A","#65725F","#75656A","#8A5E40",
    "#A75064","#AB6E7C","#E55C5C","#D66B48",
    "#5DA16E","#E09656","#D49C73","#E7946D",
    "#B1D368","#EECF5A","#436794","#9D5789",
    "#6F81B3","#77BCD6","#978C8E","#8599B0",
    "#E4A691","#E9CEA1","#BE8EC1","#EDBCCC",
    "#B1DECF","#C2C2C2","#DFE8D3","#F1E9D4",
    "#F1E5F8","#F2F9F8"
)

$body = @{
    description    = $Prompt
    image_size     = @{ width = $Width; height = $Height }
    outline_style  = "none"
    detail_style   = $DetailStyle
    view           = "side"
    direction      = "south"
    no_background  = $true
    color_palette  = $palette
} | ConvertTo-Json -Depth 5

Write-Host "=== Generating $Id ($Width x $Height) ==="

try {
    $r = Invoke-RestMethod -Uri "https://api.pixellab.ai/v2/create-image-pixen" `
        -Method POST -Headers $headers -Body $body
    
    $b64 = $r.image.base64
    $outPath = Join-Path $OutDir "$Id.png"
    [System.IO.File]::WriteAllBytes($outPath, [Convert]::FromBase64String($b64))
    
    Write-Host "SAVED: $outPath"
    Write-Host "Usage: $($r.usage.generations) generations"
    
    return @{ success = $true; path = $outPath; usage = $r.usage.generations }
} catch {
    $err = $_.ErrorDetails.Message
    Write-Host "ERROR: $err"
    return @{ success = $false; error = $err }
}
