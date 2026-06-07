@tool
extends EditorScript
## build_all_combo_sources.gd
## ─────────────────────────────────────────────────────────────────
## 前置條件：
##   1. 已執行 scripts/tools/generate_palette_combos.py 生成 1122 張 PNG
##   2. 在 Godot FileSystem 右上角按 Rescan，等待所有 PNG 匯入完成
##
## 執行：Script 編輯器開啟此檔 → File → Run
##
## 結果：mrmotext_world_tileset.tres 將有 1123 個 Sources：
##   Source 0      = 原始黑白（物理碰撞設定保留）
##   Source 1~1122 = 所有顏色組合（填充×輪廓，排除同色）
##   每個 source 是獨立彩色 PNG，無需 shader
## ─────────────────────────────────────────────────────────────────

const TILESET_PATH := "res://assets/tilesets/mrmotext/mrmotext_world_tileset.tres"
const COMBO_DIR    := "res://assets/tilesets/mrmotext/colored_combos/"

const PALETTE_NAMES: Array[String] = [
	"深棕灰","深棕","玫瑰棕","暗紅","橄欖綠","苔綠","藕灰","琥珀棕",
	"胭脂紅","玫瑰粉","番茄紅","橙紅","薄荷綠","金橙","膚色","杏橙",
	"萊姆綠","黃色","鋼藍","紫紅","矢車菊藍","天空藍","中灰","藍灰",
	"桃粉","淡金","薰衣草","粉紅","薄荷","銀灰","淡蘆薈","奶油",
	"薰衣草白","近白",
]

# ────────────────────────────────────────────────────────────────
func _run() -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  [Build All Combo Sources] 建立 1122 個顏色組合 Source")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# ── 載入 TileSet ──────────────────────────────────────────
	var tileset := load(TILESET_PATH) as TileSet
	if tileset == null:
		printerr("❌ 找不到 TileSet：", TILESET_PATH)
		return

	if not tileset.has_source(0):
		printerr("❌ TileSet 沒有 source 0")
		return
	var src0 := tileset.get_source(0) as TileSetAtlasSource
	if src0 == null:
		printerr("❌ source 0 不是 AtlasSource")
		return

	var tile_size  := src0.texture_region_size
	var tile_cnt   := src0.get_tiles_count()
	print("  Source 0：%d tiles，tile_size=%s" % [tile_cnt, tile_size])

	# ── Step 1：清除 source 0 的 alternative tiles ────────────
	print("  [1/4] 清除 source 0 alternative tiles...")
	for ti in range(tile_cnt):
		var coords := src0.get_tile_id(ti)
		var alts: Array[int] = []
		for ai in range(src0.get_alternative_tiles_count(coords)):
			var aid := src0.get_alternative_tile_id(coords, ai)
			if aid != 0:
				alts.append(aid)
		for aid in alts:
			src0.remove_alternative_tile(coords, aid)

	# ── Step 2：清除舊 sources（保留 0）──────────────────────
	print("  [2/4] 清除舊 sources...")
	var to_remove: Array[int] = []
	for si in range(tileset.get_source_count()):
		var sid := tileset.get_source_id(si)
		if sid != 0:
			to_remove.append(sid)
	for sid in to_remove:
		tileset.remove_source(sid)
	print("  已清除 %d 個舊 sources" % to_remove.size())

	# ── Step 3：收集 source 0 的 tile 座標 ───────────────────
	var all_coords: Array[Vector2i] = []
	for ti in range(src0.get_tiles_count()):
		all_coords.append(src0.get_tile_id(ti))

	# ── Step 4：建立 1122 個色板組合 Sources ─────────────────
	print("  [3/4] 建立 1122 個 sources（各含 %d tiles）..." % all_coords.size())
	print("  ⚠️  預計需要數分鐘，請耐心等待...")

	var source_id := 1
	var created   := 0
	var missing   := 0
	var t_start   := Time.get_ticks_msec()

	for fi in range(34):
		for oi in range(34):
			if fi == oi:
				continue

			var png_path := COMBO_DIR + "f%02d_o%02d.png" % [fi, oi]

			# 確認 PNG 已被 Godot 匯入
			var tex := load(png_path) as Texture2D
			if tex == null:
				printerr("  ⚠️  找不到/未匯入：%s  → 跳過（請先 Rescan）" % png_path)
				missing += 1
				continue

			# 建立新 Source
			var new_src := TileSetAtlasSource.new()
			new_src.resource_name     = "填充:%s 輪廓:%s" % [PALETTE_NAMES[fi], PALETTE_NAMES[oi]]
			new_src.texture           = tex
			new_src.texture_region_size = tile_size

			# 複製 tile 座標（僅位置，不複製物理等資料）
			for coords in all_coords:
				new_src.create_tile(coords)

			tileset.add_source(new_src, source_id)
			source_id += 1
			created   += 1

			# 進度報告
			if created % 100 == 0:
				var elapsed := (Time.get_ticks_msec() - t_start) / 1000.0
				var eta     := elapsed / created * (1122 - created)
				print("  %4d/1122  已用：%.1fs  剩餘約：%.1fs" % [created, elapsed, eta])

	# ── Step 5：儲存 ─────────────────────────────────────────
	print("  [4/4] 儲存 TileSet...")
	var err := ResourceSaver.save(tileset, TILESET_PATH)
	var elapsed_total := (Time.get_ticks_msec() - t_start) / 1000.0

	if err == OK:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("✅ 完成！總耗時：%.1f 秒" % elapsed_total)
		print("   建立 sources：%d  跳過（未匯入）：%d" % [created, missing])
		print("   TileSet 共 %d sources（Source 0 = 原始，1~%d = 彩色組合）" \
			% [tileset.get_source_count(), source_id - 1])
		if missing > 0:
			print("\n   ⚠️  %d 個 PNG 未匯入！請確認：" % missing)
			print("      1. 已執行 generate_palette_combos.py")
			print("      2. 在 Godot FileSystem 按 Rescan 等待匯入完成")
			print("      3. 重新執行本腳本")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	else:
		printerr("❌ 儲存失敗（Error code %d）" % err)
