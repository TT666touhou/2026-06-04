extends Node
## Dungeon Generator — 房間序列管理器
## [GDD §7.1 決策 2026-06-14 v2]
## 設計決策：地圖不是程序化生成的，而是由設計師預先決定的手工房間。
## DungeonGenerator 的職責是管理「固定序列」的房間推進，而非隨機生成。
##
## 舊設計（已廢棄）：
##   - 隨機普通戰鬥房 × N → 精英房（30%機率）→ 休息房 → Boss 房
##   - 依賴 min_combat_rooms / max_combat_rooms / elite_room_chance 等隨機化參數
##
## 新設計（當前）：
##   - 固定序列：area_0_room_01 → area_0_room_02 → (未來 Boss 房)
##   - 第一間房（ENTRY_ROOM）固定，不隨機
##   - Portal 系統直接決定下一房間（target_room_path），無需 DungeonGenerator 隨機化
##   - DungeonGenerator 僅作為「進度追蹤器」使用

class_name DungeonGenerator

## ─────────────────────────────────────────────
## 房間類型定義
## ─────────────────────────────────────────────
enum RoomType {
	COMBAT,   ## 普通戰鬥房
	ELITE,    ## 精英房（強敵 + 更好獎勵）
	BOSS,     ## Boss 房（最後一間，唯一）
	REST,     ## 休息房（回血 + 補給）
}

## 房間定義結構體
class RoomDef:
	var room_type: RoomType
	var scene_path: String
	var difficulty_bonus: int = 0  ## 難度加成（影響敵人數量）

	func _init(t: RoomType, path: String, bonus: int = 0) -> void:
		room_type = t
		scene_path = path
		difficulty_bonus = bonus

## ─────────────────────────────────────────────
## 房間場景定義（固定序列，設計師決定）
## ─────────────────────────────────────────────
## [GDD §10 決策 2026-06-14]
## - 正式局為 Area_0 以上的手動搭建房間，地圖由設計師預先決定
## - 非程序化生成：不使用隨機化種子、不隨機挑選房間
## - Portal 系統（target_room_path）已直接硬連結各房間的出口/入口
## - DungeonGenerator 保留作為「進度追蹤器 + 難度標記」，不負責隨機選房

## 進入點：第一間房固定為 area_0_room_01
## [GDD §10 決策 2026-06-14]
const ENTRY_ROOM: String = "res://scenes/levels/area_0/area_0_room_01.tscn"

## Area_0 完整的手工房間序列（由設計師決定，依此順序推進）
const AREA_0_ROOMS: Array[String] = [
	"res://scenes/levels/area_0/area_0_room_01.tscn",
	"res://scenes/levels/area_0/area_0_room_02.tscn",
	## 未來新增房間在此追加（保持手工決定的順序）
]

## Boss 房（Area_0 結尾，將來實作方案：area_0_boss.tscn）
## [Phase-7.0] boss_room.tscn 已刪除（架構不符規範）→ 目前 fallback 到 ENTRY_ROOM
const BOSS_ROOM: String = "res://scenes/levels/area_0/area_0_boss.tscn"

## 休息房（Area_0 程序中無休息房設計，Area_1+ 將使用 area_X_rest_XX.tscn 格式）
## [Phase-7.0] rest_room.tscn 已刪除（架構不符規範）
const REST_ROOM: String = "res://scenes/levels/area_0/area_0_rest_01.tscn"

## ─────────────────────────────────────────────
## 進度追蹤狀態
## ─────────────────────────────────────────────
## 當前生成的房間序列
var current_run: Array[RoomDef] = []
var current_room_index: int = -1

## 信號：房間序列生成完成
signal run_generated(room_list: Array)
## 信號：進入特定房間
signal room_entered(room_index: int, room_def: RoomDef)

## ─────────────────────────────────────────────
## 公開 API
## ─────────────────────────────────────────────
func _ready() -> void:
	print("[DungeonGenerator] 初始化完成（固定序列模式，非程序化生成）")

## 建立固定的 Run 房間序列（非隨機，依設計師決定的 AREA_0_ROOMS 順序）
## [GDD §10 決策 2026-06-14]：地圖由設計師預先決定
func generate_run() -> Array[RoomDef]:
	current_run.clear()
	current_room_index = -1

	## 將 AREA_0_ROOMS 依序加入（固定序列，不隨機）
	for i: int in range(AREA_0_ROOMS.size()):
		var path: String = AREA_0_ROOMS[i]
		## 第一間是 ENTRY_ROOM（COMBAT），其餘依位置推斷類型
		var room_type := RoomType.COMBAT
		var difficulty := i  ## 越後面越難
		current_run.append(RoomDef.new(room_type, path, difficulty))
		print("[DungeonGenerator] 房間 ", i + 1, ": ", path)

	## Boss 房固定在最後
	var boss_path: String = BOSS_ROOM if ResourceLoader.exists(BOSS_ROOM) else ENTRY_ROOM
	current_run.append(RoomDef.new(RoomType.BOSS, boss_path, current_run.size()))
	print("[DungeonGenerator] Boss 房：", boss_path)

	run_generated.emit(current_run)
	print("[DungeonGenerator] Run 建立完成，共 ", current_run.size(), " 間房（固定序列）")
	return current_run

## 進入下一間房間（由 RoomTransition 或 GameWorld 呼叫）
## 返回下一間房間的場景路徑，若已完成 Run 則返回 ""
func advance_room() -> String:
	current_room_index += 1
	if current_room_index >= current_run.size():
		print("[DungeonGenerator] Run 完成！")
		return ""
	var room_def := current_run[current_room_index]
	room_entered.emit(current_room_index, room_def)
	print("[DungeonGenerator] 進入房間 [", current_room_index, "/", current_run.size() - 1, "] 類型：", RoomType.keys()[room_def.room_type])
	return room_def.scene_path

## 取得當前房間定義（用於難度調整）
func get_current_room() -> RoomDef:
	if current_room_index < 0 or current_room_index >= current_run.size():
		return null
	return current_run[current_room_index]

## 取得剩餘房間數（供 UI 顯示）
func get_rooms_remaining() -> int:
	return current_run.size() - current_room_index - 1

## 取得當前 Run 的進度 0.0 ~ 1.0
func get_run_progress() -> float:
	if current_run.is_empty():
		return 0.0
	return float(current_room_index + 1) / float(current_run.size())

## ─────────────────────────────────────────────
## Debug 輸出（供 DebugBridge 讀取）
## ─────────────────────────────────────────────
func get_debug_info() -> Dictionary:
	var rooms_info: Array = []
	for i: int in range(current_run.size()):
		var r := current_run[i]
		rooms_info.append({
			"index": i,
			"type": RoomType.keys()[r.room_type],
			"difficulty": r.difficulty_bonus,
			"is_current": (i == current_room_index)
		})
	return {
		"total_rooms": current_run.size(),
		"current_index": current_room_index,
		"progress": get_run_progress(),
		"rooms": rooms_info,
		"mode": "fixed_sequence",  ## [GDD §10] 固定序列，非程序化生成
	}
