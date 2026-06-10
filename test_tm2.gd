extends SceneTree
func _init():
	var t = TileMapLayer.new()
	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	t.tile_set = ts
	print('local_to_map(-1.5, 0) = ', t.local_to_map(Vector2(-1.5, 0)))
	print('local_to_map(-16.5, 0) = ', t.local_to_map(Vector2(-16.5, 0)))
	quit()
