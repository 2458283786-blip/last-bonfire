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
	check(ResourceDatabase.get_data("wood") != null, "木材应注册")
	check(ResourceDatabase.display_name("wood") == "木头", "木材显示名")
	check(ResourceDatabase.short_name("wood") == "木", "木材短名")
	check(ResourceDatabase.display_name("monster_material") == "怪物材料", "材料显示名")
	check(ResourceDatabase.short_name("gold") == "金", "金币短名")
	check(ResourceDatabase.get_data("nonexistent") == null, "未知资源应返回空")
	check(ResourceDatabase.short_name("nonexistent") == "nonexistent", "未知资源短名回退 id")
	# 建造卡片显示全部造价（不再只显示木/石）
	var data := BuildingData.new()
	data.id = "ui_test"
	data.display_name = "测试"
	data.cost = {"wood": 5, "gold": 3, "monster_material": 2}
	data.scene = load("res://scenes/buildings/storage.tscn")
	var menu: PanelContainer = load("res://scenes/ui/build_menu.tscn").instantiate()
	var entries: Array[BuildingData] = [data]
	menu.entries = entries
	add_child(menu)
	await get_tree().process_frame
	var btn := menu.get_node("HBox").get_child(0) as Button
	check(btn.text.contains("木5"), "卡片应显示木消耗")
	check(btn.text.contains("金3"), "卡片应显示金消耗")
	check(btn.text.contains("材2"), "卡片应显示材料消耗")
	# 建筑面板短名格式化走注册表
	var panel: PanelContainer = load("res://scenes/ui/building_panel.tscn").instantiate()
	add_child(panel)
	check(panel._format_cost({"stone": 8, "monster_material": 2}) == "石8 材2", "面板应使用注册表短名")
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
