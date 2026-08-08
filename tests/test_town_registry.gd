extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var v := Villager.new()
	TownRegistry.register_villager(v)
	check(TownRegistry.get_villagers().has(v), "注册后应可查到")
	check(not TownRegistry.adjusted_today(v.villager_id), "初始未调整")
	TownRegistry.mark_adjusted(v.villager_id)
	check(TownRegistry.adjusted_today(v.villager_id), "标记后应算已调整")
	DayManager.advance_day()
	check(not TownRegistry.adjusted_today(v.villager_id), "次日应重置调整次数")
	TownRegistry.unregister_villager(v)
	check(not TownRegistry.get_villagers().has(v), "注销后应不可查")
	var hut := Node.new()
	TownRegistry.register_job_hut(hut)
	check(TownRegistry.get_job_huts().has(hut), "职业建筑应可登记")
	TownRegistry.unregister_job_hut(hut)
	check(not TownRegistry.get_job_huts().has(hut), "职业建筑应可注销")
	hut.free()
	var vs: Node = load("res://scenes/villagers/villager.tscn").instantiate()
	add_child(vs)
	await get_tree().process_frame
	check(TownRegistry.get_villagers().has(vs), "居民场景应自动注册")
	v.free()
	vs.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
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
