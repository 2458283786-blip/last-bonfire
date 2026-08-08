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
	var storage: StorageBuilding = (load("res://scenes/buildings/storage.tscn") as PackedScene).instantiate()
	add_child(storage)
	check(storage.is_in_group("buildings"), "建筑应加入 buildings 组")
	check(storage.hp == storage.max_hp, "初始血量应为满")
	storage.take_damage(10)
	check(storage.hp == storage.max_hp - 10, "受伤应扣血")
	storage.take_damage(999)
	check(storage.is_destroyed, "血量归零应损坏")
	check(not storage.visible, "损坏后应隐藏")
	storage.rebuild()
	check(not storage.is_destroyed and storage.hp == storage.max_hp, "重建应恢复")
	var bonfire: Bonfire = (load("res://scenes/buildings/bonfire.tscn") as PackedScene).instantiate()
	add_child(bonfire)
	check(bonfire.is_in_group("core_buildings"), "篝火应为核心建筑")
	check(bonfire.is_in_group("buildings"), "篝火也应属于建筑")
	bonfire.take_damage(5)
	check(bonfire.hp == bonfire.max_hp - 5, "篝火应能受伤")
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
