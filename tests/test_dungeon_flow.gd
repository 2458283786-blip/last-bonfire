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
	DungeonManager.start_run()
	check(DungeonManager.run != null, "开局应创建运行态")
	check(DungeonManager.run.pending_choice.size() == 2, "开局应有二选一候选")
	var node := DungeonManager.choose_node(0)
	check(node != null and node == DungeonManager.current_node(), "选择后应设置当前节点")
	for i in DungeonManager.run.rooms_per_stage:
		check(not DungeonManager.should_enter_boss(), "未满阶段房间数时不应进 BOSS")
		DungeonManager.room_cleared()
	check(DungeonManager.should_enter_boss(), "满阶段房间数后应进 BOSS")
	# 两门界面展示候选
	var dc: CanvasLayer = (load("res://scenes/dungeon/door_choice.tscn") as PackedScene).instantiate()
	add_child(dc)
	await get_tree().process_frame
	var left: Button = dc.get_node("UI/Buttons/LeftButton")
	var right: Button = dc.get_node("UI/Buttons/RightButton")
	check(left.text.contains("门") and right.text.contains("门"), "两门应显示房间类型")
	# BOSS 推进到下一阶段
	var boss := DungeonManager.enter_boss_room()
	check(boss != null and boss.type == "boss", "应进入 BOSS 房")
	DungeonManager.stage_boss_cleared()
	check(DungeonManager.run.current_stage == 2, "阶段推进到 2")
	DungeonManager.make_choice()
	check(DungeonManager.run.pending_choice.size() == 2, "下一阶段应重新生成候选")
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
