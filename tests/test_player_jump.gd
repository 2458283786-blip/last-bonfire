extends SceneTree

var failures: Array[String] = []
var assertions := 0
const PLAYER_SCENE := "res://scenes/player/player.tscn"

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	check(p.is_on_floor(), "落地后 is_on_floor 应为 true")
	press("jump")
	await process_frame
	await physics_frame
	check(p.velocity.y < 0, "跳跃后 y 速度应为负")
	var vy_after_jump := p.velocity.y
	await physics_frame
	check(p.velocity.y > vy_after_jump, "上升过程中重力应使 y 速度增大（绝对值减小）")
	check(not p.is_on_floor(), "跳跃后应离地")
	_finish()

func _spawn_player() -> Player:
	var scene := load(PLAYER_SCENE) as PackedScene
	var p := scene.instantiate() as Player
	root.add_child(p)
	p.global_position = Vector2(400, 375)
	_add_floor(Vector2(400, 400))
	for i in 8:
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

func press(action: String) -> void:
	Input.action_press(action)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_player_jump: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_player_jump: %d 个断言失败" % failures.size())
		quit(1)
