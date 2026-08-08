extends Node

signal finished(ok: bool)

class DummyTarget:
	extends Node2D

	var received_damage := 0

	func take_damage(amount: int) -> void:
		received_damage += amount

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	_add_floor(Vector2(500, 420))
	var data := load("res://resources/data/enemy_night_wolf.tres") as EnemyData
	data.attack_priority = ["player"]
	data.attack_interval = 0.1
	data.attack_range = 40.0
	var enemy: Enemy = (load("res://scenes/enemies/basic_enemy.tscn") as PackedScene).instantiate()
	enemy.data = data
	add_child(enemy)
	enemy.global_position = Vector2(300, 375)
	var dummy := DummyTarget.new()
	dummy.add_to_group("players")
	add_child(dummy)
	dummy.global_position = Vector2(700, 375)
	var chased := false
	for i in 180:
		await get_tree().physics_frame
		if enemy.global_position.x > 600.0:
			chased = true
			break
	check(chased, "敌人应追击目标")
	for i in 240:
		await get_tree().physics_frame
		if dummy.received_damage > 0:
			break
	check(dummy.received_damage > 0, "进入攻击范围后应按间隔造成伤害")
	finish(failures.is_empty())

func _add_floor(pos: Vector2) -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = pos
	add_child(floor)

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
