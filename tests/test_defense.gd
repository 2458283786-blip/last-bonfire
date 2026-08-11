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
	var barracks: Node = (load("res://scenes/buildings/militia_barracks.tscn") as PackedScene).instantiate()
	add_child(barracks)
	barracks.global_position = Vector2(600, 400)
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v)
	v.set_physics_process(false)
	v.global_position = Vector2(600, 400)
	barracks.assign_villager(v)
	check(v.job == "militia", "民兵营应转职为民兵")
	check(v.current_job is DefenseJob, "职业应为防御职业")
	var enemy: Enemy = (load("res://scenes/enemies/basic_enemy.tscn") as PackedScene).instantiate()
	add_child(enemy)
	enemy.global_position = Vector2(620, 400)
	var hp_before := enemy.current_hp
	v._guard(1.1)
	check(enemy.current_hp < hp_before, "范围内敌人应被民兵攻击")
	# 夜晚防御居民继续站岗（不回家）
	DayManager.advance_phase()
	DayManager.advance_phase()
	check(DayManager.phase == DayManager.TimePhase.NIGHT, "应处于夜晚")
	v._update_idle()
	check(v.state == Villager.WorkState.GUARD, "夜晚防御居民应继续站岗")
	DayManager.advance_phase()
	# 防御建筑被毁释放居民
	barracks.take_damage(9999)
	check(v.job == "idle", "防御建筑被毁后居民应转空闲")
	# 箭塔远程站桩
	var tower: Node = (load("res://scenes/buildings/arrow_tower.tscn") as PackedScene).instantiate()
	add_child(tower)
	tower.global_position = Vector2(900, 400)
	var v2: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v2)
	v2.set_physics_process(false)
	v2.global_position = Vector2(900, 400)
	tower.assign_villager(v2)
	check(v2.job == "tower_guard", "箭塔应转职为塔卫")
	check(v2.current_job is TowerGuardJob, "职业应为远程防御职业")
	var enemy2: Enemy = (load("res://scenes/enemies/basic_enemy.tscn") as PackedScene).instantiate()
	add_child(enemy2)
	enemy2.global_position = Vector2(1100, 400)
	var children_before := get_child_count()
	v2._guard(1.3)
	check(get_child_count() == children_before + 1, "远程守卫应发射弹道")
	var bolt: Node = get_child(get_child_count() - 1)
	check(bolt.get("arrow_damage") == tower.attack_damage, "弹道伤害应来自建筑配置")
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
