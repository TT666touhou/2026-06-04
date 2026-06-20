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
