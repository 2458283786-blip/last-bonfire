extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	DungeonManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	# 白天进入：距天黑 = 白天剩余 + 黄昏整段
	DayManager._phase_timer = 30.0
	DungeonManager.enter_dungeon()
	check(DungeonManager.in_dungeon, "进入后应标记在地下城")
	check(absf(DungeonManager.remaining_to_night - 90.0) < 0.01, "白天进入时距天黑应为 90 秒")
	DungeonManager._process(91.0)
	check(DungeonManager.night_forced, "探索超时应强制入夜")
	check(DayManager.phase == DayManager.TimePhase.NIGHT, "阶段应被推进到夜晚")
	check(not DayManager.wave_triggered_tonight, "强制入夜本身不应直接刷怪（回城补刷）")
	DungeonManager.exit_dungeon()
	check(not DungeonManager.in_dungeon, "撤离后应离开地下城")
	check(DungeonManager.consume_night_forced(), "晚归标记应可被消费一次")
	check(not DungeonManager.consume_night_forced(), "晚归标记只能消费一次")
	# 黄昏进入
	DayManager.reset()
	DungeonManager.reset()
	DayManager.advance_phase()
	DayManager._phase_timer = 10.0
	DungeonManager.enter_dungeon()
	check(absf(DungeonManager.remaining_to_night - 50.0) < 0.01, "黄昏进入时距天黑应为 50 秒")
	DungeonManager._process(20.0)
	check(not DungeonManager.night_forced, "未超时不应强制入夜")
	DungeonManager.exit_dungeon()
	check(DayManager.phase == DayManager.TimePhase.DUSK, "提前撤离不应改变阶段")
	# 晚归回城：夜晚 + 未触发 → spawner 补刷且带加强
	DayManager.reset()
	DungeonManager.reset()
	DayManager.phase = DayManager.TimePhase.NIGHT
	DungeonManager.night_forced = true
	var spawner := NightWaveSpawner.new()
	spawner.enemy_scene = load("res://scenes/enemies/basic_enemy.tscn") as PackedScene
	spawner.base_wave_size = 2
	spawner.wave_growth = 1
	spawner.max_wave_size = 10
	spawner.random_variance = 0.0
	spawner.away_bonus_multiplier = 1.5
	add_child(spawner)
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("enemies").size() == 3, "晚归波次应加强（2×1.5）")
	check(DayManager.wave_triggered_tonight, "刷怪后应标记当晚已触发")
	check(not DungeonManager.night_forced, "晚归标记应被波次消费")
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await get_tree().process_frame
	# 同一晚再次加载不重复刷
	var spawner2 := NightWaveSpawner.new()
	spawner2.enemy_scene = load("res://scenes/enemies/basic_enemy.tscn") as PackedScene
	spawner2.base_wave_size = 2
	spawner2.max_wave_size = 10
	spawner2.random_variance = 0.0
	add_child(spawner2)
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("enemies").is_empty(), "同一晚不应重复刷怪")
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
