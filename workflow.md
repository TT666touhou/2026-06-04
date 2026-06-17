# Godot Multi-Agent 開發工作流（完整規範）v5 (2026-06-17)

> **讀取指示（給 AI）**: 進入任何 Godot 遊戲開發對話時，必須優先讀取此文件。
> 讀完後，立刻執行「A. 對話開始時的第一步」。
> **v4 新增**: 對話開始必須讀取 `docs/DOC_INDEX.md`（Step 0.5）。詳見 §MOD（WORKFLOW 修改 SOP）和 §READ（文件讀取 SOP）。

---

## 【GLOBAL-RULE-001】嚴格禁止使用 browser_subagent（2026-06-16 硬性規則）

> [!CAUTION]
> **任何情況下禁止使用 `browser_subagent` 工具。違反此規則 Sensor 立即 Level 3 觸發。**

### 禁止原因

1. **效率極低**：每次啟動瀏覽器 Agent 耗時數倍於 API 呼叫
2. **無法妥善處理**：JavaScript 渲染頁面截圖不穩定，圖片載入失敗
3. **浪費 context**：視覺截圖佔用大量 token，實際資訊量遠低於 text 解析

### 強制替代方案

| 原本使用 browser_subagent 用途 | 強制替代方案 |
|-------------------------------|------------|
| 讀取網頁文字內容 | `read_url_content(url)` |
| 下載圖片文件 | `python requests.get()` 或 `Invoke-WebRequest -Uri` |
| 查詢 API 文件 | `read_url_content(llms.txt)` |
| 查看網頁圖片 | `requests.get()` + `view_file()` |
| 任何 HTTP 請求 | PowerShell `Invoke-RestMethod` / Python `requests` |

### Sensor 觸發條件（GLOBAL-RULE-001 違反）

```
⛔ Level 3 觸發（立即停止！）
  - 任何封裝 browser_subagent 工具的呼叫請求
  - 任何「讓瀏覽器打開 XXX 網頁」的操作
  - 任何 open_browser_url 相關操作

✅ 正確做法：
  read_url_content("https://example.com")         # 讀取網頁文字
  requests.get("https://img.itch.zone/...")        # 下載圖片
  Invoke-RestMethod -Uri "https://api.example.com" # API 呼叫
```

---

## 【GLOBAL-RULE-002】Ponytail 7-rung ladder 開發哲學（2026-06-17 硬性規則）

> [!CAUTION]
> **任何情況下實作功能或設計架構，必須嚴格遵守 Ponytail 7-rung 決策階梯。**
> **任何違反「過度工程」的行為都受到嚴格限制。**

### 階梯原則（從上到下，優先級遞減）

1. **YAGNI (You Aren't Gonna Need It)**: 不要寫任何程式碼。挑戰需求本身是否真的必要。
2. **Godot Built-ins**: 使用 Godot 內建系統（如 Node, Physics, AnimationPlayer, Timer）。這是 Godot 專屬的優先選項。
3. **Language Native**: 使用 GDScript 語言內建特性（如 Array 方法、Dictionary 操作）。
4. **Dependency**: 引用現有的專案內模組、腳本。
5. **One-liner**: 寫一行解決問題的自定義程式碼。
6. **Minimal implementation**: 寫最少行的自定義程式碼，避免防禦性、未來、過度設計。
7. **Complete abstraction**: 寫完整的物件導向/抽象架構（最後的選項）。

### 觸發與機制（Level 1 Strictness）

- 所有角色（Designer, Architect, Developer, Reviewer, QA）均受此規則約束。
- **Commit 強制檢查**：任何 Commit 訊息中必須包含 `[Ponytail]` 標記，且變更內容中必須包含 `ponytail:` 註解（用以說明採用的 Rung）。這由 `commit-msg` hook 強制阻斷。

---

這是一個 **6 角色工作流**，包含 5 個串行角色和 1 個**跨階段被動守衛（Sensor）**。
每個開發階段由特定角色完成，透過 git hooks 在技術層物理阻斷違規行為。
**Sensor 是被動式守衛，在任何階段觸發危險模式時被召喚，優先中斷當前工作。**

```
Designer → Architect → Developer → Reviewer → QA
（設計）    （架構）     （實作）     （審查）    （驗收）
                                              ↑
                                           Sensor
                              （跨階段代碼感知守衛）
                    觸發時：立即插入工作流
```

**角色狀態由 `.agent-role` 文件控制**（純文字，內容為角色名稱小寫）。
**Sensor 沒有獨立的 `.agent-role` 狀態**：在任何角色的工作中被觸發後，完成後返回原角色。

---

## A. 對話開始時的第一步（AI 必須執行）

```
【讀取順序（不可更改）】
0. 確認當前是否為 Godot 專案：檢查 project.godot 是否存在

1. 讀取 .agent-role 文件 → 確認目前角色

2. 讀取對應的 roles/<role>.md → 取得完整職責與禁止事項

3. 【MUST-DO 最優先】讀取 docs/DOC_INDEX.md → 確認本次任務涉及哪些文件
   Get-Content "D:\2026-06-04\docs\DOC_INDEX.md"
   → 確認自己角色在「職責矩陣」中的讀/寫職責
   → 依任務類型（Godot/文件）找到對應的必讀文件清單
   ⚠️ 跳過此步 = Sensor 應立即中斷任何後續操作

4. 讀取 docs/ERROR_LOG.md → 了解已知問題（必讀）

5. 讀取 docs/PROJECT_STATUS.md → 確認當前開發狀態

6. 依任務類型選擇工作路徑：
   - Godot 開發   → 繼續 G-1 路徑
   - 規則/文件修改 → 執行 G-3 路徑（§MOD 5步驟 SOP）
   - 新空白專案   → 執行「D. 新專案 Bootstrap 流程」
```

> [!IMPORTANT]
> **第 3 步「讀取 DOC_INDEX.md」是所有 ROLE 最優先的必做步驟，不可跳過。**
> DOC_INDEX.md 中包含角色職責矩陣、文件清單、§MOD 修改 SOP、§READ 強制清單。

---

## B. 六個角色速查表

| 角色 | .agent-role 值 | 可提交的文件 | 絕對不得提交 | Commit 前綴 | 觸發條件 |
|------|---------------|------------|------------|------------|---------|
| **Designer** | `designer` | `docs/GAME_DESIGN.md`, `docs/*.md` | `.gd` `.tscn` `.tres` | `[DESIGN]` | 對話開始、設計需求 |
| **Architect** | `architect` | `implementation_plan.md`, `docs/`, `roles/` | `.gd` `.tscn` `.tres` | `[ARCH]` | Designer 完成後、Developer 熔斷時 |
| **Developer** | `developer` | 文件類（docs/、實作計劃）；代碼透過 `dev-submit.ps1` 投遞 | 所有 `.gd` `.tscn` `.tres` 直接 commit | `[DEV]` | Architect 完成設計後 |
| **Reviewer** | `reviewer` | 不提交代碼，只審查 PR | 修改任何代碼 | `[REVIEW]` | Developer 建立 PR 後；限時 **30 分鐘** |
| **QA** | `qa` | 所有代碼文件（`.gd` `.tscn` `.tres`）+ `docs/qa-report-*.md` | 自行撰寫新代碼 | `[QA]` | Reviewer 批准；限時 **45 分鐘** |
| **Sensor** | _(無獨立 role)_ | _(不提交)_ 立即掃描並修裁 | 未綁 call_deferred 的場景樹操作 | 無 | 任何角色觸發危險關鍵字時 |

> **文件守護責任（Doc Guardian）**：
> - Designer 是 GAME_DESIGN.md 的唯一維護者，必須在 48h 內回應 [GDD TODO] 標記
> - Developer 在每次 commit 必須標記 [GDD TODO] 影響設計的改動
> - Reviewer 檢查 PR 必須確認 PROJECT_STATUS.md 已更新
> - QA 是最後一棒：有未解決的 [GDD TODO] → 禁止 QA 通過
> - **所有 ROLE 必須在開場時讀取 docs/DOC_INDEX.md（§READ SOP 第 -2 步）**
> - **新增任何文件時：必須更新 docs/DOC_INDEX.md（所有 ROLE 的責任）**

---

## C. Git Hooks 系統

### 安裝方式（一次性，新 clone 後執行！）
```bash
git config core.hooksPath hooks
```
> 這讓 git 直接從版本控制的 `hooks/` 目錄取，無需手動複製到 `.git/hooks/`。

### hooks/ 目錄包含文件

| 文件 | 觸發時機 | 作用 |
|------|---------|------|
| `pre-commit` | 每次 commit 前 | 角色感知驗證（LFS、機密、角色規則、**編碼驗證**、**UID 驗證**） |
| `commit-msg` | commit 訊息確認後 | 格式驗證（`[ROLE] type: 描述`）+ Ponytail 標記驗證 |
| `prepare-commit-msg` | commit 訊息編輯前 | 自動加入角色前綴 |
| `pre-push` | push 前 | 禁止直接 force push main |
| `post-merge` | merge 後 | 提示更新狀態 |

### Commit 格式規範
```
[DESIGN] docs: 更新核心玩法循環設計
[ARCH] plan: 玩家移動系統架構設計完成
[DEV] feat: 實作玩家跳躍功能
[DEV] fix: 修正碰撞在斜面的錯誤
[REVIEW] review: 批准玩家移動 PR
[QA] test: 玩家移動所有測試通過
```

### pre-commit hook 規則摘要
- **通用**：禁止 >5MB 未走 LFS 的文件；禁止硬編碼機密
- **【新增 ERR-012/015 後】編碼驗證**：所有 .gd 文件禁止 UTF-8 BOM（EF BB BF）或 UTF-16 BOM（FF FE）；自動執行 Sensor v2 編碼掃描
- **【新增 ERR-013 後】UID 驗證**：所有修改的 .tscn 文件禁止 ext_resource UID 等於場景 UID；自動執行 UID 自引用掃描
- **前置保護**：沒有 `docs/GAME_DESIGN.md` 禁止提交任何 `.gd/.tscn/.tres`
- **文件保護**：`docs/GAME_DESIGN.md` 只有 designer 能修改
- **Designer**：禁止提交任何 `.gd/.tscn/.tres`
- **Architect**：禁止提交任何 `.gd/.tscn/.tres`
- **Developer**：`.gd` 提交前必須通過 Godot `--check-only` 語法驗證；禁止在 main 分支提交 `.gd`
- **QA**：禁止提交任何自行撰寫的新 `.gd/.tscn/.tres`
- **【強化 v3】Sensor 最終閘門**：commit 前 Developer **手動執行** `.\scripts\sensor-scan.ps1`，確認全部 PASS（含 --check-only）。**注意：pre-commit hook 不會自動呼叫 sensor-scan.ps1**，這是流程紀律而非 hook 自動保護。

---

## D. 新專案 Bootstrap 流程（AI 執行！）

當進入全新空白 Godot 專案時，依序執行！

### D1. 建立目錄骨架
```
docs/
  GAME_DESIGN.md      → Designer 的必要文件（從模板建立！）
  ERROR_LOG.md        → 錯誤知識庫（從模板建立！）
  PROJECT_STATUS.md   → 專案狀態追蹤（從模板建立！）
  arch_log.md         → Architect 工作日誌
  review_log.md       → Reviewer 工作日誌
hooks/                → Git hooks（從舊專案複製）
roles/                → 6 個角色定義文件（含 sensor.md）
scripts/              → PowerShell 工具腳本
```

### D2. Git 設定
```bash
# LFS 設定
git lfs install
git lfs track "*.tscn"
git lfs track "*.tres"
git lfs track "*.png"
git lfs track "*.wav"
git lfs track "*.ogg"
git lfs track "*.mp3"
echo "*.tscn merge=binary" >> .gitattributes

# Hook 路徑設定（關鍵！）
git config core.hooksPath hooks

# tscn merge driver
git config merge.binary.name "Binary merge driver"
git config merge.binary.driver "cp %A %P"
```

### D3. 建立 .agent-role
```
echo "designer" > .agent-role
```
> 新專案永遠從 Designer 開始。

### D4. 建立必要文件（若不存在）
- `docs/GAME_DESIGN.md` → 從模板建立（所有欄位 [DRAFT]）
- `docs/ERROR_LOG.md` → 從模板建立
- `docs/PROJECT_STATUS.md` → 從模板建立
- **`docs/DOC_INDEX.md`** → **必要！文件總索引，所有 ROLE 開場必讀**
- `roles/designer.md` `architect.md` `developer.md` `reviewer.md` `qa.md` `sensor.md`
- `hooks/pre-commit` `commit-msg` `prepare-commit-msg` `pre-push` `post-merge`
- `scripts/set-role.ps1` `lock-scene.ps1` `worktree.ps1` `sensor-scan.ps1`

### D4.5 建立 DOC_INDEX.md（新專案必建）

```
DOC_INDEX.md 最小模板（複製後依實際狀況填寫！）
═══════════════════════════════════════════════════
# DOC_INDEX.md — 專案文件總索引
版本：v1 (建立日期)
維護者：所有 ROLE（每次新增文件時必須更新）
讀取時機：每個 ROLE 工作開場「第 3 步」

## 職責矩陣
| 文件 | Designer | Architect | Developer | Reviewer | QA | Sensor |
|------|:--------:|:---------:|:---------:|:--------:|:--:|:------:|
| docs/GAME_DESIGN.md | 寫/讀 | 讀 | 讀 | 讀 | 讀 | 監控 |
| docs/ERROR_LOG.md | 讀 | 讀/寫 | 讀/寫 | 讀/寫 | 讀/寫 | 讀/寫 |
（隨專案擴充）

## 完整文件清單
（依 DOC_INDEX.md 模板填寫各件路徑、負責角色、最後更新）

## 強制更新規則
☐ 新增任何文件時：在本索引加入一行
☐ 修改現有文件時：更新「最後更新」欄位
═══════════════════════════════════════════════════
```

> ⚠️ **若新專案缺少 DOC_INDEX.md → Sensor 應在第一次掃描時報告並要求補建。**

### D5. 初始 commit
```bash
git add .
git commit -m "chore: 初始化多角色開發工作流結構"
```

---

## E. scripts/ 工具說明

| 腳本 | 用途 | 使用方式 |
|------|------|---------|
| `set-role.ps1` | 設定目前角色，更新 `.agent-role` | `.\scripts\set-role.ps1 designer` |
| `lock-scene.ps1` | LFS 鎖定/解鎖 .tscn 文件（Developer 修改場景前必用） | `.\scripts\lock-scene.ps1 lock Scenes/Main.tscn` |
| `worktree.ps1` | 建立/管理 git worktree（Developer 在 feature 分支工作！） | `.\scripts\worktree.ps1 new feature-name` |
| `agent-monitor.ps1` | 監控所有 agent sessions 的表板 | `.\scripts\agent-monitor.ps1` |
| `sensor-scan.ps1` | **Sensor 自動掃描腳本**（編碼+UID+物理+**GDScript --check-only**+**ERR-028** 驗證！） | `.\scripts\sensor-scan.ps1` |

---

## F. MCP 工具使用模板

| 角色 | Memory MCP | GitHub MCP |
|------|-----------|-----------|
| Designer | 寫入確認的設計決策 | 建立 Issue 通知 Architect |
| Architect | 寫入架構決策和任務狀態；**寫入反省記錄** | 建立 Issue 追蹤任務 |
| Developer | 讀取設計決策；完成後更新狀態；**寫入開發反省記錄** | 建立 PR |
| Reviewer | 讀取設計決策作為審查基準；**讀取 Developer 反省記錄** | 審查 PR、留言；**查閱 Sensor 的掃描報告** |
| QA | 讀取 DoD 作為測試基準；完成後更新 DONE | 在 PR 留測試報告 |
| Sensor | 讀取 ERROR_LOG.md 確認已知模式；完成後更新 ERROR_LOG | 通知 Reviewer 進行二次審查 |

### Memory 實體命名規範
```
design_[決策名稱]       → 設計師存入的決策（EntityType: GameDesign）
arch_decision_[名稱]   → 架構師存入的架構決策（EntityType: ArchitectureDecision）
arch_reflection_[日期] → 架構師的反省記錄（EntityType: Reflection）
task_[功能名稱]         → 任務狀態追蹤（EntityType: Task）
                           狀態流：PLANNED → IN_DEV → IN_REVIEW → IN_QA → DONE

dev_reflection_[日期]_[功能] → Developer 的反省記錄（EntityType: Reflection）
review_reflection_[日期]_[功能] → Reviewer 的反省記錄（EntityType: Reflection）
sensor_report_[日期]_[ERR] → Sensor 的掃描報告（EntityType: SensorReport）
blocked_issue_[日期]   → 熔斷事件記錄（EntityType: BlockedIssue）
```

---

## G. 工作流狀態機（完整版）

### G-1. Godot 開發任務路徑（程式碼 / 場景 / 資源）

```
[GAME_DESIGN.md 全部 CONFIRMED]
         ↓  Designer commit → hook 驗證通過
         ↓  切換角色：set-role.ps1 architect
         ↓  Architect 讀 DOC_INDEX(-2) + ERROR_LOG(0) + PROJECT_STATUS(-1)
  → 讀 GAME_DESIGN → 寫 implementation_plan.md
  → 寫 arch_reflection → 更新 PROJECT_STATUS
         ↓  Architect commit → hook 驗證通過
         ↓  切換角色：set-role.ps1 developer
         ↓  Developer 讀 DOC_INDEX(-2) + ERROR_LOG(0) + PROJECT_STATUS(-1)
  → 建 worktree → 在 feature 分支寫代碼
  →                   ↓  遇到物理/信號代碼 → [召喚 Sensor]
  Sensor 讀 DOC_INDEX(-2) + ERROR_LOG(-1) → 掃描
  Sensor Level 1（緊急）or Level 2（輕量）→ 修裁 → 通知 Reviewer → 返回
         ↓  Developer commit（Godot --check-only + BOM + UID 驗證）→ push → PR
  → 寫 dev_reflection → 更新 PROJECT_STATUS
         ↓  切換角色：set-role.ps1 reviewer
         ↓  Reviewer 讀 DOC_INDEX(-2) + ERROR_LOG(0) + Memory 設計決策 → 審查 PR
  → 執行 BOM + UID + SubResource + callback 鏈追蹤
  → 若發現問題：退回 Developer（視情況召喚 Sensor）
  → 通過：批准 PR → 寫 review_reflection → 更新 PROJECT_STATUS
         ↓  切換角色：set-role.ps1 qa
         ↓  QA 讀 DOC_INDEX(-2) + ERROR_LOG(0) + Memory DoD → 執行測試
  → 建立 qa-report → 結論
  → 若發現運行時錯誤：召喚 Sensor → Sensor 掃描 → 退回 Developer
  → 全部通過：git commit + push → 更新 PROJECT_STATUS → DONE
```

### G-3. 文件 / 規則修改路徑（§MOD SOP）

```
[用戶要求修改 WORKFLOW / 規則 / 文件]
         ↓  必須走 §MOD 5步驟 SOP（禁止繞過直接修改）
  步驟①（Sensor）：sensor-scan.ps1 現狀掃描
  步驟②（Architect）：差距分析 + 修改計畫（等用戶確認！）
  步驟③（Developer）：實施修改 + Select-String 驗證落地
  步驟④（Reviewer）：新規則衝突審查 + ERROR_LOG 更新
  步驟⑤（QA）：模擬測試驗證（5種情境，至少選1）→ git commit
         ↓  DONE（所有文件已更新，DOC_INDEX.md 已同步）
```

---

## H. Sensor 角色詳細規格（新增！）

**Sensor 是本工作流的第六個角色，不在主串行流中，而是「隨時插入」的守衛。**

### 觸發條件

| 觸發等級 | 觸發模式 | 誰負責觸發 |
|---------|---------|---------|
| ⛔ Level 1（緊急） | 物理 callback 內有場景樹操作；.tscn 引用不存在的 .gd；deferred 鏈中直接 add_child | 任何 ROLE 看到代碼時立即觸發 |
| ⚠️ Level 2（輕量） | `int(float)` narrowing；三元運算符型別不一致；無防重入守衛；複製 .tscn（含中文 .gd，UTF-8 BOM，Godot 3 廢棄 API）；**VFX AnimatedSprite2D 未設 scale**；**@export PackedScene 未在 .tscn 中賦值**；**.tscn 開頭缺少 `[`（ERR-023）**；**SpriteFrames frame dict 中直接寫 `region` 而非使用 AtlasTexture（ERR-024）**；**`extends SceneTree` 腳本內呼叫 `get_tree()`（ERR-028）** | 當前 ROLE 本次工作結束後觸發 |

### Sensor 處理流程
1. **讀取 ERROR_LOG.md** → 確認是否已有對應 ERR 記錄
2. **追蹤完整呼叫鏈**（Level 1：快速確認；Level 2：）
3. **自動修裁**（Level 1：建議修改方向；Level 2：）
4. **執行靜態驗證**（Godot --check-only + Sensor v2 腳本）
5. **更新 ERROR_LOG.md**（若是新型態問題！）
6. **通知 Reviewer** 進行二次審查
7. **返回原 ROLE 繼續工作**

### Sensor 的自我學習機制

Sensor 在每次反省記錄（roles/sensor.md 的「Sensor 反省與成長記錄」）中：
- 記錄觸發事件、根本原因、觸發表更新
- 識別觸發表的「盲點」（哪些問題類型仍未被涵蓋！）
- 提出觸發表改進方案
- 當盲點累積超過 3 次 → 提交「Sensor 架構升級申請」給 Architect

---

## I. 關鍵規則摘要（任何角色都必須遵守！）

1. **設計優先**：沒有 `docs/GAME_DESIGN.md` 禁止任何代碼文件進入 repo
2. **角色隔離**：Designer/Architect/Reviewer/QA 的 commit 不得包含 `.gd/.tscn/.tres`
3. **分支保護**：Developer 的 `.gd` 代碼不得直接 push 到 main
4. **場景鎖定**：Developer 修改 `.tscn` 前必須執行 `lock-scene.ps1 lock`
5. **熔斷機制**：Developer 針對同一 Bug 連續失敗 3 次 → 必須回報 Architect，不得繼續嘗試
6. **測試基準**：QA 只依據 Memory 中的「DoD（完成定義）」，不依賴 Developer 的說明
7. **格式強制**：所有 commit 訊息必須符合 `[ROLE] type: 描述` 格式
8. **Sensor 優先**：任何 ROLE 看到 Level 1 觸發條件 → **立即停止當前工作，呼叫 Sensor**
9. **反省強制**：Architect/Developer/Reviewer 在每次工作結束後必須寫反省記錄（Memory MCP + 對應日誌文件）
10. **ERROR_LOG 強制**：任何 ROLE 修復錯誤後必須更新 ERROR_LOG.md；任何 ROLE 開始工作前必須讀 ERROR_LOG.md
11. **編碼強制**：所有 .gd 文件必須是 UTF-8 無 BOM（推薦統一以英文撰寫以避免編碼風險）
12. **UID 驗證強制**：複製 .tscn 後必須驗證 ext_resource UID 不等於場景自身 UID
13. **VFX Scale 強制**：所有 VFX AnimatedSprite2D 必須設定 scale（比例基準：角色高 22px。近戰弧=0.35, 槍口=0.15, 受擊=0.20, 死亡=0.30）
14. **@export 自動配置**：任何 @export PackedScene 或 @export NodePath 在腳本建立後，必須在所有引用該腳本的 .tscn 中加入 ext_resource + 屬性賦值。禁止依賴手動 Inspector 拖拽（AI 無法自動執行）；但保持 @export，不改為 Autoload
15. **修改 .tscn 安全寫入規則**：對任何 .tscn 做自動化修改時，必須使用 `[IO.File]::ReadAllText()` + `[IO.File]::WriteAllText(path, content, UTF8NoBOM)`。絕對禁止使用 `Get-Content -Encoding UTF8` 或 `Set-Content -Encoding UTF8`（老版本會加 BOM 字元，導致 -replace 時會吃掉開頭 `[`）。寫入後必須驗證：`[char]([IO.File]::ReadAllBytes(path)[0]) -eq '['`
16. **SpriteFrames 幀必須用 AtlasTexture**：Godot 4 的 SpriteFrames frame dict 中的 `region` 欄位被**完全忽略**。每幀必須使用獨立的 `AtlasTexture` sub-resource（`atlas=tex, region=Rect2`），在 frame dict 中引用該 AtlasTexture。load_steps = 2 + frameCount + 1
17. **SceneTree 腳本禁止呼叫 get_tree()**：`extends SceneTree` 的腳本中，self 就是 SceneTree，不得呼叫 `get_tree()`（那是 Node 的方法）。使用 `await process_frame` 取代 `await get_tree().process_frame`。Sensor v5 已自動偵測此模式（ERR-028）
18. **get_node_or_null 必須顯式型別（ERR-030）**：`get_node_or_null()` 回傳 `Variant`，若直接用 `:=` 推斷其屬性（如 `.global_position`），GDScript 在嚴格模式下報 `Cannot infer type` 錯誤。**必須**：`var node: Node2D = get_node_or_null("X") as Node2D`，屬性存取用 `var x: Vector2 = node.global_position`。Sensor v10 Check 11/15 自動偵測
19. **TileSet .tres 必須顯式聲明 tile_size（ERR-031）**：所有 TileSet `.tres` 的 `[resource]` 區塊必須有 `tile_size = Vector2i(W, H)`，禁止依賴 Godot 預設值 `Vector2i(16,16)`。缺少聲明會在 atlas 為 8×8px tile 時造成編輯器格線錯位（16px grid ≠ 8px tile）。確認方式：圖片尺寸 ÷ tile 數量。Sensor v10 Check 12/15 自動偵測
20. **同一 for-loop block 禁止同名變數（ERR-032）**：在同一個 `for` loop 的 inner scope 和 outer scope 中變數同名，GDScript 報 `declared below in the parent block` 警告。對策：outer scope 變數加修飾詞區別（如 `root_marker` vs `marker`）。小心 `marker/node/child/item` 等通用名稱很容易在嵌套循環中重複
21. **函式參數禁止使用基底類別屬性同名的名稱（ERR-033）**：GDScript 中函式參數名等於基底類別屬性名時，會報 `shadowing an already-declared property` 警告。**禁止用作參數名的內建屬性**：`visible / position / rotation / scale / modulate / name / owner / process_mode`。對策：參數加意義式前綴（如 `show_hint: bool` 而非 `visible: bool`）
22. **add_child 必須在 is_inside_tree 相依屬性前（ERR-034）**：`Camera2D.make_current()`, `set_as_top_level()`, 信號連接等 API 需要節點已在 SceneTree 中（`is_inside_tree()` 為 true）才能呼叫。安全順序：**允許 `add_child(node)` 再呼叫依賴樹的 API**。常見錯誤在建立節點後立即呼叫而忘記加入樹
23. **warn 邏輯必須要有 fallback 層次（ERR-035）**：在 `_ready()` 已警告「No SpawnPoint」，但設計上有 Checkpoint 的房間不需要 SpawnPoint，警告就說警告，只是亂開發/調試輸出。原則：只有在「所有 fallback 機制都失效」時才發出 push_warning，最後的 fallback 就不發警告
24. **GUT 單元測試整合規範（Phase-7.0 新增）**：
    - 插件 `addons/gut`（GUT 4.x for Godot 4）已在專案中啟用
    - **觸發條件**：QA 在驗收中發現某功能缺乏有效測試要求，可向使用者提出 GUT 測試需求
    - **撰寫責任**：Developer 負責撰寫 GUT 測試腳本，放在 `test/` 目錄
    - **執行責任**：QA 在 commit 前必須執行對應的 GUT 測試，結果記錄於 `docs/qa-report-*.md`
    - **命名規範**：測試腳本命名為 `test_<功能名>.gd`，放於 `test/` 目錄
    - **F6 測試 vs GUT 測試**：F6 實機驗證適用於一般功能，複雜系統（如 AI 狀態機、傷害計算）才需要 GUT 要求
    - **不強制 100% 要求**：大型場景更動用 F6 實機驗證即可，不必每個功能都有 GUT
25. **工具類開發腳本，不進入測試範疇**：
    - 位置：`scripts/utils/`，工具型 @tool / extends SceneTree 腳本
    - 包含：`auto_gen_convex_physics_T_sources.gd`、`build_dungeon_palette_sources.gd`、`build_palette_sources.gd`、`build_palette_sources_headless.gd`、`debug_recovery.gd`、`palette_applicator.gd`
    - 用途：Godot Editor 內的設計師/開發者助理工具，不進入正式遊戲執行流程
    - 規定：這些腳本**不被任何 `.tscn` 引用**，**不被 GUT 測試涵蓋**，**不進入 QA F6 驗證範疇**
26. **GDD 編輯紀律（Designer 強制，GAP-011）**：Designer 每次編輯 `docs/GAME_DESIGN.md` 時，**必須在寫入前執行以下三項查**：
    - **①衝突偵測**：新內容是否與現有章節中任何 [CONFIRMED] 條目相矛盾？若有衝突必須先解決再寫入
    - **②過時內容偵測**：文件中是否存在與當前實作不符的描述？發現後必須同步更新，**不得留存**
    - **③結構紀律**：**禁止把新內容直接堆在文件後段**。新節點必須整合進對應章節，文件須保持章節編號完整
    - 違反：Reviewer 有權要求 Designer 重新整理才進行其他工作

---

## J. 參考文件位置（此專案）

```
專案路徑：d:/2026-06-04/
├── docs/
│   ├── GAME_DESIGN.md              → GDD（必須含 GDD 最後同步日期標記）
│   ├── ERROR_LOG.md                → 錯誤知識庫（ERR-001 ~ ERR-041）
│   ├── PROJECT_STATUS.md           → 專案狀態追蹤
│   ├── DOC_INDEX.md                → 文件總索引（所有 ROLE 開場必讀）
│   └── archive/                   → 舊日誌文件封存（arch_log, design_log, dev_log 等）
├── hooks/                          → 所有 hook 腳本（含編碼+UID 驗證）
├── roles/                          → 6個角色完整定義（含 Doc Guardian 條款）
│   ├── designer.md                 → 含 Design Doc Guardian + GDD 編輯紀律
│   ├── architect.md
│   ├── developer.md                → 含 DEV-DOC1-5 + 禁止直接 commit 規則
│   ├── reviewer.md                 → 含 R-DOC-NEW1-4
│   ├── qa.md                       → 含 QA-FINAL-DOC + QA 驗收
│   └── sensor.md                   → 代碼感知守衛（含觸發器）
└── scripts/
    ├── set-role.ps1                → v2 新增：必讀文件清單提示（§READ SOP）
    ├── sensor-scan.ps1             → Sensor 自動掃描腳本（v10/15 checks）
    ├── dev-submit.ps1              → Developer 投遞流程
    └── utils/
        └── (工具型腳本，不進入測試)
```

> 新專案可直接複製 `hooks/` `roles/` `scripts/` 三個目錄，執行 D2 的 git 設定。
> **新增：專案建立後必須建立 docs/DOC_INDEX.md，且所有 ROLE 必須將強制讀取步驟加入其 roles/*.md 的 MUST-DO 清單。**

---

## K. 角色協動矩陣（新增！）

| 觸發情境 | 主責 ROLE | 支援 ROLE | 結果 |
|---------|---------|---------|------|
| 設計需求提出 | Designer | — | GAME_DESIGN.md 更新 |
| 設計確認後開始架構 | Architect | Designer（確認設計！） | implementation_plan.md + Memory 更新 |
| 架構完成後開始實作 | Developer | Architect（DoD 澄清） | Feature branch + PR |
| Developer 遇到物理程式 | **Sensor（Level 1）** | Developer | 修裁 + Reviewer 通知 |
| Developer 遇到 narrowing/ternary | **Sensor（Level 2）** | Developer | 快速掃描確認 |
| Developer 複製 .tscn | **Sensor（Level 2）** | Developer | UID 自引用驗證 |
| **Developer 用 := 推斷 Array 方法回傳值** | **Sensor（Level 2）** | Developer | 型別檢查（var x: Node = arr.back()） |
| Developer 三次失敗熔斷 | **Architect** | Sensor（協助分析） | 重新設計方案 |
| PR 建立後 | Reviewer | Sensor（BOM + UID 驗證輔助） | 審查報告 + PR 批准/退回 |
| Reviewer 發現 runtime 危險模式 | Reviewer → **Sensor** | — | 緊急掃描 + 退回 Developer |
| PR 批准後測試 | QA | — | QA 報告 |
| **QA 發現 [GDD TODO] 未解決** | **QA → Designer** | — | 禁止 QA 通過，要求 Designer 更新 GDD |
| QA 發現 runtime 錯誤 | QA → **Sensor** | Developer（修復） | 緊急掃描 + 退回 Developer |
| **commit 前 sensor-scan.ps1 FAIL** | **Sensor → DEVELOPER must fix** | — | Sensor exit 1，輸出錯誤文件行號 |
| 任何 ROLE 發現新型態問題 | **Architect** | Sensor（更新觸發表） | ERROR_LOG 更新 + 角色文件更新 |

---

## L. 強制跨角色通知協議 v1【ERR-027 後新增】

> **核心原則：任何角色做出修改後，必須通知所有可能受影響的角色。**

### L1. 修改觸發通知矩陣

| 誰做了改動 | 修改內容 | 必須通知誰 | 被通知角色必須執行的動作 |
|-----------|---------|-----------|----------------------|
| **Developer** | 更新 @export PackedScene（VFX/武器/道具） | → **Reviewer** | 確認**所有**引用該腳本的 .tscn 都已更新（含基底場景） |
| **Developer** | 更新 player 場景（加節點、改配置） | → **Reviewer + QA** | Reviewer 追蹤 test_room 使用哪個版本；QA 確認基底和數字版本都完整 |
| **Developer** | 修改 VFX 顏色/可見性/播放邏輯 | → **Reviewer + Designer** | Reviewer 驗證代碼；Designer 確認 GDD 同步 |
| **Designer** | 更新 GDD 設計數值 | → **Architect** | 確認實作計畫需否修改 |
| **Designer** | 更新 GDD 染色/VFX 規格 | → **Developer** | 確認代碼實作對應 |
| **Reviewer** | 發現場景配置不一致 | → **QA** | 在 QA 驗收清單中加入對應測試案例 |
| **Sensor** | 發現新型態問題 | → **Reviewer + Developer** | Reviewer 退回 PR；Developer 修復 |

### L2. Developer 強制「場景要求覆蓋」規則（ERR-027 After）

當 Developer 修改**任何 player 相關功能**後，**commit message 必須附上**：

```
[DEV] feat: 實作近戰VFX

Scene Coverage:
- [x] player.tscn（基底）
- [x] player1.tscn
- [x] player2.tscn
- [x] player3.tscn
- [x] player4.tscn

References in test scenes: test_room_a.tscn → player.tscn
```

若任何場景未打勾 → pre-commit hook 應拒絕（實際由 Reviewer 人工守門）。

### L3. QA 強制「引用鏈驗證」步驟（ERR-027 After）

QA 驗證任何「功能是否在遊戲中可見」之前，**必須先執行**：

```powershell
# ERR-027 防護：確認測試場景使用的 player 場景版本
Write-Host "=== 測試場景引用的 player 場景 ==="

# 步驟1: 確認 test_room 引用的是哪個 player 場景
Select-String -Path "D:\2026-06-04\scenes\*.tscn" -Pattern 'player\.tscn' | Select-Object Filename, Line

# 步驟2: 確認 player.tscn（基底）有 VFX 完整配置
$base = [IO.File]::ReadAllText("D:\2026-06-04\scenes\player\player.tscn")
foreach ($key in @("melee_slash_scene","melee_slash2_scene","melee_impact3_scene","MeleeVFXPivots")) {
    if ($base -match $key) { Write-Host "✅ $key" } else { Write-Host "❌ MISSING: $key → ERR-027!" }
}
```

### L4. Sensor 新增觸發條件（ERR-027 後更新）

| 觸發等級 | 觸發模式 |
|---------|---------|
| ⚠️ Level 2 | **@export PackedScene 修改後，未更新所有引用該腳本的 .tscn（含基底場景）** |
| ⚠️ Level 2 | **Commit message 沒有「Scene Coverage」清單，但 PR 涉及 player 場景** |

### L5. K 協動矩陣新增項（ERR-027 場景要求失誤）

| 觸發情境 | 主責 ROLE | 支援 ROLE | 結果 |
|---------|---------|---------|------|
| **Developer 更新 @export PackedScene** | Developer | → Reviewer（審查要求覆蓋） | 確認基底和數字版本全部更新 |
| **QA 發現特定功能在遊戲中不可見** | QA → **ERR-027 防護** | Developer | 追蹤 test_room → player.tscn 引用鏈 |
| **任何角色修改 player 場景配置** | 該角色 | → 通知 Reviewer + QA | 場景要求清單確認 |

---

## M. [RRP] 規則強化落地協議（Rule Reinforcement Protocol）v1

> **核心理念**：任何反省記錄、新 ERR 條目、口頭要求只有在被落實為以下三層之一時，才算真正的規則。**未落地的規則 = 不存在的規則。**

### M1. 三層落地架構

| 層級 | 機制 | 強度 | 可繞過？ |
|------|------|------|---------|
| 第一層 | hooks/pre-commit exit 1 | ⛔⛔⛔ | 只有 git commit --no-verify（需明確操作） |
| 第二層 | scripts/sensor-scan.ps1 | ⚠️⚠️ | 不執行時才可繞過 |
| 第三層 | roles/*.md 強制清單 | ⚠️ | AI agent 可能跳過，最弱 |

### M2. 新增規則的標準流程（Rule Reinforcement Checklist）

當你被要求「加入新規則」、「記錄新錯誤」、「做出反省改進」時，**必須按此流程執行**：

```
STEP 1：確認規則內容
  - 是哪個錯誤觸發的（ERR-xxx）
  - 哪個角色負責執行？違反行為是什麼（具體可偵測）？

STEP 2：評估「機器可偵測性」
  - 可以 grep/regex/byte 掃描偵測嗎？
    → 若是：必須加入 sensor-scan.ps1 AND/OR pre-commit hook
  - 若只能人工判斷：加入角色的「交接閘門」清單

STEP 3：更新三層（按優先序）

  [第一層] hooks/pre-commit：
    在對應 ROLE 的 if ROLE = "xxx" 區塊新增閘門
    嚴重違規 → exit 1；重要提醒 → sleep 5 + echo
    命名格式：echo "[RoleName/N] 說明..."

  [第二層] scripts/sensor-scan.ps1：
    新增 Check N/N 區段（在 Result summary 之前）
    更新 header 的 Check 清單說明（版本號）
    執行 PSParser 驗證後試跑確認無誤

  [第三層] roles/*.md：
    在對應角色的「開場強制清單」、「交接閘門」加入 checked 項目

STEP 4：更新 workflow.md
  在 §I 關鍵規則清單加入新條目
  更新 §M3 Gap 修復狀態表

STEP 5：更新 ERROR_LOG.md（若涉及具體 bug）
  確認有 ERR-xxx 條目（根本原因 + 修復方案 + Sensor 規則）

STEP 6：執行驗證
  .\scripts\sensor-scan.ps1 確認 PASS
  git add hooks/pre-commit scripts/sensor-scan.ps1 roles/ docs/ workflow.md
  git commit -m "[ARCH] enforce: 新增規則 [規則名稱] — 三層落地完成"
```

### M3. 已知缺口修復記錄（Gap Audit 2026-06-14）

| Gap ID | 問題 | 修復狀態 | 修復方案 |
|--------|------|---------|---------|
| GAP-001 | GDD 中文亂碼無機器驗證 | ✅ 已修復 | pre-commit [Designer/3] + sensor-scan v6 Check 10/10 |
| GAP-002 | 反省記錄強制要求無驗證 | ⚠️ 部分修復 | 機器無法驗證 Memory MCP；role 清單已強化說明 |
| GAP-003 | ERROR_LOG 更新無驗證 | ✅ 已修復 | pre-commit Developer 段加入 fix: 警告（sleep 5） |
| GAP-004 | GDD 關鍵章節驗證從未執行 | ✅ 已修復 | sensor-scan v6 Check 10/10 (b) 關鍵字存在性掃描 |
| GAP-005 | Reviewer BOM 掃描無明確步驟 | ✅ 已修復 | reviewer.md 交接閘門補強 |
| GAP-006 | DEV-DOC 重複定義 | ✅ 已修復 | developer.md 合併重複項 |
| GAP-007 | ARCH-DOC 無 hook 對應 | ⚠️ 部分修復 | hook 已有 [Architect/2]；ARCH-DOC3/4 仍為文件要求 |
| GAP-008 | QA GDD TODO 無閘門 | ✅ 已修復 | pre-commit [QA/4] exit 1 硬阻斷 |
| GAP-009 | Rule Reinforcement Protocol 不存在 | ✅ 已修復 | 本章節 §M |
| GAP-010 | sensor-scan 不掃 .md 文件 | ✅ 已修復 | sensor-scan v6 Check 10/10 |
| ERR-029 | Portal Walk-in 重觸發黑屏（新場景實例 _triggered=false 競態！） | ✅ 已修復 | game_world.gd entry portal monitoring 禁用 + 計時器重啟；developer.md rule w；gap-audit 驗證 |
| ERR-030 | get_node_or_null 回傳 Variant，:= 屬性推斷失敗（Parser Error） | ✅ 已修復 | room_base.gd 顯式型別修正；Sensor v10 Check 11/15 自動偵測；ERROR_LOG 新增；workflow §I rule 18 |
| ERR-031 | TileSet .tres 缺 tile_size，編輯器格線 16px vs 實際 8px tile 對不上 | ✅ 已修復 | dungeon_world_tileset.tres + monochrome_packed.tres 加入 tile_size；Sensor v10 Check 12/14；ERROR_LOG 新增；workflow §I rule 19 |
| ERR-032 | for-loop 同 block 變數同名（marker shadow） | ✅ 已修復 | room_base.gd:169 var marker → var root_marker；ERROR_LOG 新增；workflow §I rule 20 |
| ERR-033 | 函式參數遮蔽基底類別屬性（visible shadows CanvasItem.visible） | ✅ 已修復 | checkpoint.gd:142 visible → show_hint；ERROR_LOG 新增；workflow §I rule 21 |
| ERR-034 | Camera2D.make_current() 在 add_child 前呼叫（is_inside_tree() 失敗） | ✅ 已修復 | room_base.gd:208 移至 player.add_child(cam) 後；ERROR_LOG 新增；workflow §I rule 22 |
| ERR-035 | SpawnPoint 無效警告（有 Checkpoint 時仍噪音警告！） | ✅ 已修復 | room_base.gd _ready() 移除無效警告，fallback 機制已足夠；ERROR_LOG 新增；workflow §I rule 23 |
| GAP-011 | Designer 編輯 GDD 時無衝突/過時偵測規範，導致 Agent 堆積錯誤內容 | ✅ 已修復（2026-06-15） | workflow §I rule 26 新增強制三項查；pre-commit [Designer/2] 已有 GDD 必更新閘門（機器偵測僅結構驗證，衝突/過時由 AI 本身執行） |

### M4. 規則強度等級

| 等級 | 機制 | 範例 |
|------|------|------|
| ⛔⛔ 機器強制 | hook exit 1（不可繞過） | GDD亂碼(GAP-001)、GDD TODO閘門(GAP-008)、Designer提交代碼、BOM |
| ⛔ Sensor FAIL | sensor-scan exit 1 | --check-only失敗、.tscn首字節錯誤、UID自引用、GDD關鍵字缺失 |
| ⚠️ Hook警告 | sleep 5 不exit | fix: commit未更新ERROR_LOG(GAP-003)、Designer未更新GDD |
| 文件要求 | role清單（AI可跳過） | Memory MCP反省記錄(GAP-002)、ARCH-DOC3/4 |

### M5. 反省觸發標準流程

當用戶要求某 role 做出「反省」「補強」時，固定執行：

```
1. 【切換角色】Set-Content -Value "architect" -Path ".agent-role" -NoNewline
   （workflow 變更屬於架構層決策）

2. 【審計現況】.\scripts\sensor-scan.ps1 確認當前狀態

3. 【分析】M2 STEP 1-2 評估「機器可偵測性」

4. 【執行落地】M2 STEP 1-6 完整執行三層落地

5. 【驗證】再次執行 sensor-scan.ps1 確認 PASS

6. 【記錄】更新 M3 表格 Gap 修復狀態

7. 【提交】git commit -m "[ARCH] enforce: [反省主題] — 落地完成"
```

---

*workflow.md §M 由 Gap Audit 2026-06-14 新增，執行者：Architect*

---

## N. 時間限制協議 v4（防卡死機制）

> **新增於 v4（2026-06-14）— 防止任何角色無限期卡住導致整個流程死鎖。**

### N1. 各角色時間限制

| 角色 | 每次嘗試上限 | 超時處理 | 恢復方案 |
|------|-------------|----------|----------|
| **Developer** | 20 分鐘/次嘗試 | 熔斷 → 切換 architect | `set-role.ps1 architect` → 提交問題報告 |
| **Reviewer** | 30 分鐘/整個 PR | Sensor 介入 → 退回 Developer | 記錄「審查超時」原因；Sensor 協助分析 |
| **QA** | 45 分鐘/整個測試 | 退回 Developer（附報告！） | QA 寫失敗原因 → Developer 修復 → 重新提交 |
| **Sensor** | 5 分鐘/掃描 | 輸出部分結果即停 | 下次呼叫時重跑 |
| **Architect** | 30 分鐘/設計 | 無強制，但建議 checkpoint | 每 30 分鐘更新 implementation_plan.md |

### N2. 防卡死觸發機制

```
觸發條件（任一成立即執行防卡死程序）：
1. Developer 對同一 Bug 超過 3 次修復嘗試且全部失敗
2. Reviewer 20 分鐘後仍未輸出審查結論
3. QA 35 分鐘後仍未建立 qa-report
4. 任何角色在 10 分鐘內沒有任何可觀察到的進度

防卡死程序：
a. 立刻輸出當前進度快照（已完成的事、卡住的點）
b. 切換到 architect role 求援
c. 在 Memory 記錄「blocked_issue_[日期時間]」
d. Architect 分析問題並更新 implementation_plan.md
e. Developer 從下一個已知良好狀態重新開始
```

### N3. Developer → QA 代碼提交協議（v4 核心原則）

```
舊規則（v3，已廢棄！）：
  Developer → git commit code → git push → PR → Reviewer → QA → 完成

新規則（v4，強制執行）：
  Developer → dev-submit.ps1 → push feature branch → PR 通知 Reviewer
                                          ↓
                               Reviewer（30分鐘）→ 執行 F6 驗證 → 批准 PR
                                          ↓
                               QA（45分鐘）→ 執行 F6 + 實機驗證 → git commit+push（唯一合法提交者）
                                          ↓
                                        代碼進入 main
```

### N4. QA 唯一提交者宣言

```
⚠️ 以下是 v4 的絕對規則，不可例外！

1. Developer 永遠不得執行：git commit *.gd/*.tscn/*.tres
   → pre-commit hook 在 developer role 下阻斷此操作
   → 替代方案：.\scripts\dev-submit.ps1 -feature [名稱]

2. Reviewer 永遠不得執行：git commit 任何代碼
   → Reviewer 只能 APPROVE 或 REQUEST CHANGES

3. 只有 QA 角色在所有驗證完成後，才可執行：
   git add -A && git commit -m "[QA] test: ..." && git push

4. 若發現 Developer 繞過規則直接 commit 代碼：
   → 立即 git revert
   → 通知 Architect
   → 記錄違規事件到 ERROR_LOG.md
```

---

*workflow.md §N 由 2026-06-14 v4 更新新增，執行者：Architect*

---

## N2. 地毯式規則自檢協議（Carpet-Bombing Inspection SOP）

> **觸發時機**：當導入重大哲學變更（如 Ponytail）、發現系統規則過度臃腫時，由用戶發起地毯式檢查。
> **核心標準**：全面清查 YAGNI（不需要的規則）、DRY 違規（重複知識點）、過度工程（Rung 7 官方機制），將具體阻斷降至最低必要程度。

### 執行流程（接力式清單）

當協議啟動時，必須嚴格依序，由對應角色接力執行！

1. **Architect（發起與籌劃）**：
   - **檢視標的**：workflow.md, DOC_INDEX.md, ERROR_LOG.md, roles/architect.md
   - **職責**：找出跨角色的矛盾與過度工程（如廢棄流程）。將全局規則 Ponytail 化，並制定本次自檢的籌劃方向。完成後交棒給 Designer。

2. **Designer（設計層）**：
   - **檢視標的**：GAME_DESIGN.md, roles/designer.md
   - **職責**：確保設計沒有未來、過度防禦。拔除與必要設計無關的強制限制。完成後交棒給 Developer。

3. **Developer（實作層）**：
   - **檢視標的**：roles/developer.md
   - **職責**：將瑣碎的 Godot 報錯知識轉移給 ERROR_LOG，移除要求人或 AI 強行記憶的教條，縮減自身手冊。完成後交棒給 Reviewer。

4. **Reviewer（審查層）**：
   - **檢視標的**：roles/reviewer.md
   - **職責**：確保審查清單專注於架構與 Ponytail 落地，拔除可以用機器掃描（Sensor）代勞的人工查核苦工。完成後交棒給 QA。

5. **QA（驗收層）**：
   - **檢視標的**：roles/qa.md
   - **職責**：移除已經無效的測試案例、陳舊的驗收標準。完成後交棒給 Sensor。

6. **Sensor（自動防禦層）**：
   - **檢視標的**：roles/sensor.md, scripts/sensor-scan.ps1, hooks/pre-commit
   - **職責**：將弱的正則表達式檢查盡可能轉移給原生 --check-only。確保防禦機制符合「最小化實作」原則。

### 完結與防護機制

每個角色在完成自身文件的精簡後，必須在 commit 訊息標註 `[Role] refactor: 地毯式精簡完成`。最後一棒完成後，必須由 QA 執行整體 sensor-scan.ps1 確認安全底線未被破壞。

---

## §AUDIT. 全面工作流審查 SOP（系統級品質閘門）

> **觸發時機**：用戶要求「全面審查 / 流程審查 / 優化流程」時。與 §N2（YAGNI/DRY 地毯式清理）並列，兩者互補：§N2 是各角色自我清理，§AUDIT 是跨文件系統驗證。
> **執行角色**：Architect 主導，其他角色依需要協助。
> **前置條件**：`sensor-scan.ps1 15/15 PASS`（機器層通過後才做人工審查）

### AUDIT.0 觸發條件與執行節奏

| 觸發類型 | 時機 | 責任角色 |
|---------|------|---------|
| **用戶觸發** | 用戶要求「全面審查 / 優化流程」 | Architect 主導 |
| **§MOD 後觸發** | 每次 §MOD Step⑤ 完成後 | QA 執行 AUDIT.5 版本一致性掃描 |
| **§LESSON 後觸發** | 每次 §LESSON Step 6 完成後 | Architect 確認 §AUDIT 已補入新掃描項 |

> §N2 先清垃圾，§AUDIT 再驗系統——兩者互補，順序不可逆。

### AUDIT.1 規則強制力分析（Enforcement Strength Map）

**目標**：建立每條規則的「強制力等級」表，找出只靠文件聲明的弱規則。

```
強制力等級定義：
  [HOOK]   = pre-commit 或 commit-msg hook 硬阻斷（commit 時強制阻斷）← 最強
  [SENSOR] = sensor-scan.ps1 自動偵測（每次掃描必跑）← 強
  [FLOW]   = 角色 SOP 流程要求（由 AI/人工執行，無機器強制）← 中
  [DOC]    = 僅文件聲明，無任何機器或流程強制 ← 弱（需評估是否升級）

執行步驟：
1. 列出 workflow.md §I 所有規則
2. 對每條規則：查 hooks/pre-commit + hooks/commit-msg + sensor-scan.ps1
   確定其最高強制力等級
3. 標記所有 [DOC] 等級規則 → 評估是否可升級到 [SENSOR] 或 [FLOW]
4. 輸出 §AUDIT.6 報告表（見下方格式）
```

### AUDIT.2 SAS 合規掃描（Single Authoritative Source Compliance）

**目標**：確認所有 §SAS.1 規定的 SAS 政策被遵守，無未授權的完整複製。

```powershell
# 依序執行 §SAS.1 各類別掃描（貼入 PowerShell 執行）
$root = "D:\2026-06-04"
$md = Get-ChildItem $root -Recurse -Filter "*.md" | Where-Object { $_.FullName -notmatch "\\archive\\" }

# SAS-A：Ponytail 7-rung 完整定義（SAS：workflow.md）
$md | Where-Object { $_.Name -ne "workflow.md" } | ForEach-Object {
  $c = (Select-String "Rung \d" $_.FullName).Count
  if ($c -ge 4) { "[SAS-A VIOLATION] $($_.Name): $c Rung mentions = has full definition" }
}

# SAS-B：§MOD 完整 5 步驟（SAS：workflow.md）
$md | Where-Object { $_.Name -ne "workflow.md" } | ForEach-Object {
  if (Select-String "步驟①" $_.FullName) { "[SAS-B VIOLATION] $($_.Name)" }
}

# SAS-C：§READ 完整步驟（SAS：DOC_INDEX.md）
Get-ChildItem "$root\roles" -Filter "*.md" | ForEach-Object {
  $c = (Select-String "Get-Content.*(DOC_INDEX|PROJECT_STATUS)" $_.FullName).Count
  if ($c -ge 3) { "[SAS-C NOTE] $($_.Name): $c step lines — verify not full §READ copy" }
}

# SAS-D：Sensor Level 1/2 完整觸發表（SAS：sensor.md）
$md | Where-Object { $_.Name -ne "sensor.md" } | ForEach-Object {
  if (Select-String "Level [12].*觸發條件|觸發條件.*Level" $_.FullName) { "[SAS-D VIOLATION] $($_.Name)" }
}

# SAS-E：ERR-001 三層 call_deferred 架構說明（SAS：architect.md）
$md | Where-Object { $_.Name -ne "architect.md" } | ForEach-Object {
  if (Select-String "三層架構|Layer 1.*Layer 2" $_.FullName) { "[SAS-E VIOLATION] $($_.Name)" }
}
# 對每個 VIOLATION：移除完整重複內容，加 `→ 詳見 [SAS文件 §章節]` 一行引用
```

### AUDIT.3 矛盾偵測（Contradiction Detection）

**目標**：找出任何相互矛盾的規則描述。

```
必查清單：
□ DOC_INDEX.md 職責矩陣 vs roles/*.md 的讀/寫權限描述 vs hooks/pre-commit 實際限制
□ workflow.md §B 角色速查表 vs roles/*.md 的 MUST-DO/禁止事項
□ workflow.md §I 規則 vs 角色 MUST-DO 清單中對應的描述
□ pre-commit hook 自述版本（顯示 v3）vs 頂部註解版本（v4）
□ sensor-scan.ps1 標頭 Check X/15 vs §I 規則中引用的 "Check X/14"

偵測方法：
1. 列出 DOC_INDEX.md 職責矩陣中每個角色的讀/寫欄位
2. 在對應 roles/*.md 中找到對應的允許/禁止描述
3. 用 grep 找出 pre-commit hook 對該角色的實際限制
4. 三者必須一致 → 不一致 = 矛盾，記錄並修復
```

### AUDIT.4 死代碼偵測（Dead Rule Detection）

**目標**：找出廢棄、無法執行、或已被取代的規則。

```
掃描模式：
□ 過時外部工具引用：
  Select-String "PixelLab|PIXEL-REVIEW|G-2|browser_subagent.*allowed" `
    -Path "D:\2026-06-04\**\*.md","D:\2026-06-04\**\*.ps1" -Recurse
□ 引用不存在路徑（test_room_a/b、review_reports/ 等已移除目錄）
□ 明確標記「已廢棄 / 舊規則 v3」但未從流程文件移除的段落
□ [DOC] 強度的規則，且已有同等效果的 [HOOK] 或 [SENSOR] 規則存在

判斷標準：
  若某 [DOC] 規則所保護的行為已被 [HOOK] 強制阻斷，該 [DOC] 規則降級為「歷史說明」
  → 在規則後標記 [已由 HOOK/SENSOR 覆蓋]，縮短文字，保留在 §I 供參考
```

### AUDIT.5 版本與數字一致性

```
執行掃描：
  Select-String -Path "D:\2026-06-04\**\*.md","D:\2026-06-04\**\*.ps1" `
    -Pattern "Check \d+/\d+|Sensor v\d+|\d+/15" -Recurse

預期結果：所有 Check 引用均為 X/15；所有 Sensor 版本均為 v10
任何偏差 → 視為違規，記錄並修復
```

### AUDIT.6 審查報告格式（每次 §AUDIT 後必須產出）

```markdown
## §AUDIT Report — [日期]
執行者：[ROLE]  |  sensor-scan: [N/15 PASS/FAIL]

### 規則強制力地圖（§I 所有規則）
| # | 規則名稱 | 強制力 | 執行機制 | 行動建議 |
|---|---------|-------|---------|---------|

### SAS 違規
| 內容類別 | 違規文件 | 問題描述 | 行動 |

### 矛盾清單
| 規則/描述 A（來源） | 規則/描述 B（來源） | 矛盾點 | 行動 |

### 死代碼
| 位置 | 內容摘要 | 處置方式 |

### 版本不一致
| 術語 | 應有值 | 錯誤值 | 位置 |

### 結論
- 發現問題：[n 個]  |  需立即修復：[list]  |  建議但非緊急：[list]
```

---

## §MOD. WORKFLOW 修改 SOP — 5步驟標準流程

> **觸發時機**：用戶要求「修改 workflow / 強化規則 / 反省文件」時，AI 必須走此 5 步驟 SOP。
> **禁止**：繞過 SOP 直接修改文件，即使只是改一個字。

### MOD.1 步驟一覽表

| 步驟 | 角色 | 交付物 | 閘門條件 |
|------|------|---------|--------|
| ① 現狀掃描 | Sensor | 掃描報告（sensor-scan.ps1 輸出） | 全部 PASS 或找出具體問題 |
| ② 差距分析 | Architect | 修改計畫（文件清單 + 變更內容） | 用戶確認計畫後才能進行 |
| ③ 實施修改 | Developer | 修改對應文件（每一步測試落地） | Select-String 驗證內容已落地 |
| ④ 審查新規則 | Reviewer | 確認新規則不與現有規則衝突 | ERROR_LOG.md 已更新 |
| ⑤ 測試驗證 | QA | 模擬測試完成，確認觸發新規則 | Git commit 和記錄 |

### MOD.2 完整 SOP 說明

```
步驟①（Sensor）：現狀掃描
  - 執行 scripts/sensor-scan.ps1，記錄當前掃描結果
  - 讀取 docs/ERROR_LOG.md 確認相關 ERR 條目
  - 確認 docs/DOC_INDEX.md 是否需要更新
  - 輸出報告：哪些規則有問題，哪些文件需修改

步驟②（Architect）：差距分析
  - 分析現有規則與用戶需求的差距
  - 確定需修改的文件清單（更新 DOC_INDEX.md）
  - 輸出「修改計畫」給用戶確認（必須等用戶確認後才能進入步驟③）

步驟③（Developer）：實施修改
  - 依照計畫修改對應文件
  - 每次修改後確認文件落地（用 Select-String 驗證！）
  - 更新 DOC_INDEX.md 的「最後更新」欄位

步驟④（Reviewer）：實施修改審查
  - 確認新規則不與現有規則衝突
  - 確認相關的 ERROR_LOG.md 條目已更新
  - 確認所有角色的 MUST-DO 清單已同步
  - 【§LESSON 新增】確認 enforcement 機制（hook/script）的邏輯在此次修改後仍然正確：人工觸發一次，眼見為憑觀察輸出

步驟⑤（QA）：測試驗證
  - 執行模擬測試（用假場景觸發新規則）
  - 確認規則在 pre-commit hook 和 sensor-scan.ps1 中有效
  - Git commit（commit message 記錄本次修改說明；QA 驗收報告寫入 docs/qa-report-*.md）
```

### MOD.3 模擬測試清單（Dry Run）

以下 5 種情境為標準測試場景，每次 WORKFLOW 修改後 QA 必須至少驗證 1 種：

| 標籤 | 情境 | 驗證要點 |
|------|------|--------|
| **A** | Godot 場景修改 | pre-commit hook 攔截、Sensor 全部 PASS |
| **B** | GDScript 新加物理程式 | Sensor Level 1 觸發和修復 |
| **C** | 文件修改任務 | §MOD 5步驟 PASS，DOC_INDEX 已同步 |
| **D** | 新增文件/規則 | DOC_INDEX.md 已更新；ROLE 開場清單已同步 |
| **E** | 混合任務（Godot + 文件） | 兩個工作流不相互干擾 |

---

## §READ. 文件讀取 SOP — ROLE 開場強制清單

> **觸發時機**：每次切換 ROLE 時（set-role.ps1 執行後，開始工作前）。
> **set-role.ps1 v2 已自動顯示必讀清單**，本章為細節參考。

### READ.1 通用層次（所有 ROLE，不可跳過！）

```
第 -2 步：讀取 docs/DOC_INDEX.md
  Get-Content "D:\2026-06-04\docs\DOC_INDEX.md"
  → 確認自己角色在「職責矩陣」中的讀/寫職責
  → 找出本次任務涉及的文件類型（Godot/文件）
  → 依類型找到對應的必讀文件清單
  ⚠️ 若跳過此步驟 → Sensor 應介入中斷

第 -1 步：讀取 docs/PROJECT_STATUS.md

第  0 步：讀取 docs/ERROR_LOG.md
```

### READ.2 任務類型分支

| 任務類型 | 額外必讀文件 |
|---------|------------|
| Godot 場景/腳本修改 | implementation_plan.md；對應 roles/*.md |
| 文件/規則修改 | docs/DOC_INDEX.md（更新職責矩陣） |
| 混合任務 | 上述全部必讀（從各類型已讀文件開始） |

---

## §EDIT. 文件與腳本編輯守護 SOP

> **觸發時機**：任何 ROLE 對 `.md`、`hooks/`、`scripts/` 進行任何修改前。
> **禁止**：跳過此 SOP 直接修改，即使只是改一個數字。此 SOP 是 §MOD 的**前置步驟**。

### EDIT.1 下游影響掃描（修改前必做）

```
1. 識別你要修改的術語/數字/規則名稱
2. 執行掃描，找出所有引用該術語的文件：
   Select-String -Path "D:\2026-06-04\**\*.md","D:\2026-06-04\**\*.ps1","D:\2026-06-04\hooks\*" `
     -Pattern "被修改的術語" -Recurse
3. 查閱 §EDIT.3 Cascade Update Matrix，確認聯動文件
4. 列出完整的需更新文件清單 → 這就是你的 commit 範圍
```

### EDIT.2 Hook 邏輯驗證（修改 hooks/ 時額外必做）

```
修改任何 hooks/ 文件後，在 commit 之前：
1. 逐行驗證所有 exit 路徑 — 確認關鍵檢查未被提前 exit 繞過
   特別確認：Ponytail check 區塊前沒有任何裸 exit 0
2. 手動測試三個場景，確認 hook 實際阻斷：
   ❌ 測試1: commit 訊息不含 [Ponytail] 且代碼無 ponytail: → 必須 exit 1
   ❌ 測試2: commit 訊息格式不符 [ROLE] type: → 必須 exit 1
   ❌ 測試3: Designer 嘗試 commit .gd 文件 → 必須 exit 1
3. 全部測試通過後才能 commit hook 修改
```

### EDIT.3 Cascade Update Matrix

| ★ 若修改這個 | 必須同步更新以下文件 |
|---|---|
| `sensor-scan.ps1` check 數量（如 15→16） | `workflow.md §E` 工具表 · `roles/developer.md` · `roles/sensor.md`（Sensor v4/v5 承諾兩處） · `roles/reviewer.md` 交接閘門 · `scripts/set-role.ps1` |
| `sensor-scan.ps1` version banner | 同上，以及 `sensor-scan.ps1` 自身標頭 `## Checks:` 區塊 |
| `hooks/commit-msg` 任何 exit 邏輯 | 執行 EDIT.2 驗證；`workflow.md §C` |
| `hooks/pre-commit` 角色規則 | 對應 `roles/<role>.md §Hook 驗證`；`docs/DOC_INDEX.md` 職責矩陣 |
| 任何 role 的讀/寫權限 | `docs/DOC_INDEX.md` 職責矩陣 |
| `GLOBAL-RULE-001/002` 規則內容 | 各 `roles/*.md` 中引用該規則的段落 |
| `§READ SOP` 步驟 | `docs/DOC_INDEX.md §READ`；`scripts/set-role.ps1` 必讀清單 |
| `§MOD SOP` 步驟 | `docs/DOC_INDEX.md §MOD`（引用格式） |

### EDIT.4 Ponytail 評估與提交

```
1. 新增/修改內容：在 Ponytail 7-rung 中選最低可用 Rung（→ workflow.md §GLOBAL-RULE-002）
2. Commit 訊息含 [Ponytail] 標記
3. 執行 sensor-scan.ps1 確認全部 PASS（含 Check 15/15 自洽檢查）
4. 若新增規則/SOP/文件 → 更新 docs/DOC_INDEX.md 版本欄位
```

---

## §SAS. 單一權威來源政策（Single Authoritative Source）

> **核心原則**：每類規則只在一個「權威來源（SAS）」中保有完整內容。
> 其他文件只保留摘要行 + `→ 詳見 [SAS文件 §章節]`。
> **違反此原則 = 知識同步失效 = 這次審計所有版本號漏洞的根源。**

### SAS.1 權威來源對照表

| 內容類別 | 權威來源（SAS） | 其他文件的正確處理 |
|---------|--------------|----------------|
| GLOBAL-RULE-001（browser 禁令） | `workflow.md §GLOBAL-RULE-001` | Role files：1 行摘要 + `→ workflow.md §GLOBAL-RULE-001` |
| GLOBAL-RULE-002（Ponytail 完整定義） | `workflow.md §GLOBAL-RULE-002` | Role files：保留角色專屬 commit 要求 + `→ workflow.md §GLOBAL-RULE-002` |
| Git Hook 機制完整說明 | `workflow.md §C` | `roles/<role>.md §Hook 驗證`：只保留角色專屬限制 + `→ workflow.md §C` |
| §READ SOP 完整步驟 | `docs/DOC_INDEX.md §READ` | `workflow.md §READ`：保留摘要表格（現況正確） |
| §MOD SOP 完整 5 步驟 | `workflow.md §MOD` | `docs/DOC_INDEX.md §MOD`：已精簡為 1 行摘要 + 引用 |
| Sensor Level 1/2 觸發表詳細清單 | `roles/sensor.md §觸發條件` | `workflow.md §H`：保留摘要 + `→ sensor.md §觸發條件` |
| ERR-001 物理回呼架構詳細說明 | `roles/architect.md §物理系統` | 其他 roles：1 行摘要 + `→ architect.md §物理系統` |
| sensor-scan check 數字（當前值） | `scripts/sensor-scan.ps1`（腳本自身） | 所有 .md 引用：必須與腳本一致；sensor-scan Check 15/15 自動驗證 |
| 角色禁止事項完整說明 | `roles/<role>.md §禁止` | `workflow.md §B`：摘要表格 |
| 交接閘門詳細清單 | `roles/<role>.md §交接閘門` | `workflow.md §K`：摘要矩陣 |

### SAS.2 新增規則強制流程

```
1. 查 SAS.1 確定規則屬於哪個類別 → 找到對應的 SAS 文件
2. 在 SAS 文件寫入完整版本（complete content here only）
3. 在其他引用文件寫入：「[規則名稱]：→ 詳見 [SAS文件 §章節]」
4. 更新 docs/DOC_INDEX.md 版本欄位
5. 走 §EDIT SOP 驗證 cascade update 完整
6. 若為影響多角色行為的重大規則 → 同時走 §MOD SOP
```

---

## §LESSON. 問題捕捉與強化 SOP（Lesson Propagation Protocol）

> **觸發時機**（任何一條）：發現 hook/script 行為與文件描述不符；新增 ERROR_LOG 條目；規則在執行中被發現無效或有歧義；跨文件的同一資訊出現不一致。
> 由發現者立即觸發，切換 Sensor → Architect → Developer 接力執行。

### LESSON.1 根本原因分類（Root Cause Taxonomy）

| 類型 | 定義 | 本次審計實例 |
|------|------|------------|
| **(A) 實作 Bug** | Enforcement 機制程式碼有邏輯錯誤 | commit-msg hook 格式驗證通過後直接 exit 0，Ponytail 驗證被完全繞過 |
| **(B) 文件漂移** | 同一資訊存在於 N 個地方，更新時未同步 | sensor-scan.ps1 版本號硬編碼在 8+ 個檔案，版本升級後只更新腳本本身 |
| **(C) 設計缺陷** | SOP 遺漏了必要的驗證步驟 | §MOD SOP 沒有「驗證 enforcement 機制本身正確運作」的步驟 |
| **(D) 流程空白** | 規則存在但無任何機制確保其有效性 | sensor-scan.ps1 手動執行要求在任何 hook 或 SOP 中都沒有強制點 |

### LESSON.2 執行步驟

```
Step 1【RECORD — Sensor 執行】
  → ERROR_LOG.md 新增或更新條目，標記類型 (A/B/C/D)
  → 描述：什麼被發現、在哪被發現、哪個 SOP 步驟沒有攔截它

Step 2【CROSS-REF — Architect 執行】
  → 找出所有引用同一資訊的位置：
     Select-String -Path "roles\*.md","workflow.md","docs\*.md","scripts\*.ps1" -Pattern "關鍵詞"
  → 建立「需同步更新清單」（每一個引用位置）

Step 3【PROPAGATE — Developer 執行】
  → 更新清單中所有位置
  → 若為版本號/計數 → 改為不含硬編碼數字的描述
    （正確寫法：「sensor-scan.ps1 全部 PASS」，禁止寫「14/14 PASS」）
  → 若為規則文字 → workflow.md 為 canonical source，其他檔案用一行引用

Step 4【ENFORCE — Architect 判斷】
  → 此問題能被自動偵測？
    YES → 新增 sensor-scan.ps1 check 或 hook 邏輯
    NO  → 在對應角色的 MUST-DO 清單加入手動驗證步驟
  → 任何 enforcement 機制修改後：必須人工觸發一次，確認實際行為符合預期
  → 若此 Lesson 揭示「§AUDIT.1-5 目前無法偵測」的問題模式 →
    在 §AUDIT 對應小節補入一個新掃描項目。§AUDIT 每次 Lesson 後應能偵測更多。

Step 5【VERIFY — QA 執行】
  → 執行 sensor-scan.ps1 全部 PASS
  → 人工確認修復後的 enforcement 機制按預期工作（眼見為憑）

Step 6【COMMIT — 遵循 §MOD SOP Step 4–5，加 [Ponytail]】
```

### LESSON.3 防止重犯規則（永久有效）

- **禁止在文件中硬編碼計數型資訊**：文件只寫「sensor-scan.ps1 全部 PASS」，具體數字只存在於腳本本身
- **任何 enforcement 機制修改後必須人工驗證**：不能假設「寫了規則 = 規則生效」
- **§MOD SOP 第④步**已新增：確認相關 enforcement 機制的邏輯在修改後仍然正確（人工觸發）
