# PROJECT STATUS — [TBD] 鋼針跑酷遊戲
> **強制規則**：所有 Role 在任何工作開始前**必須先讀這份文件**。
> **強制規則**：任何 Phase 的進度變更，**當事 Role 必須在同次 commit 前更新此文件**。
> 格式：`更新時間 | 更新角色 | 更新內容`
>
> **這是全專案唯一的真相來源（Single Source of Truth）。**

---

## 📋 快速總覽

| Phase | 名稱 | 狀態 | 最後更新 |
|-------|------|------|---------| 
| 0.1 | 工作流建立（roles/ + hooks/ + sensor-scan） | ✅ DONE | 2026-06-19 |
| 0.2 | GDD 重設（鋼針跑酷新概念） | ✅ DONE | 2026-06-19 |
| 0.3 | Workflow 強化（GAP-012/013 修復 + Block 1-5） | ✅ DONE | 2026-06-19 |
| 0.4 | 鋼索系統核心（GAP-017~028：射針/繩索/平台） | ✅ DONE | 2026-06-20 |
| 1.x | 遊戲核心系統（待 Designer 確認 GDD） | ⏳ PENDING | — |

---

## ⚠️ §LEARN PENDING（必須完成後才能開始 Phase 1）

| SOP | 待完成步驟 | 負責角色 |
|-----|-----------|---------|
| §LEARN GAP-012/013 | Step 5: Sensor VERIFY | Developer |
| §LEARN GAP-012/013 | Step 6: Final COMMIT | Architect |
| §MOD workflow 強化 | Step ④: Reviewer 審查 | Reviewer |
| §MOD workflow 強化 | Step ⑤: QA 驗收 + 最終 push | QA |

> 詳細進度：`docs/sop-state.md`

---

## ✅ 已完成（DONE）

### Phase 0.1 — 工作流建立

- **完成日期**：2026-06-17（workflow.md 恢復）+ 2026-06-19（強化）
- **關鍵檔案**：
  - `workflow.md` — 6 角色工作流 SOP，v5
  - `roles/designer.md`, `roles/architect.md`, `roles/developer.md`, `roles/reviewer.md`, `roles/qa.md`
  - `hooks/pre-commit` (v4), `hooks/pre-push` (v2), `hooks/commit-msg`
  - `scripts/sensor-scan.ps1` (v10, 15 checks), `scripts/set-role.ps1`, `scripts/dev-submit.ps1`
- **強制流程**：每個 Role 開始前讀 `docs/PROJECT_STATUS.md` + `docs/ERROR_LOG.md`

### Phase 0.2 — GDD 重設

- **完成日期**：2026-06-19
- **關鍵檔案**：`docs/GAME_DESIGN.md` (v1, 全 [DRAFT])
- **遊戲概念**：2D 橫向跑酷，鋼針系統（投擲/穿線/鉤抓），單人，靈感：Dimension W + Titan Souls
- **重要約束**：所有 GDD 欄位從 [DRAFT] 開始，[CONFIRMED] 需正式設計會議

### Phase 0.3 — Workflow 強化

- **完成日期**：2026-06-19
- **修復問題**：GAP-012（AI 擅自 CONFIRMED）、GAP-013（workflow.md 未 merge 到 main）
- **機器層改動**：
  - `hooks/pre-commit` v4：[CONFIRMED] 攔截、SOP PENDING 警告
  - `hooks/pre-push` v2：GAP-013 核心文件存在性檢查（FAIL on missing）
  - `scripts/sensor-scan.ps1` v10：15 checks（v5 有 9 checks），check-8 false positive 修復
  - `docs/sop-state.md`：SOP 進度追蹤文件（機器可讀）
  - `scripts/set-role.ps1`：切換角色時顯示 PENDING SOP

### GAP-064 — Ronin 風格即時勾爪 + 手動收縮（2026-06-24）

- **完成日期**：2026-06-24
- **修改檔案**：`scripts/player.gd`、`scripts/aim_preview.gd`、`scripts/needle_manager.gd`
- **修改內容**：
  - 右鍵勾爪改為即時固定：raycast 偵測 480px 內牆面，命中→瞬間建立錨點；未命中→靜默失敗不消耗回合
  - 移除繩索自動收縮（`rope_reel_speed`），改為手動「⬆ 收縮」按鈕（每次縮短 120px，回合開始執行）
  - Player 任何移動（彈弓/攻擊針）自動斷線，不需手動斷開按鈕
  - aim_preview 新增：虛線範圍圈、命中綠點/未命中紅X、收縮按鈕（取代斷開按鈕）

### GAP-063 — 鏡頭控制器 + 世界擴展（2026-06-24）

- **完成日期**：2026-06-24
- **修改檔案**：`scripts/camera_controller.gd`（新增）、`scenes/MVP_Test.tscn`、`scenes/Player.tscn`
- **修改內容**：
  - Camera2D 從 Player 子節點移至場景 root，避免 FROZEN 時鏡頭被 Player 位置鎖定
  - `camera_controller.gd`：FROZEN 時 WASD 鍵盤平移、滾輪縮放（0.25x~3.0x、zoom-toward-mouse）、中鍵拖曳；PLAYING 時 lerp 跟隨 Player（FOLLOW_LERP=7）
  - 世界擴展至 2560×1440：Ground/Ceiling/WallLeft/WallRight 形狀同步更新
  - Camera limits：left=0, top=-800, right=2560, bottom=1440
  - 新增平台 F/G/H 覆蓋右側擴展區域

### GAP-062 還原（2026-06-24）

- **完成日期**：2026-06-24
- **內容**：用戶要求還原 GAP-062（右鍵 wire 預覽），使用 `git revert` 回滾

### GAP-058/059 — 輸入修復 + 預覽優化 + 回合加速（2026-06-23）

- **完成日期**：2026-06-23
- **修改檔案**：`scripts/player.gd`、`scripts/aim_preview.gd`、`scripts/turn_manager.gd`、`scenes/Player.tscn`
- **修改內容**：
  - 根本輸入修復：`ColorRect` 子節點 `mouse_filter` 從 STOP 改 IGNORE（Block 原因）；改用 `Input.is_mouse_button_pressed()` 在 `_process` 輪詢（繞過事件系統）
  - 回合時間 1.0s → 0.3s（GDD 一致）
  - 彈弓預覽：地形感知 raycast（layer 1）+ 第二回合動量延伸（淡藍虛線）
  - Wire 預覽：重新計算含 reel 效果的正確物理；顏色改為藍色（移除錯誤的綠色）
  - 預覽色統一：所有「下一步位置」用藍色
- **驗證**：`[TM-INPUT] Mouse button 1 pressed` + `[TM] TURN START/END` 確認輸入和物理均正常

### GAP-057 — 彈弓修復 / 繩索拉動 / 被動軌跡預覽（2026-06-23）

- **完成日期**：2026-06-23
- **修改檔案**：`scripts/player.gd`、`scripts/aim_preview.gd`
- **修改內容**：
  - 彈弓：左鍵任意位置開始拖曳（移除 `_is_on_player` 32×64px 精確點選要求）；拖曳 ≥ 15px = 彈弓，< 15px = 攻擊針
  - 繩索：恢復 `rope_reel_speed = 150.0`；新增 `Space` 鍵 = pass/swing 回合
  - 預覽：加入被動彈弓軌跡（鼠標方向 60% 速度，半透明淡藍，永遠顯示）；盪繩靜止 kick 20→100 px/s
- **驗證**：run_project 無語法錯誤，乾淨啟動

### GDD v5 — 回合制大改 + 最終確認（2026-06-22）

- **完成日期**：2026-06-22
- **內容**：
  - 遊戲類型改為 Ronin 式回合制（固定 0.3s 物理推進 → 凍結 → 規劃）
  - 彈弓移動取代 A/D + Space（最大射程 640px）
  - 針飛行 720px / 回合（2400 px/s × 0.3s），跨回合飛行
  - 回收機制改為 UI 按鈕（免費動作），F 鍵移除
  - 確認所有 GDD 內部矛盾（§2.1 / §9.3 / §9.5 / 標頭）已修正
  - §9 MVP 規格更新為回合制版本
- **關鍵檔案**：`docs/GAME_DESIGN.md` v5
- **待實作**：回合制狀態機、彈弓移動、虛線預覽、UI 回收按鈕（全部為新架構）

### Phase 1.3 — 盪繩切向空中控制（GAP-054）

- **完成日期**：2026-06-22
- **功能**：右鍵盪繩時，左右方向鍵沿擺弧切線方向施加 150 px/s² 加速度（像推鞦韆）
- **設計**：`swing_accel=150.0`（@export 可調），切線 = 繩方向旋轉 90°，不影響法向/重力
- **修改檔案**：`scripts/player.gd`

### Phase 1.2 — 盪繩全面重寫：pre/post split + 直線繩（GAP-053）

- **完成日期**：2026-06-22
- **問題**：速度分段感（velocity += correction/delta 衝量與重力疊加 overshoot）+ 繩子視覺分段（Verlet 12段下垂）
- **修復**：
  - `WireConstraint` 重寫：`pre_constrain()`（移除外向徑向速度）+ `post_constrain()`（direct global_position 賦值，不注入速度）
  - `_physics_process` 改為 pre→move_and_slide→post 架構
  - 廢除 Verlet rope 視覺，改用直線 Line2D（2 點：player + anchor）
  - 移除 `swing_accel`, `swing_air_drag`, `wire_slack` exports；新增 `rope_reel_speed`, `rope_min_length`, `rope_snap_factor`
  - `_wire` 型別從 `RefCounted` 改為 `WireConstraint`（修復 GDScript parse error）
- **修改檔案**：`scripts/wire_constraint.gd`、`scripts/player.gd`

### Phase 1.1 — 純鐘擺手感重構（GAP-052）

- **完成日期**：2026-06-22
- **問題**：GAP-051 Z 方案固定徑向速度導致手感不自然，無法細緻操控（玩家感覺「被強制拉」非「順物理擺盪」）
- **修復**：
  - 廢除 Z 方案，改回 `constrain()` 純鐘擺：只取消外向徑向速度，保留切向動量
  - `snap_factor = 0.0`（純鐘擺，不注入彈力）
  - 勾住期間停用空中輸入（`swing_accel`），重力完全主導
  - 位置修正繼續用 `velocity += correction / delta`（保留 `move_and_slide`，不卡地形）
  - Verlet 繩長回到 `_wire.max_length`
- **修改檔案**：`scripts/player.gd`、`scripts/wire_constraint.gd`
- **驗證**：run_project 確認 max_len 平滑 575→24，dist 跟隨 max_len，min_length 後 dist = 24 = max_len 精確穩定，無 error

### Phase 1.0 — Z 方案：固定徑向拉力取代 auto_reel（GAP-051）

- **完成日期**：2026-06-22
- **問題**：收繩時抖動、繩長視覺不穩定（auto_reel + correction 衝量與重力疊加 overshoot）
- **修復**：廢除 `auto_reel` + `constrain`，改為分解速度為切向 + 徑向，徑向固定 = `auto_reel_speed`（300 px/s）朝錨點；到達 `min_length` 後只保留切向（純鐘擺）
- **視覺**：Verlet 繩長改用實際玩家到錨點距離，視覺同步精確
- **驗證**：run_project 自動射繩確認 radial 恆定 300.0，dist 平滑 580→24，無 error
- **修改檔案**：`scripts/player.gd`

### Phase 0.9 — 繩長精確化 + 收繩減速（GAP-050）

- **完成日期**：2026-06-22
- **實作功能**：
  - GAP-050a：`wire_slack` 從 15.0 → 0.0，繩子初始長度 = 玩家到錨點精確直線距離
  - GAP-050b：`auto_reel_speed` 從 520 → 300 px/s，盪繩收近速度減慢
- **修改檔案**：`scripts/player.gd`、`docs/GAME_DESIGN.md §2.3`
- **驗證方式**：用戶實機測試確認（繩長過長 + 速度過快問題改善）

### Phase 0.8 — 盪繩卡地形修正：改用滑動修正（GAP-048）

- **完成日期**：2026-06-22
- **問題**：右鍵勾牆盪繩時常被平台/角落卡住無法繼續移動
- **根因**：`_apply_wire()` 用 `move_and_collide(correction)` 應用繩子位置修正，遇到地形完全停止；下一幀繩子繼續拉但玩家被卡死，形成惡性循環
- **修復**：位置修正改為 `velocity += correction / delta`，讓幀尾唯一的 `move_and_slide()` 統一處理，遇到角落自動沿牆面滑動（A 方案）
- **修改檔案**：`scripts/player.gd`
- **驗證**：run_project 自動射繩確認玩家從 (640,672) 正常拉至錨點 (1248,508)，無 error

### Phase 0.7 — 針跟隨敵人移動 + 右鍵勾敵人 player 不被拉（GAP-047）

- **完成日期**：2026-06-22
- **實作功能**：
  - GAP-047a：`needle_anchor.gd` 加 `_physics_process`，首幀記錄 `_body_offset`，每幀跟隨 `attached_body.global_position`，針視覺正確貼在移動敵人上
  - GAP-047b：`player.gd` `_apply_wire()` 每幀同步 `_wire.anchor_pos`；若 `attached_body != null`（鉤到敵人）不執行 WireConstraint，player 保持自由移動
- **修改檔案**：`scripts/needle_anchor.gd`、`scripts/player.gd`
- **分支**：`feature/gap-046-wire-snap-enemy-pull`

### Phase 0.6 — 右鍵 snap 彈力 + 右鍵勾敵人往玩家拉近（GAP-046）

- **完成日期**：2026-06-22
- **實作功能**：
  - GAP-046a：`wire_constraint.gd` 加 `snap_factor=0.35`，繩子拉緊瞬間反彈部分向外速度，產生鞭甩手感
  - GAP-046b：`training_dummy.gd` 右鍵 wire 針命中（n_type=1）→ 持續以 200px/s 往玩家拉近；wire 釋放時停止
- **修改檔案**：`scripts/wire_constraint.gd`、`scripts/training_dummy.gd`
- **分支**：`feature/gap-046-wire-snap-enemy-pull`

### Phase 0.5 — 遊戲手感優化 + 木人敵人（GAP-043～045）

- **完成日期**：2026-06-21
- **實作功能**：
  - GAP-043：繩子收縮加速（`auto_reel_speed` 320 → 520，`wire_slack` 30 → 15）
  - GAP-044：鋼針數量 HUD（左上角 CanvasLayer，`●●●○○` 格式，5 格即時更新）
  - GAP-045：訓練木人（CharacterBody2D 24×48，攻擊針插入 → 往玩家方向拉動 240px/s）
- **新增檔案**：`scripts/training_dummy.gd`、`scenes/TrainingDummy.tscn`、`scripts/ui/needle_hud.gd`、`scenes/ui/needle_hud.tscn`
- **修改檔案**：`wire_constraint.gd`、`player.gd`、`needle_manager.gd`（body callbacks）、`MVP_Test.tscn`
- **GDD 更新**：`docs/GAME_DESIGN.md §5.3` 訓練木人規格

---

### Phase 0.4 — 鋼索系統核心（GAP-017～028）

- **完成日期**：2026-06-20
- **實作功能**：
  - GAP-017：RayCast2D world/local space 修正
  - GAP-018：UX feedback（視窗 960×540, NeedleAnchor 黃色可見）
  - GAP-019a/b：Canvas stretch + Camera limit 修正
  - GAP-020：平台 one-way collision 初版架構
  - GAP-021a/b/c：繩索多狀態（端點切換 / catenary / one_way）
  - GAP-022：E 鍵縮線 winch 語意修正
  - GAP-023：第三針無法牽線（rolling window 修正）
  - GAP-024：第二針飛行途中線段顯示
  - GAP-025：第三針保留舊平台 + 針速 2×（1200 px/s）
  - GAP-026：平台卡頭消除（height 4px）+ 視覺 1.5px + slack 30
  - GAP-027：one-way 方向正規化（右→左錨點順序不再翻轉）
  - GAP-028：視覺下垂（SAG 20px lerpf）+ S 鍵穿透（layer 4 timer 0.25s）
- **GUT 測試**：7/7 PASS（test_platform_sag_dropthrough.gd）
- **驗證方式記錄**：GUT 自動化 + `mcp__godot__run_project` / `get_debug_output`（非 computer-use）

---

## ❌ 尚未開始（TODO）

| 功能 | 優先級 | 前置條件 | 說明 |
|------|--------|---------|------|
| 玩家基礎移動 | HIGH | §LEARN/§MOD PENDING 全部清空 | GDD §3 確認後開始 |
| 鋼針投擲系統 | HIGH | 玩家移動完成 | GDD §2 設計確認 |
| 穿線/鉤抓移動 | HIGH | 鋼針基礎完成 | GDD §2 設計確認 |
| 敵人基礎 AI | MEDIUM | 鋼針攻擊完成 | GDD §5 設計確認 |
| Boss 設計 | LOW | 敵人系統完成 | GDD §5 設計確認 |

---

## 🔒 已鎖定設計決策（來自 GAME_DESIGN.md）

| 決策 | 內容 |
|------|------|
| 遊戲類型 | 2D 橫向動作跑酷，單人 |
| 核心靈感 | Dimension W（精準投擲）+ Titan Souls（武器回收/一擊致命） |
| 核心機制 | 鋼針（固定數量，投擲/穿線/鉤抓/拉動，必須回收） |
| 遊戲名稱 | TBD（"ANTIGRACITY" 是 IDE 目錄名，非正式遊戲名） |

---

## 📁 關鍵檔案索引

### 工作流文件
| 文件 | 功能 | 強制讀取 |
|------|------|---------|
| `docs/PROJECT_STATUS.md` | **本文件** — 全專案狀態 | ✅ 所有 Role 必讀 |
| `docs/ERROR_LOG.md` | 錯誤知識庫 | ✅ 所有 Role 必讀 |
| `docs/GAME_DESIGN.md` | 遊戲設計文件（GDD）| Designer/Architect 必讀 |
| `docs/sop-state.md` | SOP 執行進度追蹤 | Sensor/set-role.ps1 自動讀取 |
| `workflow.md` | 全角色工作流 SOP | 角色切換前讀取 |

### 腳本
| 檔案 | 功能 | 狀態 |
|------|------|------|
| `scripts/set-role.ps1` | 設定 Agent 角色 + 顯示 SOP 狀態 | ✅ |
| `scripts/sensor-scan.ps1` | 自動掃描（v10，15 checks） | ✅ |
| `scripts/dev-submit.ps1` | Developer 提交腳本 | ✅ |

---

## 🔄 更新日誌

| 時間 | 角色 | 更新內容 |
|------|------|---------|
| 2026-06-20 | Architect | PixelLab：建立 docs/PIXELLAB_KB.md 知識庫 + roles/pixel-consultant.md 顧問角色；workflow §B 註冊、DOC_INDEX 同步、DEAD-A 掃描移除 PixelLab |
| 2026-06-20 | QA | GAP-042：實機插樁證明玩家被 Platform_C 擋住(卡住未穿過)、sensor 21/21、--check-only 0 → 通過 |
| 2026-06-20 | Developer | GAP-042：盪繩收繩穿過平台修復 — global_position 瞬移繞過碰撞，改 move_and_collide |
| 2026-06-20 | QA | GAP-041：NM41_TEST_PASS(攻擊針自動回收+release安全)、gap040/037 PASS、sensor 21/21、run_project 冒煙空(Player.tscn 載入正常) → 通過 |
| 2026-06-20 | Reviewer | GAP-041：審查通過 — auto_retrieve_attack 近收遠留(測試)、release_wire 冪等(is_instance_valid)、_wire_held 守鬆開時序、無平台殘留、Player.tscn 載入OK；淨減193行 |
| 2026-06-20 | Architect | GAP-041：規劃重寫 needle_manager(release_wire/auto_retrieve_attack)、player(右鍵按住/移除平台UI)、刪 WirePlatform、改 Player.tscn |
| 2026-06-20 | Designer | GAP-041：大幅簡化 — 移除平台/Q/E/F/S；盪繩改右鍵按住(自動收繩)、鬆開斷繩+回收；攻擊針靠近自動回收；GDD §2.2/2.3/2.4/2.5/9.1/9.3 |
| 2026-06-20 | QA | GAP-040：ROPE40_TEST_PASS(斷言無速度注入=自然)、gap037 PASS、sensor 21/21、run_project 冒煙空 → 通過 |
| 2026-06-20 | Reviewer | GAP-040：審查通過 — constrain 無速度注入(自然)、夾位+消徑向、針速2400 抗穿牆OK；test_rope_gap040 斷言無注入；補正 git add 漏提 |
| 2026-06-20 | Architect | GAP-040：規劃 wire_constraint 改回 constrain(無速度注入)、player 移除彈簧 export、needle flight 2400、測試改寫驗證自然 |
| 2026-06-20 | Designer | GAP-040：繩改回自然鐘擺約束(移除彈簧人工 fling 動量)、針速 1200→2400；GDD §2.3/9.3 |
| 2026-06-20 | QA | GAP-039：新驗證法示範 — test_rope_gap039 ROPE39_TEST_PASS(上甩 vel.y<0+針數5)、gap037 修剪後 PASS、sensor 21/21、run_project 冒煙空 → 通過 |
| 2026-06-20 | Reviewer | GAP-039：審查通過 — 彈性 apply 朝錨點 capped+防0、右鍵單按帶線針/左鍵攻擊、max_needles 5、Verlet 視覺一致；headless 測試覆蓋上甩物理 |
| 2026-06-20 | Architect | GAP-039：規劃 wire_constraint 彈性收繩、player 輸入/apply、needle_manager 5；workflow §F 新增驗證優先序(headless 首選)、§I-C Rule 24 改述 |
| 2026-06-20 | Designer | GAP-039：繩改彈性快速收繩(上甩接平台連段)、帶線針改單按右鍵、針數 3→5；GDD §2.1/2.2/2.3/9.1/9.3 |
| 2026-06-20 | QA | GAP-038：實機插樁驗證針 EMBED at 外牆(traveled=640)、sensor 21/21、--check-only 0 → 通過 |
| 2026-06-20 | Developer | GAP-038：修復針飛半路消失 — get_viewport_rect 回傳 1152×648≠世界 1280×720，改飛行距離 max_travel 安全網 |
| 2026-06-20 | QA | GAP-037：headless 單元測試 ROPE_TEST_PASS（Verlet+鐘擺+reel）、sensor 21/21、--check-only 0、run_project errors 空；側向假彎曲根除；繩觀感交玩家實測 → 通過 |
| 2026-06-20 | Reviewer | GAP-037：審查通過 — Verlet Jakobsen 釘端正確、constrain 鐘擺(夾位+消徑向)防0、_verlet 各清除路徑 null、max_length 介面保留；修了 tension := 推不出型別的編譯錯 |
| 2026-06-20 | Architect | GAP-037：規劃 verlet_rope.gd(preload免--import)、wire_constraint 改鐘擺約束+reel、player 整合 Verlet 視覺 |
| 2026-06-20 | Designer | GAP-037：繩重做 — 視覺改 Verlet 物理繩(去除側向假彎曲)、物理回鐘擺長度約束+auto-reel；研究後不採 Joint(需 RigidBody)；GDD §2.2/2.3 |
| 2026-06-20 | QA | GAP-036：驗收修復射不出鋼針（算術可證 + run_project errors 空）→ 通過 |
| 2026-06-20 | Developer | GAP-036：修復 needle_projectile 硬編碼舊 960×540 邊界（出生即被刪），改 get_viewport_rect 推導 |
| 2026-06-20 | QA | GAP-035：run_project 乾淨啟動（1280×720, errors 空）、sensor 21/21、--check-only 0、無 dangling 參考；手感 8 情境 + @export 交玩家實測 → 通過 |
| 2026-06-20 | Reviewer | GAP-035：審查通過 — bungee always-pull capped+防0、inertia move_toward 正確、buffer/coyote 順序正確、外牆座標框滿 0..1280/0..720 與相機 limits 一致 |
| 2026-06-25 | Developer | GAP-079：移除牆壁跳躍 coyote time 機制（手感不符預期） |
| 2026-06-25 | Developer | GAP-078：垂直牆壁黏附空隙 — velocity.x = -normal.x * 8 持續壓入牆面，move_and_slide 解析掉多餘速度 |
| 2026-06-25 | Developer | GAP-077b：牆壁跳躍手感修復 — _wall_jump_lock 0.18s 防止 kick 被 velocity.x=h*walk_speed 覆蓋；kick 220px/s；移除 _w_prev 限制 |
| 2026-06-25 | Developer | GAP-077：牆壁跳躍 coyote time — 離牆後 0.15s 內按 W 觸發，橫向 kick 120px/s，_no_stick_frames=8 防重黏 |
| 2026-06-25 | Developer | GAP-076：爬牆/天花板離開表面後持續懸浮 — _probe_stuck_surface() raycast 逐幀驗證，被動釋放無 grace |
| 2026-06-25 | Designer | GAP-074/075：GDD v13 §2.2/§2.3/§2.3a — 針飛行時間+子彈時間演出、解除黏附修復說明、清除舊回合制殘留 |
| 2026-06-25 | Developer | GAP-075：天花板/牆壁解除黏附重新黏附 bug — _no_stick_frames=4 寬限期 + velocity.y=220 離頂推力 |
| 2026-06-25 | Developer | GAP-074：左/右鍵改為發射飛行 NeedleProjectile，受 time_scale 影響，子彈時間下慢速飛行 |
| 2026-06-25 | Designer | GAP-073：移除回合制 → WASD 即時動作 + Space 子彈時間 — GDD v13，§1.2/§2.2/§2.4/§9.1/§9.1b/§10 全部更新 |
| 2026-06-25 | Developer | GAP-073：重寫 turn_manager.gd(BulletTimeManager) + player.gd(WASD即時) + camera_controller.gd(移除WASD平移) |
| 2026-06-25 | Developer | GAP-072：攻擊針改即時 raycast + mask=0xFFFF — 解決穿透敵人問題，place_attack_anchor_instant |
| 2026-06-25 | Developer | GAP-071：移除 Space 快捷鍵觸發回合 — 清空 _unhandled_input，只保留 pass |
| 2026-06-25 | Developer | GAP-070：盪繩碰牆自動黏附(Ronin機制) — 移除 _wire==null 限制，碰牆/天花板時繩索先釋放再黏附 |
| 2026-06-25 | Developer | GAP-069：恢復綁線觸發物理回合(Ronin A方案) — 還原 GAP-067 錯誤移除的 commit |
| 2026-06-24 | Developer | GAP-068：黏附改為無繩索時才觸發 — _wire == null 條件，盪繩狀態下不吸附 |
| 2026-06-24 | Developer | GAP-067：右鍵綁線改為免費動作 — 移除 _start_grapple() 內的 commit，綁線不耗回合，收縮/彈弓才啟動物理 |
| 2026-06-24 | Developer | GAP-066 修正：收縮後黏附未觸發 — 改用向錨點 raycast 確認牆面後強制 _try_stick_after_reel() |
| 2026-06-24 | Developer | GAP-066：收縮動畫化(lerp over 0.3s)+ Player 黏壁/天花板(壁虎模式)+ 平台邊緣自動掛住(ledge snap) |
| 2026-06-24 | Developer | GAP-065：收縮繩索改為即時消耗一回合 — 移除 _reel_queued 排隊機制，改為點擊按鈕直接縮短並 commit |
| 2026-06-20 | Architect | GAP-035：規劃 wire_constraint always-pull、player 慣性/buffer/coyote/可變跳、MVP_Test 放大 1280×720 外牆重框 |
| 2026-06-20 | Designer | GAP-035：繩改彈力繩自動拉近(Q切斷)、視窗放大1280×720外牆切齊、Player性能微調、左右慣性、jump buffer/coyote/可變跳；GDD §2.3/9.1/9.4/9.5 |
| 2026-06-20 | QA | GAP-034：run_project 乾淨啟動（errors 空）、sensor 21/21、--check-only 0；撿針/統一距離靜態可證；繩手感開放 4 @export 交玩家實測 → 通過 |
| 2026-06-20 | Reviewer | GAP-034：審查通過 — 彈簧僅 taut 時作用、div-by-zero 已防、damping clampf 有界、max_length 介面不變不影響 renderer/debug；動量保留正確 |
| 2026-06-20 | Architect | GAP-034：規劃 needle_manager 半徑/統一過濾、wire_constraint 改 spring-damper、player 空中控制保留動量；不新增 class_name |
| 2026-06-20 | Designer | GAP-034：回收半徑 30→60、所有針一律需夠近（取消擺錘針不限距離）；繩子改彈性 spring-damper + 保留擺盪動量；GDD §2.3/2.4/2.5 |
| 2026-06-20 | QA | GAP-033：run_project 乾淨啟動（errors 空）、sensor 21/21、--check-only 0；攔截並記錄 class_name 快取 gotcha（--import 修復）；視覺手動清單交玩家 → 通過 |
| 2026-06-20 | Reviewer | GAP-033：審查通過 — get_retrieve_info DRY、try_retrieve 行為不變、PickupPromptUI top_level 防鏡像、.tscn 無 UID 自引用；記錄新 class_name 需 --import 更新快取的 gotcha |
| 2026-06-20 | Architect | GAP-033：規劃 WorldLabel(可復用) + PickupPromptUI 控制器 + needle_manager.get_retrieve_info(DRY)；player 程式碼整合不改 .tscn |
| 2026-06-20 | Designer | GAP-033：定義回收提示 UI（可回收針上方顯示 [F] 文字、目標高亮）；GDD §2.5；可復用 UI 架構放 scripts/ui、scenes/ui |
| 2026-06-20 | QA | GAP-032：run_project 乾淨啟動（errors 空）；發現並修復 is_connected 遮蔽警告；自動化全 PASS；手動手感清單交玩家實測 → 通過 |
| 2026-06-20 | Developer | GAP-032：修復 QA 發現的 is_connected 遮蔽 Object.is_connected 警告（改名 is_player_wire）|
| 2026-06-20 | Reviewer | GAP-032：審查通過 — try_retrieve 向後相容、_remove_anchor 平台/GAP-029 鏈未動、Q 不再清平台狀態、無 .tscn/UID/物理回呼風險 |
| 2026-06-20 | Architect | GAP-032：implementation_plan 規劃 player._cut_wire 限擺錘 + needle_manager.try_retrieve 優先級選擇 |
| 2026-06-20 | Designer | GAP-032：定義 Q 只切當前擺錘線（平台不可 Q 切）、F 依優先級回收（無線針>玩家相連針>平台針）；更新 GDD §2.4 |
| 2026-06-20 | Architect | GAP-031：用戶授權完整移除 Ponytail 7-rung 機制（hooks v4/v7、sensor 21 checks、workflow GLOBAL-RULE-002）+ 新增 GLOBAL-RULE-004 防循環 |
| 2026-06-20 | Architect | GAP-030：commit-msg v3 Ponytail 強制補實作 + pre-commit Developer/Ponytail-A 補實作（已由 GAP-031 撤銷）|
| 2026-06-20 | Developer | GAP-029：F 回收鐘擺錨點線跳到舊錨點（platform_dissolved flag 修復）|
| 2026-06-20 | Architect | Phase 0.4 完成：補記 GAP-025～028 到 ERROR_LOG；更新 GDD §2.3 鋼索平台行為；更新 PROJECT_STATUS |
| 2026-06-20 | Developer | GAP-028：平台視覺下垂 + S 鍵穿透（layer 4 / lerpf sag / drop-through timer） |
| 2026-06-20 | Developer | GAP-027：修正平台 one-way 方向（右→左錨點順序導致翻轉，dir 正規化修復） |
| 2026-06-20 | Developer | GAP-026：平台卡頭修復（height 24→4）+ 視覺細線 + wire_slack 收緊 |
| 2026-06-20 | Developer | GAP-025：第三針不解散舊平台 + 針速 600→1200 px/s |
| 2026-06-19 | Architect | 重設 PROJECT_STATUS：舊 roguelite 內容全清，建立新鋼針遊戲骨架 |
| 2026-06-19 | Developer | Phase 0.3：Workflow 強化（GAP-012/013 修復，Block 1-5 實作） |
| 2026-06-19 | Architect | Phase 0.2：GDD 重設（鋼針跑酷概念，全 DRAFT） |

---

> **更新規則**：
> - Phase 狀態從 TODO → PARTIAL → DONE：當事角色必須在同次 git commit 前更新此文件
> - 新發現的 Bug 或技術債：立即加入 ERROR_LOG.md，並更新此文件
> - 設計變更：必須同時更新「已鎖定設計決策」和 GAME_DESIGN.md
> - 每次更新：在「更新日誌」加入一行記錄
