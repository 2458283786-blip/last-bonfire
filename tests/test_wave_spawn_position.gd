extends Node

signal finished(ok: bool)

class DummyTarget:
	extends Node2D

	func take_damage(_amount: int) -> void:
		pass

var failures: Array[String] = []
var assertions := 0
var _done := false
var _broadcasts: Array = []

func _ready() -> void:
	DayManager.reset()
	DungeonManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var spawner := NightWaveSpawner.new()
	spawner.enemy_scene = load("res://scenes/enemies/basic_enemy.tscn") as PackedScene
	spawner.base_wave_size = 4
	spawner.wave_growth = 0
	spawner.max_wave_size = 10
	spawner.random_variance = 0.0
	spawner.spawn_band = Rect2(1940, 850, 240, 24)
	spawner.town_bounds = Rect2(50, 800, 1820, 120)
	spawner.march_point = Vector2(960, 870)
	spawner.warning_radius = 900.0
	add_child(spawner)
	EventBus.threat_broadcast.connect(_on_threat)
	spawner._spawn_wave()
	var enemies := get_tree().get_nodes_in_group("enemies")
	check(enemies.size() == 4, "应生成 4 只怪物")
	var all_outside := true
	var all_in_band := true
	for e in enemies:
		if spawner._inside_town(e.global_position):
			all_outside = false
		if e.global_position.x < 1940.0 or e.global_position.x > 2180.0:
			all_in_band = false
		check(e.march_target == Vector2(960, 870), "怪物应携带行军目标")
	check(all_outside, "怪物不应生成在城镇范围内")
	check(all_in_band, "怪物应生成在屏幕外刷怪带内")
	check(_broadcasts.size() >= 5, "应广播威胁（每怪一次 + 预警一次）")
	EventBus.threat_broadcast.disconnect(_on_threat)
	for e in enemies:
		e.queue_free()
	await get_tree().process_frame
	# 行军：无目标时朝行军点推进，发现目标后切换追击
	var data := load("res://resources/data/enemy_night_wolf.tres") as EnemyData
	data.attack_priority = ["player"]
	var enemy: Enemy = (load("res://scenes/enemies/basic_enemy.tscn") as PackedScene).instantiate()
	enemy.data = data
	add_child(enemy)
	enemy.global_position = Vector2(1500, 375)
	enemy.march_target = Vector2(600, 375)
	enemy._idle(1.0)
	check(enemy.velocity.x < 0.0, "行军应朝城镇方向移动")
	var dummy := DummyTarget.new()
	dummy.add_to_group("players")
	add_child(dummy)
	dummy.global_position = Vector2(800, 375)
	enemy.global_position = Vector2(900, 375)
	enemy._idle(1.0)
	check(enemy.ai_state == Enemy.AIState.CHASE, "发现目标后应切换追击")
	finish(failures.is_empty())

func _on_threat(_origin: Vector2, _radius: float) -> void:
	_broadcasts.append(_origin)

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
