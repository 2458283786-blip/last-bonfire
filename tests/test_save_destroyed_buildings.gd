extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_destroyed_buildings.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	for b in get_tree().get_nodes_in_group("buildings"):
		b.queue_free()
	await get_tree().process_frame
	var base := EconomyManager.capacity
	var storage: StorageBuilding = load("res://scenes/buildings/storage.tscn").instantiate()
	add_child(storage)
	storage.global_position = Vector2(300, 850)
	storage.take_damage(9999)
	check(storage.is_destroyed, "仓库应被摧毁")
	check(EconomyManager.capacity == base, "摧毁后容量应回退")
	var quarry: Quarry = load("res://scenes/buildings/quarry.tscn").instantiate()
	add_child(quarry)
	quarry.global_position = Vector2(700, 860)
	quarry.take_damage(9999)
	await get_tree().process_frame
	check(_count_resources(quarry) == 0, "采石场被毁后场内石头应清理")
	check(SaveManager.save_game(), "被毁建筑状态应可保存")
	storage.queue_free()
	quarry.queue_free()
	await get_tree().process_frame
	check(await SaveManager.load_game(), "应可读档")
	check(EconomyManager.capacity == base, "读档后被毁仓库不应扩容")
	var restored_storage := false
	var restored_quarry := false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is StorageBuilding:
			check(b.is_destroyed, "仓库应保持被毁状态")
			restored_storage = true
		elif b is Quarry:
			check(b.is_destroyed, "采石场应保持被毁状态")
			await get_tree().process_frame
			check(_count_resources(b) == 0, "读档后被毁采石场不应有场内石头")
			restored_quarry = true
	check(restored_storage and restored_quarry, "应恢复被毁建筑")
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is StorageBuilding:
			b.repair()
			check(EconomyManager.capacity == base + b.capacity_boost, "修复后容量应恢复")
		elif b is Quarry:
			b.rebuild()
			await get_tree().process_frame
			check(_count_resources(b) == b.resource_count, "重建后应重新生成石头")
	for b in get_tree().get_nodes_in_group("buildings"):
		b.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(SaveManager.save_path)
	finish(failures.is_empty())

func _count_resources(camp: ResourceCamp) -> int:
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
