extends Label
## 底部交互提示：玩家靠近 interactables 组内的可交互物时显示。

func _process(_delta: float) -> void:
	var player := _get_player()
	if player == null:
		visible = false
		return
	var ia := _nearest_interactable(player.global_position)
	if ia != null:
		text = ia.prompt
		visible = true
	else:
		visible = false

func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	return players[0] as Node2D if not players.is_empty() else null

func _nearest_interactable(pos: Vector2) -> Interactable:
	var best: Interactable = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("interactables"):
		var ia := node as Interactable
		if ia == null:
			continue
		var d := pos.distance_to(ia.global_position)
		if d <= ia.interact_radius and d < best_dist:
			best_dist = d
			best = ia
	return best
