class_name Interactable
extends Node2D
## 可交互物：玩家靠近时由 InteractHint 显示提示，按 E 触发。

@export var prompt: String = "按 E 交互"
@export var interact_radius: float = 80.0

signal interacted

func _ready() -> void:
	add_to_group("interactables")

func try_interact(player_pos: Vector2) -> bool:
	if global_position.distance_to(player_pos) <= interact_radius:
		interacted.emit()
		return true
	return false
