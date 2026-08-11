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
	# 二选一候选
	var run := DungeonRun.new()
	run.stages = 3
	run.rooms_per_stage = 3
	run.max_rescues_per_run = 2
	run.rescue_weight = 0.10
	run.begin(12345)
	run.make_choice()
	check(run.pending_choice.size() == 2, "每组应有两个候选")
	check(run.pending_choice[0].type != run.pending_choice[1].type, "同组候选类型不应重复")
	for n in run.pending_choice:
		check(n.room_scene != null, "候选应关联房间预制件")
	# 救援不保底 + 上限
	var run2 := DungeonRun.new()
	run2.max_rescues_per_run = 2
	run2.rescue_weight = 0.5
	run2.begin(999)
	var rescue_seen := 0
	for i in 20:
		run2.make_choice()
		for n in run2.pending_choice:
			if n.type == "rescue":
				rescue_seen += 1
	check(rescue_seen <= 2, "救援房受每局上限约束（不保底）")
	# 阶段推进 / BOSS 强制 / 商人固定阶段解锁 / 通关
	DungeonManager.merchant_unlock_stage = 2
	DungeonManager.run = run
	for stage in [1, 2]:
		for i in run.rooms_per_stage:
			DungeonManager.room_cleared()
		check(DungeonManager.should_enter_boss(), "阶段末应强制进 BOSS")
		var boss := DungeonManager.enter_boss_room()
		check(boss != null and boss.type == "boss", "应生成 BOSS 节点")
		DungeonManager.stage_boss_cleared()
		if stage == 1:
			check(DungeonManager.run.current_stage == 2, "阶段 1 完成后进入阶段 2")
		else:
			check(DungeonManager.run.shop_unlocked, "第 2 阶段 BOSS 后应解锁商人")
			check(not DungeonManager.is_run_completed(), "阶段 2 未到最终阶段")
	for i in run.rooms_per_stage:
		DungeonManager.room_cleared()
	DungeonManager.enter_boss_room()
	DungeonManager.stage_boss_cleared()
	check(DungeonManager.is_run_completed(), "最终阶段 BOSS 后应通关")
	# 通关结算
	DungeonManager.finish_run_to_town()
	check(TownRegistry.is_blueprint_unlocked("shop"), "通关后商店蓝图应正式解锁")
	check(DungeonManager.run == null, "通关后运行态应清空")
	check(not DungeonManager.in_dungeon, "通关后应离开地下城状态")
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
