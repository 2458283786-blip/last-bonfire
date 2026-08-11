class_name RescueRoom
extends DungeonRoom
## 救援房：守卫清完后可解救被囚居民（救援数受每局上限约束）。

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/basic_enemy.tscn")

var _guards: Array[Node] = []
var _rescued := false

func _populate(node: DungeonNodeData) -> void:
	var markers := get_tree().get_nodes_in_group("room_enemy_spawn")
	for i in node.enemy_ids.size():
		var enemy := enemy_scene.instantiate() as Enemy
		enemy.data = EnemyDatabase.get_data(node.enemy_ids[i])
		add_child(enemy)
		if not markers.is_empty():
			enemy.global_position = (markers[i % markers.size()] as Node2D).global_position
		_guards.append(enemy)

func _process(delta: float) -> void:
	super._process(delta)
	var cage := get_node_or_null("Cage")
	if cage != null and cage.has_method("set_active"):
		var guards_clear := _guards.all(func(g) -> bool: return not is_instance_valid(g))
		cage.set_active(not _rescued and guards_clear)

func is_cleared() -> bool:
	return _rescued

func on_rescue() -> void:
	if _rescued:
		return
	_rescued = true
	DungeonManager.rescue_villager()
	var label := get_node_or_null("RescueLabel") as Label
	if label != null:
		label.text = "居民获救了！回到城镇后加入"
		label.visible = true
