extends Node2D
## 探索关卡（线性 demo）：入口 → 战斗房 ×2 → 宝箱房 → Boss 房。
## 房间按 x 区间划分，墙体留门洞；敌人/宝箱由场景配置生成。
## 后续可替换为房间预制件库拼装（关卡结构不变）。

func _ready() -> void:
	print("[Dungeon] 探索关卡已加载。")
	var players := get_tree().get_nodes_in_group("players")
	var spawn := get_node_or_null("PlayerSpawn") as Marker2D
	if not players.is_empty() and spawn != null:
		players[0].global_position = spawn.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	for node in get_tree().get_nodes_in_group("interactables"):
		var ia := node as Interactable
		if ia != null and ia.try_interact(players[0].global_position):
			return
