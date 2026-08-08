extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	_add_floor(Vector2(500, 420))
	var hut: WoodcutterHut = (load("res://scenes/buildings/woodcutter_hut.tscn") as PackedScene).instantiate()
	hut.position = Vector2(600, 380)
	add_child(hut)
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	v.position = Vector2(400, 375)
	add_child(v)
	var converted := false
	for i in 180:
		await get_tree().physics_frame
		if v.job == "woodcutter":
			converted = true
			break
	check(converted, "有伐木屋空位时无职业居民应自动转职")
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
