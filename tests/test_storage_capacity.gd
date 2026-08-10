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
	var base := EconomyManager.capacity
	var storage: StorageBuilding = (load("res://scenes/buildings/storage.tscn") as PackedScene).instantiate()
	add_child(storage)
	check(EconomyManager.capacity == base + storage.capacity_boost, "建仓库应扩容")
	storage.take_damage(9999)
	check(storage.is_destroyed, "仓库应被摧毁")
	check(EconomyManager.capacity == base, "被毁后容量应回退")
	storage.repair()
	check(EconomyManager.capacity == base + storage.capacity_boost, "修复后容量应恢复")
	storage.take_damage(9999)
	storage.rebuild()
	check(EconomyManager.capacity == base + storage.capacity_boost, "重建后容量应恢复")
	storage.refresh_function_state()
	check(EconomyManager.capacity == base + storage.capacity_boost, "重复同步不应重复扩容")
	storage.take_damage(9999)
	storage.refresh_function_state()
	check(EconomyManager.capacity == base, "重复同步被毁状态不应重复减容量")
	storage.queue_free()
	await get_tree().process_frame
	check(EconomyManager.capacity == base, "移除建筑后容量应释放")
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
