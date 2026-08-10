extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_resources.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var tree: ResourceNode = load("res://scenes/resources/tree.tscn").instantiate()
	add_child(tree)
	tree.global_position = Vector2(400, 800)
	tree.current_hp = 0
	tree.is_depleted = true
	tree.respawn_day = DayManager.day + 2
	tree.is_wild = true
	tree._update_visual()
	await get_tree().process_frame
	check(SaveManager.save_game(), "资源状态应可保存")
	tree.queue_free()
	await get_tree().process_frame
	check(await SaveManager.load_game(), "应可读档")
	var restored := false
	for r in get_tree().get_nodes_in_group("resources"):
		if r.global_position.distance_to(Vector2(400, 800)) < 1.0:
			check(r.is_depleted, "耗尽状态应恢复")
			check(r.respawn_day == DayManager.day + 2, "重生天数应恢复")
			check(r.is_wild, "野生标记应恢复")
			check(not r.visible, "耗尽树应不可见")
			restored = true
	check(restored, "应在原位置恢复资源节点")
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
