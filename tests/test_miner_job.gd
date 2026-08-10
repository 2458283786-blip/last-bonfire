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
	var tree: ResourceNode = (load("res://scenes/resources/tree.tscn") as PackedScene).instantiate()
	var tree_data := ResourceData.new()
	tree_data.id = "tree"
	tree_data.max_hp = 1
	tree_data.chop_damage = 1
	tree_data.drop_resource = "wood"
	tree_data.drop_amount = 1
	tree_data.respawn_days = 1
	tree_data.required_job = "woodcutter"
	tree.data = tree_data
	add_child(tree)
	tree.global_position = Vector2(700, 370)
	var rock: ResourceNode = (load("res://scenes/resources/rock.tscn") as PackedScene).instantiate()
	var rock_data := ResourceData.new()
	rock_data.id = "rock"
	rock_data.max_hp = 1
	rock_data.chop_damage = 1
	rock_data.drop_resource = "stone"
	rock_data.drop_amount = 1
	rock_data.respawn_days = 1
	rock_data.required_job = "miner"
	rock.data = rock_data
	add_child(rock)
	rock.global_position = Vector2(600, 370)
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v)
	v.global_position = Vector2(300, 375)
	v.set_job("miner")
	v.work_interval = 0.05
	v.move_speed = 400.0
	for i in 400:
		await get_tree().physics_frame
		if tree.is_depleted or rock.is_depleted:
			break
	check(not tree.is_depleted, "矿工不应砍树")
	check(rock.is_depleted, "矿工应挖石头")
	var stone_carried: int = v.carry.get("stone", 0)
	check(EconomyManager.get_amount("stone") > 0 or stone_carried > 0, "应产出石头（携带或入库）")
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
