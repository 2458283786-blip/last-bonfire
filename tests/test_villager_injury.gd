extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	_add_floor(Vector2(500, 420))
	var hut: WoodcutterHut = (load("res://scenes/buildings/woodcutter_hut.tscn") as PackedScene).instantiate()
	hut.job_slots = 1
	add_child(hut)
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v)
	v.global_position = Vector2(400, 375)
	hut.assign_villager(v)
	check(v.job == "woodcutter", "初始应为伐木工")
	v.take_damage(5.0)
	check(v.hp == v.max_hp - 5.0, "受伤应扣血")
	check(not v.is_injured, "未归零不应受伤状态")
	v.take_damage(v.max_hp)
	check(v.is_injured, "血量归零应进入受伤状态")
	check(v.injured_remaining_days == v.injured_days, "应记录受伤天数")
	check(v.job == "idle", "受伤后应失去职业")
	check(hut.can_accept_villager(v), "受伤应释放伐木屋名额")
	v.take_damage(5.0)
	check(v.hp == 0.0, "受伤期间不应再扣血")
	DayManager.advance_day()
	DayManager.advance_day()
	check(not v.is_injured, "两天后应恢复")
	check(v.hp == v.max_hp, "恢复后血量应回满")
	for i in 30:
		await get_tree().physics_frame
		if v.job == "woodcutter":
			break
	check(v.job == "woodcutter", "恢复后有空位应自动恢复职业")
	finish(failures.is_empty())

func _add_floor(pos: Vector2) -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = pos
	add_child(floor)

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
