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
	var spawner := WildTreeSpawner.new()
	spawner.tree_scene = load("res://scenes/resources/tree.tscn") as PackedScene
	spawner.max_trees = 3
	spawner.min_spacing = 64.0
	var zone_area := Area2D.new()
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 300)
	shape_node.shape = rect
	zone_area.add_child(shape_node)
	spawner.add_child(zone_area)
	zone_area.position = Vector2(500, 150)
	add_child(spawner)
	check(spawner.count_available_wild() == 3, "可视区域生成器应补足到 max_trees")
	var in_zone := true
	for node in get_tree().get_nodes_in_group("resources"):
		var tree := node as ResourceNode
		if tree != null and tree.is_wild:
			if tree.global_position.x < 300.0 or tree.global_position.x > 700.0 \
					or tree.global_position.y < 0.0 or tree.global_position.y > 300.0:
				in_zone = false
	check(in_zone, "可视区域生成的树应都在框内")
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
