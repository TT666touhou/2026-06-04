# 📔 審查日誌 (review_log.md)
> 所有 Reviewer 工作的記錄。每次審查後必須追加。

---

### 2026-06-12 ERR-012/013/014/015 — Reviewer 審查後反省

- **審查結論**：❌ 退回（事後修復，未在 PR 時攔截）
- **靜態錯誤狀況**：Godot --check-only 無法偵測這幾類錯誤（runtime-only 或文件系統錯誤）
- **主要問題**：
  1. **ERR-012**：`boss.gd` 中文內容以非 UTF-8 儲存 → Reviewer 審查時沒有執行 BOM 掃描腳本
  2. **ERR-013**：`player1-4.tscn` 中 ext_resource UID 全部指向場景自身的 UID → Reviewer 審查 .tscn 文件時沒有核對 ext_resource UID 與實際資源 UID 的對應
  3. **ERR-014**：`test_stretch.gd` 使用 Godot 3 廢棄 API → 測試腳本未納入審查範圍
  4. **ERR-015**：`test_*.gd` 文件有 UTF-8 BOM → 根目錄下的測試腳本被 Reviewer 忽略
- **根本失敗原因**：
  1. Reviewer 審查清單中有 SubResource 驗證（ERR-008）但沒有 ext_resource UID 驗證（ERR-013）
  2. Reviewer 的 BOM 掃描只涵蓋 UTF-16（ff/fe）未涵蓋 UTF-8 BOM（ef/bb/bf）和 non-UTF-8 編碼
  3. 根目錄下的測試腳本被視為「臨時文件」而未審查，但 Godot 啟動時會載入所有腳本
- **新增 Reviewer 強制步驟**：
  - 審查任何包含場景複製的 PR 時：必須執行 UID 自引用驗證腳本
  - 審查任何 .gd 文件時：執行 BOM 掃描（涵蓋 UTF-8 BOM + UTF-16 BOM + 非 UTF-8 位元組）
  - **根目錄下的所有 .gd 文件也需納入審查**（不是只有 scripts/ 目錄）
- **給 Developer 的建議**：
  - 統一以英文撰寫 .gd 文件（零編碼風險）
  - 每次複製 .tscn 後立即執行 UID 自引用驗證
- **給 QA 的測試重點提示**：
  - 啟動遊戲時是否有 Unicode parsing error？
  - 所有玩家場景（player1-4.tscn）是否能正確載入？
  - Boss 場景是否能進入且 Boss AI 正常運行？

### [模板] YYYY-MM-DD PR#N [功能描述]
- **審查結論**：✅ 通過 / ❌ 退回
- **靜態錯誤狀況**：0 ERROR
- **DoD 符合度**：N/N 項通過
- **DebugBridge 驗證**：✅ / ❌
- **給 Developer 的建議**：
- **給 QA 的測試重點提示**：


---

## 2026-06-12 21:00 — Reviewer 審查記錄（Phase 5.5/5.6）

### 審查範圍
- one_shot_vfx.gd 自我配置重寫
- 4個 VFX scenes（MeleeSlash/RangedMuzzle/EnemyHit/EnemyDeath）
- player.gd、enemy1/2/3.gd VFX auto-load 修改
- debug_bridge.gd、debug_overlay.gd 警告修復

### 審查結論
- ✅ BOM 掃描全通過
- ✅ spawn_pos 重複宣告已修復（只剩 L853 一個）
- ✅ StringName→String 顯式轉型正確
- ✅ roundi() 替換 narrowing 轉型正確
- ✅ AtlasTexture region 計算邏輯正確（i * frame_width, 0, frame_width, frame_height）
- ✅ VFX UID 格式已修正為 13位英數字 Godot 標準格式
- ✅ 所有 VFX scene 的 scale 設計符合比例要求

### 建議
- 未來 VFX 添加時，建議在 one_shot_vfx.gd 中加入 @tool 標註方便在 Editor 中預覽

---

## Developer 反省記錄（Session 8 — 2026-06-13）

### 觸發的錯誤
**ERR-023**: 7個 .tscn 文件標頭缺少 [ 字符

### 根本原因分析
上一個 Session（2026-06-12）的自動化 .tscn 修改腳本混用了：
- Get-Content "xxx.tscn" -Encoding UTF8 -Raw — 可能將 BOM 字符 U+FEFF 注入到字符串開頭
- Set-Content "xxx.tscn" -Value  -Encoding UTF8 — 會在文件前加入 UTF-8 BOM 前綴 (EF BB BF)

多次循環讀寫後，BOM 字符被混入文件內容，最終 BOM 移除步驟 Substring(1) 誤判 [ 為 BOM 字符並將其刪除。

### 影響範圍
- Enemy1.tscn, Enemy2.tscn, Enemy3.tscn
- player1.tscn, player2.tscn, player3.tscn, player4.tscn
- 所有這些場景在 Godot 中無法載入，導致 test_level.tscn / test_room_a.tscn / test_room_b.tscn 也失敗

### 修復方法
`powershell
# 對每個受影響文件：
 = [IO.File]::ReadAllBytes()
# 移除 BOM（如有）
 = if ([0] -eq 0xEF -and [1] -eq 0xBB) { 3 } else { 0 }
 = [Text.Encoding]::UTF8.GetString(, , .Length - )
# 如果第一個字符不是 '['，補上
if ([0] -ne '[') {  = '[' +  }
[IO.File]::WriteAllText(, , (New-Object Text.UTF8Encoding(False)))
`

### 防範措施（已實施）
1. sensor-scan.ps1 新增 Check 6/6 — 全專案 .tscn 首字節驗證
2. hooks/pre-commit 新增 Rule 1c — 提交前 .tscn 標頭格式阻斷
3. oles/developer.md 新增 Rule q — .tscn 安全讀寫協議
4. workflow.md 新增 Rule 15 — 修改 .tscn 安全寫入強制規則
5. docs/ERROR_LOG.md 新增 ERR-023 — 完整根本原因、診斷、修復文檔

### Developer 承諾
- 未來所有 .tscn 修改將只使用 [IO.File]::ReadAllText + [IO.File]::WriteAllText
- 每次 .tscn 修改後立即執行首字節驗證
- 使用 .Replace() 而非 -replace 進行標頭修改以避免正則表達式字符歧義

---

## [DEV] Review - Player Flip + 8-Direction Shooting (2026-06-13)

### Changes Made
**1. Visual Left/Right Flip**
- _visual_pivot.scale.x = _facing added to _handle_horizontal()
- Whole VisualPivot (sprite + UI sway) flips when moving left/right
- Attack tween now restores Vector2(_facing, 1.0) instead of Vector2.ONE to preserve flip state
- Sway: _visual_pivot.rotation = _sway_y * _facing — fixes sway lean direction when flipped

**2. 8-Direction Shooting**
- New _get_aim_dir() -> Vector2 function computes normalized aim vector
- Horizontal component: move_left/move_right axis
- Vertical component: im_up (-Y) and im_down (+Y) actions
- Fallback: no direction input → horizontal shot in _facing direction
- _fire_bullet() now uses _get_aim_dir() for direction and spawn position
- _perform_melee_attack() hitbox rotated by aim direction (vertical melee supported)
- Bullet auto-rotates to direction.angle() (already in player_bullet.gd ✓)

**3. Input Bindings**
| Action | P1 Key | P2 Key | P3/P4 |
|--------|--------|--------|-------|
| aim_up | I | Numpad 8 | (none - uses facing) |
| aim_down | K | Numpad 5 | (none - uses facing) |

### Sensor Check
- 7/7 PASS — No issues detected

### Design Notes
- _aim_dir state var updated by _get_aim_dir() on each attack call (not every frame) — intentional, low overhead
- Players without aim bindings (p3/p4) gracefully fall back to horizontal shooting
- Muzzle flash VFX flip_h follows shot_dir.x < 0.0


---

## Phase 6.5 Reviewer Report — 2026-06-14

### 審查範圍
- oom_portal.gd：enter_direction @export + _do_trigger 傳遞邏輯
- game_world.gd：_pending_enter_direction + load_next_room_portal 簽名 + Walk-in 呼叫
- player.gd：_entry_locked 狀態 + _physics_process Walk-in 分支 + start_room_entry()
- rea_0_room_01.tscn / rea_0_room_02.tscn：Portal 屬性完整性

### 通過項目 ✅
1. **雙向連接修復**：room_02.LeftPortal.target_room_path 已正確設定為 room_01 路徑
2. **Walk-in 速度計算**：_entry_speed = 48/0.35 = 137px/s，每幀 2.2px，0.37s 走完，合理
3. **競態保護**：_triggered + _is_loading_room 雙重防重入，Walk-in 期間不會誤觸 Portal
4. **重力保留**：Walk-in 期間 _apply_gravity(delta) 仍然執行，玩家自然落地
5. **Sensor 8/8 PASS**：無 BOM / 無 UID 自引用 / 無 physics callback / 無 narrowing / 無廢棄 API
6. **enter_direction auto 推導**：left→right / right→left / top→down / bottom→up 邏輯正確

### 潛在邊緣案例（已確認不影響當前版本）⚠️
- _respawn_player 直接 teleport 到硬編碼位置 (100, -80)，不呼叫 Walk-in → **設計上正確**（死亡重生不需要 Walk-in 效果）
- 若 enter_direction 為 "auto" 且 door_id 是未知字串 → fallback 為 "right" → **可接受**

### Reviewer 要求
- 無阻塞問題，**核准此次提交**
