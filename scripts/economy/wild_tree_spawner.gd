class_name WildTreeSpawner
extends Node2D
## 野外树生成器：在配置区域内按限量随机生成野生树，每天检查并补足数量。
## 树的重生由 ResourceNode 按天数处理；生成器只负责把可用野生树补到 max_trees。

## 要生成的树场景（默认用 tree.tscn）
@export var tree_scene: PackedScene
## 允许长树的矩形区域（世界坐标）。留空时改用子节点 Area2D 画出的可视区域
@export var zones: Array[Rect2] = []
## 野外树数量上限（含已砍倒还没重生的）
@export var max_trees: int = 10
## 两棵树之间的最小间距，避免重叠
@export var min_spacing: float = 64.0

func _ready() -> void:
	add_to_group("wild_spawners")
	DayManager.day_changed.connect(_on_day_changed)
	_refill()

func _on_day_changed(_day: int) -> void:
	_refill()

func count_available_wild() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("resources"):
		var tree := node as ResourceNode
		if tree != null and tree.is_wild and not tree.is_depleted:
			count += 1
	return count

func _refill() -> void:
	if tree_scene == null:
		return
	var missing := max_trees - count_available_wild()
	for i in missing:
		var pos := _random_free_position()
		if pos == Vector2.INF:
			break
		var tree: ResourceNode = tree_scene.instantiate()
		tree.is_wild = true
		get_parent().add_child(tree)
		tree.global_position = pos

## 获取允许种树的区域：优先用 Inspector 里填的 zones；
## 没填时，把生成器下面的 Area2D 子节点（带矩形碰撞框）当作可视区域。
func _get_zones() -> Array[Rect2]:
	if not zones.is_empty():
		return zones
	var visual_zones: Array[Rect2] = []
	for child in get_children():
		var area := child as Area2D
		if area == null:
			continue
		var rect_shape: RectangleShape2D = null
		for sub in area.get_children():
			var shape_node := sub as CollisionShape2D
			if shape_node != null:
				rect_shape = shape_node.shape as RectangleShape2D
				break
		if rect_shape == null:
			continue
		var size := rect_shape.size
		visual_zones.append(Rect2(area.global_position - size * 0.5, size))
	return visual_zones

func _random_free_position() -> Vector2:
	var active_zones := _get_zones()
	if active_zones.is_empty():
		return Vector2.INF
	for attempt in 30:
		var zone: Rect2 = active_zones.pick_random()
		var pos := Vector2(
			randf_range(zone.position.x, zone.position.x + zone.size.x),
			randf_range(zone.position.y, zone.position.y + zone.size.y))
		if _is_position_free(pos):
			return pos
	return Vector2.INF

func _is_position_free(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("resources"):
		var n := node as Node2D
		if n != null and n.global_position.distance_to(pos) < min_spacing:
			return false
	return true
