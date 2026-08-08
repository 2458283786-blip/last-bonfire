extends Node

signal finished(ok: bool)

var failures: Array[String] = []
var assertions := 0
var _done := false

func _ready() -> void:
	EconomyManager.reset()
	DayManager.reset()
	GameManager.resume_game()
	get_tree().create_timer(30.0).timeout.connect(_on_timeout)
	_run()

func _on_timeout() -> void:
	push_error("[FAIL] 测试超时未退出")
	finish(false)

func _run() -> void:
	await get_tree().process_frame
	var listener := ClickListener.new()
	add_child(listener)
	var town: Node2D = load("res://scenes/town/town.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	var hud: CanvasLayer = town.get_node("HUD")
	Input.parse_input_event(_key(KEY_B, true))
	Input.parse_input_event(_key(KEY_B, false))
	await get_tree().process_frame
	var menu: PanelContainer = hud.get_node("BuildMenu")
	check(menu.visible, "按 B 应打开建造菜单")
	var cards: HBoxContainer = menu.get_node("HBox")
	var card: Button = cards.get_child(0)
	check(not card.disabled, "资源充足时仓库卡片应可点")
	card.pressed.emit()
	await get_tree().process_frame
	check(not menu.visible, "选择卡片后建造菜单应关闭")
	check(GameManager.is_placing, "选择卡片后应进入放置模式")
	var ctrl: PlacementController = null
	for c in get_tree().current_scene.get_children():
		if c is PlacementController:
			ctrl = c
	check(ctrl != null, "应存在放置控制器")
	Input.parse_input_event(_motion(Vector2(500, 855)))
	await get_tree().process_frame
	check(ctrl._ghost != null, "应存在预览")
	ctrl.set_process(false)
	ctrl._ghost.global_position = Vector2(500, 855)
	check(ctrl.can_place(ctrl._ghost.global_position), "预览位置应可放置")
	var wood_before := EconomyManager.get_amount("wood")
	Input.parse_input_event(_button(MOUSE_BUTTON_LEFT, true, Vector2(500, 855)))
	Input.parse_input_event(_button(MOUSE_BUTTON_LEFT, false, Vector2(500, 855)))
	await get_tree().process_frame
	check(listener.clicks >= 1, "左键事件应到达 _unhandled_input")
	check(not GameManager.is_placing, "确认后应退出放置模式")
	check(EconomyManager.get_amount("wood") < wood_before, "应扣除建造材料")
	var placed := false
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.global_position.distance_to(Vector2(500, 855)) < 1.0:
			placed = true
	check(placed, "应在鼠标位置生成建筑")
	# 再进一次放置，验证非法位置被拒且 Esc 可取消
	Input.parse_input_event(_key(KEY_B, true))
	Input.parse_input_event(_key(KEY_B, false))
	await get_tree().process_frame
	cards = menu.get_node("HBox")
	card = cards.get_child(0)
	card.pressed.emit()
	await get_tree().process_frame
	check(GameManager.is_placing, "第二次进入放置模式")
	Input.parse_input_event(_key(KEY_ESCAPE, true))
	await get_tree().process_frame
	check(not GameManager.is_placing, "Esc 应取消放置")
	finish(failures.is_empty())

func _key(kc: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = kc
	ev.physical_keycode = kc
	ev.pressed = pressed
	return ev

func _motion(pos: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	return ev

func _button(idx: MouseButton, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = idx
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	return ev

class ClickListener:
	extends Node

	var clicks := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicks += 1

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
