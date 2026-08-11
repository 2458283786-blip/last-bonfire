extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var base := 180.0
	var all_in_range := true
	for i in 20:
		var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
		add_child(v)
		v.set_physics_process(false)
		if v.move_speed < base * 0.9 - 0.01 or v.move_speed > base * 1.1 + 0.01:
			all_in_range = false
	check(all_in_range, "居民移速应落在 ±10% 范围内")
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
