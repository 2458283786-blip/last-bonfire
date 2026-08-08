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
	check(DayManager.phase == DayManager.TimePhase.DAY, "初始应为白天")
	var spawner := NightWaveSpawner.new()
	spawner.enemy_scene = load("res://scenes/enemies/basic_enemy.tscn") as PackedScene
	spawner.base_wave_size = 2
	spawner.wave_growth = 1
	spawner.max_wave_size = 10
	spawner.spawn_offsets = [Vector2(-100, 0), Vector2(100, 0)]
	add_child(spawner)
	spawner.global_position = Vector2(500, 375)
	DayManager.advance_phase()
	check(DayManager.phase == DayManager.TimePhase.DUSK, "第二次阶段应为黄昏")
	DayManager.advance_phase()
	await get_tree().process_frame
	check(DayManager.phase == DayManager.TimePhase.NIGHT, "第三次阶段应为夜晚")
	check(get_tree().get_nodes_in_group("enemies").size() == 2, "第一晚应生成 2 只怪物")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	await get_tree().process_frame
	DayManager.advance_phase()
	check(DayManager.day == 2, "回到白天应进入第二天")
	DayManager.advance_phase()
	DayManager.advance_phase()
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("enemies").size() == 3, "第二晚应生成 3 只怪物")
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
