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
	var bonfire: Bonfire = (load("res://scenes/buildings/bonfire.tscn") as PackedScene).instantiate()
	add_child(bonfire)
	bonfire.global_position = Vector2(900, 380)
	var stockpile := Node2D.new()
	stockpile.add_to_group("town_stockpile")
	add_child(stockpile)
	stockpile.global_position = Vector2(200, 380)
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(p)
	p.global_position = Vector2(400, 375)
	p.take_damage(p.max_hp)
	check(p.global_position.distance_to(Vector2(900, 380)) < 10.0, "篝火完好应回篝火")
	p.invincible_timer = 0.0
	p.global_position = Vector2(400, 375)
	bonfire.take_damage(9999)
	check(bonfire.is_destroyed, "篝火应被摧毁")
	p.take_damage(p.max_hp)
	check(p.global_position.distance_to(Vector2(200, 380)) < 10.0, "篝火被毁应回临时堆点")
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
