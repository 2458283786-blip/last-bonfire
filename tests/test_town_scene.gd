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
	var town: Node2D = (load("res://scenes/town/town.tscn") as PackedScene).instantiate()
	add_child(town)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Node = town.get_node_or_null("Player")
	check(player is Player, "城镇场景应包含 Player 节点")
	check(town.get_node_or_null("GroundBody") != null, "城镇应有地面碰撞体")
	check(town.get_node_or_null("DungeonEntrance") != null, "城镇应有地下通道入口标记")
	if player is Player:
		check(player.global_position.y > 0, "玩家应在地面上方生成")
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
