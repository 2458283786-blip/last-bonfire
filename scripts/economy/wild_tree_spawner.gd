class_name WildTreeSpawner
extends Node2D
## 野外树生成器：在配置区域内按限量随机生成野生树，每天检查并补足数量。
## 树的重生由 ResourceNode 按天数处理；生成器只负责把可用野生树补到 max_trees。

@export var tree_scene: PackedScene
@export var zones: Array[Rect2] = []
@export var max_trees: int = 10
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

func _random_free_position() -> Vector2:
	if zones.is_empty():
		return Vector2.INF
	for attempt in 30:
		var zone: Rect2 = zones.pick_random()
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
