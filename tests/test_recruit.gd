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
	TownRegistry.last_recruit_day = -1000
	DebugManager.instant_recruit = false
	check(not TownRegistry.can_recruit(), "未开启调试招募时应不可招募")
	DebugManager.instant_recruit = true
	EconomyManager.stock["gold"] = 300
	var before := TownRegistry.get_villagers().size()
	check(TownRegistry.can_recruit(), "金币充足时应可招募")
	check(TownRegistry.recruit_villager(), "招募应成功")
	check(EconomyManager.get_amount("gold") == 200, "招募应扣 100 金币")
	check(TownRegistry.get_villagers().size() == before + 1, "招募后应新增 1 名居民")
	check(not TownRegistry.recruit_villager(), "冷却期内不能再次招募")
	# 存档恢复冷却状态（招募当天存档，读档后仍在冷却）
	SaveManager.save_path = "user://save_test_recruit.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	check(SaveManager.save_game(), "应可保存招募状态")
	check(await SaveManager.load_game(), "应可读档")
	check(not TownRegistry.can_recruit(), "读档后应保持冷却状态")
	DirAccess.remove_absolute(SaveManager.save_path)
	DayManager.advance_day()
	DayManager.advance_day()
	check(TownRegistry.can_recruit(), "冷却结束后应可再次招募")
	# 人口上限
	EconomyManager.stock["gold"] = 10000
	TownRegistry.last_recruit_day = -1000
	var guard := 0
	while TownRegistry.get_villagers().size() < TownRegistry.max_villagers() and guard < 30:
		if not TownRegistry.can_recruit():
			DayManager.advance_day()
			continue
		TownRegistry.recruit_villager()
		guard += 1
	check(TownRegistry.get_villagers().size() >= TownRegistry.max_villagers(), "人口应达到上限后停止招募")
	DebugManager.instant_recruit = false
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
