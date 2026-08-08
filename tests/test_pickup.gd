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
	var pickup_scene := load("res://scenes/resources/pickup.tscn") as PackedScene
	var pickup: Pickup = pickup_scene.instantiate()
	add_child(pickup)
	check(get_tree().get_nodes_in_group("pickups").size() == 1, "掉落物应加入 pickups 组")
	var got := pickup.take()
	check(got.get("resource_id") == "wood", "take 应返回资源 ID")
	check(got.get("amount") == 1, "take 应返回数量")
	check(pickup.take().is_empty(), "二次 take 应返回空")
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
