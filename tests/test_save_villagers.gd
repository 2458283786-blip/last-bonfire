extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_villagers.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var hut: WoodcutterHut = load("res://scenes/buildings/woodcutter_hut.tscn").instantiate()
	add_child(hut)
	var v: Villager = load("res://scenes/villagers/villager.tscn").instantiate()
	v.display_name = "阿强"
	add_child(v)
	v.set_physics_process(false)
	v.global_position = Vector2(260, 840)
	v.home_position = Vector2(260, 840)
	v.carry = {"wood": 2}
	v.hp = 10.0
	v.is_injured = true
	v.injured_remaining_days = 2
	v.set_job("woodcutter")
	await get_tree().process_frame
	check(SaveManager.save_game(), "居民状态应可保存")
	v.queue_free()
	hut.queue_free()
	await get_tree().process_frame
	check(await SaveManager.load_game(), "应可读档")
	var restored := false
	for n in get_tree().get_nodes_in_group("villagers"):
		if n.global_position.distance_to(Vector2(260, 840)) < 1.0:
			check(n.display_name == "阿强", "名字应恢复")
			check(n.job == "woodcutter", "职业应恢复")
			check(int(n.carry.get("wood", 0)) == 2, "搬运物应恢复")
			check(n.is_injured, "伤势应恢复")
			check(n.injured_remaining_days == 2, "伤势天数应恢复")
			restored = true
	check(restored, "应在原位置恢复居民")
	var assigned := false
	for hut_n in get_tree().get_nodes_in_group("job_huts"):
		if hut_n.assigned.size() > 0:
			assigned = true
	check(assigned, "伐木工应重新分配进伐木屋")
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
