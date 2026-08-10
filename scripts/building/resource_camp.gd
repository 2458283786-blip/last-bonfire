class_name ResourceCamp
extends Building
## 资源生成建筑基类：在周围环形生成固定数量的资源节点（城内树/石头）。
## 新资源建筑 = 子类 + 场景配置 resource_scene，无需复制生成逻辑。

## 生成的资源节点场景（tree.tscn / rock.tscn）
@export var resource_scene: PackedScene
## 生成几棵/几块资源
@export var resource_count: int = 6
## 资源围绕建筑的分布半径
@export var spawn_radius: float = 120.0

func _ready() -> void:
	super._ready()
	_spawn_resources()

func _spawn_resources() -> void:
	if resource_scene == null:
		return
	for i in resource_count:
		var angle := TAU * i / resource_count
		var node: ResourceNode = resource_scene.instantiate()
		add_child(node)
		node.position = Vector2.from_angle(angle) * spawn_radius

## 建筑被摧毁：场内资源随之下线（删除），重建后重新生成满编。
func _on_function_offline() -> void:
	for child in get_children():
		if child is ResourceNode:
			child.queue_free()

func _on_function_online() -> void:
	if _resource_children_count() == 0:
		_spawn_resources()

func _resource_children_count() -> int:
	var count := 0
	for child in get_children():
		if child is ResourceNode:
			count += 1
	return count
