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
	check(absf(DayManager.dungeon_time_scale - 0.5) < 0.01, "地下城时间流速默认 0.5")
	check(not DayManager._in_dungeon, "初始应不在地下城")
	# 白天进入：距天黑 = 白天剩余 + 黄昏整段
	DayManager._phase_timer = 30.0
	DungeonManager.enter_dungeon()
	check(DungeonManager.in_dungeon, "进入后应标记在地下城")
	check(DayManager._in_dungeon, "DayManager 应同步地下城状态")
	check(absf(DungeonManager.remaining_to_night - 90.0) < 0.01, "白天进入时距天黑应为 90 秒")
	# 地下城内时间放慢：2 真实秒只算城镇 1 秒
	DayManager._process(2.0)
	check(absf(DayManager._phase_timer - 31.0) < 0.01, "地下城内 2 真实秒只推进城镇 1 秒")
	# 倒计时从 DayManager 推导：再走 58 真实秒（城镇 29 秒）→ 白天结束进入黄昏，距天黑 = 黄昏整段
	DayManager._process(58.0)
	check(DayManager.phase == DayManager.TimePhase.DUSK, "城镇 60 秒后应进入黄昏")
	DungeonManager._process(0.0)
	check(absf(DungeonManager.remaining_to_night - 60.0) < 0.01, "黄昏阶段距天黑应为 60 秒")
	# 探索超时强制入夜：黄昏 60 城镇秒 = 120 真实秒
	DayManager._process(120.0)
	DungeonManager._process(0.0)
	check(DungeonManager.night_forced, "探索超时应强制入夜")
	check(DayManager.phase == DayManager.TimePhase.NIGHT, "阶段应被推进到夜晚")
	check(not DayManager.wave_triggered_tonight, "强制入夜本身不应直接刷怪（回城补刷）")
	DungeonManager.exit_dungeon()
	check(not DungeonManager.in_dungeon, "撤离后应离开地下城")
	check(not DayManager._in_dungeon, "撤离后 DayManager 应清除地下城状态")
	check(DungeonManager.consume_night_forced(), "晚归标记应可被消费一次")
	check(not DungeonManager.consume_night_forced(), "晚归标记只能消费一次")
	# 黄昏进入
	DayManager.reset()
	DungeonManager.reset()
	DayManager.advance_phase()
	DayManager._phase_timer = 10.0
	DungeonManager.enter_dungeon()
	check(absf(DungeonManager.remaining_to_night - 50.0) < 0.01, "黄昏进入时距天黑应为 50 秒")
	DayManager._process(20.0)
	DungeonManager._process(0.0)
	check(not DungeonManager.night_forced, "未超时不应强制入夜")
	check(absf(DungeonManager.remaining_to_night - 40.0) < 0.01, "黄昏剩余应同步为 40 秒")
	DungeonManager.exit_dungeon()
	check(DayManager.phase == DayManager.TimePhase.DUSK, "提前撤离不应改变阶段")
	# 城镇节奏不变：非地下城时 1 真实秒 = 1 城镇秒
	DayManager.reset()
	DungeonManager.reset()
	DayManager._process(60.0)
	check(DayManager.phase == DayManager.TimePhase.DUSK, "城镇内 60 秒应正常推进一个阶段")
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
