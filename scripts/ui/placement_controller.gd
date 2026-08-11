class_name PlacementController
extends Node2D
## 放置控制器：进入放置模式后鼠标跟随预览，左键确认扣费生成，右键/Esc 取消。
## 预览用色块占位，不实例化真实建筑（避免触发建筑 _ready 副作用）。

signal placement_confirmed(data: BuildingData, pos: Vector2)
signal placement_canceled
signal placement_rejected(reason: String)

## 可放置区域（世界坐标）
@export var bounds: Rect2 = Rect2(50, 800, 1820, 120)
## 建筑落地 y（放置时自动吸附）
@export var ground_y: float = 855.0
## 与地面允许的 y 偏差
@export var ground_tolerance: float = 30.0
## 与已有建筑的最小间距
@export var min_spacing: float = 96.0

var data: BuildingData = null
var _ghost: Node2D = null
var _active := false

func begin(data_: BuildingData) -> void:
	data = data_
	_active = true
	var ghost := Node2D.new()
	var rect := ColorRect.new()
	rect.size = Vector2(data.footprint_half_width * 2.0, 48.0)
	rect.position = Vector2(-data.footprint_half_width, -24.0)
	rect.color = data.icon_color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(rect)
	add_child(ghost)
	_ghost = ghost

func cancel() -> void:
	if not _active:
		return
	_active = false
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	placement_canceled.emit()

func _process(_delta: float) -> void:
	if not _active or _ghost == null:
		return
	var pos := get_global_mouse_position()
	pos.y = ground_y
	_ghost.global_position = pos
	_ghost.modulate = Color(0.4, 1.0, 0.4, 0.7) if can_place(pos) else Color(1.0, 0.4, 0.4, 0.7)

func can_place(pos: Vector2) -> bool:
	if not bounds.has_point(pos):
		return false
	if absf(pos.y - ground_y) > ground_tolerance:
		return false
	for node in get_tree().get_nodes_in_group("buildings"):
		var b := node as Node2D
		if b == null:
			continue
		if b is Building and b.is_destroyed:
			continue
		if pos.distance_to(b.global_position) < min_spacing:
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_confirm()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		_confirm()

func _confirm() -> void:
	if not _active or _ghost == null:
		return
	var pos := _ghost.global_position
	if not can_place(pos):
		placement_rejected.emit(_reject_reason(pos))
		return
	for id in data.cost:
		if not DebugManager.skip_costs and EconomyManager.get_amount(id) < int(data.cost[id]):
			placement_rejected.emit("资源不足，无法建造")
			return
	if not DebugManager.skip_costs:
		for id in data.cost:
			EconomyManager.withdraw(id, int(data.cost[id]))
	var building := data.scene.instantiate()
	get_parent().add_child(building)
	building.global_position = pos
	_ghost.queue_free()
	_ghost = null
	_active = false
	EventBus.building_built.emit(data.id)
	placement_confirmed.emit(data, pos)

func _reject_reason(pos: Vector2) -> String:
	if not bounds.has_point(pos):
		return "超出可建造区域"
	if absf(pos.y - ground_y) > ground_tolerance:
		return "位置高度不合适"
	for node in get_tree().get_nodes_in_group("buildings"):
		var b := node as Node2D
		if b == null:
			continue
		if b is Building and b.is_destroyed:
			continue
		if pos.distance_to(b.global_position) < min_spacing:
			return "与已有建筑过近"
	return "位置不可建造"
