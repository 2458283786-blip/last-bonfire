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
	quarry.resource_count = 4
	add_child(quarry)
	check(_count_resources(quarry) == 4, "采石场应生成 4 块石头")
	quarry.take_damage(9999)
	check(quarry.is_destroyed, "采石场应被摧毁")
	await get_tree().process_frame
	check(_count_resources(quarry) == 0, "被毁后场内石头应清理")
	quarry.rebuild()
	await get_tree().process_frame
	check(_count_resources(quarry) == 4, "重建后应重新生成满编")
	quarry.take_damage(9999)
	quarry.refresh_function_state()
	await get_tree().process_frame
	check(_count_resources(quarry) == 0, "重复同步被毁状态不应残留资源")
	quarry.rebuild()
	quarry.refresh_function_state()
	await get_tree().process_frame
	check(_count_resources(quarry) == 4, "重复同步完好状态不应重复生成")
	finish(failures.is_empty())

func _count_resources(camp: ResourceCamp) -> int:
	var count := 0
	for child in camp.get_children():
		if child is ResourceNode:
			count += 1
	return count

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
