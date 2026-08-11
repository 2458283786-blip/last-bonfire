extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	DungeonManager.reset()
	EconomyManager.reset()
	InventoryManager.items.clear()
	InventoryManager.equipment.clear()
	SaveManager.save_path = "user://save_test_dungeon.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	# 持久成果：商人解锁 + 救援居民已生成
	TownRegistry.unlock_blueprint("shop")
	TownRegistry.add_rescued_villagers(2)
	TownRegistry.spawn_pending_rescues()
	await get_tree().process_frame
	check(SaveManager.save_game(), "应可保存解锁与救援成果")
	TownRegistry.unlocked_blueprints.clear()
	for n in get_tree().get_nodes_in_group("villagers"):
		n.queue_free()
	await get_tree().process_frame
	check(await SaveManager.load_game(), "应可读档")
	check(TownRegistry.is_blueprint_unlocked("shop"), "读档后商店解锁应恢复")
	check(TownRegistry.get_villagers().size() >= 2, "读档后救援居民应恢复")
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
