extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var hint: Label = load("res://scenes/ui/interact_hint.tscn").instantiate()
	add_child(hint)
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(0, 0)
	var ia: Interactable = Interactable.new()
	ia.prompt = "按 E 测试"
	ia.interact_radius = 100.0
	add_child(ia)
	ia.global_position = Vector2(50, 0)
	await get_tree().process_frame
	check(hint.visible and hint.text == "按 E 测试", "靠近应显示提示")
	ia.global_position = Vector2(1000, 0)
	await get_tree().process_frame
	check(not hint.visible, "远离应隐藏提示")
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