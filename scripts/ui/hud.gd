extends CanvasLayer
## 玩家 HUD：血条显示。后续在此扩展资源/天数/建筑菜单等 UI。

@onready var health_bar: ProgressBar = $HealthBar

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	var player := players[0] as Player
	if player == null:
		return
	health_bar.max_value = player.max_hp
	health_bar.value = player.hp
