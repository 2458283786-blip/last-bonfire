class_name ChestRoom
extends DungeonRoom
## 宝箱房：按节点 loot 生成拾取物，拾光后激活出口。

@export var pickup_scene: PackedScene = preload("res://scenes/resources/pickup.tscn")

var _spawned: Array[Node] = []

func _populate(node: DungeonNodeData) -> void:
	var markers := get_tree().get_nodes_in_group("room_pickup_spawn")
	var i := 0
	for entry in node.loot:
		var count := randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
		for k in count:
			var pickup := pickup_scene.instantiate()
			add_child(pickup)
			if not markers.is_empty():
				pickup.global_position = (markers[i % markers.size()] as Node2D).global_position + Vector2(k * 24, 0)
			pickup.resource_id = str(entry.get("resource_id", "gold"))
			pickup.amount = 1
			_spawned.append(pickup)
		i += 1

func is_cleared() -> bool:
	return _spawned.all(func(p) -> bool: return not is_instance_valid(p))
