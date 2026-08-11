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
	var hut: MinerHut = MinerHut.new()
	hut.job_slots = 1
	add_child(hut)
	var house: HousingBuilding = (load("res://scenes/buildings/house.tscn") as PackedScene).instantiate()
	house.position = Vector2(300, 0)
	add_child(house)
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v)
	house.assign_villager(v)
	hut.assign_villager(v)
	check(v.job == "miner", "转职后居民应为矿工")
	check(not hut.can_accept_villager(v), "名额满后不能再接收")
	hut.release_villager(v)
	check(hut.can_accept_villager(v), "释放后应能再次接收")
	var v2: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v2)
	house.assign_villager(v2)
	for i in 120:
		await get_tree().physics_frame
		if v2.job == "miner":
			break
	check(v2.job == "miner", "空闲居民应自动转职为矿工")
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
