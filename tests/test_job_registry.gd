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
	for job_name in JobRegistry.JOBS:
		var job := JobRegistry.create(job_name)
		check(job != null, "注册职业应可实例化: " + job_name)
		check(JobRegistry.display_name(job_name) != job_name, "注册职业应有显示名: " + job_name)
	check(JobRegistry.create("idle") == null, "未注册职业应返回空")
	check(JobRegistry.display_name("unknown") == "unknown", "未知职业显示名回退 id")
	# 与既有行为类的对应关系
	check(JobRegistry.create("woodcutter") is WoodcutterJob, "woodcutter 应对应伐木职业")
	check(JobRegistry.create("miner") is MinerJob, "miner 应对应矿工职业")
	check(JobRegistry.create("militia") is MilitiaJob, "militia 应对应民兵职业")
	check(JobRegistry.create("tower_guard") is TowerGuardJob, "tower_guard 应对应塔卫职业")
	# 显示名与 UI 一致
	check(TownRegistry.job_display_name("woodcutter") == "伐木工", "职业显示名应统一")
	check(TownRegistry.job_display_name("idle") == "空闲", "空闲显示名")
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
