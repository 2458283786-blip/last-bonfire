class_name BuildingSelector
extends Node2D
## 点击建筑打开详情：左键点击时找最近建筑（含点击容差），点击 UI 时不会触发。

signal building_selected(building: Building)

## 点击判定半径
@export var click_radius: float = 80.0

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_placing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var b := _nearest_building(get_global_mouse_position(), click_radius)
		if b != null:
			building_selected.emit(b)

func _nearest_building(pos: Vector2, max_dist: float) -> Building:
	var best: Building = null
	var best_dist := max_dist
	for node in get_tree().get_nodes_in_group("buildings"):
		var b := node as Building
		if b == null or b.is_destroyed:
			continue
		var d := pos.distance_to(b.global_position)
		if d <= best_dist:
			best_dist = d
			best = b
	return best
