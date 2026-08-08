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
	var wood_before := EconomyManager.get_amount("wood")
	_add_floor(Vector2(500, 420))
	var storage := Node2D.new()
	storage.name = "TestStorage"
	storage.add_to_group("storage_buildings")
	storage.position = Vector2(700, 380)
	add_child(storage)
	var tree_scene := load("res://scenes/resources/tree.tscn") as PackedScene
	var tree: ResourceNode = tree_scene.instantiate()
	var test_data := ResourceData.new()
	test_data.id = "test_tree"
	test_data.max_hp = 1
	test_data.chop_damage = 1
	test_data.drop_resource = "wood"
	test_data.drop_amount = 1
	test_data.respawn_days = 1
	tree.data = test_data
	add_child(tree)
	tree.global_position = Vector2(500, 370)
	var villager_scene := load("res://scenes/villagers/villager.tscn") as PackedScene
	var v: Villager = villager_scene.instantiate()
	add_child(v)
	v.global_position = Vector2(300, 375)
	v.set_job("woodcutter")
	v.chop_interval = 0.05
	v.move_speed = 400.0
	var found := false
	for i in 600:
		await get_tree().physics_frame
		if EconomyManager.get_amount("wood") > wood_before:
			found = true
			break
	check(found, "居民应完成砍树→搬运→入库循环")
	check(EconomyManager.get_amount("wood") > wood_before, "库存应增加木材")
	check(tree.is_depleted, "树应被砍倒")
	check(v.carry.is_empty(), "居民搬运后背包应清空")
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
