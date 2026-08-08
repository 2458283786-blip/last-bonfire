extends Node2D
## 临时调试脚本：加载真实城镇场景，观测居民状态与资源变化。

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var town: Node2D = (load("res://scenes/town/town.tscn") as PackedScene).instantiate()
	add_child(town)
	for i in 20:
		await get_tree().physics_frame
	for frame in 720:
		await get_tree().physics_frame
		if frame % 90 == 0:
			print("=== tick ", frame)
			print("  stock wood=", EconomyManager.get_amount("wood"),
					" stone=", EconomyManager.get_amount("stone"), " cap=", EconomyManager.capacity)
			var villager_idx := 0
			for v in get_tree().get_nodes_in_group("villagers"):
				villager_idx += 1
				var vg := v as Villager
				print("  villager", villager_idx, " pos=", vg.global_position,
						" job=", vg.job, " state=", vg.state, " carry=", vg.carry)
			var tree_count := 0
			var depleted_count := 0
			for r in get_tree().get_nodes_in_group("resources"):
				var t := r as ResourceNode
				if t != null:
					tree_count += 1
					if t.is_depleted:
						depleted_count += 1
			print("  trees total=", tree_count, " depleted=", depleted_count)
	print("=== done")
	get_tree().quit(0)
