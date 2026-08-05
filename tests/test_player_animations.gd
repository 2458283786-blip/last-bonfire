extends SceneTree

var failures: Array[String] = []
var assertions := 0
const PLAYER_SCENE := "res://scenes/player/player.tscn"

func _initialize() -> void:
	create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	quit(1)

func _run() -> void:
	await process_frame
	var p := await _spawn_player()
	var frames := p.sprite.sprite_frames
	check(frames != null, "玩家应已构建 SpriteFrames")
	if frames != null:
		for anim in ["idle", "run", "jump", "attack"]:
			check(frames.has_animation(anim), "应有 " + anim + " 动画")
	check(p.sprite.animation == "idle", "静止时应播放 idle")
	press("move_right")
	await process_frame
	await physics_frame
	await physics_frame
	check(p.sprite.animation == "run", "移动时应播放 run")
	_finish()

func _spawn_player() -> Player:
	var scene := load(PLAYER_SCENE) as PackedScene
	var p := scene.instantiate() as Player
	root.add_child(p)
	p.global_position = Vector2(400, 375)
	_add_floor(Vector2(400, 400))
	for i in 8:
		await physics_frame
	return p

func _add_floor(pos: Vector2) -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = pos
	root.add_child(floor)

func press(action: String) -> void:
	Input.action_press(action)

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_player_animations: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_player_animations: %d 个断言失败" % failures.size())
		quit(1)
