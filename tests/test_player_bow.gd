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
	press("bow")
	await get_tree().process_frame
	await get_tree().physics_frame
	var arrows := get_tree().get_nodes_in_group("arrows")
	check(arrows.size() == 1, "射箭后应生成 1 支箭")
	if arrows.size() == 1:
		var arrow := arrows[0] as Area2D
		check(arrow.global_position.x > p.global_position.x, "朝右射箭应生成在玩家右侧")
		var ax := arrow.global_position.x
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(arrow.global_position.x > ax, "箭矢应向右移动")
	finish(failures.is_empty())

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
