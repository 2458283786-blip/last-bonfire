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
	var data := BuildingData.new()
	data.id = "test"
	data.display_name = "测试建筑"
	data.cost = {"wood": 5, "stone": 2}
	data.scene = load("res://scenes/buildings/storage.tscn")
	data.footprint_half_width = 48.0
	var menu: PanelContainer = load("res://scenes/ui/build_menu.tscn").instantiate()
	var entries: Array[BuildingData] = [data]
	menu.entries = entries
	add_child(menu)
	await get_tree().process_frame
	var cards: HBoxContainer = menu.get_node("HBox")
	check(cards.get_child_count() == 1, "每份配置应生成一张卡片")
	var btn := cards.get_child(0) as Button
	check(not btn.disabled, "资源充足时卡片应可点击")
	EconomyManager.withdraw("wood", 10)
	check(btn.disabled, "资源不足时卡片应置灰")
	# 无手动条目时从建筑数据库构建（单一注册表）
	var menu_db: PanelContainer = load("res://scenes/ui/build_menu.tscn").instantiate()
	add_child(menu_db)
	await get_tree().process_frame
	check(menu_db.entries.size() == BuildingDatabase.all_data().size(), "菜单应从数据库构建全部建筑")
	var db_cards: HBoxContainer = menu_db.get_node("HBox")
	check(db_cards.get_child_count() == BuildingDatabase.all_data().size() - 1, "锁定蓝图（商店）应被过滤")
	var first_btn := db_cards.get_child(0) as Button
	check(first_btn.text.contains("仓库"), "菜单应按 build_menu_order 排序，第一张为仓库")
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
