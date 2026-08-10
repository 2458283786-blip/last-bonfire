extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	SaveManager.save_path = "user://save_test_global.json"
	DirAccess.remove_absolute(SaveManager.save_path)
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	DayManager.day = 3
	DayManager.phase = 1
	DayManager._phase_timer = 12.5
	EconomyManager.set_capacity(100)
	EconomyManager.deposit("wood", 7)
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(500, 800)
	player.take_damage(30.0)
	await get_tree().process_frame
	check(SaveManager.save_game(), "全局状态应可保存")
	DayManager.day = 9
	DayManager.phase = 2
	DayManager._phase_timer = 0.0
	EconomyManager.reset()
	player.global_position = Vector2(100, 100)
	player.hp = 100.0
	check(await SaveManager.load_game(), "应可读档")
	check(DayManager.day == 3, "天数应恢复")
	check(DayManager.phase == 1, "阶段应恢复")
	check(absf(DayManager._phase_timer - 12.5) < 1.0, "阶段计时应恢复")
	check(EconomyManager.get_amount("wood") == 17, "木材库存应恢复（10+7）")
	check(player.global_position.distance_to(Vector2(500, 800)) < 1.0, "玩家位置应恢复")
	check(int(player.hp) == 70, "玩家血量应恢复")
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
