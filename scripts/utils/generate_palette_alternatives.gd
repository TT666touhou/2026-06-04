@tool
extends EditorScript
## generate_palette_alternatives.gd
## ─────────────────────────────────────────────────────────────
## 批量為 mrmotext_world_tileset.tres 的全部 tile 建立 Alternative Tile(ID=1)
## 並掛載 mrmotext_palette_swap.gdshader
## 預設：填充色 = 近白(index 33)，輪廓色 = 深棕灰(index 0)
##
## ▸ 執行方式：
##   1. 在 Godot Script 編輯器開啟此檔案
##   2. 上方選單 File → Run（或 Ctrl+Shift+X）
##   3. 觀察 Output 面板的進度與結果
##
## ▸ 前置條件：
##   mrmotext_world_tileset.tres 必須已存在
##   （在 FileSystem 右鍵 mrmotext_ex_tileset.tres → Duplicate）
## ─────────────────────────────────────────────────────────────

const TILESET_PATH   := "res://assets/tilesets/mrmotext/mrmotext_world_tileset.tres"
const SHADER_PATH    := "res://assets/shaders/mrmotext_palette_swap.gdshader"
const ALT_ID         := 1    ## 建立的 alternative tile ID
const FILL_INDEX     := 33   ## 近白 #F2F9F8（最接近白色）
const OUTLINE_INDEX  := 0    ## 深棕灰 #363232（最接近黑色）

# ────────────────────────────────────────────────────────────
func _run() -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  [批量 Alternative] 開始處理 mrmotext_world_tileset")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	# ── 載入 TileSet ──────────────────────────────────────────
	var tileset := load(TILESET_PATH) as TileSet
	if tileset == null:
		printerr("❌ 找不到 TileSet：", TILESET_PATH)
		printerr("   請先在 Godot FileSystem 右鍵 mrmotext_ex_tileset.tres → Duplicate")
		printerr("   並將複製出的檔案命名為 mrmotext_world_tileset.tres")
		return

	# ── 載入 Shader ───────────────────────────────────────────
	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		printerr("❌ 找不到 Shader：", SHADER_PATH)
		return

	var created  := 0   # 新建立的 alternative
	var updated  := 0   # 已存在、重新套用 material 的

	# ── 遍歷所有 AtlasSource ──────────────────────────────────
	for si in range(tileset.get_source_count()):
		var source_id := tileset.get_source_id(si)
		var source    := tileset.get_source(source_id) as TileSetAtlasSource
		if source == null:
			print("  ⚠️  Source %d 非 AtlasSource，跳過" % source_id)
			continue

		var tile_cnt := source.get_tiles_count()
		print("  Source %d — %d 個 tile" % [source_id, tile_cnt])

		for ti in range(tile_cnt):
			var coords := source.get_tile_id(ti)

			# 建立 alternative（若已存在則只更新 Material）
			if not source.has_alternative_tile(coords, ALT_ID):
				source.create_alternative_tile(coords, ALT_ID)
				created += 1
			else:
				updated += 1

			# 取得 TileData 並掛 ShaderMaterial
			var tile_data := source.get_tile_data(coords, ALT_ID)
			if tile_data == null:
				printerr("  ⚠️  tile_data 為 null：coords=%s alt=%d" % [str(coords), ALT_ID])
				continue

			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("fill_index",    FILL_INDEX)
			mat.set_shader_parameter("outline_index", OUTLINE_INDEX)
			tile_data.material = mat

	# ── 儲存 ─────────────────────────────────────────────────
	print("  儲存中...")
	var err := ResourceSaver.save(tileset, TILESET_PATH)
	if err == OK:
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("✅ 完成！新建：%d  重新套用：%d  合計：%d 個 alternative tile" \
			% [created, updated, created + updated])
		print("   fill_index=%d（近白）  outline_index=%d（深棕灰）" \
			% [FILL_INDEX, OUTLINE_INDEX])
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	else:
		printerr("❌ 儲存失敗（Error code %d）" % err)
		printerr("   確認 .tres 未在 Godot 編輯器以外的程式打開")
