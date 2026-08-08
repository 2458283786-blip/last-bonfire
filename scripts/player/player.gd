class_name Player
extends CharacterBody2D
## 玩家角色：移动 / 跳跃 / 近战 / 弓箭。
## 移动与跳跃参数集中在下方 @export，便于后续迁移到 resources/data 配置。

## 行走速度（像素/秒）
@export var move_speed: float = 260.0
## 跳跃初速度（负值向上）
@export var jump_velocity: float = -420.0
## 重力加速度
@export var gravity: float = 1200.0

## 攻击命中框持续时长（秒）
@export var attack_duration: float = 0.25
## 攻击冷却（秒）
@export var attack_cooldown: float = 0.5
## 射箭冷却（秒）
@export var bow_cooldown: float = 0.6
## 箭矢飞行速度
@export var arrow_speed: float = 520.0
## 箭矢场景（arrow.tscn）
@export var arrow_scene: PackedScene

var facing := 1
var is_attacking := false
var attack_timer := 0.0
var attack_cooldown_timer := 0.0
var bow_cooldown_timer := 0.0
var _prev_jump_pressed := false
var _prev_attack_pressed := false
var _prev_bow_pressed := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var bow_spawn: Marker2D = $BowSpawn

func _ready() -> void:
	add_to_group("players")
	sprite.sprite_frames = PlayerAnimations.build_sprite_frames()
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0:
		facing = 1 if dir > 0 else -1
	velocity.x = dir * move_speed
	var jump_pressed := Input.is_action_pressed("jump")
	if jump_pressed and not _prev_jump_pressed and is_on_floor():
		velocity.y = jump_velocity
	_prev_jump_pressed = jump_pressed
	var attack_pressed := Input.is_action_pressed("attack")
	if attack_pressed and not _prev_attack_pressed:
		try_attack()
	_prev_attack_pressed = attack_pressed
	var bow_pressed := Input.is_action_pressed("bow")
	if bow_pressed and not _prev_bow_pressed:
		try_shoot_bow()
	_prev_bow_pressed = bow_pressed
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
	if attack_cooldown_timer > 0.0 or is_attacking:
		return
	is_attacking = true
	attack_timer = attack_duration
	attack_cooldown_timer = attack_cooldown
	attack_hitbox.monitoring = true

func try_shoot_bow() -> void:
	if bow_cooldown_timer > 0.0:
		return
	bow_cooldown_timer = bow_cooldown
	var arrow: Arrow = arrow_scene.instantiate()
	arrow.add_to_group("arrows")
	get_parent().add_child(arrow)
	arrow.global_position = bow_spawn.global_position
	arrow.setup(Vector2(facing, 0), arrow_speed)

func _update_visual() -> void:
	sprite.flip_h = facing < 0
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * facing
	bow_spawn.position.x = absf(bow_spawn.position.x) * facing
	if is_attacking:
		sprite.play("attack")
	elif not is_on_floor():
		sprite.play("jump")
	elif absf(velocity.x) > 10.0:
		sprite.play("run")
	else:
		sprite.play("idle")
