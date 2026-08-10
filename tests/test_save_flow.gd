extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_flow.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var old_name := get_tree().current_scene.name
	get_tree().current_scene.name = "Town"
	DayManager.advance_day()
	await get_tree().process_frame
	check(SaveManager.has_save(), "城镇内推进一天应自动存档")
	get_tree().current_scene.name = old_name
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	hud.get_node("PauseMenu").get_node("VBox/SaveButton").pressed.emit()
	await get_tree().process_frame
	check(SaveManager.has_save(), "暂停菜单存档按钮应可存档")
	check(hud.get_node("PauseMenu").get_node("VBox/LoadButton") != null, "暂停菜单应有读档按钮")
	check(not GameManager.pending_load, "初始不应待读档")
	GameManager.pending_load = true
	var town: Node2D = load("res://scenes/town/town.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not GameManager.pending_load, "进入城镇后应消费待读档标记")
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
