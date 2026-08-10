extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_buildings.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var storage: Building = load("res://scenes/buildings/storage.tscn").instantiate()
	add_child(storage)
	storage.global_position = Vector2(300, 850)
	storage.take_damage(30)
	var hut: Building = load("res://scenes/buildings/woodcutter_hut.tscn").instantiate()
	add_child(hut)
	hut.global_position = Vector2(700, 860)
	await get_tree().process_frame
	check(SaveManager.save_game(), "建筑状态应可保存")
	storage.queue_free()
	hut.queue_free()
	await get_tree().process_frame
	check(await SaveManager.load_game(), "应可读档")
	check(get_tree().get_nodes_in_group("buildings").size() >= 2, "应重建建筑")
	var restored := false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.global_position.distance_to(Vector2(300, 850)) < 1.0:
			check(b is StorageBuilding, "恢复的应是仓库")
			check(b.hp == 70, "仓库血量应恢复")
			restored = true
	check(restored, "应在原位置恢复仓库")
	for b in get_tree().get_nodes_in_group("buildings"):
		b.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(SaveManager.save_path)
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
