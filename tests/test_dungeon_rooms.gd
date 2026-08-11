extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	DungeonManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	# 战斗房
	var combat_node := DungeonNodeData.new()
	combat_node.type = "combat"
	combat_node.enemy_ids = ["night_wolf", "night_wolf"]
	var room: DungeonRoom = (load("res://scenes/dungeon/rooms/combat_room.tscn") as PackedScene).instantiate()
	DungeonManager._current_node = combat_node
	add_child(room)
	await get_tree().process_frame
	var enemies := get_tree().get_nodes_in_group("enemies")
	check(enemies.size() == 2, "战斗房应生成 2 只敌人")
	for e in enemies.duplicate():
		e.take_damage(99)
	await get_tree().process_frame
	check(room.is_cleared(), "清怪后战斗房应判定清场")
	# 清掉战斗房遗留的掉落物，避免污染宝箱房计数
	for p in get_tree().get_nodes_in_group("pickups").duplicate():
		p.queue_free()
	await get_tree().process_frame
	# 宝箱房
	var chest_node := DungeonNodeData.new()
	chest_node.type = "chest"
	chest_node.loot = [{"resource_id": "gold", "min": 2, "max": 2}]
	var chest: DungeonRoom = (load("res://scenes/dungeon/rooms/chest_room.tscn") as PackedScene).instantiate()
	DungeonManager._current_node = chest_node
	add_child(chest)
	await get_tree().process_frame
	var pickups := get_tree().get_nodes_in_group("pickups")
	check(pickups.size() == 2, "宝箱房应生成 2 个拾取物")
	for p in pickups.duplicate():
		p.take()
	await get_tree().process_frame
	check(chest.is_cleared(), "拾光后宝箱房应判定清场")
	# 救援房
	var rescue_node := DungeonNodeData.new()
	rescue_node.type = "rescue"
	rescue_node.enemy_ids = ["night_wolf", "night_wolf"]
	DungeonManager.run = DungeonRun.new()
	DungeonManager.run.begin(1)
	var rescue: RescueRoom = (load("res://scenes/dungeon/rooms/rescue_room.tscn") as PackedScene).instantiate()
	DungeonManager._current_node = rescue_node
	add_child(rescue)
	await get_tree().process_frame
	var guards := get_tree().get_nodes_in_group("enemies")
	check(guards.size() == 2, "救援房应生成守卫")
	for g in guards.duplicate():
		g.take_damage(99)
	await get_tree().process_frame
	await get_tree().process_frame
	# 确定性驱动：直接执行一次守卫清场判定（避免测试容器下 _process 时序差异）
	rescue._process(0.016)
	var cage := rescue.get_node("Cage")
	check(cage._active, "守卫清完后囚笼应可交互")
	rescue.on_rescue()
	check(DungeonManager.run.rescued_villagers == 1, "解救后救援数应 +1")
	check(rescue.is_cleared(), "解救后救援房应判定完成")
	# BOSS 房
	var boss_node := DungeonNodeData.new()
	boss_node.type = "boss"
	boss_node.enemy_ids = ["boss_wolf"]
	var boss_room: BossRoom = (load("res://scenes/dungeon/rooms/boss_room.tscn") as PackedScene).instantiate()
	DungeonManager._current_node = boss_node
	add_child(boss_room)
	await get_tree().process_frame
	var boss := get_tree().get_first_node_in_group("enemies")
	check(boss != null and boss.data.id == "boss_wolf", "BOSS 房应生成狼王")
	boss.take_damage(999)
	await get_tree().process_frame
	check(boss_room.is_cleared(), "击杀 BOSS 后应判定清场")
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
