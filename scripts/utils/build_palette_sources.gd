@tool
extends EditorScript
## build_palette_sources.gd
## ─────────────────────────────────────────────────────────────
## 將 mrmotext_world_tileset.tres 重建為 35 個 Source：
##   Source  0  = 原始黑白（保留，供物理碰撞設定用）
##   Source  1  = 深棕灰填充（index 0）
##   Source  2  = 深棕填充  （index 1）
##   ...
##   Source 34  = 近白填充  （index 33）
##
## 每個 Source 共用同一張貼圖（MRMOTEXT_EX），透過 ShaderMaterial 染色。
## 同一 Source 內所有 tile 共用一個 ShaderMaterial（減少 .tres 大小）。
##
## ▸ 執行前提：mrmotext_world_tileset.tres 必須已存在
## ▸ 執行方式：Script 編輯器開啟此檔 → File → Run（Ctrl+Shift+X）
## ─────────────────────────────────────────────────────────────

const TILESET_PATH := "res://assets/tilesets/mrmotext/mrmotext_world_tileset.tres"
const SHADER_PATH  := "res://assets/shaders/mrmotext_palette_swap.gdshader"
const FIXED_OUTLINE_IDX := 0   ## 所有 source 的固定輪廓色 = 深棕灰 #363232

const PALETTE_NAMES: Array[String] = [
	"深棕灰 #363232", "深棕 #453C3C",    "玫瑰棕 #62494C",  "暗紅 #7F4A50",
	"橄欖綠 #56774A", "苔綠 #65725F",    "藕灰 #75656A",    "琥珀棕 #8A5E40",
	"胭脂紅 #A75064", "玫瑰粉 #AB6E7C",  "番茄紅 #E55C5C",  "橙紅 #D66B48",
	"薄荷綠 #5DA16E", "金橙 #E09656",    "膚色 #D49C73",    "杏橙 #E7946D",
	"萊姆綠 #B1D368", "黃色 #EECF5A",    "鋼藍 #436794",    "紫紅 #9D5789",
	"矢車菊藍 #6F81B3","天空藍 #77BCD6", "中灰 #978C8E",    "藍灰 #8599B0",
	"桃粉 #E4A691",   "淡金 #E9CEA1",    "薰衣草 #BE8EC1",  "粉紅 #EDBCCC",
	"薄荷 #B1DECF",   "銀灰 #C2C2C2",    "淡蘆薈 #DFE8D3",  "奶油 #F1E9D4",
	"薰衣草白 #F1E5F8","近白 #F2F9F8",
]

# ────────────────────────────────────────────────────────────
func _run() -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  [Build Palette Sources] 重建色板 Sources")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# ── 載入資源 ──────────────────────────────────────────────
	var tileset := load(TILESET_PATH) as TileSet
	if tileset == null:
		printerr("❌ 找不到 TileSet：", TILESET_PATH)
		printerr("   請先在 FileSystem 右鍵 mrmotext_ex_tileset.tres → Duplicate")
		return

	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		printerr("❌ 找不到 Shader：", SHADER_PATH)
		return

	# ── 取得並驗證 Source 0 ───────────────────────────────────
	if not tileset.has_source(0):
		printerr("❌ TileSet 沒有 source 0")
		return
	var src0 := tileset.get_source(0) as TileSetAtlasSource
	if src0 == null:
		printerr("❌ source 0 不是 AtlasSource")
		return

	var tile_size  := src0.texture_region_size
	var tile_tex   := src0.texture
	var tile_cnt   := src0.get_tiles_count()
	print("  Source 0：%d tiles，tile_size=%s" % [tile_cnt, tile_size])

	# ── Step 1：清除 source 0 的所有 alternative tiles ────────
	print("  [1/4] 清除 source 0 的 alternative tiles...")
	var alt_removed := 0
	for ti in range(tile_cnt):
		var coords := src0.get_tile_id(ti)
		# 先收集再刪除，避免迭代中修改
		var alts: Array[int] = []
		for ai in range(src0.get_alternative_tiles_count(coords)):
			var aid := src0.get_alternative_tile_id(coords, ai)
			if aid != 0:
				alts.append(aid)
		for aid in alts:
			src0.remove_alternative_tile(coords, aid)
			alt_removed += 1
	print("  已清除 %d 個 alternative tiles" % alt_removed)

	# ── Step 2：刪除 source 0 以外的所有 sources ──────────────
	print("  [2/4] 清除舊 sources（保留 source 0）...")
	var ids_to_remove: Array[int] = []
	for si in range(tileset.get_source_count()):
		var sid := tileset.get_source_id(si)
		if sid != 0:
			ids_to_remove.append(sid)
	for sid in ids_to_remove:
		tileset.remove_source(sid)
	print("  已清除 %d 個舊 sources" % ids_to_remove.size())

	# ── Step 3：收集 source 0 的所有 tile 座標 ────────────────
	var all_coords: Array[Vector2i] = []
	for ti in range(src0.get_tiles_count()):
		all_coords.append(src0.get_tile_id(ti))

	# ── Step 4：建立 34 個色板 sources ────────────────────────
	print("  [3/4] 建立 34 個色板 sources（各含 %d tiles）..." % all_coords.size())

	for ci in range(34):
		# 每個 source 共用一個 ShaderMaterial（減小 .tres 體積）
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("fill_index",    ci)
		mat.set_shader_parameter("outline_index", FIXED_OUTLINE_IDX)
		mat.resource_name = PALETTE_NAMES[ci]

		# 建立新 Source
		var new_src := TileSetAtlasSource.new()
		new_src.resource_name    = PALETTE_NAMES[ci]
		new_src.texture          = tile_tex   # 共用同一張貼圖
		new_src.texture_region_size = tile_size

		# 複製所有 tile 座標（base tile only，不複製物理資料）
		for coords in all_coords:
			new_src.create_tile(coords)
			var td := new_src.get_tile_data(coords, 0)
			if td:
				td.material = mat  # 整個 source 共用同一個 mat

		# 加入 TileSet（ID = ci + 1）
		tileset.add_source(new_src, ci + 1)

		if (ci + 1) % 10 == 0 or ci == 33:
			print("    ✓ %d / 34  (%s)" % [ci + 1, PALETTE_NAMES[ci]])

	# ── Step 5：儲存 ──────────────────────────────────────────
	print("  [4/4] 儲存 TileSet...")
	var err := ResourceSaver.save(tileset, TILESET_PATH)
	if err == OK:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("✅ 完成！TileSet 現共有 %d sources：" % tileset.get_source_count())
		print("   Source  0 = 原始黑白（物理碰撞設定用）")
		print("   Source  1 = 深棕灰")
		print("   Source  2 = 深棕  ... Source 34 = 近白")
		print("   在 TileSet 編輯器左側選擇 Source 切換顏色")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	else:
		printerr("❌ 儲存失敗（Error code %d）" % err)
		printerr("   請確認 .tres 未在其他程式中開啟")
