extends SceneTree
func _init():
	var t = TileMapLayer.new()
	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	t.tile_set = ts
	print('map_to_local(0,0) = ', t.map_to_local(Vector2i(0,0)))
	quit()
