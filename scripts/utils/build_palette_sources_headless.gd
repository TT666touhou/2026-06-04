extends SceneTree
## build_palette_sources_headless.gd
## ─────────────────────────────────────────────────────────────────
## 執行：
##   godot --headless -s scripts/utils/build_palette_sources_headless.gd
## ─────────────────────────────────────────────────────────────────

const TILESET_PATH := "res://assets/tilesets/mrmotext/mrmotext_world_tileset.tres"
const COLORED_DIR  := "res://assets/tilesets/mrmotext/colored/"

const COLOR_NAMES: Array[String] = [
	"深棕灰","深棕","玫瑰棕","暗紅","橄欖綠","苔綠","藕灰","琥珀棕",
	"胭脂紅","玫瑰粉","番茄紅","橙紅","薄荷綠","金橙","膚色","杏橙",
	"萊姆綠","黃色","鋼藍","紫紅","矢車菊藍","天空藍","中灰","藍灰",
	"桃粉","淡金","薰衣草","粉紅","薄荷","銀灰","淡蘆薈","奶油",
	"薰衣草白","近白",
]

func _init() -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  [Build Palette Sources (Headless)]")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	var tileset := load(TILESET_PATH) as TileSet
	if not tileset:
		printerr("❌ 找不到 TileSet：", TILESET_PATH)
		quit(1)
		return

	if not tileset.has_source(0):
		printerr("❌ 沒有 source 0")
		quit(1)
		return
	var src0 := tileset.get_source(0) as TileSetAtlasSource
	if not src0:
		printerr("❌ source 0 不是 AtlasSource")
		quit(1)
		return

	var tile_size := src0.texture_region_size
	print("  Source 0: %d tiles, tile_size=%s" % [src0.get_tiles_count(), tile_size])

	# ── Step 1：清除 source 0 的 alternative tiles ────────────
	print("  [1/3] 清除 source 0 alternative tiles...")
	for ti in range(src0.get_tiles_count()):
		var coords := src0.get_tile_id(ti)
		var alts: Array[int] = []
		for ai in range(src0.get_alternative_tiles_count(coords)):
			var aid := src0.get_alternative_tile_id(coords, ai)
			if aid != 0:
				alts.append(aid)
		for aid in alts:
			src0.remove_alternative_tile(coords, aid)
	print("  alt tiles 清除完成")

	# ── Step 2：移除舊的彩色 sources（保留 0）────────────────
	print("  [2/3] 移除舊 sources...")
	var to_remove: Array[int] = []
	for si in range(tileset.get_source_count()):
		var sid := tileset.get_source_id(si)
		if sid != 0:
			to_remove.append(sid)
	for sid in to_remove:
		tileset.remove_source(sid)
	print("  移除 %d 個舊 sources" % to_remove.size())

	# ── Step 3：動態掃描並建立 PNG Sources ───────────────────
	print("  [3/3] 掃描 colored/ 目錄並建立 Sources...")
	
	var dir := DirAccess.open(COLORED_DIR)
	if not dir:
		printerr("❌ 無法開啟目錄：", COLORED_DIR)
		quit(1)
		return
	
	var png_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			png_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	png_files.sort()
	print("  找到 %d 個 PNG 圖源" % png_files.size())

	var all_coords: Array[Vector2i] = []
	for ti in range(src0.get_tiles_count()):
		all_coords.append(src0.get_tile_id(ti))

	var created := 0
	var missing := 0

	for i in range(png_files.size()):
		var fname := png_files[i]
		var png_path := COLORED_DIR + fname
		var tex := load(png_path) as Texture2D
		if not tex:
			printerr("  ⚠️  找不到/未匯入：%s" % png_path)
			missing += 1
			continue

		var new_src := TileSetAtlasSource.new()
		var display_name := fname.get_basename()
		
		if fname.begins_with("color_T_"):
			var parts := fname.split("_")
			if parts.size() >= 4:
				var fg_idx := parts[2].to_int()
				if fg_idx >= 0 and fg_idx < COLOR_NAMES.size():
					display_name = "[T] " + COLOR_NAMES[fg_idx] + " (透明背景)"
		elif fname.begins_with("color_C_"):
			var parts := fname.split("_")
			if parts.size() >= 6:
				var fg_str := parts[2].replace("fg", "")
				var bg_str := parts[3].replace("bg", "")
				var fg_idx := fg_str.to_int()
				var bg_idx := bg_str.to_int()
				if fg_idx >= 0 and fg_idx < COLOR_NAMES.size() and bg_idx >= 0 and bg_idx < COLOR_NAMES.size():
					display_name = "[C] " + COLOR_NAMES[fg_idx] + " on " + COLOR_NAMES[bg_idx]

		new_src.resource_name     = display_name
		new_src.texture           = tex
		new_src.texture_region_size = tile_size

		# 複製 tile 座標與其屬性 (如物理碰撞、導航區等)
		for coords in all_coords:
			new_src.create_tile(coords)
			var sdata := src0.get_tile_data(coords, 0)
			var ndata := new_src.get_tile_data(coords, 0)
			if sdata and ndata:
				# 1. 基礎屬性
				ndata.probability = sdata.probability
				ndata.y_sort_origin = sdata.y_sort_origin
				ndata.texture_origin = sdata.texture_origin
				ndata.z_index = sdata.z_index
				ndata.terrain_set = sdata.terrain_set
				ndata.terrain = sdata.terrain
				
				# 2. 複製地形連接位 (Peering Bits)
				for bit in range(16):
					var cell_neighbor := bit as TileSet.CellNeighbor
					if sdata.is_valid_terrain_peering_bit(cell_neighbor):
						var t_idx := sdata.get_terrain_peering_bit(cell_neighbor)
						ndata.set_terrain_peering_bit(cell_neighbor, t_idx)
				
				# 3. 複製物理碰撞多邊形
				for phys_idx in range(tileset.get_physics_layers_count()):
					var poly_count := sdata.get_collision_polygons_count(phys_idx)
					ndata.set_collision_polygons_count(phys_idx, poly_count)
					for poly_idx in range(poly_count):
						var points := sdata.get_collision_polygon_points(phys_idx, poly_idx)
						ndata.set_collision_polygon_points(phys_idx, poly_idx, points)
						ndata.set_collision_polygon_one_way(phys_idx, poly_idx, sdata.is_collision_polygon_one_way(phys_idx, poly_idx))
						ndata.set_collision_polygon_one_way_margin(phys_idx, poly_idx, sdata.get_collision_polygon_one_way_margin(phys_idx, poly_idx))
				
				# 4. 複製導航多邊形
				for nav_idx in range(tileset.get_navigation_layers_count()):
					var nav_poly := sdata.get_navigation_polygon(nav_idx)
					if nav_poly:
						ndata.set_navigation_polygon(nav_idx, nav_poly)
				
				# 5. 複製遮擋多邊形
				for occ_idx in range(tileset.get_occlusion_layers_count()):
					var occ_poly := sdata.get_occluder(occ_idx)
					if occ_poly:
						ndata.set_occluder(occ_idx, occ_poly)
				
				# 6. 複製自訂數據
				for cd_idx in range(tileset.get_custom_data_layers_count()):
					var cd_name := tileset.get_custom_data_layer_name(cd_idx)
					var cd_val := sdata.get_custom_data(cd_name)
					ndata.set_custom_data(cd_name, cd_val)

		tileset.add_source(new_src, i + 1)
		created += 1

	# ── 儲存 ─────────────────────────────────────────────────
	print("  儲存 TileSet...")
	var err := ResourceSaver.save(tileset, TILESET_PATH)

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	if err == OK:
		print("✅ 完成！TileSet 共 %d sources（0=黑白，1~%d=彩色組合 PNG）" \
			% [tileset.get_source_count(), created])
	else:
		printerr("❌ 儲存失敗（Error %d）" % err)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	quit(0 if err == OK else 1)
