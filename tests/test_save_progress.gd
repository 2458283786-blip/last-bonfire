extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false
var _started := false
var _progresses: Array[float] = []
var _finished := false
var _finished_ok := false

func _ready() -> void:
	DayManager.reset()
	EconomyManager.reset()
	SaveManager.save_path = "user://save_test_progress.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var house: HousingBuilding = (load("res://scenes/buildings/house.tscn") as PackedScene).instantiate()
	add_child(house)
	house.global_position = Vector2(400, 300)
	var hut: WoodcutterHut = (load("res://scenes/buildings/woodcutter_hut.tscn") as PackedScene).instantiate()
	add_child(hut)
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v)
	v.set_physics_process(false)
	v.global_position = Vector2(300, 300)
	house.assign_villager(v)
	hut.assign_villager(v)
	check(SaveManager.save_game(), "应可保存")
	for n in [house, hut, v]:
		n.queue_free()
	await get_tree().process_frame
	SaveManager.load_started.connect(func() -> void: _started = true)
	SaveManager.load_progress.connect(func(p: float, _label: String) -> void: _progresses.append(p))
	SaveManager.load_finished.connect(func(ok: bool) -> void:
		_finished = true
		_finished_ok = ok)
	check(await SaveManager.load_game(), "应可读档")
	check(_started, "应发射读档开始信号")
	check(_progresses.size() >= 3, "应发射多次进度信号")
	check(_progresses.back() >= 0.99, "最终进度应接近 100%")
	check(_finished and _finished_ok, "应发射读档完成信号")
	var restored: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		restored = n as Villager
		break
	check(restored != null, "应恢复居民")
	check(restored.is_physics_processing(), "读档后居民应恢复物理处理（回归：站立不动）")
	restored._update_idle()
	check(restored.state != Villager.WorkState.IDLE, "读档后居民应恢复行动（进入工作流程）")
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
