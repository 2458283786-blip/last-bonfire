class_name LumberCamp
extends Node2D
## 伐木场（资源生成建筑）：在周围生成固定数量的城内树，供伐木工砍伐。

## 生成的城内树场景（默认 tree.tscn）
@export var tree_scene: PackedScene
## 在伐木场周围生成几棵树
@export var tree_count: int = 6
## 树围绕伐木场的分布半径
@export var spawn_radius: float = 120.0

func _ready() -> void:
	add_to_group("lumber_camps")
	_spawn_trees()

func _spawn_trees() -> void:
	if tree_scene == null:
		return
	for i in tree_count:
		var angle := TAU * i / tree_count
		var tree: ResourceNode = tree_scene.instantiate()
		add_child(tree)
		tree.position = Vector2.from_angle(angle) * spawn_radius
