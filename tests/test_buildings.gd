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
	var base_capacity := EconomyManager.capacity
	var storage_scene := load("res://scenes/buildings/storage.tscn") as PackedScene
	var storage: StorageBuilding = storage_scene.instantiate()
	add_child(storage)
	check(storage.is_in_group("storage_buildings"), "仓库应加入 storage_buildings 组")
	check(EconomyManager.capacity > base_capacity, "仓库应扩容库存容量")
	var hut_scene := load("res://scenes/buildings/woodcutter_hut.tscn") as PackedScene
	var hut: WoodcutterHut = hut_scene.instantiate()
	add_child(hut)
	var villager_scene := load("res://scenes/villagers/villager.tscn") as PackedScene
	var v: Villager = villager_scene.instantiate()
	add_child(v)
	check(hut.can_accept_villager(v), "伐木屋应能接收居民")
	hut.assign_villager(v)
	check(v.job == "woodcutter", "转职后居民应为伐木工")
	var v2: Villager = villager_scene.instantiate()
	add_child(v2)
	hut.assign_villager(v2)
	check(v2.job == "woodcutter", "第二个居民也应转职")
	var v3: Villager = villager_scene.instantiate()
	add_child(v3)
	check(not hut.can_accept_villager(v3), "满员后不能再接收")
	var camp_scene := load("res://scenes/buildings/lumber_camp.tscn") as PackedScene
	var camp: LumberCamp = camp_scene.instantiate()
	add_child(camp)
	var tree_count := 0
	for child in camp.get_children():
		if child is ResourceNode:
			tree_count += 1
	check(tree_count == camp.resource_count, "伐木场应生成固定数量的树")
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
