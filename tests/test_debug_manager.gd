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
	var data := BuildingData.new()
	data.id = "locked_test"
	data.display_name = "锁定建筑"
	data.cost = {"wood": 1}
	data.scene = load("res://scenes/buildings/storage.tscn")
	data.footprint_half_width = 48.0
	data.requires_unlock = true
	DebugManager.unlock_all_blueprints = false
	var menu: PanelContainer = load("res://scenes/ui/build_menu.tscn").instantiate()
	var entries: Array[BuildingData] = [data]
	menu.entries = entries
	add_child(menu)
	await get_tree().process_frame
	var cards: HBoxContainer = menu.get_node("HBox")
	check(cards.get_child_count() == 0, "未解锁蓝图不应显示")
	DebugManager.unlock_all_blueprints = true
	menu._rebuild_cards()
	check(cards.get_child_count() == 1, "调试解锁后应显示蓝图")
	DebugManager.unlock_all_blueprints = false
	# skip_costs：调试开关跳过建造资源消耗
	var ctrl: PlacementController = PlacementController.new()
	ctrl.bounds = Rect2(50, 800, 1820, 120)
	ctrl.ground_y = 855.0
	add_child(ctrl)
	ctrl.begin(data)
	ctrl._ghost.global_position = Vector2(400, 855)
	DebugManager.skip_costs = true
	ctrl._confirm()
	check(EconomyManager.get_amount("wood") == 10, "跳过造价时不应扣资源")
	check(not ctrl._active, "放置应成功")
	DebugManager.skip_costs = false
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
