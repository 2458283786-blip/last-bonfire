extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var storage: Building = load("res://scenes/buildings/storage.tscn").instantiate()
	add_child(storage)
	await get_tree().process_frame
	var panel: PanelContainer = load("res://scenes/ui/building_panel.tscn").instantiate()
	add_child(panel)
	panel.show_building(storage)
	check(panel.visible, "打开后应可见")
	check(panel.get_node("VBox/TitleLabel").text == "仓库", "应显示建筑名")
	check(not panel.get_node("VBox/RepairButton").visible, "满血不应显示修复按钮")
	storage.take_damage(30)
	panel._refresh()
	check(panel.get_node("VBox/RepairButton").visible, "受损后应显示修复按钮")
	panel._on_repair_pressed()
	check(storage.hp == storage.max_hp, "修复后应满血")
	check(storage.is_destroyed == false, "修复后不应处于摧毁态")
	storage.take_damage(storage.max_hp)
	panel._refresh()
	check(panel.get_node("VBox/RepairButton").text == "重建", "摧毁后按钮应显示重建")
	panel._on_repair_pressed()
	check(not storage.is_destroyed, "重建后应恢复")
	panel._on_demolish_confirmed()
	check(not is_instance_valid(storage) or storage.is_queued_for_deletion(), "拆除应移除建筑")
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