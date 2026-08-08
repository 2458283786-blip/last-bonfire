extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
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
	var bar: PanelContainer = hud.get_node("TopBar")
	check(bar.visible, "顶栏应常驻显示")
	check(bar.get_node("HBox/DayLabel").text == "第 1 天", "天数应显示第 1 天")
	check(bar.get_node("HBox/WoodLabel").text == "木头 10", "木材标签初始值")
	check(bar.get_node("HBox/CapacityLabel").text == "库存 15/20", "容量标签初始值")
	EconomyManager.deposit("wood", 3)
	check(bar.get_node("HBox/WoodLabel").text == "木头 13", "资源标签应随库存刷新")
	DayManager.advance_day()
	check(bar.get_node("HBox/DayLabel").text == "第 2 天", "天数推进后标签应刷新")
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	var hp_bar := bar.get_node("HBox/HealthBar") as ProgressBar
	check(hp_bar.max_value == player.max_hp, "血条最大值应来自玩家")
	player.take_damage(30.0)
	await get_tree().process_frame
	check(int(hp_bar.value) == 70, "血条应随玩家血量刷新")
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
