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
## 每升一级额外生成的资源数量
@export var resources_per_level: int = 3

func _ready() -> void:
	super._ready()
	_spawn_resources_until(effective_resource_count())

func effective_resource_count() -> int:
	return resource_count + maxi(level - 1, 0) * resources_per_level

## 补足式生成：把场内资源补到有效数量（幂等）。
func _spawn_resources_until(count: int) -> void:
	if resource_scene == null:
		return
	var current := _resource_children_count()
	for i in range(current, count):
		# 基础环在 spawn_radius，升级新增的资源放到外层环，避免与旧节点重叠。
		var radius := spawn_radius
		if i >= resource_count:
			radius = spawn_radius * 1.3
		var angle := TAU * (i % maxi(resource_count, 1)) / maxi(resource_count, 1)
		var node: ResourceNode = resource_scene.instantiate()
		add_child(node)
		node.position = Vector2.from_angle(angle) * radius

## 建筑被摧毁：场内资源随之下线（删除），重建后重新生成满编。
func _on_function_offline() -> void:
	for child in get_children():
		if child is ResourceNode:
			child.queue_free()

func _on_function_online() -> void:
	_spawn_resources_until(effective_resource_count())

func _apply_level_effects() -> void:
	if not is_destroyed:
		_spawn_resources_until(effective_resource_count())

func _resource_children_count() -> int:
	var count := 0
	for child in get_children():
		if child is ResourceNode:
			count += 1
	return count
