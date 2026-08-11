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
	var house: HousingBuilding = (load("res://scenes/buildings/house.tscn") as PackedScene).instantiate()
	add_child(house)
	house.global_position = Vector2(400, 300)
	var v1: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v1)
	v1.set_physics_process(false)
	v1.global_position = Vector2(300, 300)
	check(not v1.has_home(), "初始应无住宅")
	check(v1._try_assign_home(), "有空住宅时无职业居民应自动入住")
	check(v1.has_home(), "入住后应有住宅")
	check(v1.home == house, "住宅引用应正确")
	var v2: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v2)
	v2.set_physics_process(false)
	v2.global_position = Vector2(320, 300)
	check(house.assign_villager(v2), "第二个居民应可入住")
	var v3: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v3)
	v3.set_physics_process(false)
	check(not house.assign_villager(v3), "满员后不能再入住")
	var hut: WoodcutterHut = (load("res://scenes/buildings/woodcutter_hut.tscn") as PackedScene).instantiate()
	add_child(hut)
	check(not v3._try_auto_convert(), "没房子不能自动转职")
	# 升级扩容
	EconomyManager.deposit("wood", 100)
	EconomyManager.deposit("stone", 100)
	check(house.upgrade(), "住宅应可升级")
	check(house.effective_capacity() == 4, "2 级住宅容量应为 4")
	check(house.assign_villager(v3), "升级后应可入住第三个居民")
	# 夜晚亮灯 + 回家
	DayManager.advance_phase()
	check(not house.window_light.visible, "黄昏不亮灯")
	DayManager.advance_phase()
	check(house.window_light.visible, "夜晚有住户应亮灯")
	v1._update_idle()
	check(v1.state == Villager.WorkState.GO_HOME or v1._is_near_home(), "夜晚居民应回家")
	DayManager.advance_phase()
	check(not house.window_light.visible, "白天应熄灯")
	# 住宅被毁释放居民与职业
	var v4: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v4)
	v4.set_physics_process(false)
	house.assign_villager(v4)
	hut.assign_villager(v4)
	house.take_damage(9999)
	check(not v4.has_home(), "住宅被毁后应失去住宅")
	check(v4.job == "idle", "没房子应失去职业")
	check(house.assigned.is_empty(), "被毁后住宅应无住户")
	house.repair()
	check(house.effective_capacity() == 4, "重建后容量应恢复")
	check(house.assign_villager(v4), "重建后应可重新入住")
	# 空闲小动作
	v4._show_idle_emote()
	check(v4.emote_label.visible and v4.emote_label.text != "", "休息时应显示小动作")
	v4._hide_idle_emote()
	check(not v4.emote_label.visible, "移动后应隐藏小动作")
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
