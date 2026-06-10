extends SceneTree
func _init():
	var g = Gradient.new()
	var c = PackedColorArray([Color.RED])
	var o = PackedFloat32Array([0.0])
	g.colors = c
	g.offsets = o
	print('Colors: ', g.colors)
	quit()
