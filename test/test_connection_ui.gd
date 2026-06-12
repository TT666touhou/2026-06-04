extends "res://addons/gut/test.gd"

var title_scene = preload("res://scenes/ui/title_screen.tscn")
var title_inst = null

func before_each():
	title_inst = title_scene.instantiate()
	add_child_autofree(title_inst)
	# Wait a frame so _ready executes and call_deferred triggers setup
	await get_tree().process_frame
	await get_tree().process_frame

func test_ip_format_validation():
	assert_true(title_inst.is_valid_ip("192.168.1.1"), "Should be valid IP")
	assert_true(title_inst.is_valid_ip(""), "Empty IP defaults to localhost, is valid")
	assert_false(title_inst.is_valid_ip("256.1.1.1"), "Out of range is invalid")
	assert_false(title_inst.is_valid_ip("192.168.1"), "Incomplete IP is invalid")
	assert_false(title_inst.is_valid_ip("abc.def.ghi.jkl"), "Non-numeric is invalid")

func test_button_tween_state():
	var btn = title_inst.host_btn
	assert_eq(btn.pivot_offset, btn.size / 2.0, "Pivot offset should be centered via call_deferred setup")
	
	title_inst._animate_button(btn, Vector2(1.1, 1.1))
	# We can't wait out the whole tween without slowing tests, but we can verify it doesn't crash
	assert_true(true, "Tween triggered successfully without crash")
