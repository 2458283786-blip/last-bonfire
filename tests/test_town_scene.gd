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
	var town: Node2D = (load("res://scenes/town/town.tscn") as PackedScene).instantiate()
	root.add_child(town)
	await physics_frame
	await physics_frame
	var player: Node = town.get_node_or_null("Player")
	check(player is Player, "城镇场景应包含 Player 节点")
	check(town.get_node_or_null("GroundBody") != null, "城镇应有地面碰撞体")
	if player is Player:
		check(player.global_position.y > 0, "玩家应在地面上方生成")
	_finish()

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_town_scene: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_town_scene: %d 个断言失败" % failures.size())
		quit(1)
