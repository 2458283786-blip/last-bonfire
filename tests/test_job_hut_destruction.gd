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
	hut.job_slots = 2
	add_child(hut)
	var v1: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	var v2: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v1)
	add_child(v2)
	hut.assign_villager(v1)
	hut.assign_villager(v2)
	check(hut.assigned.size() == 2, "应分配两名矿工")
	hut.take_damage(9999)
	check(hut.is_destroyed, "小屋应被摧毁")
	check(hut.assigned.is_empty(), "被毁后名额应全部释放")
	check(v1.job == "idle", "居民应恢复空闲")
	check(v2.job == "idle", "第二名居民也应恢复空闲")
	hut.rebuild()
	check(not hut.is_destroyed, "重建后应恢复")
	check(hut.can_accept_villager(v1), "重建后应能再分配")
	hut.assign_villager(v1)
	check(v1.job == "miner", "重建后分配应生效")
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
