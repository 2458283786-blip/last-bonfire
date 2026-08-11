class_name CombatRoom
extends DungeonRoom
## 战斗/精英房：按节点 enemy_ids 生成敌人，清场后激活出口。

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/basic_enemy.tscn")

var _spawned: Array[Node] = []

func _populate(node: DungeonNodeData) -> void:
	var markers := get_tree().get_nodes_in_group("room_enemy_spawn")
	for i in node.enemy_ids.size():
		var enemy := enemy_scene.instantiate() as Enemy
		enemy.data = EnemyDatabase.get_data(node.enemy_ids[i])
		add_child(enemy)
		if not markers.is_empty():
			enemy.global_position = (markers[i % markers.size()] as Node2D).global_position
		_spawned.append(enemy)

func is_cleared() -> bool:
	# 注意：lambda 参数不能强类型 Node——数组里可能含已释放对象，强类型转换会报错。
	return _spawned.all(func(e) -> bool: return not is_instance_valid(e))
