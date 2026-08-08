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
	spawner.zones = [Rect2(0, 0, 400, 300)]
	spawner.max_trees = 5
	spawner.min_spacing = 64.0
	add_child(spawner)
	check(spawner.count_available_wild() == 5, "生成器应补足到 max_trees")
	var all_in_zone := true
	for node in get_tree().get_nodes_in_group("resources"):
		var tree := node as ResourceNode
		if tree != null and tree.is_wild:
			if not spawner.zones[0].has_point(tree.global_position):
				all_in_zone = false
	check(all_in_zone, "野生树应都在区域内")
	var chopped := 0
	for node in get_tree().get_nodes_in_group("resources"):
		var tree := node as ResourceNode
		if tree != null and tree.is_wild and not tree.is_depleted and chopped < 2:
			tree.chop(999, tree.data.max_hp)
			chopped += 1
	spawner._refill()
	check(spawner.count_available_wild() == 5, "补足后可用野生树应恢复为 5")
	DayManager.advance_day()
	check(spawner.count_available_wild() == 5, "新的一天补足后仍为 5")
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
