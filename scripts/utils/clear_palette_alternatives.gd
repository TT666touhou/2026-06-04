@tool
extends EditorScript
## clear_palette_alternatives.gd
## ─────────────────────────────────────────────────────────────
## 清除 mrmotext_world_tileset.tres 中所有 alternative tile (ID != 0)
## 執行方式：Script 編輯器開啟此檔 → File → Run
## ─────────────────────────────────────────────────────────────

const TILESET_PATH := "res://assets/tilesets/mrmotext/mrmotext_world_tileset.tres"

func _run() -> void:
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("  清除所有 Alternative Tiles (ID != 0)")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	var tileset := load(TILESET_PATH) as TileSet
	if tileset == null:
		printerr("❌ 找不到 TileSet：", TILESET_PATH)
		return

	var removed := 0

	for si in range(tileset.get_source_count()):
		var source_id := tileset.get_source_id(si)
		var source    := tileset.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue

		for ti in range(source.get_tiles_count()):
			var coords := source.get_tile_id(ti)
			# 取得所有 alternative（ID=0 是 base，跳過）
			var alt_count := source.get_alternative_tiles_count(coords)
			for ai in range(alt_count - 1, -1, -1):  # 倒序刪除
				var alt_id := source.get_alternative_tile_id(coords, ai)
				if alt_id != 0:
					source.remove_alternative_tile(coords, alt_id)
					removed += 1

	var err := ResourceSaver.save(tileset, TILESET_PATH)
	if err == OK:
		print("✅ 完成！已移除 %d 個 alternative tile" % removed)
	else:
		printerr("❌ 儲存失敗（Error code %d）" % err)
