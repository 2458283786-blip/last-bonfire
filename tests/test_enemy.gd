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
	check(data != null, "夜狼配置应可加载")
	if data == null:
		finish(failures.is_empty())
		return
	check(data.max_hp == 3, "夜狼血量应为 3")
	check(data.attack_priority.size() > 0 and data.attack_priority[0] == "villager", "夜狼应优先攻击居民")
	var enemy_scene := load("res://scenes/enemies/basic_enemy.tscn") as PackedScene
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.data = data
	add_child(enemy)
	enemy.global_position = Vector2(300, 375)
	# 受伤与死亡掉落
	var loot: Array[Dictionary] = [
		{"resource_id": "gold", "min": 1, "max": 1, "chance": 1.0},
	]
	enemy.data.loot_table = loot
	enemy.take_damage(1)
	check(enemy.current_hp == 2, "受伤应扣血")
	enemy.take_damage(2)
	var was_queued := enemy.is_queued_for_deletion()
	await get_tree().process_frame
	check(was_queued, "血量归零应标记死亡")
	check(not is_instance_valid(enemy), "敌人应在下一帧被移除")
	check(get_tree().get_nodes_in_group("pickups").size() == 1, "死亡应生成 1 个掉落物")
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
