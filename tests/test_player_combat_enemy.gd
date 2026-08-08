extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	DayManager.reset()
	EconomyManager.reset()
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	_add_floor(Vector2(500, 420))
	var data := load("res://resources/data/enemy_night_wolf.tres") as EnemyData
	data = data.duplicate() as EnemyData
	data.attack_priority = []
	var p: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(p)
	p.global_position = Vector2(400, 375)
	# 近战命中敌人
	var enemy: Enemy = _spawn_enemy(Vector2(430, 375), data)
	press("attack")
	for i in 30:
		await get_tree().physics_frame
		if enemy.current_hp < enemy.data.max_hp:
			break
	check(enemy.current_hp == enemy.data.max_hp - 1, "近战攻击应命中敌人")
	enemy.global_position = Vector2(100, 375)
	# 箭矢命中敌人
	var enemy2: Enemy = _spawn_enemy(Vector2(620, 375), data)
	p.global_position = Vector2(300, 375)
	p.facing = 1
	press("bow")
	var arrow_hit := false
	for i in 120:
		await get_tree().physics_frame
		if enemy2.current_hp < enemy2.data.max_hp:
			arrow_hit = true
			break
	check(arrow_hit, "箭矢应命中敌人")
	# 玩家走过自动拾取
	var pickup: Pickup = (load("res://scenes/resources/pickup.tscn") as PackedScene).instantiate()
	pickup.resource_id = "wood"
	pickup.amount = 2
	add_child(pickup)
	pickup.global_position = p.global_position
	var wood_before := EconomyManager.get_amount("wood")
	for i in 30:
		await get_tree().physics_frame
		if EconomyManager.get_amount("wood") > wood_before:
			break
	check(EconomyManager.get_amount("wood") == wood_before + 2, "走过拾取物应自动拾取入库")
	finish(failures.is_empty())

func _spawn_enemy(pos: Vector2, data: EnemyData) -> Enemy:
	var enemy: Enemy = (load("res://scenes/enemies/basic_enemy.tscn") as PackedScene).instantiate()
	enemy.data = data
	add_child(enemy)
	enemy.global_position = pos
	return enemy

func _add_floor(pos: Vector2) -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = pos
	add_child(floor)

func press(action: String) -> void:
	Input.action_press(action)

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
