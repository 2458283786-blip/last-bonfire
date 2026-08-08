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
	var overlay: Control = load("res://scenes/ui/night_overlay.tscn").instantiate()
	add_child(overlay)
	await get_tree().process_frame
	overlay._on_phase_changed(DayManager.TimePhase.DUSK)
	check(overlay.get_node("Dim").color.a > 0.0, "黄昏应压暗")
	check(overlay.get_node("Banner").visible, "黄昏应显示预警横幅")
	overlay._on_phase_changed(DayManager.TimePhase.NIGHT)
	check(overlay.get_node("Dim").color.a > 0.1, "夜晚应更深压暗")
	overlay._on_phase_changed(DayManager.TimePhase.DAY)
	check(overlay.get_node("Banner").text.contains("夜晚过去"), "白天应显示夜晚结算")
	check(overlay.get_node("Dim").color.a == 0.0, "白天不应压暗")
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