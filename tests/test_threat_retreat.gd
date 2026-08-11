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
	var house: HousingBuilding = (load("res://scenes/buildings/house.tscn") as PackedScene).instantiate()
	house.position = Vector2(600, 380)
	add_child(house)
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	v.position = Vector2(300, 375)
	add_child(v)
	v.set_physics_process(false)
	house.assign_villager(v)
	# 威胁广播触发撤退
	EventBus.threat_broadcast.emit(Vector2(320, 375), 600.0)
	check(v.state == Villager.WorkState.FLEE, "威胁广播后应进入逃跑状态")
	check(v._fleeing, "应标记逃跑中")
	# 无敌人时威胁清除恢复
	check(not v._any_threat_nearby(), "附近无敌人应判定安全")
	v._flee(0.1)
	check(not v._fleeing, "安全后应停止逃跑")
	check(v.state == Villager.WorkState.IDLE, "安全后应恢复空闲")
	# 附近有敌人时不恢复
	var enemy: Enemy = (load("res://scenes/enemies/basic_enemy.tscn") as PackedScene).instantiate()
	add_child(enemy)
	enemy.global_position = Vector2(400, 375)
	check(v._any_threat_nearby(), "附近有敌人应判定受威胁")
	# 威胁半径跟随敌人自身配置（用独立 EnemyData，避免污染共享资源）
	var custom := EnemyData.new()
	custom.id = "threat_test"
	custom.max_hp = 3
	custom.aggro_range = 100.0
	custom.attack_priority = ["player"]
	enemy.data = custom
	enemy.global_position = Vector2(500, 375)
	check(not v._any_threat_nearby(), "超出敌人感知范围不应判定受威胁")
	enemy.global_position = Vector2(350, 375)
	check(v._any_threat_nearby(), "进入敌人感知范围应判定受威胁")
	# 范围外威胁不触发
	v._fleeing = false
	v.state = Villager.WorkState.IDLE
	EventBus.threat_broadcast.emit(Vector2(5000, 5000), 100.0)
	check(v.state == Villager.WorkState.IDLE, "范围外威胁不应触发逃跑")
	# 逃跑速度倍率
	v.move_speed = 100.0
	check(absf(v.move_speed * Villager.FLEE_SPEED_MULT - 120.0) < 0.01, "逃跑速度应为 1.2 倍")
	# 受伤居民不参与撤退
	v.take_damage(v.max_hp)
	v.state = Villager.WorkState.IDLE
	v._fleeing = false
	EventBus.threat_broadcast.emit(Vector2(310, 375), 600.0)
	check(v.state == Villager.WorkState.IDLE, "受伤居民不应逃跑")
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
