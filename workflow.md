# Godot Multi-Agent 開發工作流（完整規範）v8 (2026-06-19)

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

## 【GLOBAL-RULE-004】AskUserQuestion 中文亂碼防止規則（2026-06-22 硬性規則）

> [!CAUTION]
> **AskUserQuestion 的 question/label/description 欄位，禁止使用複雜罕見漢字。**

### 規則細節

| 規則 | 說明 |
|------|------|
| 使用高頻常用字 | 每個選項 label 控制在 8 個漢字以內，優先用常見字 |
| 技術術語加英文 | 關鍵名詞並排英文，例：「彈道 (trajectory)」 |
| 易混淆字確認 | 寫完後逐字確認：針/錢、合/吆、軌/辌、傳/産、射/鐘、貼/貧 |
| 禁用複雜字 | 以下字禁止在 AskUserQuestion 中使用，改用括號內的替代字：貼(緊靠)、軌(路)、傳(舊有)、辌(禁用)、産(禁用) |
| 簡繁混用 | 禁止用簡體字：离→離、边→邊、飞→飛；確保全程用繁體 |
| 禁止用純文字替代 | 即使擔心亂碼，也不改用「直接用文字提問」取代 AskUserQuestion |

### 禁止行為

- ❌ 改用「請直接回覆:」取代 AskUserQuestion（使用者明確要求保留選項字卡）
- ❌ 選項文字超過 15 個漢字

---

## 【GLOBAL-RULE-003】使用者輸入收集規則（2026-06-20 硬性規則）

> [!CAUTION]
> **需要向使用者收集選項時，優先使用 `AskUserQuestion` 工具（選項字卡），而非 `show_widget` 表單。**
> **若使用 `show_widget` 且回傳為空，只問一次文字補問，之後選最保守選項自行繼續，禁止鬼打牆。**

### 規則細節

| 情境 | 強制做法 |
|------|---------|
| 需要使用者在 2-4 個選項中選擇 | 使用 `AskUserQuestion` 工具（可靠，terminal 環境原生支援） |
| 需要複雜預覽/視覺對比輔助選擇 | `show_widget` + 立即在文字中補上 "或直接輸入：A/B/C" |
| `show_widget` 送出後未收到回傳 | 文字補問一次；若再無回應，選最安全/可逆選項繼續，並在回覆中說明假設 |
| 已卡問超過 1 輪 | 停止等待，做出假設，繼續工作 |

### 禁止行為

- ❌ 同一問題問超過 2 次（包含不同表達方式）
- ❌ 停在「等你的回覆」而不做任何事
- ❌ 用 `show_widget` 作為唯一的輸入通道（terminal 環境無法保證回傳）

---

## 【GLOBAL-RULE-002】（已移除）Ponytail 7-rung 機制

> [!NOTE]
> **Ponytail 7-rung ladder 機制已於 2026-06-20 經用戶授權完整移除（GAP-031）。**
> commit-msg / pre-commit / sensor-scan 不再有任何 `[Ponytail]` / `rung=N` 強制或檢查。
> **後續 session 不得以「未授權」為由重新加回此機制**——移除為用戶明確決定。
> 簡潔/避免過度工程的精神改由 GLOBAL-RULE-004 與各角色 SOP 自律維持。

---

## 【GLOBAL-RULE-004】防止鬼打牆 / 無限循環（2026-06-20 硬性規則）

> [!CAUTION]
> **AI 不得卡進重試循環。任何動作失敗時，先理解原因再行動，禁止原封不動重試。**

### 規則細節

| 情境 | 強制做法 |
|------|---------|
| 同一指令/commit 連續失敗 | 最多嘗試 **2 次**；第 2 次仍失敗 → 停止，讀錯誤訊息找根因，換方法或向用戶報告具體阻斷點 |
| commit 被 git hook 阻斷 | 閱讀 hook 輸出 → 修正該項 → 再試一次；不可盲目重複 `git commit` |
| 同一 Bug 連續失敗 3 次 | 觸發熔斷（§I Rule 5）→ 切換 Architect 重新設計，不得繼續嘗試 |
| 需要用戶輸入卻無回應 | 依 GLOBAL-RULE-003：最多補問一次 → 之後選最保守可逆選項自行繼續 |
| 純文件 / hook / 腳本的**小型維護**修改 | 可由單一角色（通常 Architect）走 §MOD 精簡路徑完成，不必強制 5 角色全程切換（避免 ceremony loop）|

### 禁止行為

- ❌ 連續 3 次以上重複同一個失敗的指令或 commit
- ❌ 在同一 SOP 步驟間反覆橫跳而無實質進展
- ❌ 為一個小修改啟動完整 5 角色 + feature branch + PR 的重型流程（除非涉及 `.gd/.tscn/.tres` 遊戲邏輯）

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

## B. 角色速查表（6 串行/守衛 + 1 顧問）

| 角色 | .agent-role 值 | 可提交的文件 | 絕對不得提交 | Commit 前綴 | 觸發條件 |
|------|---------------|------------|------------|------------|---------|
| **Designer** | `designer` | `docs/GAME_DESIGN.md`, `docs/*.md` | `.gd` `.tscn` `.tres` | `[DESIGN]` | 對話開始、設計需求 |
| **Architect** | `architect` | `implementation_plan.md`, `docs/`, `roles/` | `.gd` `.tscn` `.tres` | `[ARCH]` | Designer 完成後、Developer 熔斷時 |
| **Developer** | `developer` | 文件類（docs/、實作計劃）；代碼透過 `dev-submit.ps1` 投遞 | 所有 `.gd` `.tscn` `.tres` 直接 commit | `[DEV]` | Architect 完成設計後 |
| **Reviewer** | `reviewer` | 不提交代碼，只審查 PR | 修改任何代碼 | `[REVIEW]` | Developer 建立 PR 後；限時 **30 分鐘** |
| **QA** | `qa` | 所有代碼文件（`.gd` `.tscn` `.tres`）+ `docs/qa-report-*.md` | 自行撰寫新代碼 | `[QA]` | Reviewer 批准；限時 **45 分鐘** |
| **Sensor** | _(無獨立 role)_ | _(不提交)_ 立即掃描並修裁 | 未綁 call_deferred 的場景樹操作 | 無 | 任何角色觸發危險關鍵字時 |
| **Pixel Consultant** | `pixel-consultant` | `docs/PIXELLAB_KB.md`, `docs/art-*.md`, `docs/`, `roles/` | `.gd` `.tscn` `.tres` | `[PIXEL]` | 用戶提出**像素美術 / PixelLab / Aseprite** 需求時（顧問，非串行）|

> **Pixel Consultant（顧問角色，2026-06-20 新增）**：專責 **PixelLab × Aseprite** 像素美術諮詢——用戶給美術需求，它回「正確作法 + 推薦關鍵字 + 一致性銜接」。權威來源 `docs/PIXELLAB_KB.md`，完整職責 → `roles/pixel-consultant.md`。不寫遊戲程式碼。

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
| `pre-commit` (v7) | 每次 commit 前 | 角色感知驗證（LFS、機密、角色規則、編碼、UID、CASCADE 0e/0f、Developer auto-sensor） |
| `commit-msg` (v5) | commit 訊息確認後 | 格式驗證（`[ROLE] type: 描述`，含 `[PIXEL]`）+ fix commit ERR-XXX/GAP-XXX 引用提示（WARN） |
| `prepare-commit-msg` | commit 訊息編輯前 | 自動加入角色前綴 |
| `pre-push` (v3) | push 前 | 禁止 force push main + **SOP PENDING 阻斷 push** |
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
- **【強化 v5】Sensor 自動閘門**：pre-commit hook v5+ 在 Developer commit 時**自動執行** `sensor-scan.ps1`（21 checks）；FAIL 項目阻斷 commit。Developer 也可手動執行 `.\scripts\sensor-scan.ps1` 進行提前確認。

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

### Godot MCP（2026-06-19 新增）

> 本專案已安裝 `@coding-solo/godot-mcp` v0.1.1，透過 `.mcp.json` 接入 Claude Code。
> **無需在 Godot 安裝任何插件**；MCP server 透過 Godot CLI/stdio 與引擎通訊。
> **已驗證**：14 個工具全部可用；`get_project_info` 回傳 Godot 版本 `4.6.2.stable`。

#### 可用工具一覽（14 個）

| 工具 | 用途 | 最常用角色 |
|------|------|----------|
| `get_godot_version` | 取得 Godot 版本 | Sensor/QA 驗證 |
| `get_project_info` | 取得專案結構（scenes/scripts/assets 數量）| Architect/Reviewer |
| `run_project` | 以 debug 模式啟動遊戲 | Developer/QA |
| `get_debug_output` | 取得執行時 console 輸出與錯誤訊息 | Sensor/QA |
| `stop_project` | 停止執行中的遊戲 | Developer/QA |
| `launch_editor` | 開啟 Godot Editor | Developer |
| `list_projects` | 掃描目錄找出所有 Godot 專案 | Architect |
| `create_scene` | 建立新場景（指定 root node 類型） | Developer（謹慎使用）|
| `add_node` | 向場景新增節點（含屬性設定）| Developer（謹慎使用）|
| `save_scene` | 儲存場景（支援建立 variant） | Developer（謹慎使用）|
| `load_sprite` | 載入貼圖至 Sprite2D | Developer（謹慎使用）|
| `export_mesh_library` | 匯出 3D 場景為 MeshLibrary | Developer |
| `get_uid` | 取得檔案 UID（Godot 4.4+）| Developer/Reviewer |
| `update_project_uids` | 批次更新 UID 引用 | Reviewer/QA |

#### 使用規範

> [!IMPORTANT]
> **【驗證優先序】（2026-06-20 GAP-039 修訂）run_project 純開機效果差、效率低，不再是主驗證手段。**
> 1. **Headless 自動化測試（首選）**：GUT 或 `godot --headless --path . --script res://tests/xxx.gd`（`extends SceneTree`）。可重複、快、能**斷言邏輯/數值**、無需人工輸入。**純函式 / RefCounted 元件（物理、狀態機、約束）一律優先寫測試**（範例見 `tests/test_rope_gap037.gd`、`test_rope_gap039.gd`）。
> 2. **暫時插樁 + run_project + get_debug_output**：需要**實機真值**（座標、碰撞、viewport 尺寸等無法純邏輯推算者）時用；插樁（print / auto-fire）查完**即還原**（範例：GAP-038 抓到 `get_viewport_rect=1152×648`）。
> 3. **run_project 純開機**：僅確認「載入無 Parse/Runtime 錯誤」，**不算行為驗證**。
> 4. **玩家手動實測**：僅留給無法自動化的**主觀手感**（繩感、跳躍感）。**被動等待** — AI 實作完後告知參數數值即停止，**絕不追問「你測試了嗎？結果如何？」**。用戶有回饋自然會說。

```
[何時使用]
✅ QA 驗收：優先 headless 測試斷言邏輯；需實機真值才插樁 run_project（見上方優先序）
✅ Sensor 掃描：get_debug_output 取得即時 runtime 錯誤（補充靜態 sensor-scan.ps1）
✅ Architect 分析：get_project_info 確認專案結構數量符合設計
✅ Developer 調試：優先 headless 測試；需實機真值才 run_project + get_debug_output 插樁
✅ Reviewer 審查：get_uid 確認 UID 正確性

[謹慎使用場景]
⚠️ create_scene / add_node / save_scene：會直接修改 .tscn 檔案
   → 必須走完整 §IMPL SOP，結果需 Reviewer 確認
   → 不可替代手動在 Godot Editor 操作（缺乏視覺確認）
   → 執行前先 git status，確保有退路

[禁止場景]
❌ 用 MCP 工具繞過 git hook 提交（hook 仍然有效）
❌ 在 QA 角色用 create_scene/add_node（QA 不寫代碼）
```

#### MCP 配置檔

```json
// .mcp.json（已 commit）
{
  "mcpServers": {
	"godot": {
	  "command": "node",
	  "args": ["D:\\2026-06-04\\node_modules\\@coding-solo\\godot-mcp\\build\\index.js"],
	  "env": {
		"GODOT_PATH": "C:\\Users\\88698\\Downloads\\Godot_v4.6.2-stable_win64.exe\\Godot_v4.6.2-stable_win64.exe"
	  }
	}
  }
}
```

> **注意**：`node_modules/` 已加入 `.gitignore`，重新 clone 後需執行 `npm install` 重建。
> MCP server 在 Claude Code 啟動時自動連線，無需手動啟動。

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

## H. Sensor 角色

**Sensor 是本工作流的第六個角色，不在主串行流中，而是「隨時插入」的守衛。**

> → 完整觸發條件與處理流程：`roles/sensor.md`（SAS 權威來源）

---

## I. 關鍵規則體系（三層架構）

> **閱讀說明**：I-A 違反時機器自動阻斷；I-B 有機器升級路徑（§LEARN 追蹤）；I-C 行為準則，無法機器化。

### I-A. 機器強制層（違反時自動阻斷）

| # | 規則 | 執行機制 |
|---|------|---------|
| 2 | **角色隔離**：Designer/Arch/Reviewer/QA commit 不得含 `.gd/.tscn/.tres` | `[HOOK]` pre-commit 角色閘門 |
| 7 | **格式強制**：所有 commit 須符合 `[ROLE] type: 描述` | `[HOOK]` commit-msg |
| 11 | **編碼強制**：所有 .gd 必須是 UTF-8 無 BOM | `[HOOK+SENSOR]` pre-commit + Check 1 |
| 12 | **UID 驗證**：複製 .tscn 後 ext_resource UID 不得等於場景自身 UID | `[HOOK+SENSOR]` pre-commit + Check 2 |
| 16 | **SpriteFrames AtlasTexture**：frame dict 必須用獨立 AtlasTexture sub-resource，禁直接寫 `region` | `[SENSOR]` Check 7 |
| 17 | **SceneTree 禁 get_tree()**：`extends SceneTree` 腳本中用 `await process_frame` 取代 | `[SENSOR]` Check 9 (ERR-028) |
| 18 | **get_node_or_null 顯式型別（ERR-030）**：`var node: Node2D = get_node_or_null("X") as Node2D` | `[SENSOR]` Check 11 |
| 19 | **TileSet tile_size 顯式聲明（ERR-031）**：`[resource]` 區塊必須有 `tile_size = Vector2i(W,H)` | `[SENSOR]` Check 12 |
| 20 | **for-loop 禁同名變數（ERR-032）**：inner/outer scope 同名報警告，用前綴區別（`root_marker` vs `marker`） | `[SENSOR]` Check 8 --check-only |
| 21 | **函式參數禁基底屬性同名（ERR-033）**：禁用 `visible/position/rotation/scale/name/owner` 作參數名 | `[SENSOR]` Check 13 |
| 22 | **add_child 前置順序（ERR-034）**：`make_current()`/`set_as_top_level()` 必須在 `add_child()` 之後呼叫 | `[SENSOR]` Check 14/21 |

> **2026-06-19 升級**：以下規則由 I-B/I-C 升級至機器層（sensor v12 / pre-commit v5 / commit-msg v2）

| # | 規則 | 執行機制 |
|---|------|---------|
| 1 | **設計優先**：有 `.gd` 但無 `docs/GAME_DESIGN.md` → WARN | `[SENSOR]` Check 15/21 |
| 10 | **ERROR_LOG 同步**：`fix:` commit 未引用 ERR-XXX/GAP-XXX → WARN | `[HOOK]` commit-msg v2 WARN |
| 15 | **tscn 安全寫入**：`.ps1` 中 `Set-Content/Get-Content *.tscn` → FAIL | `[SENSOR]` Check 16/21 FAIL |
| 23 | **warn fallback 層次**：`.gd` 有 `push_warning()` → WARN（確認是否必要） | `[SENSOR]` Check 18/21 |
| 25 | **工具腳本範疇**：`.tscn` 引用 `scripts/utils/` → WARN | `[SENSOR]` Check 17/21 |
| 26 | **GDD TODO 清除**：Designer commit GDD 時 diff 含 `[GDD TODO]` → WARN | `[HOOK]` pre-commit Designer/3 |
| — | **CASCADE: sensor-scan → workflow**：`sensor-scan.ps1` staged 但 `workflow.md` 未同步 → WARN | `[HOOK]` pre-commit 0e |
| — | **CASCADE: roles → DOC_INDEX**：`roles/*.md` staged 但 `DOC_INDEX.md` 未同步 → WARN | `[HOOK]` pre-commit 0f |
| — | **hook 版本一致性**：pre-commit header/echo 版本號不符 → FAIL | `[SENSOR]` Check 19/21 FAIL |
| — | **SOP 完整性**：`sop-state.md` 有 PENDING 步驟 → 阻斷 push 到 main | `[HOOK]` pre-push v3 FAIL |

### I-B. 強制力缺口層（§LEARN 追蹤，目標升級為機器執行）

| # | 規則 | 升級路徑 |
|---|------|---------|
| 3 | **分支保護**：Developer `.gd` 不得直接 push main，須走 dev-submit.ps1 | pre-push hook 升級 |
| 4 | **場景鎖定**：修改 .tscn 前必須執行 `lock-scene.ps1 lock` | pre-commit 偵測 .tscn 未 lock |
| 13 | **VFX Scale 強制**：VFX AnimatedSprite2D 必須設 scale（近戰弧=0.35, 槍口=0.15, 受擊=0.20, 死亡=0.30） | sensor 掃 .tscn VFX scale 缺失 |
| 14 | **@export 自動配置**：@export PackedScene/NodePath 腳本建立後，所有引用 .tscn 必須加 ext_resource + 賦值 | reviewer 交接閘門人工守門 |

### I-C. 行為準則層（人工自律，無法機器化）

> **[DOC-ONLY — 機器層無法覆蓋，依賴 AI 自律]**
> 以下規則無法由 hook 或 sensor 自動強制執行，完全依賴 Agent 的行為紀律。
> 違反時僅能在事後發現（§LEARN 記錄）。

| # | 準則 | 強制層級 |
|---|------|---------|
| 5 | **熔斷**：同一 Bug 連續失敗 3 次 → 切換 Architect，不得繼續嘗試 | [DOC-ONLY] |
| 6 | **測試基準**：QA 只依據 Memory DoD，不依賴 Developer 說明 | [DOC-ONLY] |
| 8 | **Sensor 優先**：看到 Level 1 觸發條件 → 立即停止，呼叫 Sensor | [DOC-ONLY] |
| 9 | **反省強制**：Architect/Developer/Reviewer 每次工作後寫反省記錄（Memory MCP） | [DOC-ONLY] |
| 24 | **驗證優先序**：純函式/RefCounted 邏輯（物理/狀態機/約束）優先寫 headless 測試（GUT 或 `--script`）；run_project 純開機僅作冒煙，不算行為驗證（→ §F 驗證優先序，GAP-039） | [DOC-ONLY] |

---

## J. 參考文件位置（此專案）

```
專案路徑：d:/2026-06-04/
├── docs/
│   ├── GAME_DESIGN.md              → GDD（必須含 GDD 最後同步日期標記）
│   ├── ERROR_LOG.md                → 錯誤知識庫（ERR-001 ~ ERR-041）
│   ├── PROJECT_STATUS.md           → 專案狀態追蹤
│   ├── sop-state.md                → SOP 執行進度追蹤（Sensor [21/21] + set-role.ps1 讀取）
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
	├── sensor-scan.ps1             → Sensor 自動掃描腳本（v12/22 checks）
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

## N2. 深度人工清查（Deep Clean）

> 觸發時機：發現系統規則過度臃腫時，由用戶發起。各角色依序清查自己的文件，按 §AUDIT.4 DEAD 判斷標準移除廢棄規則，按 §LEARN 記錄發現的問題。完成後 QA 執行 sensor-scan.ps1 確認安全底線。

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

```powershell
# 必查清單（可執行）
$root = "D:\2026-06-04"

# CONTR-A：DOC_INDEX 職責矩陣 vs roles/*.md 讀/寫權限 vs pre-commit 實際限制
# 手動對照：DOC_INDEX.md 職責矩陣每個角色 → roles/<role>.md 允許/禁止 → hooks/pre-commit 限制
# 三者必須一致 → 不一致 = 矛盾

# CONTR-B：workflow.md §B 速查表 vs roles/*.md MUST-DO
# 手動對照：§B 表格「禁止」欄 vs 各 role file 的「你禁止做的事」

# CONTR-C：pre-commit echo 版本 vs 頂部註解版本（§LESSON-2026-06-18 發現，機器可偵測）
$hookLines = Get-Content "$root\hooks\pre-commit"
$echoVer = ($hookLines | Select-String '\[Pre-Commit Hook v(\d+)\]' | Select-Object -First 1).Matches[0].Groups[1].Value
$commentVer = ($hookLines | Select-String '^\# hooks/pre-commit.*\(v(\d+)' | Select-Object -First 1).Matches[0].Groups[1].Value
if ($echoVer -ne $commentVer) { "[CONTRADICTION] pre-commit echo=v$echoVer ≠ header=v$commentVer" }
else { "[OK] pre-commit echo v$echoVer matches header" }

# CONTR-D：sensor-scan banner vs 實際 [X/Y] 標頭數（已由 Check 15/15 自動偵測，此處僅說明）
# → 自動：sensor-scan.ps1 Check 15/15 self-consistency 已覆蓋此項
```

### AUDIT.4 死代碼偵測（Dead Rule Detection）

**目標**：找出廢棄、無法執行、或已被取代的規則。

```powershell
$root = "D:\2026-06-04"
$md = Get-ChildItem $root -Recurse -Filter "*.md" | Where-Object { $_.FullName -notmatch "\\archive\\" }
$all = Get-ChildItem $root -Recurse | Where-Object { $_.Extension -in ".md",".ps1" -and $_.FullName -notmatch "\\archive\\" }

# DEAD-A：過時外部工具引用
#   注意：PixelLab 已於 2026-06-20 重新啟用為正式美術工具（見 docs/PIXELLAB_KB.md +
#   Pixel Consultant 角色），故已從本 DEAD 掃描移除，不再視為過時引用。
$all | ForEach-Object {
  $h = Select-String "PIXEL-REVIEW|browser_subagent.*allow" $_.FullName
  if ($h) { $h | ForEach-Object { "[DEAD-A] $($_.Filename) L$($_.LineNumber): $($_.Line.Trim())" } }
}

# DEAD-B：文件中引用的目錄路徑不存在（§LESSON-2026-06-18 發現）
$knownDirRefs = @("docs/review_reports","docs/archive","scripts/utils","hooks","roles","docs")
$knownDirRefs | ForEach-Object {
  $status = if (Test-Path "$root\$_") {"✅"} else {"[DEAD-B] 路徑不存在：$_"}
  $status
}

# DEAD-C：明確標記「已廢棄」但未移除的段落
$md | ForEach-Object {
  $h = Select-String "已廢棄|DEPRECATED|舊規則|舊版本" $_.FullName
  if ($h) { $h | ForEach-Object { "[DEAD-C] $($_.Filename) L$($_.LineNumber): $($_.Line.Trim())" } }
}

# 判斷標準：
# 若某 [DOC] 規則已被 [HOOK] 強制阻斷 → 在規則後標記 [已由 HOOK/SENSOR 覆蓋]，縮短文字
```

### AUDIT.5 版本與數字一致性

```
執行掃描：
  Select-String -Path "D:\2026-06-04\**\*.md","D:\2026-06-04\**\*.ps1" `
	-Pattern "Check \d+/\d+|Sensor v\d+|\d+/21" -Recurse

預期結果：所有 Check 引用均為 X/21；所有 Sensor 版本均為 v11
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
2. 手動測試三個場景，確認 hook 實際阻斷：
   ❌ 測試1: commit 訊息格式不符 [ROLE] type: → 必須 exit 1
   ❌ 測試2: Designer 嘗試 commit .gd 文件 → 必須 exit 1
   ❌ 測試3: Architect 嘗試 commit 遊戲 .gd（addons/ 除外）→ 必須 exit 1
3. 全部測試通過後才能 commit hook 修改
```

### EDIT.3 Cascade Update Matrix

| ★ 若修改這個 | 必須同步更新以下文件 |
|---|---|
| `sensor-scan.ps1` check 數量（如 15→21） | `workflow.md §E` 工具表 · `roles/developer.md` · `roles/sensor.md` · `roles/reviewer.md` 交接閘門 · `scripts/set-role.ps1` |
| `sensor-scan.ps1` version banner | 同上，以及 `sensor-scan.ps1` 自身標頭 `## Checks:` 區塊 |
| `hooks/commit-msg` 任何 exit 邏輯 | 執行 EDIT.2 驗證；`workflow.md §C` |
| `hooks/pre-commit` 角色規則 | 對應 `roles/<role>.md §Hook 驗證`；`docs/DOC_INDEX.md` 職責矩陣 |
| 任何 role 的讀/寫權限 | `docs/DOC_INDEX.md` 職責矩陣 |
| `GLOBAL-RULE-001/003/004` 規則內容 | 各 `roles/*.md` 中引用該規則的段落 |
| `§READ SOP` 步驟 | `docs/DOC_INDEX.md §READ`；`scripts/set-role.ps1` 必讀清單 |
| `§MOD SOP` 步驟 | `docs/DOC_INDEX.md §MOD`（引用格式） |
| `scripts/sensor-scan.ps1`（任何修改） | `workflow.md §I`（規則列表）；pre-commit [0e] 自動 WARN 提醒 |
| `roles/*.md`（任何修改） | `docs/DOC_INDEX.md` 職責矩陣；pre-commit [0f] 自動 WARN 提醒 |

### EDIT.4 評估與提交

```
1. 新增/修改內容：優先選最簡單可行方案，避免過度工程（→ GLOBAL-RULE-004）
2. Commit 訊息符合 `[ROLE] type: 描述`；fix commit 引用 ERR-XXX/GAP-XXX
3. 執行 sensor-scan.ps1 確認全部 PASS
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
| GLOBAL-RULE-004（防循環完整定義） | `workflow.md §GLOBAL-RULE-004` | Role files：1 行摘要 + `→ workflow.md §GLOBAL-RULE-004` |
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

## §LEARN. 自動學習與強化 SOP

> **觸發時機（任一）**：遇到錯誤、實作失敗、規則執行失效；§AUDIT 發現問題；ERROR_LOG 新增條目；hook/script 行為與文件不符；跨文件資訊不一致。
> **執行者**：發現者立即觸發 → Sensor → Architect → Developer → QA 接力。

### LEARN.1 根本原因分類

| 類型 | 定義 | 典型實例 |
|------|------|---------|
| **(A) 實作 Bug** | Enforcement 機制程式碼有邏輯錯誤 | hook 在關鍵檢查前提前 exit 0，導致該檢查被繞過 |
| **(B) 文件漂移** | 同一資訊存在於 N 個地方，更新時未同步 | sensor-scan 版本號硬編碼在 8+ 個檔案 |
| **(C) 設計缺陷** | SOP 遺漏了必要的驗證步驟 | §MOD 沒有「驗證 enforcement 機制本身正確運作」的步驟 |
| **(D) 流程空白** | 規則存在但無任何機制確保其有效性 | sensor-scan.ps1 手動執行在任何 hook/SOP 中都無強制點 |

### LEARN.2 執行步驟

```
Step 1【CAPTURE — Sensor 執行】
  → ERROR_LOG.md 記錄，標記類型 (A/B/C/D)
  → 描述：什麼被發現、在哪被發現、哪個步驟沒攔截它

Step 2【CROSS-REF — Architect 執行】
  → Select-String -Path "roles\*.md","workflow.md","docs\*.md","scripts\*.ps1" -Pattern "關鍵詞"
  → 建立「需同步更新清單」

Step 3【PROPAGATE — Developer 執行】
  → 更新清單中所有位置
  → 禁止硬編碼計數型資訊：寫「sensor-scan.ps1 全部 PASS」，禁止寫「14/14 PASS」
  → 規則文字：workflow.md 為 canonical source，其他檔案用一行引用

Step 4【ENFORCE — Architect 判斷三層落地】

  ┌──────────┬──────────┬──────────────────────────┬────────────────────────────────┐
  │ 層級     │ 強度     │ 機制                     │ 如何升級                       │
  ├──────────┼──────────┼──────────────────────────┼────────────────────────────────┤
  │ 第一層   │ ⛔⛔⛔  │ hooks/pre-commit exit 1  │ 在對應 ROLE 區塊加 exit 1 閘門 │
  │ 第二層   │ ⚠️⚠️   │ sensor-scan.ps1 自動偵測 │ 新增 Check N+1 區段            │
  │ 第三層   │ ⚠️      │ role 交接閘門清單        │ 在對應 role 的閘門加 □ 項目    │
  └──────────┴──────────┴──────────────────────────┴────────────────────────────────┘

  機器可偵測 → 升級第一或第二層
  無法機器化 → 第三層，在 §I I-B 標記「ENFORCEMENT GAP」
  此 Lesson 揭示 §AUDIT.1-5 無法偵測的模式 → 在 §AUDIT 對應小節補入新掃描項目

Step 5【VERIFY — QA 執行】
  → sensor-scan.ps1 全部 PASS
  → 人工確認修復後的 enforcement 機制按預期工作（眼見為憑）

Step 6【COMMIT — 遵循 §MOD SOP Step 4-5】
```

### LEARN.3 累積防範規則（每次 §LEARN 後增加）

- **禁止在文件中硬編碼計數型資訊**：具體數字只存在於腳本本身
- **任何 enforcement 機制修改後必須人工驗證**：不能假設「寫了規則 = 規則生效」
- **§MOD SOP 第④步**：確認 enforcement 機制的邏輯在修改後仍然正確（人工觸發）
