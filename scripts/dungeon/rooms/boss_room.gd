class_name BossRoom
extends DungeonRoom
## BOSS 房：生成阶段 BOSS，击杀后阶段完成/通关。

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/boss_enemy.tscn")

var _boss: Node = null

func _populate(node: DungeonNodeData) -> void:
	if node.enemy_ids.is_empty():
		return
	var boss := enemy_scene.instantiate() as Enemy
	boss.data = EnemyDatabase.get_data(node.enemy_ids[0])
	add_child(boss)
	var marker := get_tree().get_first_node_in_group("room_boss_spawn") as Node2D
	if marker != null:
		boss.global_position = marker.global_position
	_boss = boss

func is_cleared() -> bool:
	return _boss == null or not is_instance_valid(_boss)
