class_name Player
extends CharacterBody2D
## 玩家角色：移动 / 跳跃 / 近战 / 弓箭。
## 移动与跳跃参数集中在下方 @export，便于后续迁移到 resources/data 配置。

@export var move_speed: float = 260.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 1200.0

@export var attack_duration: float = 0.25
@export var attack_cooldown: float = 0.5
@export var bow_cooldown: float = 0.6
@export var arrow_speed: float = 520.0
@export var arrow_scene: PackedScene

var facing := 1
var is_attacking := false
var attack_timer := 0.0
var attack_cooldown_timer := 0.0
var bow_cooldown_timer := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var bow_spawn: Marker2D = $BowSpawn

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0:
		facing = 1 if dir > 0 else -1
	velocity.x = dir * move_speed
	if Input.is_action_just_pressed("attack"):
		try_attack()
	if Input.is_action_just_pressed("bow"):
		try_shoot_bow()
	_tick_timers(delta)
	move_and_slide()
	_update_visual()

func _tick_timers(delta: float) -> void:
	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)
	bow_cooldown_timer = maxf(bow_cooldown_timer - delta, 0.0)
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			is_attacking = false
			attack_hitbox.monitoring = false

func try_attack() -> void:
	# Task 5 实现：进入攻击状态并启用命中框
	pass

func try_shoot_bow() -> void:
	# Task 6 实现：生成箭矢
	pass

func _update_visual() -> void:
	sprite.flip_h = facing < 0
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * facing
	bow_spawn.position.x = absf(bow_spawn.position.x) * facing
