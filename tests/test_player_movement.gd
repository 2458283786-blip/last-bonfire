extends SceneTree

var failures: Array[String] = []
var assertions := 0
const PLAYER_SCENE := "res://scenes/player/player.tscn"

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	Input.action_press("move_right")
	await process_frame
	await physics_frame
	check(p.velocity.x > 0, "按住 move_right 应产生正 x 速度")
	var x0 := p.global_position.x
	await physics_frame
	await physics_frame
	check(p.global_position.x > x0, "持续 move_right 位置应右移")
	Input.action_release("move_right")
	await process_frame
	await physics_frame
	check(p.velocity.x == 0, "松开 move_right 后 x 速度应为 0")
	check(p.facing == 1, "朝右时 facing 应为 1")
	Input.action_press("move_left")
	await process_frame
	await physics_frame
	check(p.velocity.x < 0, "按住 move_left 应产生负 x 速度")
	check(p.facing == -1, "朝左时 facing 应为 -1")
	_finish()

func _spawn_player() -> Player:
	var scene := load(PLAYER_SCENE) as PackedScene
	var p := scene.instantiate() as Player
	root.add_child(p)
	p.global_position = Vector2(400, 300)
	_add_floor(Vector2(400, 420))
	await physics_frame
	await physics_frame
	return p

func _add_floor(pos: Vector2) -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = pos
	root.add_child(floor)

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_player_movement: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_player_movement: %d 个断言失败" % failures.size())
		quit(1)
