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
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.set_physics_process(false)
	check(player.collision_layer == PhysicsLayers.PLAYER, "玩家层应为 PLAYER")
	check(player.collision_mask == PhysicsLayers.MASK_WORLD_ENEMY, "玩家掩码应为 世界|敌人")
	check(player.get_node("AttackHitbox").collision_mask == PhysicsLayers.MASK_WORLD_ENEMY, "攻击框掩码应一致")
	var villager: Villager = (load("res://scenes/villagers/villager.tscn") as PackedScene).instantiate()
	add_child(villager)
	villager.set_physics_process(false)
	check(villager.collision_layer == PhysicsLayers.VILLAGER, "居民层应为 VILLAGER")
	check(villager.collision_mask == PhysicsLayers.MASK_WORLD_ONLY, "居民掩码应为 仅世界")
	var enemy: Enemy = (load("res://scenes/enemies/basic_enemy.tscn") as PackedScene).instantiate()
	add_child(enemy)
	check(enemy.collision_layer == PhysicsLayers.ENEMY, "敌人层应为 ENEMY")
	check(enemy.collision_mask == PhysicsLayers.MASK_WORLD_PLAYER, "敌人掩码应为 世界|玩家")
	var arrow: Arrow = (load("res://scenes/player/arrow.tscn") as PackedScene).instantiate()
	add_child(arrow)
	check(arrow.collision_mask == PhysicsLayers.MASK_WORLD_ENEMY, "箭矢掩码应为 世界|敌人")
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
