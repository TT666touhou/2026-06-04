extends SceneTree
func _init():
	var src = TileSetAtlasSource.new()
	print('Has texture_region_size: ', 'texture_region_size' in src)
	quit()
