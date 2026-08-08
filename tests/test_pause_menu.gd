extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	GameManager.resume_game()
	get_tree().create_timer(20.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var hud: CanvasLayer = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	check(not GameManager.is_paused, "初始不应暂停")
	hud._toggle_pause()
	check(GameManager.is_paused and get_tree().paused, "暂停应生效")
	check(hud.get_node("PauseMenu").visible, "暂停菜单应显示")
	hud._toggle_pause()
	check(not GameManager.is_paused, "再次切换应恢复")
	hud._toggle_backpack()
	check(hud.get_node("BackpackPanel").visible, "背包面板应打开")
	EconomyManager.deposit("gold", 3)
	check(hud.get_node("BackpackPanel").get_node("VBox/GoldLabel").text == "金币 3", "背包应显示金币")
	hud._toggle_backpack()
	check(not hud.get_node("BackpackPanel").visible, "背包面板应关闭")
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
