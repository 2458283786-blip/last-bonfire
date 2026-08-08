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
	_add_wall(Vector2(450, 370))
	var tree: ResourceNode = (load("res://scenes/resources/tree.tscn") as PackedScene).instantiate()
	var data := ResourceData.new()
	data.id = "tree"
	data.max_hp = 1
	data.chop_damage = 1
	data.drop_resource = "wood"
	data.drop_amount = 1
	data.respawn_days = 1
	tree.data = data
	add_child(tree)
	tree.global_position = Vector2(700, 370)
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v)
	v.global_position = Vector2(300, 375)
	v.set_job("woodcutter")
	v.stuck_frames_limit = 10
	for i in 200:
		await get_tree().physics_frame
	check(v._stuck_frames < v.stuck_frames_limit, "被墙挡住时应触发卡死检测并重置")
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

func _add_wall(pos: Vector2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 200)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = pos
	add_child(wall)

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
