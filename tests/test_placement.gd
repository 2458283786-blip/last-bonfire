extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var data := BuildingData.new()
	data.id = "test"
	data.display_name = "测试建筑"
	data.cost = {"wood": 1}
	data.scene = load("res://scenes/buildings/storage.tscn")
	data.footprint_half_width = 48.0
	var ctrl: PlacementController = PlacementController.new()
	ctrl.bounds = Rect2(50, 800, 1820, 120)
	ctrl.ground_y = 855.0
	ctrl.min_spacing = 96.0
	add_child(ctrl)
	check(ctrl.can_place(Vector2(300, 855)), "空地上应可放置")
	check(not ctrl.can_place(Vector2(100, 500)), "超出边界应不可放置")
	var existing: Building = load("res://scenes/buildings/storage.tscn").instantiate()
	add_child(existing)
	existing.global_position = Vector2(900, 855)
	check(not ctrl.can_place(Vector2(940, 855)), "与已有建筑过近应不可放置")
	ctrl.begin(data)
	check(ctrl._ghost != null, "进入放置模式应生成预览")
	ctrl._ghost.global_position = Vector2(400, 855)
	ctrl._confirm()
	check(EconomyManager.get_amount("wood") == 9, "建造应扣除 1 木材")
	check(not ctrl._active, "放置成功后应退出放置状态")
	var placed := 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.global_position.distance_to(Vector2(400, 855)) < 1.0:
			placed += 1
	check(placed == 1, "应在指定位置生成建筑")
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