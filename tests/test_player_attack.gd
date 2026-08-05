extends SceneTree

var failures: Array[String] = []
var assertions := 0
const PLAYER_SCENE := "res://scenes/player/player.tscn"

func _initialize() -> void:
	create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	quit(1)

func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	press("attack")
	await process_frame
	await physics_frame
	check(p.is_attacking, "按下攻击后 is_attacking 应为 true")
	check(p.attack_hitbox.monitoring, "攻击期间命中框应启用")
	release("attack")
	press("jump")
	await process_frame
	await physics_frame
	check(p.velocity.y < 0, "攻击不影响跳跃输入")
	await _wait_seconds(p.attack_cooldown + 0.3)
	release("jump")
	press("attack")
	await process_frame
	await physics_frame
	check(p.is_attacking, "冷却结束后可再次攻击")
	_finish()

func _wait_seconds(sec: float) -> void:
	for i in int(sec * 60.0):
		await physics_frame

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

func press(action: String) -> void:
	Input.action_press(action)

func release(action: String) -> void:
	Input.action_release(action)

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_player_attack: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_player_attack: %d 个断言失败" % failures.size())
		quit(1)
