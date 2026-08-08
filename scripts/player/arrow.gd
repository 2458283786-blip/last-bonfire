class_name Arrow
extends Area2D
## 箭矢投射物：沿固定方向飞行，命中物体或超时后消失。

## 箭矢伤害
@export var arrow_damage: int = 1

var direction := Vector2.RIGHT
var speed := 520.0
var lifetime := 2.0

func setup(dir: Vector2, spd: float) -> void:
	direction = dir.normalized()
	speed = spd

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(_body: Node2D) -> void:
	if _body is Enemy:
		_body.take_damage(arrow_damage)
	queue_free()
