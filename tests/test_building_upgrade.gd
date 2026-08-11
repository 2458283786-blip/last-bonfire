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
	EconomyManager.stock = {"wood": 100, "stone": 100, "monster_material": 100}
	var base_capacity := EconomyManager.capacity
	var storage: StorageBuilding = (load("res://scenes/buildings/storage.tscn") as PackedScene).instantiate()
	add_child(storage)
	check(EconomyManager.capacity == base_capacity + 80, "1 级仓库应 +80 容量")
	check(storage.can_upgrade(), "有资源时应可升级")
	var wood_before := EconomyManager.get_amount("wood")
	check(storage.upgrade(), "升级应成功")
	check(storage.level == 2, "升级后等级应为 2")
	check(EconomyManager.capacity == base_capacity + 160, "2 级仓库应 +160 容量")
	check(EconomyManager.get_amount("wood") == wood_before - 15, "升级应扣除木材")
	# 资源不足时升级失败且不扣费、不改等级
	EconomyManager.stock = {}
	EconomyManager.stock["wood"] = 5
	check(not storage.upgrade(), "资源不足升级应失败")
	check(storage.level == 2, "资源不足时等级不应变化")
	EconomyManager.stock = {"wood": 100, "stone": 100, "monster_material": 100}
	check(storage.upgrade(), "补足资源后应可再次升级")
	check(storage.level == 3, "满级前应可升级到 3 级")
	check(not storage.upgrade(), "满级后不能再升级")
	storage.take_damage(9999)
	check(not storage.upgrade(), "已摧毁建筑不能升级")
	# 职业小屋升级加名额
	var hut: WoodcutterHut = (load("res://scenes/buildings/woodcutter_hut.tscn") as PackedScene).instantiate()
	add_child(hut)
	check(hut.effective_slots() == 2, "1 级伐木屋名额应为 2")
	check(hut.upgrade(), "伐木屋升级应成功")
	check(hut.effective_slots() == 3, "2 级伐木屋名额应为 3")
	# 资源建筑升级补足资源
	var camp: LumberCamp = (load("res://scenes/buildings/lumber_camp.tscn") as PackedScene).instantiate()
	add_child(camp)
	check(_resource_count(camp) == camp.resource_count, "1 级伐木场资源数应为初始值")
	check(camp.upgrade(), "伐木场升级应成功")
	check(_resource_count(camp) == camp.resource_count + camp.resources_per_level, "升级后资源数应增加")
	# 怪物材料已进入升级造价
	var storage_data := load("res://resources/data/buildings/storage.tres") as BuildingData
	check(int(storage_data.upgrade_cost.get("monster_material", 0)) > 0, "仓库升级应消耗怪物材料")
	finish(failures.is_empty())

func _resource_count(camp: ResourceCamp) -> int:
	var count := 0
	for child in camp.get_children():
		if child is ResourceNode:
			count += 1
	return count

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
