extends Node

signal finished(ok: bool)

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
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	v.position = Vector2(500, 375)
	add_child(v)
	v.wander_wait_min = 0.1
	v.wander_wait_max = 0.2
	var home := Vector2(500, 375)
	var moved := false
	for i in 600:
		await get_tree().physics_frame
		if v.global_position.distance_to(home) > 30.0:
			moved = true
			break
	check(moved, "无职业居民应在城镇内漫游走动")
	var within := true
	for i in 300:
		await get_tree().physics_frame
		if v.global_position.distance_to(home) > 220.0:
			within = false
			break
	check(within, "漫游应保持在出生点附近")
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
