extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	DungeonManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var spawner := NightWaveSpawner.new()
	spawner.base_wave_size = 2
	spawner.wave_growth = 1
	spawner.max_wave_size = 10
	spawner.random_variance = 0.0
	spawner.villagers_per_point = 2
	spawner.buildings_per_point = 3
	spawner.hoard_threshold = 60
	spawner.hoard_per_point = 30
	add_child(spawner)
	check(spawner._wave_size() == 2, "第一天基线应为 2")
	var v1: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v1)
	v1.set_physics_process(false)
	var v2: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v2)
	v2.set_physics_process(false)
	check(spawner._wave_size() == 3, "2 名居民应 +1 波次")
	for i in 3:
		var b: Building = (load("res://scenes/buildings/storage.tscn") as PackedScene).instantiate()
		add_child(b)
	check(spawner._wave_size() == 4, "3 座建筑应 +1 波次")
	EconomyManager.stock = {"wood": 100}
	check(spawner._wave_size() == 5, "囤积超过阈值应 +1 波次")
	DayManager.day = 20
	check(spawner._wave_size() == 10, "波次应被上限封顶")
	DungeonManager.night_forced = true
	check(spawner._wave_size() == 10, "晚归加强后仍应封顶")
	DungeonManager.consume_night_forced()
	finish(failures.is_empty())

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
