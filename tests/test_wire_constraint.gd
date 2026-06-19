# GUT 單元測試 — WireConstraint 純數學邏輯
# 需要 GUT addon (addons/gut) 才能執行
# 安裝：https://github.com/bitwes/Gut
extends GutTest

var wc: WireConstraint

func before_each() -> void:
	wc = WireConstraint.new()
	wc.setup(Vector2(0.0, -100.0), 80.0)

# 鬆弛時 velocity 不變
func test_slack_no_interference() -> void:
	var vel_in := Vector2(50.0, 0.0)
	var player_pos := Vector2(0.0, -20.0)  # dist=80, max_length=90 → slack
	var vel_out := wc.apply(player_pos, vel_in)
	assert_eq(vel_out, vel_in, "slack: velocity should be unchanged")

# 繃緊時，移除「遠離」分量
func test_taut_removes_radial_away() -> void:
	wc.setup(Vector2(0.0, -100.0), 60.0)  # max_length=70
	var player_pos := Vector2(0.0, -20.0)  # dist=80 > 70 → taut
	var vel_in := Vector2(0.0, 100.0)      # moving away from anchor (downward)
	var vel_out := wc.apply(player_pos, vel_in)
	# radial (away component) should be removed; y should be ~0 or positive removed
	assert_lt(vel_out.y, vel_in.y, "taut: away radial should be reduced")

# 繃緊時，切線方向不受影響
func test_taut_preserves_tangent() -> void:
	wc.setup(Vector2(0.0, -100.0), 60.0)
	var player_pos := Vector2(0.0, -20.0)  # taut
	var vel_in := Vector2(100.0, 0.0)      # horizontal = tangent to rope
	var vel_out := wc.apply(player_pos, vel_in)
	assert_almost_eq(vel_out.x, vel_in.x, 1.0, "taut: tangent velocity should be preserved")

# E 收線縮短 max_length
func test_reel_in_shortens_length() -> void:
	var initial_length := wc.max_length
	wc.reel_in(100.0, 0.5)  # 50px shorter
	assert_almost_eq(wc.max_length, initial_length - 50.0, 0.1, "reel_in: max_length should decrease")

# reel 不超過 MIN_LENGTH
func test_reel_in_clamps_to_min() -> void:
	wc.reel_in(10000.0, 10.0)
	assert_almost_eq(wc.max_length, WireConstraint.MIN_LENGTH, 0.01, "reel_in: must not go below MIN_LENGTH")

# tension_ratio: 鬆弛時 < 1
func test_tension_ratio_slack() -> void:
	var player_pos := Vector2(0.0, -20.0)  # dist=80, max_length=90 → slack
	var ratio := wc.tension_ratio(player_pos)
	assert_lt(ratio, 1.0, "slack: tension_ratio should be below 1")

# tension_ratio: 繃緊時接近 1
func test_tension_ratio_taut() -> void:
	wc.setup(Vector2(0.0, -100.0), 60.0)  # max_length=70
	var player_pos := Vector2(0.0, -20.0)  # dist=80 → ratio≈1.14
	var ratio := wc.tension_ratio(player_pos)
	assert_gt(ratio, 1.0, "taut: tension_ratio should exceed 1")
