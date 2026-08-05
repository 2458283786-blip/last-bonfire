extends SceneTree

var failures: Array[String] = []
var assertions := 0
const REQUIRED_ACTIONS := ["move_left", "move_right", "jump", "attack", "bow", "interact"]

func _initialize() -> void:
	create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	quit(1)

func _run() -> void:
	await process_frame
	for action in REQUIRED_ACTIONS:
		check(InputMap.has_action(action), "缺少输入动作: " + action)
	_finish()

func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)

func _finish() -> void:
	if failures.is_empty():
		print("[PASS] test_input_map: %d 断言全部通过" % assertions)
		quit(0)
	else:
		for f in failures:
			push_error("[FAIL] " + f)
		print("[FAIL] test_input_map: %d 个断言失败" % failures.size())
		quit(1)
