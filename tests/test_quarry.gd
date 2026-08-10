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
	var quarry: Quarry = Quarry.new()
	quarry.resource_scene = load("res://scenes/resources/rock.tscn")
	quarry.resource_count = 6
	quarry.spawn_radius = 120.0
	add_child(quarry)
	var rock_count := 0
	for child in quarry.get_children():
		var r := child as ResourceNode
		if r != null:
			rock_count += 1
	check(rock_count == 6, "应生成 6 块石头")
	var miner_rock := false
	for child in quarry.get_children():
		var r := child as ResourceNode
		if r != null and r.data != null and r.data.required_job == "miner":
			miner_rock = true
			break
	check(miner_rock, "生成的石头应使用 rock.tres（要求矿工职业）")
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
