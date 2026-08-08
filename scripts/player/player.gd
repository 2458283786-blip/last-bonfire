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
## 最大生命值（血条制）
@export var max_hp: float = 100.0
## 受击无敌时长（秒）
@export var invincible_time: float = 1.0
## 近战攻击力
@export var attack_damage: int = 1

var facing := 1
var is_attacking := false
var attack_timer := 0.0
var attack_cooldown_timer := 0.0
var bow_cooldown_timer := 0.0
var hp: float = 100.0
var invincible_timer := 0.0
var is_dead := false
var _prev_jump_pressed := false
var _prev_attack_pressed := false
var _prev_bow_pressed := false
var _attack_hits_applied := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var bow_spawn: Marker2D = $BowSpawn
@onready var pickup_area: Area2D = $PickupArea

func _ready() -> void:
	add_to_group("players")
	hp = max_hp
	pickup_area.area_entered.connect(_on_pickup_area_entered)
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
	invincible_timer = maxf(invincible_timer - delta, 0.0)
	move_and_slide()
	_update_visual()

## 受击：扣除血量并进入无敌；血量归零回篝火复活（无彻底失败）。
func take_damage(amount: float) -> void:
	if is_dead or invincible_timer > 0.0:
		return
	hp -= amount
	invincible_timer = invincible_time
	if hp <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	hp = max_hp
	invincible_timer = invincible_time
	var bonfire := _nearest_in_group("bonfires")
	if bonfire != null:
		global_position = (bonfire as Node2D).global_position
	is_dead = false
	EventBus.player_died.emit()

func _nearest_in_group(group: String) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node2D
		if n == null:
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_dist:
			best_dist = d
			best = n
	return best

func _tick_timers(delta: float) -> void:
	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)
	bow_cooldown_timer = maxf(bow_cooldown_timer - delta, 0.0)
	if is_attacking:
		if not _attack_hits_applied and _apply_attack_hits():
			_attack_hits_applied = true
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
	_attack_hits_applied = false

## 攻击命中结算：对命中框内的敌人造成一次伤害；命中任意敌人返回 true。
func _apply_attack_hits() -> bool:
	var hit_any := false
	for body in attack_hitbox.get_overlapping_bodies():
		if body is Enemy:
			body.take_damage(attack_damage)
			hit_any = true
	return hit_any

## 走过拾取物自动拾取入库。
func _on_pickup_area_entered(area: Area2D) -> void:
	var pickup := area as Pickup
	if pickup == null:
		return
	var got := pickup.take()
	if not got.is_empty():
		EconomyManager.deposit(str(got["resource_id"]), int(got["amount"]))

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
