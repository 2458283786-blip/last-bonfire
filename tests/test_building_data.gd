extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var storage := load("res://resources/data/buildings/storage.tres") as BuildingData
	check(storage != null, "storage.tres 应可加载")
	check(storage.display_name == "仓库", "仓库显示名")
	check(storage.scene != null, "仓库应关联场景")
	check(int(storage.cost.get("wood", 0)) > 0, "仓库造价应含木材")
	var hut := load("res://resources/data/buildings/woodcutter_hut.tres") as BuildingData
	check(hut != null and hut.display_name == "伐木屋", "伐木屋配置")
	var camp := load("res://resources/data/buildings/lumber_camp.tres") as BuildingData
	check(camp != null and camp.display_name == "伐木场", "伐木场配置")
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
