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
	var tree_scene := load("res://scenes/resources/tree.tscn") as PackedScene
	var tree: ResourceNode = tree_scene.instantiate()
	add_child(tree)
	tree.global_position = Vector2(400, 370)
	check(tree.data != null, "树应有资源配置")
	if tree.data != null:
		check(tree.data.drop_resource == "wood", "树应产出木材")
		check(tree.data.respawn_days == 2, "树应 2 天重生")
	check(_has_no_blocking_body(tree), "树不应有 StaticBody2D（可穿过）")
	check(tree.try_reserve(1), "第一个居民应能预留")
	check(not tree.try_reserve(2), "预留后其他居民不能预留")
	tree.release_reservation(1)
	check(tree.try_reserve(2), "释放后可被其他居民预留")
	tree.chop(2, tree.data.max_hp)
	check(tree.is_depleted, "血量归零应耗尽")
	check(get_tree().get_nodes_in_group("pickups").size() == 1, "耗尽应生成 1 个掉落物")
	check(not tree.visible, "耗尽后应隐藏")
	DayManager.advance_day()
	DayManager.advance_day()
	check(not tree.is_depleted, "到重生日应恢复")
	check(tree.visible, "重生后应可见")
	finish(failures.is_empty())

func _has_no_blocking_body(node: Node) -> bool:
	if node is StaticBody2D or node is CharacterBody2D or node is RigidBody2D:
		return false
	for child in node.get_children():
		if not _has_no_blocking_body(child):
			return false
	return true

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
