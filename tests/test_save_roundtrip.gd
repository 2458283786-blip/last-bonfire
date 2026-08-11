extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	EconomyManager.reset()
	DungeonManager.reset()
	InventoryManager.items.clear()
	InventoryManager.equipment.clear()
	SaveManager.save_path = "user://save_test_roundtrip.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	# 满状态：升级仓库 / 住宅 / 职业小屋 / 耗尽资源 / 健康与受伤居民 / 装备背包 / 招募冷却
	EconomyManager.stock = {"wood": 100, "stone": 100, "monster_material": 100}
	var storage: StorageBuilding = (load("res://scenes/buildings/storage.tscn") as PackedScene).instantiate()
	add_child(storage)
	storage.global_position = Vector2(300, 850)
	check(storage.upgrade(), "仓库升级")
	var house: HousingBuilding = (load("res://scenes/buildings/house.tscn") as PackedScene).instantiate()
	add_child(house)
	house.global_position = Vector2(600, 850)
	var hut: WoodcutterHut = (load("res://scenes/buildings/woodcutter_hut.tscn") as PackedScene).instantiate()
	add_child(hut)
	hut.global_position = Vector2(700, 850)
	var tree: ResourceNode = (load("res://scenes/resources/tree.tscn") as PackedScene).instantiate()
	add_child(tree)
	tree.global_position = Vector2(900, 850)
	tree.current_hp = 0
	tree.is_depleted = true
	tree.respawn_day = DayManager.day + 2
	tree._update_visual()
	var v1: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v1)
	v1.set_physics_process(false)
	v1.global_position = Vector2(550, 850)
	v1.home_position = v1.global_position
	house.assign_villager(v1)
	hut.assign_villager(v1)
	v1.carry = {"wood": 2}
	var v2: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v2)
	v2.set_physics_process(false)
	v2.global_position = Vector2(560, 850)
	house.assign_villager(v2)
	v2.take_damage(v2.max_hp)
	InventoryManager.add_item("wooden_sword", 1)
	InventoryManager.equip("melee", "wooden_sword")
	InventoryManager.add_item("health_potion", 2)
	TownRegistry.last_recruit_day = 5
	DayManager.day = 7
	await get_tree().process_frame
	check(SaveManager.save_game(), "满状态应可保存")
	for n in get_tree().get_nodes_in_group("buildings"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("resources"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("villagers"):
		n.queue_free()
	await get_tree().process_frame
	InventoryManager.items.clear()
	InventoryManager.equipment.clear()
	check(await SaveManager.load_game(), "应可读档")
	var storage_ok := false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.building_id == "storage":
			check(b.level == 2, "仓库等级应恢复")
			storage_ok = true
	check(storage_ok, "仓库应恢复")
	check(EconomyManager.capacity >= 180, "仓库容量加成应恢复")
	var healthy: Villager = null
	var injured: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if n.is_injured:
			injured = n
		else:
			healthy = n
	check(healthy != null and healthy.job == "woodcutter", "健康居民职业应恢复")
	check(healthy != null and int(healthy.carry.get("wood", 0)) == 2, "搬运物应恢复")
	check(healthy != null and healthy.has_home(), "住宅归属应恢复")
	check(injured != null and injured.is_injured, "受伤状态应恢复")
	var tree_restored := false
	for r in get_tree().get_nodes_in_group("resources"):
		if r.is_depleted:
			tree_restored = true
	check(tree_restored, "耗尽资源状态应恢复")
	check(InventoryManager.count_item("wooden_sword") == 1, "背包物品应恢复")
	check(InventoryManager.equipped("melee") == "wooden_sword", "装备应恢复")
	check(InventoryManager.count_item("health_potion") == 2, "消耗品数量应恢复")
	check(TownRegistry.last_recruit_day == 5, "招募冷却应恢复")
	check(DayManager.day == 7, "天数应恢复")
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
