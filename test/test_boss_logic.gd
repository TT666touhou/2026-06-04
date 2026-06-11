extends GutTest

var boss_scene = load("res://scenes/enemy/boss.tscn")
var boss_node = null

func before_each():
	boss_node = boss_scene.instantiate()
	add_child_autofree(boss_node)

func test_boss_initialization():
	assert_not_null(boss_node)
	assert_eq(boss_node.current_health, 50, "Boss should start with 50 health")
	assert_true(boss_node.is_in_group("Enemies"), "Boss should be in Enemies group")

func test_boss_takes_damage():
	boss_node.take_damage(10)
	assert_eq(boss_node.current_health, 40, "Boss should take damage correctly")

func test_boss_death():
	boss_node.take_damage(50)
	# wait for physics frames or idle frames since queue_free is deferred
	await wait_physics_frames(2)
	assert_true(not is_instance_valid(boss_node) or boss_node.is_queued_for_deletion(), "Boss should be freed upon reaching 0 HP")

func test_boss_bullet_hell_spawn():
	boss_node.fire_bullet_hell()
	var parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var bullets = parent.find_children("", "EnemyBullet")
	assert_gt(bullets.size(), 0, "Should spawn multiple bullets")
