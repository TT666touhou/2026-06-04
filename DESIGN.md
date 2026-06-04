# 專案架構與設計指南 (DESIGN.md)

本文件描述了本 Godot 專案的軟體架構、目錄樹規範以及開發原則，用以維護程式碼的模組化與高內聚性。

---

## 🏗️ 1. 目錄結構規範 (Directory Structure)

專案採用 **Feature-Based (基於功能)** 的組織方式，所有與特定功能相關的檔案都應放在同一個資料夾內：

```text
d:\2026-06-04/
├── .vscode/               # VSCode 設定
├── src/                   # 原始碼主目錄
│   ├── core/              # 核心框架（全域單例、核心管理器）
│   │   ├── autoload/      # 自動載入的 Singletons
│   │   └── base/          # 基礎類別定義 (如 BaseEntity)
│   │
│   └── features/          # 功能模組（高內聚、低耦合）
│       ├── player/        # 玩家控制器模組
│       │   ├── player.tscn
│       │   ├── player.gd
│       │   └── player_test.gd
│       │
│       └── enemy/         # 敵人類別模組
│           ├── enemy.tscn
│           ├── enemy.gd
│           └── enemy_test.gd
│
└── project.godot          # Godot 專案檔
```

---

## 🔌 2. 模組通信與解耦原則 (Decoupling Principles)

為了維持架構完整，避免代碼耦合：

1. **單向依賴 (Dependency Direction)**：
   - 核心模組（`src/core/`）不應依賴任何特定的功能模組（`src/features/*`）。
   - 功能模組可以引用核心模組的通用功能與基礎類別。
2. **避免 Feature 間的直接引用**：
   - `player` 模組不應直接調用 `enemy.gd` 內的內部屬性，反之亦然。
   - 跨 Feature 的數據與狀態傳遞，必須透過 `core` 的事件總線（Event Bus / Global Signals）或全域狀態管理器進行中轉。
3. **Signal 向上，Method 向下 (Signals Up, Methods Down)**：
   - 子節點（Child）與父節點（Parent）通信時，一律使用 `Signal` 向上拋出事件。
   - 父節點控制子節點時，直接調用子節點的公共方法。

---

## 🛠️ 3. 代碼風格與型別安全 (GDScript Coding Style)

1. **強型別聲明 (Static Typing)**：
   - 所有的變數、函式參數與傳回值，必須顯式標註型別。
   ```gdscript
   # ❌ 錯誤示例
   var hp = 100
   func take_damage(amount):
       hp -= amount
       
   #  正確示例
   var hp: float = 100.0
   func take_damage(amount: float) -> void:
       hp -= amount
   ```
2. **節點引用快取**：
   - 必須使用 `@onready` 快取需要的子節點引用，嚴禁在 `_process` 或 `_physics_process` 中頻繁使用 `get_node()` 或 `$`。
3. **性能優化**：
   - 若節點不需要每幀更新，應在 `_ready()` 中調用 `set_process(false)` 或 `set_physics_process(false)` 以降低 CPU 開銷。
