extends SceneTree
func _init():
	var s = TileSetAtlasSource.new()
	print(s.get_tile_texture_region(Vector2i(0,0)))
	quit()
