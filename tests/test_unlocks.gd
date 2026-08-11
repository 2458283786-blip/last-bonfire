extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	DungeonManager.reset()
	EconomyManager.reset()
	TownRegistry.unlocked_blueprints.clear()
	TownRegistry.pending_rescued_villagers = 0
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	# 蓝图正式解锁
	check(not TownRegistry.is_blueprint_unlocked("shop"), "初始商店未解锁")
	check(TownRegistry.unlock_blueprint("shop"), "应可解锁商店")
	check(not TownRegistry.unlock_blueprint("shop"), "重复解锁应返回 false")
	check(TownRegistry.is_blueprint_unlocked("shop"), "解锁后应可查询")
	# 建造菜单：正式解锁后出现（不开 Debug 开关）
	DebugManager.unlock_all_blueprints = false
	var menu: PanelContainer = load("res://scenes/ui/build_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var cards: HBoxContainer = menu.get_node("HBox")
	var shop_visible := false
	for child in cards.get_children():
		if (child as Button).text.contains("商店"):
			shop_visible = true
	check(shop_visible, "正式解锁后商店应出现在建造菜单")
	# 救援居民回城
	var before := TownRegistry.get_villagers().size()
	TownRegistry.add_rescued_villagers(2)
	TownRegistry.spawn_pending_rescues()
	check(TownRegistry.get_villagers().size() == before + 2, "救援居民应生成到城镇")
	check(TownRegistry.pending_rescued_villagers == 0, "生成后待结算应归零")
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
