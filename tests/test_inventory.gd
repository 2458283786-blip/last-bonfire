extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	InventoryManager.items.clear()
	InventoryManager.equipment.clear()
	InventoryManager.add_item("wooden_sword", 1)
	check(InventoryManager.count_item("wooden_sword") == 1, "应能添加物品")
	check(InventoryManager.melee_bonus() == 0, "未装备时无加成")
	check(InventoryManager.equip("melee", "wooden_sword"), "装备应成功")
	check(InventoryManager.melee_bonus() == 1, "近战加成应为 1")
	check(not InventoryManager.equip("armor", "wooden_sword"), "槽位不匹配应失败")
	InventoryManager.add_item("leather_armor", 1)
	check(InventoryManager.equip("armor", "leather_armor"), "护甲应可装备")
	check(InventoryManager.defense_bonus() == 1, "防御加成应为 1")
	InventoryManager.unequip("melee")
	check(InventoryManager.melee_bonus() == 0, "卸下后加成归零")
	# 消耗品
	InventoryManager.add_item("health_potion", 2)
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.hp = 50.0
	check(InventoryManager.use_consumable("health_potion"), "药水应可使用")
	check(absf(player.hp - 80.0) < 0.01, "药水应回血 30")
	check(InventoryManager.count_item("health_potion") == 1, "药水数量应减少")
	# 存档恢复
	SaveManager.save_path = "user://save_test_inventory.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	check(SaveManager.save_game(), "含背包的存档应可保存")
	InventoryManager.equipment.clear()
	InventoryManager.items.clear()
	check(await SaveManager.load_game(), "应可读档")
	check(InventoryManager.count_item("wooden_sword") == 1, "读档后物品应恢复")
	check(InventoryManager.equipped("armor") == "leather_armor", "读档后装备应恢复")
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
