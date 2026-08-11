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
	var cfg := load("res://resources/data/game_config.tres") as GameConfig
	check(cfg != null, "配置应可加载")
	check(absf(cfg.gravity - 1200.0) < 0.01, "重力默认 1200")
	check(absf(cfg.enemy_gravity - 1200.0) < 0.01, "敌人重力默认 1200")
	check(absf(cfg.villager_flee_speed_mult - 1.2) < 0.01, "逃跑倍率默认 1.2")
	check(absf(cfg.villager_injured_speed_mult - 0.5) < 0.01, "受伤倍率默认 0.5")
	var v: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(v)
	v.set_physics_process(false)
	check(absf(v.flee_speed_mult - 1.2) < 0.01, "居民应读取逃跑倍率")
	check(absf(v.injured_speed_mult - 0.5) < 0.01, "居民应读取受伤倍率")
	check(absf(v.gravity - 1200.0) < 0.01, "居民应读取重力")
	var enemy: Enemy = (load("res://scenes/enemies/basic_enemy.tscn") as PackedScene).instantiate()
	add_child(enemy)
	check(absf(enemy.gravity - 1200.0) < 0.01, "敌人应读取重力")
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.set_physics_process(false)
	check(absf(player.gravity - 1200.0) < 0.01, "玩家应读取重力")
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
