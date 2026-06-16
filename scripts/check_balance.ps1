$r = Invoke-RestMethod -Uri "https://api.pixellab.ai/v2/balance" -Headers @{Authorization="Bearer 956460ee-978e-4d60-999a-f4b0f567bb48"}
$r | ConvertTo-Json
