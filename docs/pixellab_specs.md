# PixelLab 角色規格文件 — Pixel Art Character Specs
> **維護者**：Designer ROLE  
> **用途**：定義所有 PixelLab API 呼叫的角色規格與 Prompt  
> **引用**：workflow.md §O | GDD 第 3.2 節  
> **格式**：每個角色一個區塊，狀態標記參考 GDD 格式

---

## 帳戶配額追蹤

| 項目 | 數值 |
|------|------|
| API Token | `956460ee-978e-4d60-999a-f4b0f567bb48` |
| 訂閱方案 | Trial |
| 初始配額 | 40 次 |
| 已使用 | 0 次（截至 2026-06-15）|
| 剩餘 | ~14.9 次（上次查詢 2026-06-15）|
| **警戒線** | **< 3 次時 → 立即通知 Designer** |

> [!CAUTION]
> Developer 每次執行 `pixellab_generate.py` 前，**必須**先執行餘額檢查。
> 確認 `remaining >= 1` 後才可繼續。

---

## 技術規格（所有角色共用）

| 規格 | 數值 | 說明 |
|------|------|------|
| API Base URL | `https://api.pixellab.ai/v2` | |
| 主要 Endpoint | `POST /create-image-pixflux` | 同步返回，支援透明背景 |
| 認證 | `Bearer TOKEN` | |
| 最小尺寸 | `32×32 px` | API 限制 |
| 最大尺寸 | `400×400 px` | API 限制 |
| 目標尺寸 | `32×32 px` | 符合 GDD：8px tile × 4 = 32px |
| 背景 | `transparent` | `no_background: true` |
| 輸出格式 | PNG（base64）| |
| 保存路徑 | `assets/characters/` | |

---

## 角色規格清單

### CHAR-001：Player Base（玩家基底）
- **GDD 對應**：§6.1 玩家外觀
- **狀態**：`[PIXELLAB_READY]`
- **優先度**：🔴 P1（最高）
- **圖片尺寸**：32×32 px
- **Endpoint**：`/create-image-pixflux`

**Prompt（英文）**：
```
2D side-scrolling platformer hero, male warrior with simple leather armor,
short sword on belt, 8-bit pixel art style, castlevania dark fantasy,
side view facing left, small character about 22 pixels tall,
transparent background, clean minimal pixel art, dark dungeon atmosphere,
retro game sprite, dark color palette
```

**預期外觀**（依 GDD）：
- 身高約 22px（2.75 tiles @ 8px）
- 側視圖（2D platformer）
- 深色系配色
- 簡潔的盔甲設計

**輸出文件**：`assets/characters/player_base_YYYYMMDD_HHMMSS.png`

---

### CHAR-002：Enemy1 - 地面巡邏骷髏（Ground Patrol Skeleton）
- **GDD 對應**：§4.3 enemy1.gd，§3.2 E-01
- **狀態**：`[PIXELLAB_READY]`
- **優先度**：🔴 P2
- **圖片尺寸**：32×32 px
- **Endpoint**：`/create-image-pixflux`

**Prompt（英文）**：
```
skeleton warrior enemy soldier with tattered cloth and simple sword,
8-bit pixel art, side view facing left, dark dungeon castlevania style,
transparent background, small character 22 pixels tall,
retro game sprite, dark fantasy, minimal color palette,
simple clean design for game enemy
```

**預期外觀**（依 GDD）：
- E-01 骨骼類型（Humanoid/骷髏）
- 3×4 tiles 大小（~3 tiles = 24px 寬，4 tiles = 32px 高）
- 橙色色調（P1 顏色 #FF8C42 的中性版本）

**輸出文件**：`assets/characters/enemy1_patrol_YYYYMMDD_HHMMSS.png`

---

### CHAR-003：Enemy3 - 遠程射手（Ranged Archer）
- **GDD 對應**：§4.3 enemy3.gd，射擊 bullet_enemy3.tscn
- **狀態**：`[PIXELLAB_READY]`
- **優先度**：🔴 P3
- **圖片尺寸**：32×32 px
- **Endpoint**：`/create-image-pixflux`

**Prompt（英文）**：
```
small goblin archer enemy, holding a short bow raised to shoot,
8-bit pixel art style, side view facing left,
dark dungeon fantasy style, transparent background,
22 pixels tall, retro castlevania game sprite,
minimal palette, clean pixel art
```

**預期外觀**（依 GDD）：
- E-03 類型（Humanoid/輕甲）
- 3×4 tiles 大小
- 持弓姿勢（便於識別為遠程敵人）

**輸出文件**：`assets/characters/enemy3_ranged_YYYYMMDD_HHMMSS.png`

---

### CHAR-004：Enemy2 - 盾兵（Shield Soldier）[可選]
- **GDD 對應**：§4.3 enemy2.gd，spawn_disabled 行為
- **狀態**：`[DRAFT]`（暫緩，配額不足時跳過）
- **優先度**：🟡 P4
- **圖片尺寸**：32×32 px

**Prompt（英文）**：
```
armored enemy soldier with round shield and short spear,
defending pose, 8-bit pixel art, side view,
dark castlevania dungeon style, transparent background,
22 pixels tall, retro game sprite
```

---

### CHAR-005：Boss Preview（Boss 預覽）[可選]
- **GDD 對應**：§4.5 Boss 設計（DRAFT 狀態）
- **狀態**：`[DRAFT]`（GDD Boss 章節仍是 DRAFT，暫緩）
- **優先度**：🟡 P5
- **圖片尺寸**：48×48 px

**Prompt（英文）**：
```
large dark fantasy boss demon lord with horns and dark armor,
imposing menacing pose, 8-bit pixel art, side view,
castlevania style, transparent background, 44 pixels tall,
retro game boss sprite, dramatic dark atmosphere
```

---

## 執行說明（Developer 執行前必讀）

### Step 1：確認餘額
```powershell
$headers = @{ "Authorization" = "Bearer 956460ee-978e-4d60-999a-f4b0f567bb48" }
$balance = Invoke-RestMethod -Uri "https://api.pixellab.ai/v2/balance" -Headers $headers
Write-Host "剩餘次數: $($balance.subscription.generations)"
if ($balance.subscription.generations -lt 3) {
    Write-Error "⚠️ 配額不足！停止執行，通知 Designer"
    exit 1
}
```

### Step 2：執行生成腳本
```powershell
# 確認 Python 可用
python --version

# 執行生成（預設只生成 P1~P3 優先度的角色）
python D:\2026-06-04\scripts\utils\pixellab_generate.py
```

### Step 3：驗收
1. 確認 `assets/characters/` 下有新 PNG 文件
2. 確認 `generation_log.json` 已更新
3. 截圖記錄生成的角色外觀
4. 向 Designer 回報（若外觀不符規格，Designer 需修改 Prompt 後重試）

### Step 4：整合到 Godot（若外觀通過）
> ⚠️ 整合到 .tscn 是 Developer 的工作，需要 Reviewer 審查

---

## 修改歷史

| 日期 | 角色 | 更新 |
|------|------|------|
| 2026-06-15 | 全部 | 初始建立（Architect 設計，Designer 確認後維護）|

---

*此文件由 Architect 建立於 2026-06-15，後續由 Designer 維護*
