extends Node
## Dungeon Generator — Rogue-lite 房間生成系統
## Phase 3：根據設計文件，生成隨機的房間序列
## 規則：普通房 → 精英房 → Boss房 → 休息房
## 每次進入新 Run 時呼叫 generate_run()

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
## 房間場景池（設計師可擴充）
## ─────────────────────────────────────────────
## 普通戰鬥房場景列表（設計師可擴充）
## [GDD §10 決策 2026-06-14]
## - 正式局為 Area_0 以上的手動搭建房間
## - test_room_a/b 已從池中移除（設計驗證用屏擤除）
const COMBAT_ROOMS: Array[String] = [
	"res://scenes/levels/area_0/area_0_room_01.tscn",
	"res://scenes/levels/area_0/area_0_room_02.tscn",
]

## 進入點：性第一間房固定為 area_0_room_01（不隨機）
## [GDD §10 決策 2026-06-14]
const ENTRY_ROOM: String = "res://scenes/levels/area_0/area_0_room_01.tscn"

## 精英房場景列表（若不存在則退回普通房）
const ELITE_ROOMS: Array[String] = [
	"res://scenes/test_room_b.tscn",  ## 暫時複用， Phase 3.2 新增
]

## Boss 房
const BOSS_ROOM: String = "res://scenes/level/boss_room.tscn"

## 休息房（若無則跳過）
const REST_ROOM: String = "res://scenes/level/rest_room.tscn"

## ─────────────────────────────────────────────
## 生成設定
## ─────────────────────────────────────────────
@export var min_combat_rooms: int = 3
@export var max_combat_rooms: int = 5
@export var elite_room_chance: float = 0.3   ## 30% 機率將普通房升級為精英房
@export var include_rest_room: bool = true
@export var seed_override: int = 0  ## 0 = 隨機；非零 = 固定種子（DEBUG 用）

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
	print("[DungeonGenerator] 初始化完成")

## 生成一次完整的 Run 房間序列
## 返回：Array[RoomDef]（已排序，Boss 在最後）
func generate_run() -> Array[RoomDef]:
	var rng := RandomNumberGenerator.new()
	if seed_override != 0:
		rng.seed = seed_override
		print("[DungeonGenerator] 使用固定種子：", seed_override)
	else:
		rng.randomize()
		print("[DungeonGenerator] 使用隨機種子：", rng.seed)

	current_run.clear()
	current_room_index = -1

	## [GDD §10 2026-06-14] 第一間房固定為 area_0_room_01（不隨機選）
	current_run.append(RoomDef.new(RoomType.COMBAT, ENTRY_ROOM, 0))
	print("[DungeonGenerator] 進入點（固定）：", ENTRY_ROOM)

	## 1. 決定普通房數量（追加房間，不包含進入點）
	var n_combat := rng.randi_range(max(0, min_combat_rooms - 1), max(0, max_combat_rooms - 1))
	print("[DungeonGenerator] 生成 ", n_combat, " 間追加戰鬥房")

	## 2. 生成戰鬥房序列（隨機決定是否為精英）
	## 從 COMBAT_ROOMS 中排除已使用的 ENTRY_ROOM
	var combat_pool: Array[String] = []
	for p: String in COMBAT_ROOMS:
		if p != ENTRY_ROOM:
			combat_pool.append(p)
	combat_pool.shuffle()

	var difficulty := 0
	for i: int in range(n_combat):
		difficulty += 1
		## 是否升級為精英房
		var is_elite := rng.randf() < elite_room_chance and i > 0
		if is_elite:
			var elite_path: String = _pick_random(ELITE_ROOMS, rng)
			current_run.append(RoomDef.new(RoomType.ELITE, elite_path, difficulty))
			print("[DungeonGenerator] 房間 ", i + 2, ": 精英房 (", elite_path, ")")
		else:
			if combat_pool.is_empty():
				print("[DungeonGenerator] 房間池已空，跟進入點重式使用")
				current_run.append(RoomDef.new(RoomType.COMBAT, ENTRY_ROOM, difficulty))
			else:
				var combat_path: String = combat_pool[i % combat_pool.size()]
				current_run.append(RoomDef.new(RoomType.COMBAT, combat_path, difficulty))
				print("[DungeonGenerator] 房間 ", i + 2, ": 普通房 (", combat_path, ")")

	## 3. 休息房（可選，在 Boss 前一間）
	if include_rest_room and ResourceLoader.exists(REST_ROOM):
		current_run.append(RoomDef.new(RoomType.REST, REST_ROOM, 0))
		print("[DungeonGenerator] 加入休息房")

	## 4. Boss 房（固定在最後）
	var boss_path: String = BOSS_ROOM if ResourceLoader.exists(BOSS_ROOM) else ENTRY_ROOM
	current_run.append(RoomDef.new(RoomType.BOSS, boss_path, difficulty + 2))
	print("[DungeonGenerator] Boss 房：", boss_path)

	run_generated.emit(current_run)
	print("[DungeonGenerator] Run 生成完成，共 ", current_run.size(), " 間房")
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
## 內部工具函式
## ─────────────────────────────────────────────
func _pick_random(arr: Array, rng: RandomNumberGenerator) -> String:
	if arr.is_empty():
		return ""
	return arr[rng.randi_range(0, arr.size() - 1)]

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
	}
