extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
	create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	quit(1)

func _run() -> void:
	await process_frame
	var scene: Node2D = (load("res://scenes/dungeon/level_forest.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await physics_frame
	check(scene.get_node_or_null("PlayerSpawn") != null, "关卡模板应有 PlayerSpawn 标记")
	check(scene.get_node_or_null("EnemySpawn") != null, "关卡模板应有 EnemySpawn 标记")
	check(scene.get_node_or_null("DungeonExit") != null, "关卡模板应有 DungeonExit 标记")
	_finish()

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_dungeon_template: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_dungeon_template: %d 个断言失败" % failures.size())
		quit(1)
