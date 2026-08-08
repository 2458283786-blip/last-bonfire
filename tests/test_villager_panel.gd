extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var panel: PanelContainer = load("res://scenes/ui/villager_panel.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame
	var hut: WoodcutterHut = load("res://scenes/buildings/woodcutter_hut.tscn").instantiate()
	add_child(hut)
	var v1 := _make_villager("阿强")
	var v2 := _make_villager("阿花")
	var v3 := _make_villager("阿土")
	panel.open_panel()
	check(panel.get_node("HBox/Left/VillagerList").get_child_count() == 3, "列表应显示 3 名居民")
	check(panel.try_assign_to_hut(v1, hut), "第一次调整应成功")
	check(v1.job == "woodcutter", "应转职为伐木工")
	check(not panel.try_assign_to_hut(v1, hut), "同一天第二次调整应失败")
	check(panel.try_assign_to_hut(v2, hut), "第二名居民应可转职")
	check(not panel.try_assign_to_hut(v3, hut), "名额已满应失败")
	check(hut.assigned.size() == 2, "伐木屋应满员")
	DayManager.advance_day()
	check(panel.try_assign_idle(v2), "次日应可再次调整")
	check(v2.job == "idle", "v2 应转空闲")
	check(panel.try_assign_idle(v1), "v1 转空闲也应成功")
	check(v1.job == "idle", "v1 职业应回到空闲")
	finish(failures.is_empty())

func _make_villager(nick: String) -> Villager:
	var v: Villager = load("res://scenes/villagers/villager.tscn").instantiate()
	v.display_name = nick
	add_child(v)
	v.set_physics_process(false)
	return v

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
