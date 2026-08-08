extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false
const PLAYER_SCENE := "res://scenes/player/player.tscn"

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var p := await _spawn_player()
	press("attack")
	await get_tree().process_frame
	await get_tree().physics_frame
	check(p.is_attacking, "按下攻击后 is_attacking 应为 true")
	check(p.attack_hitbox.monitoring, "攻击期间命中框应启用")
	release("attack")
	press("jump")
	await get_tree().process_frame
	await get_tree().physics_frame
	check(p.velocity.y < 0, "攻击不影响跳跃输入")
	await _wait_seconds(p.attack_cooldown + 0.3)
	release("jump")
	press("attack")
	await get_tree().process_frame
	await get_tree().physics_frame
	check(p.is_attacking, "冷却结束后可再次攻击")
	finish(failures.is_empty())

func _wait_seconds(sec: float) -> void:
	for i in int(sec * 60.0):
		await get_tree().physics_frame

func _spawn_player() -> Player:
	var scene := load(PLAYER_SCENE) as PackedScene
	var p := scene.instantiate() as Player
	add_child(p)
	p.global_position = Vector2(400, 375)
	_add_floor(Vector2(400, 400))
	for i in 8:
		await get_tree().physics_frame
	return p

func _add_floor(pos: Vector2) -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = pos
	add_child(floor)

func press(action: String) -> void:
	Input.action_press(action)

func release(action: String) -> void:
	Input.action_release(action)

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	if ok:
		print("[PASS] %s: %d 断言全部通过" % [name, assertions])
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] %s: %d 个断言失败" % [name, failures.size()])
	finished.emit(ok)
