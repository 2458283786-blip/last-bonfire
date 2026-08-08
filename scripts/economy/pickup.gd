class_name Pickup
extends Area2D
## 掉落物：居民砍伐后生成，待居民捡起；无碰撞。

@export var resource_id: String = "wood"
@export var amount: int = 1

var taken := false

func _ready() -> void:
	add_to_group("pickups")

func take() -> Dictionary:
	if taken:
		return {}
	taken = true
	queue_free()
	return {"resource_id": resource_id, "amount": amount}
