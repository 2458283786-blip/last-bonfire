class_name ResourceNode
extends Area2D
## 可砍伐/挖掘的资源（树/石头）：无物理碰撞（只有 Area2D），
## 靠预留机制被居民砍伐，按游戏天数重生。

signal depleted(node: ResourceNode)

@export var data: ResourceData
@export var pickup_scene: PackedScene
@export var instance_id: String = ""

var current_hp := 0
var reserved_by := -1
var is_depleted := false
var respawn_day := -1
var is_wild := false

@onready var visual: CanvasItem = $Visual

func _ready() -> void:
	add_to_group("resources")
	current_hp = data.max_hp
	DayManager.day_changed.connect(_on_day_changed)
	_update_visual()

func try_reserve(worker_id: int) -> bool:
	if is_depleted or (reserved_by != -1 and reserved_by != worker_id):
		return false
	reserved_by = worker_id
	return true

func release_reservation(worker_id: int) -> void:
	if reserved_by == worker_id:
		reserved_by = -1

func chop(worker_id: int, amount: int) -> void:
	if is_depleted or (reserved_by != -1 and reserved_by != worker_id):
		return
	reserved_by = worker_id
	current_hp -= amount
	if current_hp <= 0:
		_deplete()

func _deplete() -> void:
	is_depleted = true
	reserved_by = -1
	respawn_day = DayManager.day + data.respawn_days
	if pickup_scene != null:
		var pickup: Pickup = pickup_scene.instantiate()
		pickup.resource_id = data.drop_resource
		pickup.amount = data.drop_amount
		get_parent().add_child(pickup)
		pickup.global_position = global_position
	_update_visual()
	depleted.emit(self)

func _on_day_changed(day: int) -> void:
	if is_depleted and day >= respawn_day:
		current_hp = data.max_hp
		is_depleted = false
		respawn_day = -1
		_update_visual()

func _update_visual() -> void:
	visible = not is_depleted
