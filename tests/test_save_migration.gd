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
	# 纯 migrate 单测
	var old := {"version": 1, "day": {"day": 3, "phase": 0, "phase_elapsed": 5.0}, "economy": {"stock": {"wood": 5}, "capacity": 20}}
	var migrated := SaveManager.migrate(old)
	check(int(migrated["version"]) == SaveManager.SAVE_VERSION, "迁移后版本应为当前版本")
	check(migrated.has("inventory"), "迁移应补齐背包字段")
	check(migrated.has("town"), "迁移应补齐城镇招募字段")
	check(migrated.has("unlocked_blueprints"), "迁移应补齐解锁表字段")
	check(int(migrated["day"]["day"]) == 3, "迁移应保留原有字段")
	# 端到端：v1 存档文件可直接读档
	SaveManager.save_path = "user://save_test_migration.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"version": 1,
		"day": {"day": 2, "phase": 0, "phase_elapsed": 0.0},
		"economy": {"stock": {"wood": 3}, "capacity": 20},
	}))
	f.close()
	DayManager.reset()
	EconomyManager.reset()
	InventoryManager.items.clear()
	InventoryManager.equipment.clear()
	check(await SaveManager.load_game(), "v1 存档应可读档")
	check(DayManager.day == 2, "v1 天数应恢复")
	check(EconomyManager.get_amount("wood") == 3, "v1 库存应恢复")
	check(InventoryManager.items.is_empty(), "v1 读档后背包应为空（迁移补齐）")
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
